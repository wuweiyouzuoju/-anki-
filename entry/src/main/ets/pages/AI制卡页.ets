// SPDX-License-Identifier: AGPL-3.0-or-later

// AI 制卡/改卡共享页：带结构化工具、可编辑草稿与显式确认的轻量 Agent。
// 由 首页.ets 通过 Navigation pathStack 以 NavDestination 形式入栈（与 添加笔记页 同机制）。
// 顶部：历史与 AI 配置；目标牌组和笔记类型位于本地对话设置卡。
// 中间：聊天消息流。AI 返回的卡片以草稿形式内嵌在 AI 消息里，可勾选、可编辑字段、批量保存。
// 底部：材料输入框 + 发送按钮。
// 所有写入都经 AgentDraftExecutor，最终仍只调用现有 Anki ArkTS Service。
// 不支持 Image Occlusion（走独立 RPC，本页直接从笔记类型候选中过滤）。

import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@ohos.base';
import { 后端会话 } from '../backend/后端会话';
import { 笔记服务, 笔记字段校验错误 } from '../backend/笔记服务';
import { 笔记类型服务 } from '../backend/笔记类型服务';
import { 卡片服务 } from '../backend/卡片服务';
import type { AgentEvent, AgentMode, AgentToolTrace, AgentToolTraceStatus, ChangeDraft, DraftOperation, ProviderId, SearchSource } from '../model/agent/AgentTypes';
import type { ProviderInputItem, ProviderTurnRequest } from '../model/agent/ProviderProtocol';
import { agentFunctionTools } from '../model/agent/AgentToolCatalog';
import { explicitWebSearchRequested } from '../model/agent/AgentPolicy';
import { DEEPSEEK_PROVIDER, OPENAI_PROVIDER } from '../model/agent/ProviderCatalog';
import { AgentRunner, AgentRunObserver, AgentRunResult } from '../backend/agent/AgentRunner';
import { AgentTransportError } from '../backend/agent/AgentTransport';
import { AgentScope } from '../backend/agent/AgentScope';
import { AgentToolRegistry } from '../backend/agent/AgentToolRegistry';
import { CardAgentTools } from '../backend/agent/CardAgentTools';
import { HighRiskAgentTools } from '../backend/agent/HighRiskAgentTools';
import {
  AgentDraftExecutionResult,
  AgentDraftExecutor,
  PreparedAgentDraft
} from '../backend/agent/AgentDraftExecutor';
import type { AgentConfirmationToken } from '../model/agent/AgentConfirmation';
import { buildFailedOperationsRetryDraft } from '../model/agent/AgentDraftRetry';
import type {
  AgentClarificationAnswer,
  AgentClarificationOption,
  AgentClarificationRequest,
  AgentClarificationState,
  AgentClarificationView
} from '../model/agent/AgentClarification';
import {
  buildClarificationAnswerText,
  buildClarificationAnswerVisibleText,
  cloneAgentClarificationView
} from '../model/agent/AgentClarification';
import type { AgentReadinessReason, AgentTaskSetup, AgentTaskSnapshot } from '../model/agent/AgentTaskContext';
import {
  buildAgentTaskProviderText,
  buildAgentTaskVisibleText,
  evaluateAgentReadiness
} from '../model/agent/AgentTaskContext';
import { agentContextFieldHasOmittedMedia, sanitizeAgentContextField } from '../model/agent/AgentMediaPolicy';
import { explicitYearClozeRequested, inferRequestedCardCount } from '../model/agent/AgentRequestIntent';
import {
  AgentSettings,
  defaultAgentSettings,
  loadAgentSettings,
  saveAgentSettings
} from '../backend/agent/AgentSettingsStore';
import { loadAgentSecret, saveAgentSecret } from '../backend/agent/AgentSecretStore';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';
import { CustomTransition } from '../utils/自定义转场';
import type { EditableNote } from '../proto/messages/NoteMessages';
import type { Card } from '../proto/messages/CardsMessages';
import { NOTE_TYPE_KIND_NORMAL } from '../proto/messages/NotetypeMessages';
import type { NotetypeCapabilities, NotetypeNameId } from '../proto/messages/NotetypeMessages';
import {
  AgentConversation,
  AgentHistoryAudit,
  AgentHistoryMessage,
  AgentHistoryResult,
  deleteAgentConversation,
  loadAgentConversations,
  saveAgentConversation
} from '../model/agent/AgentConversationStore';
import { AgentDisclosureCard } from '../components/agent/AgentDisclosureCard';
import { AgentSetupCard } from '../components/agent/AgentSetupCard';
import { AgentClarificationCard } from '../components/agent/AgentClarificationCard';

/** 建卡目标牌组候选（通过 Navigation param 传入） */
export interface AI制卡牌组选项 {
  id: number;
  name: string;
}

/** 笔记类型下拉候选 */
export interface AI制卡笔记类型选项 {
  id: number;
  name: string;
}

/** Navigation 入栈参数（与 添加笔记页参数 同风格） */
export interface AI制卡页参数 {
  mode?: AgentMode;
  deckId?: string;
  deckName?: string;
  deckOptions?: AI制卡牌组选项[];
  cardIds?: number[];
  noteIds?: number[];
  templateIdx?: number;
}

interface 页面AI配置 { apiKey: string; baseUrl: string; model: string; }

/** Select 组件使用的通用选项结构。 */
interface AI制卡下拉选项 {
  value: string;
}

/** 单张待确认卡片：fields 与当前笔记类型字段顺序一一对应。 */
interface 卡片草稿 {
  fields: string[];
  已选中: boolean;
  /** draft=待保存 saved=已入库 failed=保存失败（可再次保存） */
  状态: string;
  /** 保存失败原因（本地化文案），仅 状态=failed 时非空 */
  失败提示: string;
}

/** 一条聊天消息。 */
interface 聊天消息 {
  id: number;
  /** 'user' | 'ai' */
  角色: string;
  正文: string;
  /** AI 错误消息（红色展示，无卡片） */
  是否错误: boolean;
  /** 仅 AI 成功消息有；同一批卡共用该消息的字段名 */
  卡片列表: 卡片草稿[];
  /** 该批次笔记类型的真实字段名（渲染字段标签用） */
  字段名列表: string[];
  /** 本批保存结果文案；空串=尚未保存过 */
  批次结果: string;
  批次保存中: boolean;
  变更草稿列表: ChangeDraft[];
  工具过程: AgentToolTrace[];
  来源列表: SearchSource[];
  推理摘要: string;
  kind: string;
  clarification: AgentClarificationView | null;
  expanded: boolean;
  taskStatus: string;
  answerMessageId: number;
  providerText: string;
}

class 页面Agent观察者 implements AgentRunObserver {
  private readonly callback: (event: AgentEvent) => void;
  constructor(callback: (event: AgentEvent) => void) { this.callback = callback; }
  onEvent(event: AgentEvent): void { this.callback(event); }
}

@Component
export struct AI制卡页 {
  /** Navigation 入栈参数 */
  pageDeckId: string = '';
  pageDeckName: string = '';
  pageDeckOptions: AI制卡牌组选项[] = [];
  pageMode: AgentMode = 'create';
  pageCardIds: number[] = [];
  pageNoteIds: number[] = [];
  pageTemplateIdx: number = -1;
  /** 页面栈：关闭时 pop 返回首页 */
  pathStack: NavPathStack = new NavPathStack();

  private readonly 笔记服务实例: 笔记服务 = new 笔记服务();
  private readonly 笔记类型服务实例: 笔记类型服务 = new 笔记类型服务();
  private readonly 卡片服务实例: 卡片服务 = new 卡片服务();
  private readonly 聊天滚动器: Scroller = new Scroller();
  private readonly agentScope: AgentScope = new AgentScope();
  private readonly agentExecutor: AgentDraftExecutor = new AgentDraftExecutor();
  private agentRunner: AgentRunner | null = null;
  private 本地范围卡片IDs: number[] = [];
  private 本地范围笔记IDs: number[] = [];
  private 本地范围牌组IDs: number[] = [];
  private 本地范围笔记类型IDs: number[] = [];
  private conversationId: string = `agent-${Date.now()}-${Math.random()}`;
  private 历史执行结果: AgentHistoryResult[] = [];
  private omittedMediaInContext: boolean = false;

  @State private 消息列表: 聊天消息[] = [];
  @State private 输入草稿: string = '';
  @State private 处理中: boolean = false;
  @State private 牌组ID: number = 0;
  @State private 牌组选项: AI制卡牌组选项[] = [];
  @State private 已选笔记类型ID: number = 0;
  @State private 笔记类型选项: AI制卡笔记类型选项[] = [];
  @State private 笔记类型名: string = '';
  @State private 字段名列表: string[] = [];
  @State private noteTypeKind: number = NOTE_TYPE_KIND_NORMAL;
  @State private clozeFieldOrds: number[] = [];
  @State private AI配置: 页面AI配置 =
    { apiKey: '', baseUrl: DEEPSEEK_PROVIDER.baseUrl, model: DEEPSEEK_PROVIDER.defaultModel };
  private agentSettings: AgentSettings = defaultAgentSettings();
  @State private 页面Provider: ProviderId = 'deepseek';
  @State private 本地入口上下文: string = '';
  @State private 显示配置区: boolean = false;
  @State private 配置密钥输入: string = '';
  @State private 配置地址输入: string = '';
  @State private 配置模型输入: string = '';
  @State private 配置提示: string = '';
  @State private 错误信息: string = '';
  @State private setupExpanded: boolean = true;

  private 下一个消息ID值: number = 1;

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下色: string = '#1E4FB8';
  @StorageProp('导航条高度') private 导航条高度: number = 0;
  @StorageProp('状态栏高度') private 状态栏高度: number = 0;
  /** NavDestination 透明度（由 customNavContentTransition 回调控制，实现淡入淡出转场）。 */
  @State private 转场透明度: number = 1;

  // 图片遮盖第一版仍走独立 RPC；填空能力改由 Anki 后端结构提供，不再按名称猜测。
  private static readonly 图片遮盖笔记类型名集合: string[] = ['Image Occlusion', '图片遮盖', '影像遮擋'];

  async aboutToAppear(): Promise<void> {
    // 注册自定义转场回调：首页 Navigation.customNavContentTransition 通过此 name 查找回调
    CustomTransition.getInstance().注册NavParam('AiCardPage',
      (isPush: boolean, isExit: boolean): void => {
        this.转场透明度 = isExit ? 1 : 0;
      },
      (isPush: boolean, isExit: boolean): void => {
        this.转场透明度 = isExit ? 0 : 1;
      }
    );
    this.牌组选项 = this.pageDeckOptions;
    this.追加稳定IDs(this.本地范围卡片IDs, this.pageCardIds);
    this.追加稳定IDs(this.本地范围笔记IDs, this.pageNoteIds);
    this.追加稳定IDs(this.本地范围牌组IDs,
      this.pageDeckOptions.map((item: AI制卡牌组选项): number => item.id));
    const 入参牌组ID: number = this.pageDeckId === '' ? 0 : parseInt(this.pageDeckId);
    const 命中入参: boolean = this.牌组选项.some((项: AI制卡牌组选项): boolean => 项.id === 入参牌组ID);
    this.牌组ID = 命中入参 ? 入参牌组ID : 0;
    try {
      this.agentSettings = await loadAgentSettings();
    } catch (错误) {
      this.agentSettings = defaultAgentSettings();
    }
    const provider: ProviderId = this.agentSettings.selectedProvider;
    this.页面Provider = provider;
    const baseUrl: string = provider === 'deepseek' ? DEEPSEEK_PROVIDER.baseUrl :
      (provider === 'openai' ? OPENAI_PROVIDER.baseUrl : this.agentSettings.customBaseUrl);
    const model: string = provider === 'deepseek' ? this.agentSettings.deepseekModel :
      (provider === 'openai' ? this.agentSettings.openaiModel : this.agentSettings.customModel);
    this.AI配置 = { apiKey: await loadAgentSecret(provider), baseUrl: baseUrl, model: model };
    this.配置密钥输入 = this.AI配置.apiKey;
    this.配置地址输入 = this.AI配置.baseUrl;
    this.配置模型输入 = this.AI配置.model;
    await this.加载笔记类型列表();
    const registry: AgentToolRegistry = new AgentToolRegistry();
    new CardAgentTools(this.agentScope).register(registry, this.pageMode);
    if (this.pageMode === 'edit') { new HighRiskAgentTools(this.agentScope).register(registry); }
    this.agentRunner = new AgentRunner(registry);
    await this.加载本地入口上下文();
  }

  aboutToDisappear(): void {
    if (this.agentRunner !== null) { this.agentRunner.cancel(); }
    CustomTransition.getInstance().注销NavParam('AiCardPage');
  }

  private 追加稳定IDs(target: number[], values: number[]): void {
    for (const value of values) {
      if (value > 0 && target.indexOf(value) < 0) { target.push(value); }
    }
  }

  /** 每次用户发送前重建授权集合，上一轮工具搜索到的 ID 不会自动延续。 */
  private 重建本轮AgentScope(): void {
    this.agentScope.reset();
    this.agentScope.configureBatchLimit(this.agentSettings.batchLimit);
    this.agentScope.configureCreateTarget(
      this.pageMode === 'create' ? this.牌组ID : 0,
      this.pageMode === 'create' ? this.已选笔记类型ID : 0);
    this.agentScope.registerCardIds(this.本地范围卡片IDs);
    this.agentScope.registerNoteIds(this.本地范围笔记IDs);
    this.agentScope.registerDeckIds(this.本地范围牌组IDs);
    this.agentScope.registerNotetypeIds(this.本地范围笔记类型IDs);
    if (this.牌组ID > 0) { this.agentScope.registerDeckIds([this.牌组ID]); }
    if (this.已选笔记类型ID > 0) { this.agentScope.registerNotetypeIds([this.已选笔记类型ID]); }
  }

  /** 仅从本地 Anki Service 读取并显示，绝不在页面出现时调用 AgentRunner。 */
  private async 加载本地入口上下文(): Promise<void> {
    if (this.pageMode !== 'edit') { return; }
    const summary: string[] = [];
    const noteIds: number[] = this.pageNoteIds.slice();
    for (const cardId of this.pageCardIds) {
      try {
        const card: Card = await this.卡片服务实例.获取卡片(cardId);
        if (noteIds.indexOf(card.noteId) < 0) { noteIds.push(card.noteId); }
        this.追加稳定IDs(this.本地范围笔记IDs, [card.noteId]);
        this.追加稳定IDs(this.本地范围牌组IDs, [card.deckId]);
        summary.push(`card=${card.id} note=${card.noteId} deck=${card.deckId} template=${card.templateIdx}`);
      } catch (error) { summary.push(`card=${cardId} unavailable`); }
    }
    for (const noteId of noteIds) {
      try {
        const note: EditableNote = await this.笔记服务实例.获取笔记(noteId);
        const siblings: number[] = await this.笔记服务实例.获取笔记的卡片(noteId);
        this.追加稳定IDs(this.本地范围笔记类型IDs, [note.notetypeId]);
        this.追加稳定IDs(this.本地范围卡片IDs, siblings);
        const safeFields: string[] = [];
        for (const field of note.fields) {
          if (agentContextFieldHasOmittedMedia(field)) { this.omittedMediaInContext = true; }
          safeFields.push(sanitizeAgentContextField(field));
        }
        summary.push(`note=${note.id} type=${note.notetypeId} fields=${JSON.stringify(safeFields)} tags=${JSON.stringify(note.tags)} cards=${siblings.length}`);
      } catch (error) { summary.push(`note=${noteId} unavailable`); }
    }
    this.本地入口上下文 = summary.join('\n');
  }

  private 取能力上下文(): common.UIAbilityContext | null {
    const 上下文: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return 上下文 === undefined ? null : 上下文;
  }

  /** 读取本地化文案，context 不可用时回退空串。 */
  private 取本地化文案(资源: Resource): string {
    const 上下文: common.UIAbilityContext | null = this.取能力上下文();
    if (上下文 === null) {
      return '';
    }
    try {
      return 上下文.resourceManager.getStringSync(资源.id);
    } catch (错误) {
      return '';
    }
  }

  /** 交由 ResourceManager 处理 %s、%d 和带序号的本地化占位符。 */
  private 取本地化格式(资源: Resource, 参数: Array<string | number>): string {
    const 上下文: common.UIAbilityContext | null = this.取能力上下文();
    if (上下文 === null) { return ''; }
    try {
      return 上下文.resourceManager.getStringSync(资源.id, ...参数);
    } catch (错误) {
      return '';
    }
  }

  private selectedDeckName(): string {
    const selected: AI制卡牌组选项 | undefined = this.牌组选项.find(
      (item: AI制卡牌组选项): boolean => item.id === this.牌组ID);
    return selected === undefined ? '' : selected.name;
  }

  private selectedNotetypeName(): string {
    const selected: AI制卡笔记类型选项 | undefined = this.笔记类型选项.find(
      (item: AI制卡笔记类型选项): boolean => item.id === this.已选笔记类型ID);
    return selected === undefined ? this.笔记类型名 : selected.name;
  }

  private providerReady(): boolean {
    if (this.AI配置.apiKey.trim().length === 0 || this.AI配置.model.trim().length === 0) {
      return false;
    }
    return this.pageMode !== 'create' || this.页面Provider !== 'custom' ||
      this.AI配置.baseUrl.startsWith('https://');
  }

  private taskSetup(): AgentTaskSetup {
    return {
      mode: this.pageMode,
      deckId: this.pageMode === 'create' ? this.牌组ID : 0,
      deckName: this.pageMode === 'create' ? this.selectedDeckName() : '',
      notetypeId: this.pageMode === 'create' ? this.已选笔记类型ID : 0,
      notetypeName: this.pageMode === 'create' ? this.selectedNotetypeName() : '',
      fieldNames: this.pageMode === 'create' ? this.字段名列表.slice() : [],
      noteTypeKind: this.pageMode === 'create' ? this.noteTypeKind : NOTE_TYPE_KIND_NORMAL,
      clozeFieldOrds: this.pageMode === 'create' ? this.clozeFieldOrds.slice() : [],
      expanded: this.setupExpanded
    };
  }

  private hasPendingClarification(): boolean {
    for (const message of this.消息列表) {
      if (message.kind === 'clarification' && message.clarification !== null &&
        (message.clarification.state === 'pending' || message.clarification.state === 'submitting' ||
          message.clarification.state === 'submit_failed')) { return true; }
    }
    return false;
  }

  private readinessReason(): AgentReadinessReason {
    return evaluateAgentReadiness(this.taskSetup(), this.输入草稿,
      this.providerReady(), this.处理中 || this.hasPendingClarification());
  }

  private taskSnapshot(input: string): AgentTaskSnapshot {
    const setup: AgentTaskSetup = this.taskSetup();
    return {
      mode: setup.mode, deckId: setup.deckId, deckName: setup.deckName,
      notetypeId: setup.notetypeId, notetypeName: setup.notetypeName,
      fieldNames: setup.fieldNames.slice(), noteTypeKind: setup.noteTypeKind,
      clozeFieldOrds: setup.clozeFieldOrds.slice(), userText: input,
      localContext: this.本地入口上下文.length > 0 ? this.本地入口上下文 : '无预选卡片，可使用搜索工具。',
      omittedMedia: this.omittedMediaInContext,
      batchLimit: this.agentSettings.batchLimit
    };
  }

  private readinessText(): ResourceStr {
    const reason: AgentReadinessReason = this.readinessReason();
    if (reason === 'missing_deck') { return $r('app.string.ai_agent_setup_missing_deck'); }
    if (reason === 'missing_notetype') { return $r('app.string.ai_agent_setup_missing_notetype'); }
    if (reason === 'missing_input') { return $r('app.string.ai_agent_setup_missing_input'); }
    if (reason === 'missing_provider') { return $r('app.string.ai_agent_setup_missing_provider'); }
    if (reason === 'busy') { return $r('app.string.ai_agent_clarification_waiting'); }
    return $r('app.string.ai_agent_setup_ready');
  }

  private editSetupContext(): string {
    if (this.本地入口上下文.length > 0) { return this.本地入口上下文; }
    return this.取本地化文案($r('app.string.ai_agent_edit_search_welcome'));
  }

  // ========================================================
  // 笔记类型加载：拉取列表 → 过滤 Image Occlusion；只为明确选择加载能力。
  // ========================================================

  private async 加载笔记类型列表(): Promise<void> {
    const 上下文: common.UIAbilityContext | null = this.取能力上下文();
    if (上下文 === null) {
      this.错误信息 = this.取本地化文案($r('app.string.ai_card_err_no_notetype'));
      return;
    }
    try {
      await 后端会话.获取实例().确保已打开(上下文.filesDir);
      const 名称列表: NotetypeNameId[] = await this.笔记类型服务实例.获取笔记类型名列表();
      // 第一版不支持 Image Occlusion（独立 RPC 建卡流程），直接从候选中剔除
      const 可用列表: NotetypeNameId[] = 名称列表.filter(
        (项: NotetypeNameId): boolean =>
          AI制卡页.图片遮盖笔记类型名集合.indexOf(项.name) < 0);
      if (可用列表.length === 0) {
        this.错误信息 = this.取本地化文案($r('app.string.ai_card_err_no_notetype'));
        return;
      }
      this.笔记类型选项 = 可用列表.map((项: NotetypeNameId): AI制卡笔记类型选项 =>
        ({ id: 项.id, name: 项.name }));
      this.追加稳定IDs(this.本地范围笔记类型IDs,
        可用列表.map((item: NotetypeNameId): number => item.id));
      this.已选笔记类型ID = 0;
      this.笔记类型名 = '';
      this.字段名列表 = [];
    } catch (错误) {
      this.已选笔记类型ID = 0;
      this.笔记类型名 = '';
      this.字段名列表 = [];
      this.noteTypeKind = NOTE_TYPE_KIND_NORMAL;
      this.clozeFieldOrds = [];
      this.setupExpanded = true;
      this.错误信息 = this.取本地化文案($r('app.string.ai_card_err_no_notetype'));
    }
  }

  private async 加载笔记类型(notetypeId: number): Promise<void> {
    try {
      const 能力: NotetypeCapabilities = await this.笔记类型服务实例.获取笔记类型能力(notetypeId);
      this.已选笔记类型ID = 能力.notetypeId;
      this.笔记类型名 = 能力.name;
      this.字段名列表 = 能力.fieldNames;
      this.noteTypeKind = 能力.kind;
      this.clozeFieldOrds = 能力.clozeFieldOrds;
      this.错误信息 = '';
    } catch (错误) {
      this.已选笔记类型ID = 0;
      this.笔记类型名 = '';
      this.字段名列表 = [];
      this.noteTypeKind = NOTE_TYPE_KIND_NORMAL;
      this.clozeFieldOrds = [];
      this.setupExpanded = true;
      this.错误信息 = this.取本地化文案($r('app.string.ai_card_err_no_notetype'));
    }
  }

  // ========================================================
  // 消息流：不可变数据结构 + 整列表替换（与 添加笔记页 更新字段 同款思路）
  // 属性绑定统一经 this.消息列表[索引] 读取，保证 @State 重赋值后 UI 刷新。
  // ========================================================

  private 下一个消息ID(): number {
    const id: number = this.下一个消息ID值;
    this.下一个消息ID值++;
    return id;
  }

  private 空消息(角色: string, 正文: string, 是否错误: boolean): 聊天消息 {
    return {
      id: this.下一个消息ID(), 角色: 角色, 正文: 正文, 是否错误: 是否错误,
      卡片列表: [], 字段名列表: [], 批次结果: '', 批次保存中: false,
      变更草稿列表: [], 工具过程: [], 来源列表: [], 推理摘要: '',
      kind: 'normal', clarification: null, expanded: false, taskStatus: '',
      answerMessageId: 0, providerText: 正文
    };
  }

  private 克隆卡片(卡: 卡片草稿): 卡片草稿 {
    return {
      fields: 卡.fields.slice(),
      已选中: 卡.已选中,
      状态: 卡.状态,
      失败提示: 卡.失败提示
    };
  }

  private 克隆工具追踪(追踪: AgentToolTrace): AgentHistoryAudit {
    return {
      callId: 追踪.callId, toolName: 追踪.toolName, status: 追踪.status,
      providerRound: 追踪.providerRound, sequence: 追踪.sequence,
      argumentsJson: 追踪.argumentsJson, outputJson: 追踪.outputJson,
      errorCode: 追踪.errorCode, errorPath: 追踪.errorPath, errorMessage: 追踪.errorMessage,
      receivedKeys: 追踪.receivedKeys.slice(), allowedKeys: 追踪.allowedKeys.slice(),
      validTemplateJson: 追踪.validTemplateJson, repeatCount: 追踪.repeatCount,
      argumentsTruncated: 追踪.argumentsTruncated, outputTruncated: 追踪.outputTruncated,
      diagnosticTruncated: 追踪.diagnosticTruncated, expanded: 追踪.expanded,
      legacySummary: 追踪.legacySummary
    };
  }

  private 克隆历史审计(追踪: AgentToolTrace): AgentHistoryAudit {
    return {
      callId: 追踪.callId, toolName: 追踪.toolName, status: 追踪.status,
      providerRound: 追踪.providerRound, sequence: 追踪.sequence,
      argumentsJson: 追踪.argumentsJson, outputJson: 追踪.outputJson,
      errorCode: 追踪.errorCode, errorPath: 追踪.errorPath, errorMessage: 追踪.errorMessage,
      receivedKeys: 追踪.receivedKeys.slice(), allowedKeys: 追踪.allowedKeys.slice(),
      validTemplateJson: 追踪.validTemplateJson, repeatCount: 追踪.repeatCount,
      argumentsTruncated: 追踪.argumentsTruncated, outputTruncated: 追踪.outputTruncated,
      diagnosticTruncated: 追踪.diagnosticTruncated, expanded: 追踪.expanded,
      legacySummary: 追踪.legacySummary
    };
  }

  private 克隆消息(消息: 聊天消息): 聊天消息 {
    return {
      id: 消息.id,
      角色: 消息.角色,
      正文: 消息.正文,
      是否错误: 消息.是否错误,
      卡片列表: 消息.卡片列表.map((卡: 卡片草稿): 卡片草稿 => this.克隆卡片(卡)),
      字段名列表: 消息.字段名列表.slice(),
      批次结果: 消息.批次结果,
      批次保存中: 消息.批次保存中,
      变更草稿列表: 消息.变更草稿列表.slice(),
      工具过程: 消息.工具过程.map((追踪: AgentToolTrace): AgentToolTrace => this.克隆工具追踪(追踪)),
      来源列表: 消息.来源列表.slice(),
      推理摘要: 消息.推理摘要,
      kind: 消息.kind,
      clarification: 消息.clarification === null ? null : cloneAgentClarificationView(消息.clarification),
      expanded: 消息.expanded,
      taskStatus: 消息.taskStatus,
      answerMessageId: 消息.answerMessageId,
      providerText: 消息.providerText
    };
  }

  /** 对某条消息做克隆-修改-回写；保证 ForEach 键不变时属性绑定仍走 @State 通道。 */
  private 更新消息(消息索引: number, 修改: (消息: 聊天消息) => void): void {
    const 列表: 聊天消息[] = this.消息列表.slice();
    const 消息: 聊天消息 = this.克隆消息(列表[消息索引]);
    修改(消息);
    列表[消息索引] = 消息;
    this.消息列表 = 列表;
  }

  private 更新卡片字段(消息索引: number, 卡片索引: number, 字段索引: number, 值: string): void {
    this.更新消息(消息索引, (消息: 聊天消息): void => {
      const 卡: 卡片草稿 = this.克隆卡片(消息.卡片列表[卡片索引]);
      const fields: string[] = 卡.fields.slice();
      fields[字段索引] = 值;
      卡.fields = fields;
      消息.卡片列表[卡片索引] = 卡;
    });
  }

  private 更新卡片选中(消息索引: number, 卡片索引: number, 值: boolean): void {
    this.更新消息(消息索引, (消息: 聊天消息): void => {
      const 卡: 卡片草稿 = this.克隆卡片(消息.卡片列表[卡片索引]);
      卡.已选中 = 值;
      消息.卡片列表[卡片索引] = 卡;
    });
  }

  private 追加消息(消息: 聊天消息): void {
    this.消息列表 = this.消息列表.concat([消息]);
    this.滚动到底部();
  }

  private 滚动到底部(): void {
    setTimeout(() => {
      try {
        this.聊天滚动器.scrollEdge(Edge.Bottom);
      } catch (错误) {
        // 滚动失败不影响功能
      }
    }, 50);
  }

  private 取Agent错误文案(错误: Error): string {
    if (错误 instanceof AgentTransportError) {
      if (错误.kind === 'http') {
        if (错误.detailMessage.length > 0) {
          return this.取本地化格式($r('app.string.ai_agent_http_error_detail'),
            [错误.statusCode, 错误.detailMessage]);
        }
        return this.取本地化格式($r('app.string.ai_agent_http_error'), [错误.statusCode]);
      }
      if (错误.kind === 'network') {
        return this.取本地化文案($r('app.string.ai_card_err_network'));
      }
      if (错误.kind === 'cancelled') {
        return this.取本地化文案($r('app.string.ai_agent_turn_cancelled'));
      }
    }
    if (错误.message === 'cancelled') {
      return this.取本地化文案($r('app.string.ai_agent_turn_cancelled'));
    }
    if (错误.message === 'web_search_unsupported') {
      return this.取本地化文案($r('app.string.ai_agent_web_search_unsupported'));
    }
    if (错误.message === 'agent_provider_limit' || 错误.message === 'agent_tool_limit') {
      return this.取本地化文案($r('app.string.ai_agent_turn_limit_reached'));
    }
    if (错误.message === 'agent_no_valid_draft') {
      return this.取本地化文案($r('app.string.ai_agent_no_valid_draft'));
    }
    if (错误.message === 'agent_repeated_tool_failure') {
      return this.取本地化文案($r('app.string.ai_agent_repeated_tool_failure'));
    }
    return 错误.message.length > 0 ? 错误.message :
      this.取本地化文案($r('app.string.ai_card_err_network'));
  }

  private 取消当前请求(): void {
    if (this.agentRunner !== null) { this.agentRunner.cancel(); }
    this.cancelPendingClarifications();
  }

  private 构建Provider输入(): ProviderInputItem[] {
    const values: ProviderInputItem[] = [];
    for (const message of this.消息列表) {
      if (!(message.kind === 'normal' || message.kind === 'clarification')) { continue; }
      if (message.正文.length === 0) { continue; }
      values.push({
        kind: 'message', role: message.角色 === 'user' ? 'user' : 'assistant',
        content: message.角色 === 'user' ? message.providerText : message.正文,
        callId: '', name: '', argumentsJson: '', output: ''
      });
    }
    return values;
  }

  private async 发送(): Promise<void> {
    const 输入: string = this.输入草稿.trim();
    if (this.readinessReason() !== 'ready') { return; }
    const snapshot: AgentTaskSnapshot = this.taskSnapshot(输入);
    this.输入草稿 = '';
    const result: AgentRunResult | null = await this.runAgentTurn(
      buildAgentTaskProviderText(snapshot), buildAgentTaskVisibleText(snapshot));
    if (result !== null && result.status === 'awaiting_clarification' && result.clarification !== null) {
      this.appendClarificationMessage(result.clarification);
      await this.保存当前会话历史();
    }
  }

  private async runAgentTurn(providerText: string, visibleUserText: string,
    existingUserMessageId: number = 0): Promise<AgentRunResult | null> {
    if (this.处理中 || this.agentRunner === null) { return null; }
    this.重建本轮AgentScope();
    this.agentScope.configureCreateConstraints(this.pageMode === 'create' &&
      explicitYearClozeRequested(providerText));
    this.错误信息 = '';
    let userMessageId: number = existingUserMessageId;
    let foundExisting: boolean = false;
    if (existingUserMessageId > 0) {
      for (let index: number = 0; index < this.消息列表.length; index++) {
        if (this.消息列表[index].id === existingUserMessageId) {
          this.更新消息(index, (message: 聊天消息): void => {
            message.正文 = visibleUserText;
            message.providerText = providerText;
          });
          foundExisting = true;
          break;
        }
      }
    }
    if (!foundExisting) {
      const userMessage: 聊天消息 = this.空消息('user', visibleUserText, false);
      userMessage.providerText = providerText;
      userMessageId = userMessage.id;
      this.追加消息(userMessage);
    }
    this.storeClarificationAnswerMessageId(userMessageId);
    this.处理中 = true;
    const aiMessage: 聊天消息 = this.空消息('ai', '', false);
    this.追加消息(aiMessage);
    const aiIndex: number = this.消息列表.length - 1;
    try {
      const request: ProviderTurnRequest = {
        apiKey: this.AI配置.apiKey,
        baseUrl: this.AI配置.baseUrl,
        model: this.AI配置.model,
        instructions: this.构建Agent指令(),
        input: this.构建Provider输入(),
        functionTools: agentFunctionTools(this.agentSettings.batchLimit, this.pageMode),
        searchMode: this.agentSettings.searchMode,
        requiresSearchEvidence: this.agentSettings.searchMode === 'always' ||
          (this.agentSettings.searchMode === 'auto' && explicitWebSearchRequested(providerText)),
        requiresDraft: this.pageMode === 'create',
        expectedDraftCount: this.pageMode === 'create' ?
          inferRequestedCardCount(providerText, this.agentSettings.batchLimit) : 0,
        reasoningEffort: 'low', maxOutputTokens: 32768
      };
      const observer: 页面Agent观察者 = new 页面Agent观察者(
        (event: AgentEvent): void => { this.处理Agent事件(aiIndex, event); });
      const result: AgentRunResult = await this.agentRunner.run(this.agentSettings.selectedProvider, request, observer);
      this.setupExpanded = false;
      if (result.status === 'awaiting_clarification') {
        this.更新消息(aiIndex, (message: 聊天消息): void => {
          message.taskStatus = 'waiting';
        });
      } else {
        this.接收Agent草稿(aiIndex, result.drafts);
      }
      return result;
    } catch (错误) {
      const 异常: Error = 错误 instanceof Error ? 错误 : new Error(`${错误}`);
      const 错误文案: string = this.取Agent错误文案(异常);
      this.更新消息(aiIndex, (message: 聊天消息): void => {
        message.正文 = message.正文.length > 0 ? `${message.正文}\n\n${错误文案}` : 错误文案;
        message.是否错误 = true;
        message.kind = 'error';
      });
      return null;
    } finally {
      this.处理中 = false;
      await this.保存当前会话历史();
    }
  }

  private storeClarificationAnswerMessageId(messageId: number): void {
    for (let index: number = this.消息列表.length - 1; index >= 0; index--) {
      const view: AgentClarificationView | null = this.消息列表[index].clarification;
      if (this.消息列表[index].kind === 'clarification' &&
        view !== null && view.state === 'submitting') {
        this.更新消息(index, (message: 聊天消息): void => {
          message.answerMessageId = messageId;
        });
        return;
      }
    }
  }

  private appendClarificationMessage(request: AgentClarificationRequest): void {
    if (this.hasPendingClarification()) { throw new Error('clarification_already_pending'); }
    const message: 聊天消息 = this.空消息('ai', request.question, false);
    message.kind = 'clarification';
    message.clarification = {
      request: request, selectedOptionId: '', supplementalText: '',
      state: 'pending', expanded: true
    };
    message.expanded = true;
    this.追加消息(message);
  }

  private updateClarificationState(messageIndex: number, state: AgentClarificationState,
    expanded: boolean): void {
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      if (message.clarification !== null) {
        message.clarification.state = state;
        message.clarification.expanded = expanded;
        message.expanded = expanded;
      }
    });
  }

  private selectClarificationOption(messageIndex: number, optionId: string): void {
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      if (message.clarification !== null &&
        (message.clarification.state === 'pending' || message.clarification.state === 'submit_failed')) {
        message.clarification.selectedOptionId = optionId;
      }
    });
  }

  private updateClarificationSupplement(messageIndex: number, value: string): void {
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      if (message.clarification !== null &&
        (message.clarification.state === 'pending' || message.clarification.state === 'submit_failed')) {
        message.clarification.supplementalText = value;
      }
    });
  }

  private toggleClarification(messageIndex: number): void {
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      if (message.clarification !== null &&
        (message.clarification.state === 'resolved' || message.clarification.state === 'cancelled')) {
        message.clarification.expanded = !message.clarification.expanded;
        message.expanded = message.clarification.expanded;
      }
    });
  }

  private clarificationStatusText(view: AgentClarificationView): ResourceStr {
    if (view.state === 'submitting') { return $r('app.string.ai_agent_clarification_submitting'); }
    if (view.state === 'resolved') {
      const selected: AgentClarificationOption | undefined = view.request.options.find(
        (item: AgentClarificationOption): boolean => item.id === view.selectedOptionId);
      return this.取本地化格式($r('app.string.ai_agent_clarification_resolved_summary'),
        [selected === undefined ? '' : selected.label]);
    }
    if (view.state === 'submit_failed') { return $r('app.string.ai_agent_clarification_submit_failed'); }
    if (view.state === 'cancelled') { return $r('app.string.ai_agent_clarification_cancelled'); }
    return $r('app.string.ai_agent_clarification_waiting');
  }

  private async continueClarification(messageIndex: number): Promise<void> {
    const source: AgentClarificationView | null = this.消息列表[messageIndex].clarification;
    if (source === null || source.selectedOptionId.length === 0 || this.处理中) { return; }
    const view: AgentClarificationView = cloneAgentClarificationView(source);
    const option: AgentClarificationOption | undefined = view.request.options.find(
      (item: AgentClarificationOption): boolean => item.id === view.selectedOptionId);
    if (option === undefined) { return; }
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      if (message.clarification !== null) {
        message.clarification.state = 'submitting';
        message.clarification.expanded = true;
      }
    });
    const answer: AgentClarificationAnswer = {
      clarificationId: view.request.id, optionId: option.id, optionLabel: option.label,
      supplementalText: view.supplementalText.trim()
    };
    this.重建本轮AgentScope();
    const result: AgentRunResult | null = await this.runAgentTurn(
      buildClarificationAnswerText(view.request, answer),
      buildClarificationAnswerVisibleText(answer),
      this.消息列表[messageIndex].answerMessageId);
    const current: AgentClarificationView | null = this.消息列表[messageIndex].clarification;
    if (result === null) {
      if (current !== null && current.state !== 'cancelled') {
        this.更新消息(messageIndex, (message: 聊天消息): void => {
          if (message.clarification !== null) {
            message.clarification.state = 'submit_failed';
            message.clarification.expanded = true;
          }
        });
      }
      await this.保存当前会话历史();
      return;
    }
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      if (message.clarification !== null) {
        message.clarification.state = 'resolved';
        message.clarification.expanded = false;
        message.expanded = false;
      }
    });
    if (result.status === 'awaiting_clarification' && result.clarification !== null) {
      this.appendClarificationMessage(result.clarification);
    }
    await this.保存当前会话历史();
  }

  private cancelPendingClarifications(): void {
    for (let index: number = 0; index < this.消息列表.length; index++) {
      const view: AgentClarificationView | null = this.消息列表[index].clarification;
      if (view !== null && (view.state === 'pending' || view.state === 'submitting' ||
        view.state === 'submit_failed')) {
        this.更新消息(index, (message: 聊天消息): void => {
          if (message.clarification !== null) {
            message.clarification.state = 'cancelled';
            message.clarification.expanded = false;
            message.expanded = false;
          }
        });
      }
    }
  }

  private 构建Agent指令(): string {
    const modeText: string = this.pageMode === 'create' ? '制卡' : '改卡';
    return `你是记得闪卡应用内的${modeText} Agent。只可使用所列语义工具。读取工具可直接调用；任何写入都必须调用 propose_ 工具生成草稿，绝不能声称已保存。创建模式目标 deckId=${this.牌组ID} notetypeId=${this.已选笔记类型ID}，字段=${JSON.stringify(this.字段名列表)}，kind=${this.noteTypeKind}，clozeFieldOrds=${JSON.stringify(this.clozeFieldOrds)}，单轮最多 ${this.agentSettings.batchLimit} 张。填空类型必须把 {{c1::答案}} 写在允许的字段。含糊请求应合理澄清或提出可编辑草稿，不要输出需要客户端自行解析的自由 JSON。`;
  }

  private 处理Agent事件(messageIndex: number, event: AgentEvent): void {
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      if (event.kind === 'status' && event.text === 'draft_correction') {
        message.正文 = '';
        message.是否错误 = false;
      }
      if (event.kind === 'text_delta') { message.正文 += event.text; }
      if (event.kind === 'reasoning_delta' || event.kind === 'reasoning_summary') {
        message.推理摘要 += event.text;
      }
      if ((event.kind === 'tool_started' || event.kind === 'tool_completed' || event.kind === 'tool_failed') &&
        event.toolTrace !== null) {
        const trace: AgentToolTrace = this.克隆工具追踪(event.toolTrace);
        let existingIndex: number = -1;
        for (let index: number = 0; index < message.工具过程.length; index++) {
          if (message.工具过程[index].callId === trace.callId) { existingIndex = index; break; }
        }
        if (existingIndex < 0) { message.工具过程.push(trace); }
        else {
          trace.expanded = message.工具过程[existingIndex].expanded;
          message.工具过程[existingIndex] = trace;
        }
      }
      if (event.kind === 'search_source' && event.source !== null) {
        message.来源列表.push({ url: event.source.url, title: event.source.title });
      }
      if (event.kind === 'error') { message.是否错误 = true; }
    });
  }

  private 接收Agent草稿(messageIndex: number, drafts: ChangeDraft[]): void {
    const cards: 卡片草稿[] = [];
    const changes: ChangeDraft[] = [];
    for (const draft of drafts) {
      const createOnly: boolean = draft.operations.length > 0 &&
        draft.operations.every((operation: DraftOperation): boolean => operation.kind === 'create_note');
      if (createOnly) {
        const groupedFields: Map<number, string[]> = new Map<number, string[]>();
        for (const operation of draft.operations) {
          let fields: string[] | undefined = groupedFields.get(operation.noteId);
          if (fields === undefined) {
            fields = this.字段名列表.map((_name: string): string => '');
            groupedFields.set(operation.noteId, fields);
          }
          if (operation.fieldOrd >= 0 && operation.fieldOrd < fields.length) {
            fields[operation.fieldOrd] = operation.after;
          }
        }
        for (const fields of groupedFields.values()) {
          cards.push({ fields: fields, 已选中: true, 状态: 'draft', 失败提示: '' });
        }
      } else { changes.push(draft); }
    }
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      message.卡片列表 = cards;
      message.字段名列表 = this.字段名列表.slice();
      message.变更草稿列表 = changes;
      if (message.正文.length === 0) {
        message.正文 = cards.length > 0 ?
          this.取本地化格式($r('app.string.ai_card_generated_summary'), [`${cards.length}`]) :
          this.取本地化格式($r('app.string.ai_agent_changes_generated'), [changes.length]);
      }
    });
    this.滚动到底部();
  }

  private 影响范围(draft: ChangeDraft): string {
    return this.取本地化格式($r('app.string.ai_agent_impact'), [
      draft.affectedNoteIds.length, draft.affectedCardIds.length,
      draft.affectedDeckIds.length, draft.affectedNotetypeIds.length
    ]);
  }

  private 更新草稿操作(messageIndex: number, draftIndex: number, operationIndex: number, after: string): void {
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      const draft: ChangeDraft = message.变更草稿列表[draftIndex];
      draft.operations[operationIndex].after = after;
      message.变更草稿列表[draftIndex] = draft;
    });
  }

  /** 第一次 UI 事件：重读基线并生成 level-1 短时令牌。 */
  private async 准备执行草稿(messageIndex: number, draftIndex: number): Promise<void> {
    const draft: ChangeDraft = this.消息列表[messageIndex].变更草稿列表[draftIndex];
    try {
      const prepared: PreparedAgentDraft = await this.agentExecutor.prepare(draft);
      if (draft.risk === 'high_risk') {
        this.getUIContext().showAlertDialog({
          title: this.取本地化文案($r('app.string.ai_agent_danger_title')),
          message: `${this.取本地化文案($r('app.string.ai_agent_danger_body'))}\n${this.影响范围(draft)}\n${draft.summary}`,
          autoCancel: false,
          primaryButton: { value: $r('app.string.cancel'), action: (): void => { draft.status = 'pending'; } },
          secondaryButton: {
            value: $r('app.string.continue'), fontColor: $r('app.color.error_text'),
            action: (): void => { this.打开高风险最终确认(messageIndex, draftIndex, prepared); }
          }
        });
      } else {
        this.getUIContext().showAlertDialog({
          title: this.取本地化文案($r('app.string.ai_agent_confirm_title')),
          message: `${this.取本地化文案($r('app.string.ai_agent_confirm_body'))}\n${this.影响范围(draft)}`,
          primaryButton: { value: $r('app.string.cancel'), action: (): void => { draft.status = 'pending'; } },
          secondaryButton: {
            value: $r('app.string.settings_confirm'),
            action: (): void => { this.执行普通草稿(messageIndex, draftIndex, prepared); }
          }
        });
      }
    } catch (error) { this.记录草稿错误(messageIndex, error); }
  }

  /** 第二次、不同的 UI 事件：签发 level-2 令牌后显示永久操作最终确认。 */
  private 打开高风险最终确认(messageIndex: number, draftIndex: number,
    prepared: PreparedAgentDraft): void {
    try {
      const secondToken: AgentConfirmationToken =
        this.agentExecutor.authorizeHighRisk(prepared, prepared.firstToken);
      this.getUIContext().showAlertDialog({
        title: this.取本地化文案($r('app.string.ai_agent_danger_final_title')),
        message: `${this.取本地化文案($r('app.string.ai_agent_danger_final_body'))}\n${this.影响范围(prepared.draft)}`,
        autoCancel: false,
        primaryButton: { value: $r('app.string.cancel'), action: (): void => { prepared.draft.status = 'pending'; } },
        secondaryButton: {
          value: $r('app.string.settings_confirm'), fontColor: $r('app.color.error_text'),
          action: (): void => { this.执行高风险草稿(messageIndex, draftIndex, prepared, secondToken); }
        }
      });
    } catch (error) { this.记录草稿错误(messageIndex, error); }
  }

  private async 执行普通草稿(messageIndex: number, draftIndex: number,
    prepared: PreparedAgentDraft): Promise<void> {
    try {
      const result: AgentDraftExecutionResult =
        await this.agentExecutor.executeOrdinary(prepared, prepared.firstToken);
      this.记录执行结果(messageIndex, draftIndex, result);
    } catch (error) { this.记录草稿错误(messageIndex, error); }
  }

  private async 执行高风险草稿(messageIndex: number, draftIndex: number,
    prepared: PreparedAgentDraft, secondToken: AgentConfirmationToken): Promise<void> {
    try {
      const result: AgentDraftExecutionResult =
        await this.agentExecutor.executeHighRisk(prepared, prepared.firstToken, secondToken);
      this.记录执行结果(messageIndex, draftIndex, result);
    } catch (error) { this.记录草稿错误(messageIndex, error); }
  }

  private 记录执行结果(messageIndex: number, draftIndex: number,
    result: AgentDraftExecutionResult): void {
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      message.批次结果 = this.取本地化格式(
        $r('app.string.ai_agent_execution_result'), [result.succeeded, result.failed, result.status]);
      const original: ChangeDraft = message.变更草稿列表[draftIndex];
      const retry: ChangeDraft | null = buildFailedOperationsRetryDraft(
        original, result, `${original.id}-retry-${Date.now()}`);
      if (retry !== null) {
        message.变更草稿列表[draftIndex] = retry;
      } else {
        original.status = 'completed';
        message.变更草稿列表[draftIndex] = original;
      }
    });
    this.历史执行结果.push({
      draftId: result.draftId, status: result.status,
      succeeded: result.succeeded, failed: result.failed
    });
    this.保存当前会话历史();
    if (result.succeeded > 0) { AppStorage.setOrCreate<number>('noteAddedTick', Date.now()); }
  }

  private 记录草稿错误(messageIndex: number, error: Object): void {
    this.更新消息(messageIndex, (message: 聊天消息): void => {
      message.批次结果 = error instanceof Error ? error.message : `${error}`;
    });
  }

  // ========================================================
  // 保存：逐卡 新建笔记 → fields → 添加笔记；单卡失败不中断整批
  // ========================================================

  /** 该消息里还可保存的卡（已勾选且未入库；含失败卡，可重试）。 */
  private 待保存数(消息索引: number): number {
    let 数量: number = 0;
    const 消息: 聊天消息 = this.消息列表[消息索引];
    for (const 卡 of 消息.卡片列表) {
      if (卡.已选中 && 卡.状态 !== 'saved') {
        数量++;
      }
    }
    return 数量;
  }

  /** 保存一张卡。成功返回空串；失败返回本地化错误文案。 */
  private async 保存单卡(fields: string[]): Promise<string> {
    try {
      const operations: DraftOperation[] = [];
      for (let fieldOrd: number = 0; fieldOrd < fields.length; fieldOrd++) {
        operations.push({
          kind: 'create_note', noteId: 0, cardId: 0, deckId: this.牌组ID,
          fieldOrd: fieldOrd, before: '', after: fields[fieldOrd]
        });
      }
      const draft: ChangeDraft = {
        id: `ui-create-${Date.now()}-${Math.random()}`, risk: 'write',
        summary: '用户确认创建可编辑卡片草稿', baselineHash: '', confirmationLevel: 1,
        status: 'pending', affectedNoteIds: [], affectedCardIds: [],
        affectedDeckIds: [this.牌组ID], affectedNotetypeIds: [this.已选笔记类型ID],
        operations: operations
      };
      const prepared: PreparedAgentDraft = await this.agentExecutor.prepare(draft);
      const result: AgentDraftExecutionResult = await this.agentExecutor.executeOrdinary(prepared, prepared.firstToken);
      return result.failed === 0 ? '' : this.取本地化文案($r('app.string.ai_card_save_failed'));
    } catch (错误) {
      if (错误 instanceof 笔记字段校验错误) {
        if (错误.messageKey === 'add_note_empty_error') {
          return this.取本地化文案($r('app.string.add_note_empty_error'));
        }
        if (错误.messageKey === 'add_note_duplicate_error') {
          return this.取本地化文案($r('app.string.add_note_duplicate_error'));
        }
        // MISSING_CLOZE / NOTETYPE_NOT_CLOZE / FIELD_NOT_CLOZE
        return this.取本地化文案($r('app.string.add_note_cloze_missing'));
      }
      return this.取本地化文案($r('app.string.ai_card_save_failed'));
    }
  }

  private async 保存批次(消息索引: number): Promise<void> {
    const 消息: 聊天消息 = this.消息列表[消息索引];
    if (消息.批次保存中 || this.牌组ID === 0 || this.已选笔记类型ID === 0) {
      return;
    }
    const 目标索引列表: number[] = [];
    for (let i: number = 0; i < 消息.卡片列表.length; i++) {
      const 卡: 卡片草稿 = 消息.卡片列表[i];
      if (卡.已选中 && 卡.状态 !== 'saved') {
        目标索引列表.push(i);
      }
    }
    if (目标索引列表.length === 0) {
      return;
    }
    this.更新消息(消息索引, (目标: 聊天消息): void => {
      目标.批次保存中 = true;
    });
    let 成功数: number = 0;
    let 失败数: number = 0;
    for (const 卡索引 of 目标索引列表) {
      const 卡: 卡片草稿 = this.消息列表[消息索引].卡片列表[卡索引];
      const 失败提示: string = await this.保存单卡(卡.fields);
      if (失败提示.length === 0) {
        成功数++;
        this.更新消息(消息索引, (目标: 聊天消息): void => {
          const 已存卡: 卡片草稿 = this.克隆卡片(目标.卡片列表[卡索引]);
          已存卡.状态 = 'saved';
          已存卡.失败提示 = '';
          目标.卡片列表[卡索引] = 已存卡;
        });
      } else {
        失败数++;
        this.更新消息(消息索引, (目标: 聊天消息): void => {
          const 失败卡: 卡片草稿 = this.克隆卡片(目标.卡片列表[卡索引]);
          失败卡.状态 = 'failed';
          失败卡.失败提示 = 失败提示;
          目标.卡片列表[卡索引] = 失败卡;
        });
      }
    }
    const 结果文案: string = 失败数 === 0
      ? this.取本地化格式($r('app.string.ai_card_batch_all_ok'), [`${成功数}`])
      : this.取本地化格式($r('app.string.ai_card_batch_done'),
        [`${成功数}`, `${失败数}`]);
    this.更新消息(消息索引, (目标: 聊天消息): void => {
      目标.批次保存中 = false;
      目标.批次结果 = 结果文案;
    });
    if (成功数 > 0) {
      // 笔记添加成功：写 AppStorage 标志位通知首页/牌组详情面板立即刷新统计计数（与 添加笔记页 同机制）
      AppStorage.setOrCreate<number>('noteAddedTick', Date.now());
    }
  }

  // ========================================================
  // AI 配置：折叠区输入 + 保存
  // ========================================================

  private 页面Provider索引(): number {
    return this.页面Provider === 'deepseek' ? 0 : (this.页面Provider === 'openai' ? 1 : 2);
  }

  private 页面模型选项(): AI制卡下拉选项[] {
    const models: string[] = this.页面Provider === 'deepseek' ?
      DEEPSEEK_PROVIDER.models : OPENAI_PROVIDER.models;
    return models.map((value: string): AI制卡下拉选项 => ({ value: value }));
  }

  private 页面模型索引(): number {
    const models: string[] = this.页面Provider === 'deepseek' ?
      DEEPSEEK_PROVIDER.models : OPENAI_PROVIDER.models;
    const index: number = models.indexOf(this.配置模型输入);
    return index < 0 ? 0 : index;
  }

  private async 切换页面Provider(index: number): Promise<void> {
    this.页面Provider = index === 0 ? 'deepseek' : (index === 1 ? 'openai' : 'custom');
    this.agentSettings.selectedProvider = this.页面Provider;
    const baseUrl: string = this.页面Provider === 'deepseek' ? DEEPSEEK_PROVIDER.baseUrl :
      (this.页面Provider === 'openai' ? OPENAI_PROVIDER.baseUrl : this.agentSettings.customBaseUrl);
    const model: string = this.页面Provider === 'deepseek' ? this.agentSettings.deepseekModel :
      (this.页面Provider === 'openai' ? this.agentSettings.openaiModel : this.agentSettings.customModel);
    this.配置地址输入 = baseUrl;
    this.配置模型输入 = model;
    this.配置密钥输入 = await loadAgentSecret(this.页面Provider);
    this.AI配置 = { apiKey: this.配置密钥输入, baseUrl: baseUrl, model: model };
    this.配置提示 = '';
  }

  private async 保存配置(): Promise<void> {
    const provider: ProviderId = this.页面Provider;
    const 地址: string = provider === 'deepseek' ? DEEPSEEK_PROVIDER.baseUrl :
      (provider === 'openai' ? OPENAI_PROVIDER.baseUrl : this.配置地址输入.trim());
    const 新配置: 页面AI配置 = {
      apiKey: this.配置密钥输入.trim(),
      baseUrl: 地址,
      model: this.配置模型输入.trim()
    };
    if (provider === 'custom' && (!新配置.baseUrl.startsWith('https://') || 新配置.model.length === 0)) {
      this.配置提示 = this.取本地化文案($r('app.string.ai_agent_custom_invalid'));
      return;
    }
    this.agentSettings.selectedProvider = provider;
    if (provider === 'deepseek') { this.agentSettings.deepseekModel = 新配置.model; }
    else if (provider === 'openai') { this.agentSettings.openaiModel = 新配置.model; }
    else { this.agentSettings.customBaseUrl = 新配置.baseUrl; this.agentSettings.customModel = 新配置.model; }
    await saveAgentSettings(this.agentSettings);
    await saveAgentSecret(provider, 新配置.apiKey);
    this.AI配置 = 新配置;
    // 地址留空时回填默认值到输入框，让用户看到实际生效的值
    this.配置地址输入 = 新配置.baseUrl;
    this.配置密钥输入 = 新配置.apiKey;
    this.配置模型输入 = 新配置.model;
    this.配置提示 = this.取本地化文案($r('app.string.ai_card_config_saved'));
    this.错误信息 = '';
  }

  private async 保存当前会话历史(): Promise<void> {
    try {
      const messages: AgentHistoryMessage[] = [];
      const audits: AgentHistoryAudit[] = [];
      const sources: SearchSource[] = [];
      const defaultTitle: string = this.取本地化文案(this.pageMode === 'create' ?
        $r('app.string.ai_agent_history_create_title') : $r('app.string.ai_agent_history_edit_title'));
      let title: string = defaultTitle;
      for (const message of this.消息列表) {
        if (message.正文.length > 0 && (message.kind === 'normal' || message.kind === 'clarification')) {
          messages.push({
            role: message.角色 === 'user' ? 'user' : 'assistant', text: message.正文,
            kind: message.kind,
            clarification: message.clarification === null ? null : cloneAgentClarificationView(message.clarification),
            expanded: message.clarification === null ? message.expanded : message.clarification.expanded
          });
          if (message.角色 === 'user' && title === defaultTitle) {
            title = message.正文.slice(0, 40);
          }
        }
        for (const item of message.工具过程) { audits.push(this.克隆历史审计(item)); }
        for (const source of message.来源列表) { sources.push(source); }
      }
      if (messages.length === 0) { return; }
      const conversation: AgentConversation = {
        id: this.conversationId, mode: this.pageMode, title: title, updatedAt: Date.now(),
        setup: this.taskSetup(),
        messages: messages, audits: audits, sources: sources,
        results: this.历史执行结果.slice()
      };
      await saveAgentConversation(conversation);
    } catch (error) {
      // 历史落盘失败不能阻断制卡或改卡。
    }
  }

  /** 列出同模式历史；每页 4 条，使用系统最多 6 按钮的 ActionMenu 翻页。 */
  private async 打开历史会话(): Promise<void> {
    const all: AgentConversation[] = await loadAgentConversations();
    const sameMode: AgentConversation[] = [];
    for (const item of all) {
      if (item.mode === this.pageMode) { sameMode.push(item); }
    }
    if (sameMode.length === 0) {
      this.配置提示 = this.取本地化文案($r('app.string.ai_agent_history_none'));
      return;
    }
    this.显示历史菜单页(sameMode, 0);
  }

  private 历史标题(all: AgentConversation[], index: number): string {
    return index >= 0 && index < all.length ? all[index].title : '—';
  }

  private 显示历史菜单页(all: AgentConversation[], start: number): void {
    promptAction.showActionMenu({
      title: $r('app.string.ai_agent_history'),
      buttons: [
        { text: this.历史标题(all, start), color: $r('app.color.text_primary') },
        { text: this.历史标题(all, start + 1), color: $r('app.color.text_primary') },
        { text: this.历史标题(all, start + 2), color: $r('app.color.text_primary') },
        { text: this.历史标题(all, start + 3), color: $r('app.color.text_primary') },
        { text: $r('app.string.ai_agent_history_next'), color: $r('app.color.text_primary') },
        { text: $r('app.string.ai_agent_history_new'), color: $r('app.color.text_primary') }
      ]
    }, (error: BusinessError, data: promptAction.ActionMenuSuccessResponse): void => {
      if (error !== null) { return; }
      if (data.index >= 0 && data.index < 4) {
        const selectedIndex: number = start + data.index;
        if (selectedIndex < all.length) { this.恢复历史会话(all[selectedIndex]); }
      } else if (data.index === 4) {
        const next: number = start + 4 < all.length ? start + 4 : 0;
        this.显示历史菜单页(all, next);
      } else if (data.index === 5) {
        this.开始新会话();
      }
    });
  }

  /** 只恢复可见文本与审计结果，不恢复旧草稿和确认令牌。 */
  private async 恢复历史会话(selected: AgentConversation): Promise<void> {
    const restored: 聊天消息[] = [];
    for (const item of selected.messages) {
      const message: 聊天消息 = this.空消息(item.role === 'user' ? 'user' : 'ai', item.text, false);
      message.kind = item.kind;
      message.clarification = item.clarification;
      message.expanded = item.expanded;
      message.providerText = item.text;
      restored.push(message);
    }
    let auditTarget: number = -1;
    for (let index: number = restored.length - 1; index >= 0; index--) {
      if (restored[index].角色 === 'ai') { auditTarget = index; break; }
    }
    if (selected.audits.length > 0 && auditTarget < 0) {
      restored.push(this.空消息('ai', '', false));
      auditTarget = restored.length - 1;
    }
    if (auditTarget >= 0) {
      for (const audit of selected.audits) {
        restored[auditTarget].工具过程.push(this.克隆工具追踪(audit));
      }
    }
    this.conversationId = selected.id;
    this.历史执行结果 = selected.results.slice();
    this.消息列表 = restored;
    this.setupExpanded = selected.setup.expanded;
    let validContext: boolean = true;
    if (this.pageMode === 'create') {
      const deckExists: boolean = this.牌组选项.some(
        (item: AI制卡牌组选项): boolean => item.id === selected.setup.deckId);
      const notetypeExists: boolean = this.笔记类型选项.some(
        (item: AI制卡笔记类型选项): boolean => item.id === selected.setup.notetypeId);
      if (!deckExists || !notetypeExists) {
        validContext = false;
        this.牌组ID = deckExists ? selected.setup.deckId : 0;
        this.已选笔记类型ID = 0;
      } else {
        this.牌组ID = selected.setup.deckId;
        await this.加载笔记类型(selected.setup.notetypeId);
        validContext = this.已选笔记类型ID === selected.setup.notetypeId && this.字段名列表.length > 0;
      }
    }
    if (!validContext) {
      this.setupExpanded = true;
      this.cancelRestoredClarifications(this.取本地化文案(
        this.牌组ID === 0 ? $r('app.string.ai_agent_setup_missing_deck') :
          $r('app.string.ai_agent_setup_missing_notetype')));
    }
    this.滚动到底部();
  }

  private cancelRestoredClarifications(reason: string): void {
    for (let index: number = 0; index < this.消息列表.length; index++) {
      const view: AgentClarificationView | null = this.消息列表[index].clarification;
      if (view !== null && (view.state === 'pending' || view.state === 'submit_failed')) {
        this.更新消息(index, (message: 聊天消息): void => {
          if (message.clarification !== null) {
            message.clarification.state = 'cancelled';
            message.clarification.expanded = false;
            message.expanded = false;
            message.taskStatus = reason;
          }
        });
      }
    }
  }

  private 开始新会话(): void {
    this.cancelPendingClarifications();
    this.conversationId = `agent-${Date.now()}-${Math.random()}`;
    this.历史执行结果 = [];
    this.消息列表 = [];
    this.setupExpanded = true;
    this.配置提示 = '';
  }

  private 删除当前历史会话(): void {
    this.getUIContext().showAlertDialog({
      title: this.取本地化文案($r('app.string.ai_agent_history_delete_title')),
      message: this.取本地化文案($r('app.string.ai_agent_history_delete_body')),
      primaryButton: { value: $r('app.string.cancel'), action: (): void => {} },
      secondaryButton: {
        value: $r('app.string.settings_confirm'), fontColor: $r('app.color.error_text'),
        action: (): void => {
          const removingId: string = this.conversationId;
          deleteAgentConversation(removingId);
          this.开始新会话();
        }
      }
    });
  }

  // ========================================================
  // UI
  // ========================================================

  @Builder
  private 顶部条() {
    Row() {
      Row() {
        Button($r('app.string.study_back'))
          .height(应用尺寸.按钮高度)
          .padding({ left: 应用尺寸.间距_10, right: 应用尺寸.间距_10 })
          .constraintSize({ minWidth: 0 })
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_胶囊)
          .onClick((): void => { this.pathStack.pop(); })
      }
      .width('35%')
      Text(this.pageMode === 'create' ? $r('app.string.ai_card_title') : $r('app.string.ai_card_edit'))
        .fontSize(应用尺寸.字号_标题)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('30%')
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 应用尺寸.间距_8 }) {
        Button($r('app.string.ai_agent_history'))
          .height(应用尺寸.按钮高度)
          .padding({ left: 应用尺寸.间距_8, right: 应用尺寸.间距_8 })
          .constraintSize({ minWidth: 0 })
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_胶囊)
          .enabled(!this.处理中)
          .onClick((): void => { this.打开历史会话(); })
          .gesture(LongPressGesture({ duration: 600 }).onAction((): void => {
            this.删除当前历史会话();
          }))
        Button($r('app.string.ai_card_config'))
          .height(应用尺寸.按钮高度)
          .padding({ left: 应用尺寸.间距_8, right: 应用尺寸.间距_8 })
          .constraintSize({ minWidth: 0 })
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_胶囊)
          .enabled(!this.处理中)
          .onClick((): void => { this.显示配置区 = !this.显示配置区; })
      }
      .width('35%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(应用尺寸.工具栏高度 + this.状态栏高度)
    .padding({
      left: 应用尺寸.页面内边距_水平,
      right: 应用尺寸.页面内边距_水平,
      top: this.状态栏高度 + 应用尺寸.间距_8,
      bottom: 应用尺寸.间距_8
    })
    .backgroundColor($r('app.color.surface_page'))
  }

  @Builder
  private 配置区() {
    Column({ space: 应用尺寸.间距_8 }) {
      Row() {
        Text($r('app.string.ai_agent_provider')).layoutWeight(1)
        Select([{ value: 'DeepSeek' }, { value: 'OpenAI' },
          { value: this.取本地化文案($r('app.string.ai_agent_provider_custom')) }])
          .selected(this.页面Provider索引())
          .value(this.页面Provider === 'deepseek' ? 'DeepSeek' :
            (this.页面Provider === 'openai' ? 'OpenAI' :
              this.取本地化文案($r('app.string.ai_agent_provider_custom'))))
          .onSelect((index: number): void => { this.切换页面Provider(index); })
      }.width('100%')
      TextInput({
        placeholder: $r('app.string.ai_card_api_key_hint'),
        text: this.配置密钥输入
      })
        .type(InputType.Password)
        .width('100%')
        .height(应用尺寸.按钮高度)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .backgroundColor($r('app.color.surface_card'))
        .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
        .borderRadius(应用尺寸.圆角_面板)
        .padding({ left: 应用尺寸.间距_10, right: 应用尺寸.间距_10 })
        .onChange((值: string): void => {
          this.配置密钥输入 = 值;
          this.配置提示 = '';
        })
      if (this.页面Provider === 'custom') {
        TextInput({ placeholder: $r('app.string.ai_agent_custom_url_hint'), text: this.配置地址输入 })
          .width('100%')
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
          .borderRadius(应用尺寸.圆角_面板)
          .padding({ left: 应用尺寸.间距_10, right: 应用尺寸.间距_10 })
          .onChange((value: string): void => { this.配置地址输入 = value; this.配置提示 = ''; })
        TextInput({ placeholder: $r('app.string.ai_card_model_hint'), text: this.配置模型输入 })
          .width('100%')
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
          .borderRadius(应用尺寸.圆角_面板)
          .padding({ left: 应用尺寸.间距_10, right: 应用尺寸.间距_10 })
          .onChange((value: string): void => { this.配置模型输入 = value; this.配置提示 = ''; })
      } else {
        Row() {
          Text($r('app.string.ai_card_model')).layoutWeight(1)
          Select(this.页面模型选项())
            .selected(this.页面模型索引()).value(this.配置模型输入)
            .onSelect((index: number): void => {
              const models: string[] = this.页面Provider === 'deepseek' ?
                DEEPSEEK_PROVIDER.models : OPENAI_PROVIDER.models;
              if (index >= 0 && index < models.length) { this.配置模型输入 = models[index]; }
            })
        }.width('100%')
      }
      Row({ space: 应用尺寸.间距_10 }) {
        Button($r('app.string.ai_card_save_config'))
          .height(应用尺寸.按钮高度)
          .layoutWeight(1)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.action_on_primary'))
          .backgroundColor(this.主色按钮背景色)
          .borderRadius(应用尺寸.圆角_胶囊)
          .onClick((): void => {
            this.保存配置();
          })
      }
      .width('100%')
      if (this.配置提示 !== '') {
        Text(this.配置提示)
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor(this.动作主色)
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private 用户气泡(消息索引: number) {
    Row() {
      Blank()
      Text(this.消息列表[消息索引].正文)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.action_on_primary'))
        .backgroundColor(this.主色按钮背景色)
        .borderRadius(应用尺寸.圆角_面板)
        .padding({
          left: 应用尺寸.卡片内边距,
          right: 应用尺寸.卡片内边距,
          top: 应用尺寸.间距_10,
          bottom: 应用尺寸.间距_10
        })
        .constraintSize({ maxWidth: '82%' })
    }
    .width('100%')
  }

  @Builder
  private 卡片项(消息索引: number, 卡片索引: number) {
    Column({ space: 应用尺寸.间距_5 }) {
      Row({ space: 应用尺寸.间距_8 }) {
        // 选中圈：已保存的卡固定勾选且不可改
        Row() {
          if (this.消息列表[消息索引].卡片列表[卡片索引].已选中) {
            Text('✓')
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor($r('app.color.action_on_primary'))
          }
        }
        .width(20)
        .height(20)
        .borderRadius(10)
        .backgroundColor(this.消息列表[消息索引].卡片列表[卡片索引].已选中
          && this.消息列表[消息索引].卡片列表[卡片索引].状态 !== 'saved'
          ? this.动作主色 : Color.Transparent)
        .border({ width: 应用尺寸.卡片边框, color: this.动作主色 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .enabled(this.消息列表[消息索引].卡片列表[卡片索引].状态 !== 'saved')
        .onClick((): void => {
          const 当前: 卡片草稿 = this.消息列表[消息索引].卡片列表[卡片索引];
          this.更新卡片选中(消息索引, 卡片索引, !当前.已选中);
        })

        Text(this.取本地化格式($r('app.string.ai_card_card_index'), [`${卡片索引 + 1}`]))
          .fontSize(应用尺寸.字号_正文)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .opacity(this.消息列表[消息索引].卡片列表[卡片索引].已选中 ? 1 : 0.5)

        if (this.消息列表[消息索引].卡片列表[卡片索引].状态 === 'saved') {
          Text($r('app.string.ai_card_saved'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor(this.动作主色)
        } else if (this.消息列表[消息索引].卡片列表[卡片索引].状态 === 'failed') {
          Text($r('app.string.ai_card_save_failed'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.error_text'))
        }
      }
      .width('100%')

      if (this.消息列表[消息索引].卡片列表[卡片索引].状态 === 'failed'
        && this.消息列表[消息索引].卡片列表[卡片索引].失败提示 !== '') {
        Text(this.消息列表[消息索引].卡片列表[卡片索引].失败提示)
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.error_text'))
          .width('100%')
      }

      // 字段编辑区：勾选才展开；已保存的卡展示为只读
      if (this.消息列表[消息索引].卡片列表[卡片索引].已选中) {
        ForEach(this.消息列表[消息索引].字段名列表, (字段名: string, 字段索引: number) => {
          Column({ space: 应用尺寸.间距_5 }) {
            Text(字段名)
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            TextArea({
              text: this.消息列表[消息索引].卡片列表[卡片索引].fields[字段索引]
            })
              .width('100%')
              .height(56)
              .fontSize(应用尺寸.字号_正文)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
              .borderRadius(应用尺寸.圆角_面板)
              .padding(应用尺寸.间距_10)
              .enabled(this.消息列表[消息索引].卡片列表[卡片索引].状态 === 'draft')
              .onChange((值: string): void => {
                this.更新卡片字段(消息索引, 卡片索引, 字段索引, 值);
              })
          }
          .width('100%')
        }, (字段名: string, 字段索引: number): string =>
          `${消息索引}-${卡片索引}-${字段索引}-${字段名}`)
      }
    }
    .width('100%')
    .padding(应用尺寸.间距_10)
    .backgroundColor($r('app.color.surface_page'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
    .borderRadius(应用尺寸.圆角_面板)
  }

  @Builder
  private 变更草稿项(消息索引: number, 草稿索引: number) {
    Column({ space: 应用尺寸.间距_8 }) {
      Text(this.消息列表[消息索引].变更草稿列表[草稿索引].summary)
        .fontSize(应用尺寸.字号_正文).fontWeight(FontWeight.Medium).width('100%')
      Text(this.影响范围(this.消息列表[消息索引].变更草稿列表[草稿索引]))
        .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_secondary')).width('100%')
      ForEach(this.消息列表[消息索引].变更草稿列表[草稿索引].operations,
        (operation: DraftOperation, operationIndex: number) => {
          Column({ space: 应用尺寸.间距_4 }) {
            Text(this.取本地化格式($r('app.string.ai_agent_operation_target'),
              [operation.kind, operation.noteId, operation.cardId]))
              .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_secondary')).width('100%')
            if (operation.kind === 'update_field' &&
              this.消息列表[消息索引].变更草稿列表[草稿索引].risk === 'write') {
              TextArea({ text: operation.after })
                .width('100%').height(72)
                .onChange((value: string): void => {
                  this.更新草稿操作(消息索引, 草稿索引, operationIndex, value);
                })
            } else {
              Text(this.取本地化格式($r('app.string.ai_agent_operation_diff'),
                [operation.before, operation.after]))
                .fontSize(应用尺寸.字号_正文_小).maxLines(6)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            }
          }.width('100%')
        }, (_operation: DraftOperation, operationIndex: number): string => `op-${operationIndex}`)
      Button($r('app.string.ai_agent_draft_apply'))
        .width('100%').height(应用尺寸.按钮高度)
        .fontColor($r('app.color.action_on_primary'))
        .backgroundColor(this.消息列表[消息索引].变更草稿列表[草稿索引].risk === 'high_risk'
          ? $r('app.color.error_text') : this.主色按钮背景色)
        .enabled(this.消息列表[消息索引].变更草稿列表[草稿索引].status === 'pending')
        .onClick((): void => { this.准备执行草稿(消息索引, 草稿索引); })
    }
    .width('100%').padding(应用尺寸.间距_10)
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
  }

  private 工具状态文案(status: AgentToolTraceStatus): string {
    if (status === 'completed') { return this.取本地化文案($r('app.string.ai_agent_tool_completed')); }
    if (status === 'failed') { return this.取本地化文案($r('app.string.ai_agent_tool_failed')); }
    return this.取本地化文案($r('app.string.ai_agent_tool_started'));
  }

  private 切换工具详情(消息索引: number, 追踪索引: number): void {
    this.更新消息(消息索引, (消息: 聊天消息): void => {
      if (追踪索引 >= 0 && 追踪索引 < 消息.工具过程.length) {
        消息.工具过程[追踪索引].expanded = !消息.工具过程[追踪索引].expanded;
      }
    });
  }

  @Builder
  private 工具过程项(消息索引: number, 追踪索引: number) {
    AgentDisclosureCard({
      title: this.取本地化格式($r('app.string.ai_agent_tool_round'), [
          this.消息列表[消息索引].工具过程[追踪索引].providerRound,
          this.消息列表[消息索引].工具过程[追踪索引].sequence
        ]) + ` · ${this.消息列表[消息索引].工具过程[追踪索引].toolName}`,
      status: this.工具状态文案(this.消息列表[消息索引].工具过程[追踪索引].status),
      showStatus: true,
      expanded: this.消息列表[消息索引].工具过程[追踪索引].expanded,
      toggleLocked: false,
      onToggle: (): void => { this.切换工具详情(消息索引, 追踪索引); },
      content: (): void => { this.工具详情内容(消息索引, 追踪索引); }
    })
  }

  @Builder
  private 工具详情内容(消息索引: number, 追踪索引: number) {
        if (this.消息列表[消息索引].工具过程[追踪索引].legacySummary.length > 0) {
          Text(this.消息列表[消息索引].工具过程[追踪索引].legacySummary)
            .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_secondary')).width('100%')
        }
        Text($r('app.string.ai_agent_tool_arguments'))
          .fontSize(应用尺寸.字号_正文_小).fontWeight(FontWeight.Medium).width('100%')
        Text(this.消息列表[消息索引].工具过程[追踪索引].argumentsJson.length > 0 ?
          this.消息列表[消息索引].工具过程[追踪索引].argumentsJson : '—')
          .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_secondary')).width('100%')
        if (this.消息列表[消息索引].工具过程[追踪索引].outputJson.length > 0) {
          Text($r('app.string.ai_agent_tool_output'))
            .fontSize(应用尺寸.字号_正文_小).fontWeight(FontWeight.Medium).width('100%')
          Text(this.消息列表[消息索引].工具过程[追踪索引].outputJson)
            .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_secondary')).width('100%')
        }
        if (this.消息列表[消息索引].工具过程[追踪索引].errorCode.length > 0) {
          Text(`${this.取本地化文案($r('app.string.ai_agent_tool_error_code'))}: ` +
            `${this.消息列表[消息索引].工具过程[追踪索引].errorCode}`)
            .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.error_text')).width('100%')
          Text(`${this.取本地化文案($r('app.string.ai_agent_tool_error_path'))}: ` +
            `${this.消息列表[消息索引].工具过程[追踪索引].errorPath || '—'}`)
            .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.error_text')).width('100%')
          if (this.消息列表[消息索引].工具过程[追踪索引].errorMessage.length > 0) {
            Text(this.消息列表[消息索引].工具过程[追踪索引].errorMessage)
              .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.error_text')).width('100%')
          }
          Text(`${this.取本地化文案($r('app.string.ai_agent_tool_received_keys'))}: ` +
            `${JSON.stringify(this.消息列表[消息索引].工具过程[追踪索引].receivedKeys)}`)
            .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_secondary')).width('100%')
          Text(`${this.取本地化文案($r('app.string.ai_agent_tool_allowed_keys'))}: ` +
            `${JSON.stringify(this.消息列表[消息索引].工具过程[追踪索引].allowedKeys)}`)
            .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_secondary')).width('100%')
          if (this.消息列表[消息索引].工具过程[追踪索引].validTemplateJson.length > 0) {
            Text($r('app.string.ai_agent_tool_template'))
              .fontSize(应用尺寸.字号_正文_小).fontWeight(FontWeight.Medium).width('100%')
            Text(this.消息列表[消息索引].工具过程[追踪索引].validTemplateJson)
              .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_secondary')).width('100%')
          }
          Text(this.取本地化格式($r('app.string.ai_agent_tool_repeat_count'),
            [this.消息列表[消息索引].工具过程[追踪索引].repeatCount]))
            .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_tertiary')).width('100%')
        }
        if (this.消息列表[消息索引].工具过程[追踪索引].argumentsTruncated ||
          this.消息列表[消息索引].工具过程[追踪索引].outputTruncated ||
          this.消息列表[消息索引].工具过程[追踪索引].diagnosticTruncated) {
          Text($r('app.string.ai_agent_tool_truncated'))
            .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_tertiary')).width('100%')
        }
  }

  @Builder
  private AI气泡(消息索引: number) {
    Row() {
      Column({ space: 应用尺寸.间距_10 }) {
        if (this.消息列表[消息索引].taskStatus === 'waiting') {
          Text($r('app.string.ai_agent_clarification_waiting'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        Text(this.消息列表[消息索引].正文)
          .fontSize(应用尺寸.字号_正文)
          .fontColor(this.消息列表[消息索引].是否错误
            ? $r('app.color.error_text') : $r('app.color.text_primary'))
          .width('100%')

        if (this.消息列表[消息索引].推理摘要 !== '') {
          Text($r('app.string.ai_agent_reasoning_process'))
            .fontSize(应用尺寸.字号_正文_小).fontWeight(FontWeight.Medium)
          Text(this.消息列表[消息索引].推理摘要)
            .fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_tertiary')).maxLines(8)
        }
        if (this.消息列表[消息索引].工具过程.length > 0) {
          Text($r('app.string.ai_agent_tool_process')).fontSize(应用尺寸.字号_正文_小).fontWeight(FontWeight.Medium)
          ForEach(this.消息列表[消息索引].工具过程, (_trace: AgentToolTrace, index: number) => {
            this.工具过程项(消息索引, index)
          }, (trace: AgentToolTrace, index: number): string => `${index}-${trace.callId}-${trace.status}`)
        }
        if (this.消息列表[消息索引].来源列表.length > 0) {
          Text($r('app.string.ai_agent_sources')).fontSize(应用尺寸.字号_正文_小).fontWeight(FontWeight.Medium)
          ForEach(this.消息列表[消息索引].来源列表, (source: SearchSource) => {
            Text(`${source.title}\n${source.url}`).fontSize(应用尺寸.字号_正文_小)
              .fontColor(this.动作主色).width('100%')
          }, (source: SearchSource): string => source.url)
        }

        // 草稿是本轮 Agent 的最终产物，始终位于思考、工具过程和来源之后。
        if (this.消息列表[消息索引].卡片列表.length > 0) {
          ForEach(this.消息列表[消息索引].卡片列表,
            (卡: 卡片草稿, 卡片索引: number) => {
              this.卡片项(消息索引, 卡片索引)
            }, (卡: 卡片草稿, 卡片索引: number): string => `card-${卡片索引}`)
        }

        if (this.消息列表[消息索引].变更草稿列表.length > 0) {
          ForEach(this.消息列表[消息索引].变更草稿列表,
            (_draft: ChangeDraft, draftIndex: number) => {
              this.变更草稿项(消息索引, draftIndex)
            }, (draft: ChangeDraft): string => draft.id)
        }

        // 保存操作：本批次保存选中卡片
        if (this.消息列表[消息索引].卡片列表.length > 0) {
          Button(this.消息列表[消息索引].批次保存中
            ? $r('app.string.ai_card_saving_cards')
            : (this.待保存数(消息索引) > 0
              ? this.取本地化格式($r('app.string.ai_card_save_selected_count'),
                [`${this.待保存数(消息索引)}`])
              : $r('app.string.ai_card_save_selected')))
            .width('100%')
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.主色按钮背景色)
            .borderRadius(应用尺寸.圆角_胶囊)
            .enabled(this.待保存数(消息索引) > 0 && !this.消息列表[消息索引].批次保存中)
            .onClick((): void => {
              this.保存批次(消息索引);
            })
        }

        if (this.消息列表[消息索引].批次结果 !== '') {
          Text(this.消息列表[消息索引].批次结果)
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor(this.动作主色)
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.surface_card'))
      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
      .borderRadius(应用尺寸.圆角_面板)
      .padding(应用尺寸.卡片内边距)
      // 占满消息区宽度：左右边距对称（均为 卡片内边距），且内嵌卡片 width('100%')
      // 以此为确定的父宽解析，不会再超出气泡右边界。
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private clarificationBubble(messageIndex: number) {
    if (this.消息列表[messageIndex].clarification !== null) {
      AgentClarificationCard({
        clarification: this.消息列表[messageIndex].clarification!,
        statusText: this.消息列表[messageIndex].taskStatus.length > 0 ?
          this.消息列表[messageIndex].taskStatus :
          this.clarificationStatusText(this.消息列表[messageIndex].clarification!),
        onOptionSelected: (id: string): void => { this.selectClarificationOption(messageIndex, id); },
        onSupplementChanged: (value: string): void => {
          this.updateClarificationSupplement(messageIndex, value);
        },
        onContinue: (): void => { this.continueClarification(messageIndex); },
        onToggle: (): void => { this.toggleClarification(messageIndex); }
      })
    }
  }

  @Builder
  private 消息流() {
    Scroll(this.聊天滚动器) {
      Column({ space: 应用尺寸.间距_12 }) {
        AgentSetupCard({
          mode: this.pageMode,
          setup: this.taskSetup(),
          deckOptions: this.牌组选项,
          notetypeOptions: this.笔记类型选项,
          readinessText: this.readinessText(),
          editContext: this.editSetupContext(),
          disabled: this.处理中 || this.hasPendingClarification(),
          onDeckSelected: (id: number): void => {
            this.牌组ID = id;
            this.错误信息 = '';
          },
          onNotetypeSelected: (id: number): void => { this.加载笔记类型(id); },
          onToggle: (): void => { this.setupExpanded = !this.setupExpanded; }
        })
        ForEach(this.消息列表, (消息: 聊天消息, 消息索引: number) => {
          if (this.消息列表[消息索引].角色 === 'user') {
            this.用户气泡(消息索引)
          } else if (this.消息列表[消息索引].kind === 'clarification') {
            this.clarificationBubble(消息索引)
          } else {
            this.AI气泡(消息索引)
          }
        }, (消息: 聊天消息): string => `msg-${消息.id}`)
      }
      .width('100%')
      .padding({
        left: 应用尺寸.卡片内边距,
        right: 应用尺寸.卡片内边距,
        top: 应用尺寸.间距_8,
        bottom: 应用尺寸.间距_8
      })
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
  }

  @Builder
  private 输入区() {
    Row({ space: 应用尺寸.间距_10 }) {
      TextArea({
        placeholder: $r('app.string.ai_card_input_hint'),
        text: this.输入草稿
      })
        .width('100%')
        .layoutWeight(1)
        .height(应用尺寸.按钮高度 * 2)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .backgroundColor($r('app.color.surface_card'))
        .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
        .borderRadius(应用尺寸.圆角_面板)
        .padding(应用尺寸.间距_10)
        .enabled(!this.处理中 && !this.hasPendingClarification())
        .onChange((值: string): void => {
          this.输入草稿 = 值;
        })
      Button(this.处理中 ? $r('app.string.ai_agent_cancel') : $r('app.string.ai_card_send'))
        .height(应用尺寸.按钮高度)
        .constraintSize({ minWidth: 72 })
        .fontSize(应用尺寸.字号_按钮)
        .fontColor($r('app.color.action_on_primary'))
        .backgroundColor(this.处理中 ? this.主色按钮按下色 : this.主色按钮背景色)
        .borderRadius(应用尺寸.圆角_胶囊)
        .enabled(this.处理中 || this.readinessReason() === 'ready')
        .onClick((): void => {
          if (this.处理中) { this.取消当前请求(); }
          else { this.发送(); }
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
    .padding({
      left: 应用尺寸.卡片内边距,
      right: 应用尺寸.卡片内边距,
      top: 应用尺寸.间距_8,
      bottom: 应用尺寸.间距_8 + this.导航条高度
    })
  }

  build() {
    NavDestination() {
      Column() {
        this.顶部条()
        if (this.显示配置区) {
          this.配置区()
        }
        Divider()
          .color($r('app.color.border_subtle'))
          .strokeWidth(应用尺寸.卡片边框)
        this.消息流()
        if (this.错误信息 !== '') {
          Text(this.错误信息)
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.error_text'))
            .width('100%')
            .maxLines(3)
            .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
        }
        this.输入区()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.surface_page'))
    }
    .hideTitleBar(true)
    .opacity(this.转场透明度)
  }
}
