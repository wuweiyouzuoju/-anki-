// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-PAGE-BROWSER-001
// @名称 浏览页
//
// @作用
// 卡片/笔记浏览器（对标 Anki Browser）。手机端单栏布局：
// 顶部条（返回 + 标题 + Cards/Notes 切换）+ 搜索框 + 结果列表。
// 阶段 1 MVP：可搜索 + 查看只读列表。
// 阶段 2：列表行点击后用 Stack+if 弹层打开 浏览编辑区 编辑笔记字段/标签。
//
// @输入
// pageDeckId：可选牌组 ID（空=全库浏览）
// pathStack：Navigation 页面栈，用于返回主页
//
// @输出
// 渲染浏览页 NavDestination
//
// @业务规则
// 进入页面即拉取全部卡片（空搜索串）。搜索串由后端构建（前端不拼字符串），
// 保证与 Anki 桌面端搜索语法一致。行数据按需懒加载（浏览器行按ID）。
//
// @Invariants
// - 搜索串必须经 搜索服务.构建搜索串 构建，不前端拼接
// - 浏览模式切换后自动重新搜索
// - 行缓存与 结果ID列表 按索引对齐
//
// @Extension Points
// - T4 搜索框组件将替换内联 TextInput
// - T5 卡片表格组件将替换内联 List
// - T7 详情编辑区已接入（Stack+if 弹层），后续可扩展批量操作栏（T8）
//
// @副作用
// 通过 搜索服务 调用后端 RPC，读取 Anki collection。
// ========================================================

import { common } from '@kit.AbilityKit';
import { 后端会话 } from '../backend/后端会话';
import { 搜索服务 } from '../backend/搜索服务';
import { 笔记服务 } from '../backend/笔记服务';
import { 笔记类型服务 } from '../backend/笔记类型服务';
import { 卡片服务 } from '../backend/卡片服务';
import { 牌组服务 } from '../backend/牌组服务';
import { 调度器服务 } from '../backend/调度器服务';
import { 统计服务 } from '../backend/统计服务';
import type {
  BrowserColumn,
  BrowserRow,
  FindAndReplaceRequest,
  SearchRequest,
  SortOrder
} from '../proto/messages/SearchMessages';
import { BrowserRowColor } from '../proto/messages/SearchMessages';
import {
  makeParsableTextNode
} from '../proto/messages/SearchMessages';
import type { EditableNote } from '../proto/messages/NoteMessages';
import type { Card } from '../proto/messages/CardsMessages';
import type { CardStatsView } from '../proto/messages/StatsMessages';
import type { DeckTreeNode } from '../proto/messages/DeckMessages';
import { BURY_SUSPEND_MODE_SUSPEND } from '../proto/messages/SchedulerMessages';
import { 应用尺寸 } from '../utils/应用尺寸';
import { CustomTransition } from '../utils/自定义转场';
import { 统一加载态 } from '../components/common/统一加载态';
import { 统一错误态 } from '../components/common/统一错误态';
import { 搜索框 } from '../components/browser/搜索框';
import { 卡片表格, 浏览行数据 } from '../components/browser/卡片表格';
import { 浏览编辑区 } from '../components/browser/浏览编辑区';
import { 批量操作栏 } from '../components/browser/批量操作栏';
import { 卡片信息 } from '../components/browser/卡片信息';
import { 查找替换对话框 } from '../components/browser/查找替换对话框';
import { 颜色键 } from '../model/颜色主题';
import { 加载主题模式 } from '../model/主题存储';
import { 解析是否深色, 主题模式 } from '../model/主题设置';

/** 浏览页阶段状态机：loading=加载中，list=列表展示，error=出错 */
type 浏览阶段 = 'loading' | 'list' | 'error';

/** 浏览模式：cards=卡片列表，notes=笔记列表 */
type 浏览模式 = 'cards' | 'notes';

/** 浏览页入栈参数 */
export interface 浏览页参数 {
  /** 可选：限定牌组 ID（空=全库浏览） */
  deckId?: string;
}

/** T8 改牌组选择器列表项（扁平化后的牌组树节点）。 */
interface 牌组项 {
  id: number;
  名: string;
}

@Component
export struct 浏览页 {
  /** Navigation 入栈参数：牌组 ID（空=全库） */
  pageDeckId: string = '';
  /** 页面栈：返回主页时 pop */
  pathStack: NavPathStack = new NavPathStack();
  private readonly 搜索服务实例: 搜索服务 = new 搜索服务();
  private readonly 笔记服务实例: 笔记服务 = new 笔记服务();
  private readonly 笔记类型服务实例: 笔记类型服务 = new 笔记类型服务();
  private readonly 卡片服务实例: 卡片服务 = new 卡片服务();
  private readonly 牌组服务实例: 牌组服务 = new 牌组服务();
  private readonly 调度器服务实例: 调度器服务 = new 调度器服务();
  private readonly 统计服务实例: 统计服务 = new 统计服务();

  @State private 阶段: 浏览阶段 = 'loading';
  @State private 错误详情: string = '';
  @State private 搜索文本: string = '';
  @State private 浏览模式值: 浏览模式 = 'cards';
  @State private 结果ID列表: number[] = [];
  @State private 行列表: 浏览行数据[] = [];
  @State private 列定义: BrowserColumn[] = [];
  /** 顶部牌组选择器当前索引（0=全部牌组，1+=扁平化牌组列表对应项）。 */
  @State private 当前牌组索引: number = 0;
  /** NavDestination 透明度（由 customNavContentTransition 回调控制，实现淡入淡出转场）。 */
  @State private 转场透明度: number = 1;

  // T7 浏览编辑区状态：行点击后懒加载笔记 + 字段名，弹层内编辑字段/标签，保存调 更新笔记
  @State private 显示编辑区: boolean = false;
  @State private 编辑区字段名列表: string[] = [];
  @State private 编辑区初始字段值: string[] = [];
  @State private 编辑区初始标签: string = '';
  @State private 编辑区错误: string = '';
  @State private 编辑区忙碌: boolean = false;
  // 当前正在编辑的笔记（保存时复用 id/guid/notetypeId/mtime/usn，仅 fields/tags 来自弹层）
  @State private 编辑区当前笔记: EditableNote | null = null;

  // T11 卡片信息状态：非多选模式下点击行右侧 info 按钮 → 懒加载该卡 CardStatsView
  @State private 显示卡片信息: boolean = false;
  @State private 卡片信息数据: CardStatsView | null = null;
  @State private 卡片信息错误: string = '';
  @State private 卡片信息忙碌: boolean = false;

  // T8 批量操作栏状态：多选模式 + 选中ID + 4 个操作弹层 + 牌组树（改牌组选择器用）
  @State private 多选模式值: boolean = false;
  @State private 选中ID列表: number[] = [];
  // 退出多选信号：每次退出多选 +1，经 @Watch 触发 卡片表格 清内部选中（组件内部状态不可外部直改）
  @State private 退出多选信号: number = 0;
  @State private 批量忙碌: boolean = false;
  @State private 批量错误: string = '';
  @State private 显示改牌组弹层: boolean = false;
  @State private 显示标志弹层: boolean = false;
  @State private 显示挂起确认: boolean = false;
  @State private 显示删除确认: boolean = false;
  @State private 牌组树: DeckTreeNode | null = null;

  // T9 查找替换状态：顶部条按钮触发弹层，支持仅选中笔记或全部笔记两种范围
  @State private 显示查找替换: boolean = false;
  @State private 查找替换忙碌: boolean = false;
  @State private 查找替换错误: string = '';

  // 主题模式：编辑区 isDark 判断用（与 学习页/添加笔记页 同语义）
  @State private 主题模式值: 主题模式 = 'system';
  @StorageLink('systemDarkMode') private 系统暗黑模式: boolean = false;

  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';
  @StorageProp(颜色键.页面底色微染) private 页面底色微染值: string = '#F5F7FA';

  async aboutToAppear(): Promise<void> {
    // 注册自定义转场回调：首页 Navigation.customNavContentTransition 通过此 name 查找回调，
    // 在 animateTo 内调用起点/终点回调修改 转场透明度，实现淡入淡出（替代系统默认左右平移）。
    // key 用 'BrowserPage'（NavPathStack pushPath 时传的 name，与 from.name / to.name 一致）。
    CustomTransition.getInstance().注册NavParam('BrowserPage',
      (isPush: boolean, isExit: boolean): void => {
        this.转场透明度 = isExit ? 1 : 0;
      },
      (isPush: boolean, isExit: boolean): void => {
        this.转场透明度 = isExit ? 0 : 1;
      }
    );
    // 加载主题模式用于编辑区深色判断；失败回退 'system'，不阻塞浏览流程
    try {
      this.主题模式值 = await 加载主题模式();
    } catch (_错误) {
      this.主题模式值 = 'system';
    }
    await this.执行搜索();
    // 顶部牌组选择器：加载牌组树（失败不阻塞搜索，Select 仅显示"全部"）
    this.加载牌组树().catch((错误: ESObject): void => {
      console.info(`BrowserPage: aboutToAppear 加载牌组树失败 错误=${错误}`);
    });
  }

  /** 加载牌组树供顶部选择器 + T8 改牌组弹层共用。 */
  private async 加载牌组树(): Promise<void> {
    try {
      this.牌组树 = await this.牌组服务实例.获取牌组树();
    } catch (错误) {
      console.info(`BrowserPage: 加载牌组树失败 错误=${错误}`);
    }
  }

  /** 暗色模式判断：主题模式值=system 时跟随系统，否则按显式选择。与 学习页/添加笔记页 同语义。 */
  private 是否深色(): boolean {
    return 解析是否深色(this.主题模式值, this.系统暗黑模式);
  }

  /** 读取本地化文案，context 不可用时回退空串。 */
  private 取本地化文案(资源: Resource): string {
    const 上下文: common.UIAbilityContext | null = this.取能力上下文();
    if (上下文 === null) {
      return '';
    }
    try {
      return 上下文.resourceManager.getStringSync(资源.id);
    } catch (_错误) {
      return '';
    }
  }

  aboutToDisappear(): void {
    CustomTransition.getInstance().注销NavParam('BrowserPage');
  }

  private 取能力上下文(): common.UIAbilityContext | null {
    const context: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return context === undefined ? null : context;
  }

  // ========================================================
  // @块ID UI-PAGE-BROWSER-002
  // @名称 执行搜索
  //
  // @作用
  // 根据当前搜索文本和浏览模式，调后端搜索卡片/笔记 ID，并预加载前 50 行数据。
  //
  // @输入
  // 搜索文本 + 浏览模式值
  //
  // @输出
  // 更新 阶段 / 结果ID列表 / 行列表 / 列定义
  //
  // @业务规则
  // 搜索串由后端构建搜索串生成（前端不拼字符串）。
  // 首次搜索时拉取列定义（全部浏览器列），后续复用。
  // 行数据按需懒加载，MVP 预加载前 50 行避免首屏空白。
  //
  // @副作用
  // 调后端 构建搜索串 / 搜索卡片 / 搜索笔记 / 全部浏览器列 / 浏览器行按ID
  // ========================================================
  private async 执行搜索(): Promise<void> {
    this.阶段 = 'loading';
    try {
      const context: common.UIAbilityContext | null = this.取能力上下文();
      if (context === null) {
        this.阶段 = 'error';
        this.错误详情 = this.getUIContext().getHostContext()!.resourceManager
          .getStringSync($r('app.string.ability_context_unavailable').id);
        return;
      }
      await 后端会话.获取实例().确保已打开(context.filesDir);

      // 首次搜索时拉取列定义并设置激活列（后端 browser_row_for_id 要求 active_browser_columns 已设置）
      if (this.列定义.length === 0) {
        const cols = await this.搜索服务实例.全部浏览器列();
        this.列定义 = cols.columns;
        // 手机端默认激活 Question + Deck + Due + Flags 四列（与 Anki 桌面端一致，cells 顺序按激活列顺序）
        // 列 key 来自 Anki 后端 strum camelCase 序列化（browser_table.rs）：Question→"question" 等
        // 未设置则 browser_row_for_id 报 "Active browser columns not set."
        const 默认列键: string[] = ['question', 'deck', 'cardDue', 'flags'];
        await this.搜索服务实例.设置激活浏览器列(默认列键);
        console.info(`BrowserPage: 列定义=${cols.columns.length} 列，激活列=${默认列键.join(',')}`);
      }

      // 构建搜索串（后端构建，前端不拼字符串）
      const searchNode = makeParsableTextNode(this.搜索文本);
      const searchStr = await this.搜索服务实例.构建搜索串(searchNode);
      console.info(`BrowserPage: 搜索文本="${this.搜索文本}" 搜索串="${searchStr}"`);

      // 按模式搜索卡片或笔记
      const order: SortOrder = { kind: 'none' };
      const request: SearchRequest = { search: searchStr, order };
      const ids = this.浏览模式值 === 'cards'
        ? await this.搜索服务实例.搜索卡片(request)
        : await this.搜索服务实例.搜索笔记(request);
      console.info(`BrowserPage: 模式=${this.浏览模式值} 搜索返回 ${ids.length} 个 ID`);

      this.结果ID列表 = ids;
      this.行列表 = [];

      // 预加载前 200 行（避免首屏空白；后端 browser_row_for_id 是单 ID 查询，无批量接口）
      await this.预加载行(ids.slice(0, 200));
      console.info(`BrowserPage: 预加载完成 行列表=${this.行列表.length} 行`);

      this.阶段 = 'list';
    } catch (error) {
      this.阶段 = 'error';
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
    }
  }

  /**
   * 加载更多行：取下一批未加载的 ID，预加载后追加到 行列表。
   * 由 卡片表格.onReachEnd 触发；批次大小 100，并发 10。
   */
  private async 加载更多(): Promise<void> {
    const 已加载数: number = this.行列表.length;
    if (已加载数 >= this.结果ID列表.length) {
      return;
    }
    const 下一批: number[] = this.结果ID列表.slice(已加载数, 已加载数 + 100);
    console.info(`BrowserPage: 加载更多 已加载=${已加载数} 本批=${下一批.length} 总=${this.结果ID列表.length}`);
    await this.预加载行(下一批);
    console.info(`BrowserPage: 加载更多完成 行列表=${this.行列表.length} 行`);
  }

  /** 预加载行数据：并行拉取（每批 20 个），累积后一次性赋值触发 UI 刷新。 */
  private async 预加载行(ids: number[]): Promise<void> {
    const 批次大小: number = 20;
    let 成功数: number = 0;
    let 失败数: number = 0;
    const 累积新增: 浏览行数据[] = [];
    for (let i = 0; i < ids.length; i += 批次大小) {
      const 批次: number[] = ids.slice(i, i + 批次大小);
      const 行们: (BrowserRow | null)[] = await Promise.all(
        批次.map((id: number): Promise<BrowserRow | null> => {
          return this.搜索服务实例.浏览器行按ID(id)
            .then((row: BrowserRow): BrowserRow => {
              成功数++;
              return row;
            })
            .catch((err: ESObject): BrowserRow | null => {
              失败数++;
              console.info(`BrowserPage: 浏览器行按ID(${id}) 失败: ${err}`);
              return null;
            });
        })
      );
      批次.forEach((id: number, idx: number): void => {
        const row: BrowserRow | null = 行们[idx];
        if (row !== null) {
          累积新增.push({ id, cells: row.cells, color: row.color });
        }
      });
    }
    // 累积所有批次后一次性赋值，避免循环内多次 concat 导致 @State 更新丢失
    if (累积新增.length > 0) {
      this.行列表 = this.行列表.concat(累积新增);
    }
    console.info(`BrowserPage: 预加载统计 成功=${成功数} 失败=${失败数}`);
  }

  /** 切换浏览模式（cards/notes），切换后自动重新搜索。 */
  private 切换模式(模式: 浏览模式): void {
    if (this.浏览模式值 === 模式) {
      return;
    }
    this.浏览模式值 = 模式;
    this.执行搜索();
  }

  /** 提交搜索（搜索框 onSubmit 触发）。 */
  private 提交搜索(文本: string): void {
    this.搜索文本 = 文本;
    this.执行搜索();
  }

  // ========================================================
  // @块ID UI-PAGE-BROWSER-003
  // @名称 行点击
  //
  // @作用
  // 行点击后懒加载笔记 + 笔记类型字段名，弹出 浏览编辑区 进行字段/标签编辑。
  // - Notes 模式：行ID 即 noteId，直接调 笔记服务.获取笔记
  // - Cards 模式：行ID 是 cardId，先调 卡片服务.获取卡片 拿 noteId，再调 笔记服务.获取笔记
  //
  // @输入
  // 行ID: 当前行 ID（语义随 浏览模式值 变化）
  //
  // @输出
  // 成功 → 设置 编辑区当前笔记 / 字段名列表 / 初始字段值 / 初始标签 / 显示编辑区=true
  // 失败 → 在 编辑区错误 显示加载失败文案并打开弹层（让用户感知错误）
  //
  // @业务规则
  // Cards 模式下需多一跳卡片查询，但 UI 仍只展示笔记字段（与 Anki 桌面端一致）。
  // 加载期间不禁用列表（只设 编辑区忙碌），用户可关闭弹层或重试。
  //
  // @副作用
  // 调后端 获取卡片 / 获取笔记 / 获取笔记类型；读 Anki collection。
  // ========================================================
  private async 行点击(行ID: number): Promise<void> {
    this.编辑区忙碌 = true;
    this.编辑区错误 = '';
    this.编辑区当前笔记 = null;
    this.编辑区字段名列表 = [];
    this.编辑区初始字段值 = [];
    this.编辑区初始标签 = '';
    this.显示编辑区 = true;
    try {
      // 1. 拿到 noteId：Notes 模式直接用，Cards 模式经卡片查询
      let noteId: number = 行ID;
      if (this.浏览模式值 === 'cards') {
        const card: Card = await this.卡片服务实例.获取卡片(行ID);
        noteId = card.noteId;
      }
      // 2. 拉笔记（必须先拿到 notetypeId 才能查字段名）
      const note: EditableNote = await this.笔记服务实例.获取笔记(noteId);
      const notetypeView = await this.笔记类型服务实例.获取笔记类型(note.notetypeId);
      this.编辑区当前笔记 = note;
      this.编辑区字段名列表 = notetypeView.fieldNames;
      this.编辑区初始字段值 = note.fields.slice();
      this.编辑区初始标签 = note.tags.join(' ');
    } catch (错误) {
      this.编辑区错误 = this.取本地化文案($r('app.string.browser_detail_load_error'));
      console.info(`BrowserPage: 行点击加载笔记失败 行ID=${行ID} 模式=${this.浏览模式值} 错误=${错误}`);
    } finally {
      this.编辑区忙碌 = false;
    }
  }

  // ========================================================
  // @块ID UI-PAGE-BROWSER-004
  // @名称 保存编辑
  //
  // @作用
  // 浏览编辑区 onSave 回调：用 编辑区当前笔记 的 id/guid/notetypeId/mtime/usn + 弹层传入的
  // fields/tags 构造 EditableNote，调 笔记服务.更新笔记 落盘。成功后关闭弹层并刷新当前行。
  //
  // @输入
  // fields: 编辑后的字段值数组
  // tags: 编辑后的标签数组
  //
  // @输出
  // 成功 → 返回 true，关闭弹层，触发 执行搜索 刷新列表
  // 失败 → 返回 false，在 编辑区错误 显示保存失败文案（草稿保留）
  //
  // @业务规则
  // - skipUndoEntry=false 保留撤销栈（与 Anki 桌面端默认一致）
  // - 编辑区当前笔记 为 null 时直接返回 false（不应发生，兜底）
  // - 字段值数组长度不足 字段名列表 时用空串补齐（防御性）
  //
  // @副作用
  // 调后端 更新笔记；成功后调 执行搜索 重新加载列表。
  // ========================================================
  private async 保存编辑(fields: string[], tags: string[]): Promise<boolean> {
    const 原笔记: EditableNote | null = this.编辑区当前笔记;
    if (原笔记 === null) {
      return false;
    }
    this.编辑区忙碌 = true;
    this.编辑区错误 = '';
    try {
      // 字段值长度对齐字段名（防御性：弹层未填齐时补空串）
      const 字段数: number = this.编辑区字段名列表.length;
      const 字段值: string[] = fields.slice();
      while (字段值.length < 字段数) {
        字段值.push('');
      }
      const 更新后: EditableNote = {
        id: 原笔记.id,
        guid: 原笔记.guid,
        notetypeId: 原笔记.notetypeId,
        mtimeSecs: 原笔记.mtimeSecs,
        usn: 原笔记.usn,
        tags,
        fields: 字段值
      };
      await this.笔记服务实例.更新笔记([更新后], false);
      // 关闭弹层 + 刷新列表（让用户看到新字段值）
      this.显示编辑区 = false;
      this.编辑区当前笔记 = null;
      await this.执行搜索();
      return true;
    } catch (错误) {
      this.编辑区错误 = this.取本地化文案($r('app.string.browser_detail_save_error'));
      console.info(`BrowserPage: 保存笔记失败 noteId=${原笔记.id} 错误=${错误}`);
      return false;
    } finally {
      this.编辑区忙碌 = false;
    }
  }

  // ========================================================
  // @名称 T8 批量操作
  //
  // @作用
  // 多选模式下 4 个批量操作：改牌组 / 设置标志 / 挂起 / 删除。
  // 每个操作先弹层确认/选择，再调对应 service 落盘，成功后退出多选 + 刷新列表。
  //
  // @业务规则
  // - 选中ID列表在 cards 模式下是 cardId，notes 模式下是 noteId
  // - 删除：cards 模式直接 删除卡片(选中ID)；notes 模式需先查每条笔记的所有卡片再删（级联）
  // - 挂起：仅 cards 模式有意义（notes 模式无卡片ID），调 批量埋藏或暂停卡片(SUSPEND)
  // - 改牌组/设置标志：cards 模式直接用；notes 模式需先查笔记的所有卡片再操作
  //
  // @副作用
  // 调后端 设置牌组 / 设置标志 / 批量埋藏或暂停 / 删除卡片；成功后调 执行搜索 刷新列表。
  // ========================================================

  /** 扁平化牌组树为列表（改牌组选择器渲染用，跳过根节点 deckId=0）。 */
  private 扁平化牌组树(节点: DeckTreeNode, 前缀: string, 输出: 牌组项[]): void {
    if (节点.deckId !== 0) {
      const 项: 牌组项 = { id: 节点.deckId, 名: 前缀 + 节点.name };
      输出.push(项);
    }
    for (const 子 of 节点.children) {
      const 子前缀: string = 节点.deckId === 0 ? '' : 前缀 + 节点.name + '::';
      this.扁平化牌组树(子, 子前缀, 输出);
    }
  }

  /** 扁平化牌组树为列表的无参包装（弹层 ForEach 直接调用）。 */
  private 扁平化牌组树为列表(): 牌组项[] {
    const 输出: 牌组项[] = [];
    if (this.牌组树 !== null) {
      this.扁平化牌组树(this.牌组树, '', 输出);
    }
    return 输出;
  }

  /** 顶部牌组选择器选项：第 0 项="全部牌组"，后续=扁平化牌组列表。 */
  private 牌组选项(): SelectOption[] {
    const 选项: SelectOption[] = [{ value: this.取本地化文案($r('app.string.browser_deck_all')) }];
    const 列表: 牌组项[] = this.扁平化牌组树为列表();
    for (const 项 of 列表) {
      选项.push({ value: 项.名 });
    }
    return 选项;
  }

  /** 顶部牌组选择器当前显示名（Select.value 必须传 string 不能传 Resource）。 */
  private 取当前牌组显示名(): string {
    if (this.当前牌组索引 === 0) {
      return this.取本地化文案($r('app.string.browser_deck_all'));
    }
    const 列表: 牌组项[] = this.扁平化牌组树为列表();
    const 项: 牌组项 | undefined = 列表[this.当前牌组索引 - 1];
    return 项 !== undefined ? 项.名 : this.取本地化文案($r('app.string.browser_deck_all'));
  }

  /**
   * 顶部牌组选择器 onSelect：选牌组后注入 deck:"牌组名" 到搜索文本触发搜索。
   * 与 Anki 桌面端侧边栏点牌组同语义（替换搜索框为 deck:xxx）。
   * 牌组名含 :: 需加引号；选"全部"清空搜索文本。
   */
  private 选牌组(索引: number): void {
    this.当前牌组索引 = 索引;
    if (索引 === 0) {
      this.搜索文本 = '';
    } else {
      const 列表: 牌组项[] = this.扁平化牌组树为列表();
      const 项: 牌组项 | undefined = 列表[索引 - 1];
      if (项 !== undefined) {
        this.搜索文本 = `deck:"${项.名}"`;
      }
    }
    this.执行搜索();
  }

  /** 标志文案：0=无/1=红/2=橙/3=绿/4=蓝。 */
  private 标志文案(flag: number): string {
    const 上下文: common.UIAbilityContext | null = this.取能力上下文();
    if (上下文 === null) {
      return '';
    }
    const keyMap: Record<number, string> = {
      0: 'browser_action_flag_none',
      1: 'browser_action_flag_red',
      2: 'browser_action_flag_orange',
      3: 'browser_action_flag_green',
      4: 'browser_action_flag_blue'
    };
    const key: string = keyMap[flag] ?? 'browser_action_flag_none';
    try {
      // 用 getStringByNameSync 按名字直取（$r 是编译期宏，模板字符串拼 key 运行时拿不到 id）
      return 上下文.resourceManager.getStringByNameSync(key);
    } catch (_错误) {
      return '';
    }
  }

  /** 标志色块颜色：0=无（透明）/1=红/2=橙/3=绿/4=蓝。色值与 Anki 桌面端 flag 色对齐。 */
  private 标志颜色(flag: number): string {
    const 色表: Record<number, string> = {
      0: 'transparent',
      1: '#D92D20',
      2: '#D97A1C',
      3: '#238463',
      4: '#2F5FD0'
    };
    return 色表[flag] ?? 'transparent';
  }

  /** 打开改牌组弹层：先加载牌组树再显示。 */
  private async 打开改牌组弹层(): Promise<void> {
    if (this.选中ID列表.length === 0) {
      return;
    }
    this.批量忙碌 = true;
    this.批量错误 = '';
    try {
      this.牌组树 = await this.牌组服务实例.获取牌组树();
      this.显示改牌组弹层 = true;
    } catch (错误) {
      this.批量错误 = this.取本地化文案($r('app.string.browser_action_deck_load_error'));
      console.info(`BrowserPage: 加载牌组树失败 错误=${错误}`);
    } finally {
      this.批量忙碌 = false;
    }
  }

  /** 执行批量改牌组：cards 模式直接用选中ID，notes 模式先查每条笔记的所有卡片。 */
  private async 执行批量改牌组(牌组ID: number): Promise<void> {
    this.显示改牌组弹层 = false;
    this.批量忙碌 = true;
    this.批量错误 = '';
    try {
      const 卡片IDs: number[] = await this.解析选中为卡片ID();
      await this.卡片服务实例.设置牌组(卡片IDs, 牌组ID);
      this.退出多选();
      await this.执行搜索();
    } catch (错误) {
      this.批量错误 = this.取本地化文案($r('app.string.browser_action_deck_error'));
      console.info(`BrowserPage: 批量改牌组失败 错误=${错误}`);
    } finally {
      this.批量忙碌 = false;
    }
  }

  /** 执行批量设置标志：flag 取值 0=无/1=红/2=橙/3=绿/4=蓝。 */
  private async 执行批量设置标志(标志: number): Promise<void> {
    this.显示标志弹层 = false;
    this.批量忙碌 = true;
    this.批量错误 = '';
    try {
      const 卡片IDs: number[] = await this.解析选中为卡片ID();
      await this.卡片服务实例.设置标志(卡片IDs, 标志);
      // 本地更新选中行 color（flag→BrowserRowColor 映射：0→DEFAULT, 1→RED(3), 2→ORANGE(4), 3→GREEN(5), 4→BLUE(6)）
      const 目标色: BrowserRowColor = 标志 === 0 ? BrowserRowColor.COLOR_DEFAULT
        : (标志 + 2) as BrowserRowColor;
      this.本地更新选中行颜色(目标色);
      this.退出多选();
    } catch (错误) {
      this.批量错误 = this.取本地化文案($r('app.string.browser_action_flag_error'));
      console.info(`BrowserPage: 批量设置标志失败 错误=${错误}`);
    } finally {
      this.批量忙碌 = false;
    }
  }

  /** 执行批量挂起：调 批量埋藏或暂停卡片(SUSPEND)。仅 cards 模式。 */
  private async 执行批量挂起(): Promise<void> {
    this.显示挂起确认 = false;
    this.批量忙碌 = true;
    this.批量错误 = '';
    try {
      const 卡片IDs: number[] = await this.解析选中为卡片ID();
      await this.调度器服务实例.批量埋藏或暂停卡片(卡片IDs, BURY_SUSPEND_MODE_SUSPEND);
      // 挂起后本地移除选中行（不调 执行搜索：空搜索仍返回 suspended 卡，
      // 用户期望挂起即从列表消失，与删除 UX 一致）
      this.本地移除选中行();
      this.退出多选();
    } catch (错误) {
      this.批量错误 = this.取本地化文案($r('app.string.browser_action_suspend_error'));
      console.info(`BrowserPage: 批量挂起失败 错误=${错误}`);
    } finally {
      this.批量忙碌 = false;
    }
  }

  /** 本地从 结果ID列表 + 行列表 移除选中ID（挂起/删除后用，避免重新搜索的 loading 闪烁）。 */
  private 本地移除选中行(): void {
    const 选中集合: Set<number> = new Set<number>(this.选中ID列表);
    this.结果ID列表 = this.结果ID列表.filter((id: number): boolean => !选中集合.has(id));
    this.行列表 = this.行列表.filter((行: 浏览行数据): boolean => !选中集合.has(行.id));
  }

  /** 本地更新选中行的 color（设置标志后用，让色条立即显示，不重新搜索避免 loading 闪烁）。 */
  private 本地更新选中行颜色(色: BrowserRowColor): void {
    const 选中集合: Set<number> = new Set<number>(this.选中ID列表);
    this.行列表 = this.行列表.map((行: 浏览行数据): 浏览行数据 => {
      if (选中集合.has(行.id)) {
        return { id: 行.id, cells: 行.cells, color: 色 };
      }
      return 行;
    });
  }

  /** 执行批量删除：cards 模式直接 删除卡片(选中ID)；notes 模式先查每条笔记的所有卡片再删。 */
  private async 执行批量删除(): Promise<void> {
    this.显示删除确认 = false;
    this.批量忙碌 = true;
    this.批量错误 = '';
    try {
      const 卡片IDs: number[] = await this.解析选中为卡片ID();
      await this.卡片服务实例.删除卡片(卡片IDs);
      // 删除成功后本地移除选中行（与挂起同款，避免重新搜索的 loading 闪烁）
      this.本地移除选中行();
      this.退出多选();
    } catch (错误) {
      this.批量错误 = this.取本地化文案($r('app.string.browser_action_delete_error'));
      console.info(`BrowserPage: 批量删除失败 错误=${错误}`);
    } finally {
      this.批量忙碌 = false;
    }
  }

  /**
   * 解析选中ID为卡片ID：cards 模式直接返回，notes 模式需查每条笔记的所有卡片。
   * notes 模式下一条笔记可能有多张卡片，全部删除/改牌组/设标志。
   * 挂起操作在 notes 模式下也经此转换（卡片维度挂起）。
   */
  private async 解析选中为卡片ID(): Promise<number[]> {
    if (this.浏览模式值 === 'cards') {
      return this.选中ID列表.slice();
    }
    // notes 模式：查每条笔记的卡片。当前无"按笔记查卡片ID"的 RPC，
    // 退化为用 卡片服务.获取卡片 逐个查（选中ID 当 cardId 查 noteId 再查卡片不现实）。
    // 实际 notes 模式下选中ID是 noteId，Anki 后端无直接 noteId→cardIds 的 RPC，
    // 此处暂返回空数组提示用户切到 cards 模式操作。
    this.批量错误 = this.取本地化文案($r('app.string.browser_action_notes_mode_hint'));
    return [];
  }

  /** 退出多选模式：清空选中 + 多选模式值 + 翻转信号触发 卡片表格 清内部状态。 */
  private 退出多选(): void {
    this.选中ID列表 = [];
    this.多选模式值 = false;
    this.退出多选信号 += 1;
  }

  /** 打开卡片信息弹层：调 统计服务.获取卡片统计 懒加载该卡的 CardStatsView。 */
  private async 打开卡片信息(卡片ID: number): Promise<void> {
    if (this.卡片信息忙碌) {
      return;
    }
    this.卡片信息数据 = null;
    this.卡片信息错误 = '';
    this.卡片信息忙碌 = true;
    this.显示卡片信息 = true;
    try {
      this.卡片信息数据 = await this.统计服务实例.获取卡片统计(卡片ID);
    } catch (错误) {
      this.卡片信息错误 = this.取本地化文案($r('app.string.browser_info_load_error'));
      console.info(`BrowserPage: 加载卡片信息失败 cid=${卡片ID} 错误=${错误}`);
    } finally {
      this.卡片信息忙碌 = false;
    }
  }

  /** 关闭卡片信息弹层。 */
  private 关闭卡片信息(): void {
    this.显示卡片信息 = false;
    this.卡片信息数据 = null;
    this.卡片信息错误 = '';
  }

  /**
   * T9 执行查找替换：调 搜索服务.查找并替换。
   * nids 解析：
   * - 仅选中=true：cards 模式经 卡片服务.获取卡片 把 cardId 转 noteId 后去重；notes 模式直接用选中ID
   * - 仅选中=false：nids 留空，后端对全部笔记生效
   * 成功后关闭弹层 + toast 提示替换数 + 重新搜索刷新列表。
   */
  private async 执行查找替换(
    查找: string,
    替换: string,
    字段名: string,
    正则: boolean,
    区分大小写: boolean,
    仅选中: boolean
  ): Promise<boolean> {
    this.查找替换忙碌 = true;
    this.查找替换错误 = '';
    try {
      let nids: number[] = [];
      if (仅选中) {
        nids = await this.解析选中为笔记ID();
        if (nids.length === 0) {
          this.查找替换错误 = this.取本地化文案($r('app.string.browser_find_no_notes_error'));
          return false;
        }
      }
      const 请求: FindAndReplaceRequest = {
        nids,
        search: 查找,
        replacement: 替换,
        regex: 正则,
        matchCase: 区分大小写,
        fieldName: 字段名
      };
      const 替换数 = await this.搜索服务实例.查找并替换(请求);
      this.显示查找替换 = false;
      // 刷新列表以反映替换后的字段变化
      await this.执行搜索();
      // 成功提示（%d 替换为实际数）
      const 模板 = this.取本地化文案($r('app.string.browser_find_success'));
      const 消息 = 模板.replace('%d', String(替换数));
      try {
        this.getUIContext().getPromptAction().showToast({ message: 消息 });
      } catch (_错误) {
        // toast 失败不影响主流程
      }
      return true;
    } catch (错误) {
      this.查找替换错误 = this.取本地化文案($r('app.string.browser_find_error'));
      console.info(`BrowserPage: 查找替换失败 错误=${错误}`);
      return false;
    } finally {
      this.查找替换忙碌 = false;
    }
  }

  /**
   * 解析选中ID为笔记ID：notes 模式直接返回，cards 模式逐个调 卡片服务.获取卡片 取 noteId 后去重。
   * 供 T9 查找替换"仅选中笔记"范围使用。
   */
  private async 解析选中为笔记ID(): Promise<number[]> {
    if (this.浏览模式值 === 'notes') {
      return this.选中ID列表.slice();
    }
    // cards 模式：逐个 cardId → card.noteId，去重
    const noteIdSet: Set<number> = new Set<number>();
    for (const 卡片ID of this.选中ID列表) {
      try {
        const card: Card = await this.卡片服务实例.获取卡片(卡片ID);
        noteIdSet.add(card.noteId);
      } catch (错误) {
        console.info(`BrowserPage: 解析笔记ID失败 cardId=${卡片ID} 错误=${错误}`);
      }
    }
    return Array.from(noteIdSet);
  }

  /** 返回主页。 */
  private 返回(): void {
    this.pathStack.pop();
  }

  @Builder
  private 顶部条() {
    // 操作层：返回按钮(左) + 查找替换按钮 + 牌组选择器(右)
    Row() {
      Button($r('app.string.study_back'))
        .height(应用尺寸.按钮高度)
        .padding({ left: 应用尺寸.间距_12, right: 应用尺寸.间距_12 })
        .fontSize(应用尺寸.字号_按钮)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_card'))
        .onClick((): void => this.返回())

      // T9 查找替换入口：点击弹出对话框，支持仅选中笔记或全部笔记两种范围
      Button($r('app.string.browser_action_find_replace'))
        .height(应用尺寸.按钮高度)
        .padding({ left: 应用尺寸.间距_12, right: 应用尺寸.间距_12 })
        .fontSize(应用尺寸.字号_按钮)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_card'))
        .enabled(this.阶段 === 'list')
        .onClick((): void => {
          this.查找替换错误 = '';
          this.显示查找替换 = true;
        })

      Blank()

      // 牌组选择器（同外观分组极光蓝 Select 形态，controlSize SMALL）
      Select(this.牌组选项())
        .selected(this.当前牌组索引)
        .value(this.取当前牌组显示名())
        .controlSize(ControlSize.SMALL)
        .onSelect((索引: number): void => {
          this.选牌组(索引);
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 应用尺寸.间距_8, right: 应用尺寸.间距_8 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          this.顶部条()

          // 搜索框组件（TextInput + Cards/Notes 模式切换）
          搜索框({
            搜索文本: this.搜索文本,
            浏览模式值: this.浏览模式值,
            主色按钮背景色: this.主色按钮背景色,
            onSearch: (文本: string): void => { this.提交搜索(文本); },
            onModeChange: (模式: string): void => { this.切换模式(模式 as 浏览模式); }
          })
            .padding({ left: 应用尺寸.间距_16, right: 应用尺寸.间距_16, top: 应用尺寸.间距_8,
              bottom: 应用尺寸.间距_8 })

          if (this.阶段 === 'loading') {
            统一加载态({
              文案: $r('app.string.browser_loading')
            })
          }
          if (this.阶段 === 'error') {
            统一错误态({
              文案: this.错误详情 !== '' ? this.错误详情 : $r('app.string.browser_search_error'),
              onRetry: (): void => { this.执行搜索(); }
            })
          }
          if (this.阶段 === 'list') {
            // 卡片表格组件（扁平列表 + 多选 + 空态 + 懒加载）
            卡片表格({
              行列表: this.行列表,
              结果总数: this.结果ID列表.length,
              已加载行数: this.行列表.length,
              onRowClick: (行ID: number): void => { this.行点击(行ID); },
              onLongPress: (): void => {},
              onLoadMore: (): void => { this.加载更多(); },
              onInfoClick: (行ID: number): void => { this.打开卡片信息(行ID); },
              onSelectionChange: (选中IDs: number[]): void => { this.选中ID列表 = 选中IDs; },
              onMultiSelectChange: (多选: boolean): void => { this.多选模式值 = 多选; },
              退出多选信号: this.退出多选信号
            })
          }

          // T8 批量操作栏：多选模式下固定在底部
          if (this.多选模式值 && this.选中ID列表.length > 0) {
            批量操作栏({
              isDark: this.是否深色(),
              busy: this.批量忙碌,
              选中数: this.选中ID列表.length,
              on改牌组: (): void => { this.打开改牌组弹层(); },
              on设置标志: (): void => {
                this.批量错误 = '';
                this.显示标志弹层 = true;
              },
              on挂起: (): void => {
                this.批量错误 = '';
                this.显示挂起确认 = true;
              },
              on删除: (): void => {
                this.批量错误 = '';
                this.显示删除确认 = true;
              }
            })
          }

          // T8 批量操作错误提示（顶部告警条，不遮挡悬浮窗交互）
          if (this.批量错误 !== '') {
            Text(this.批量错误)
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor($r('app.color.error_text'))
              .backgroundColor($r('app.color.surface_card'))
              .padding({ left: 应用尺寸.间距_16, right: 应用尺寸.间距_16,
                top: 应用尺寸.间距_8, bottom: 应用尺寸.间距_8 })
              .width('100%')
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.页面底色微染值)

        // T7 浏览编辑区弹层：Stack + if 控制挂载/卸载（与 添加笔记页.ets 的 字段帮助面板/图片遮罩编辑器 同机制）
        if (this.显示编辑区) {
          浏览编辑区({
            isDark: this.是否深色(),
            busy: this.编辑区忙碌,
            errorMessage: this.编辑区错误,
            fieldNames: this.编辑区字段名列表,
            initialFieldValues: this.编辑区初始字段值,
            initialTags: this.编辑区初始标签,
            onCancel: (): void => {
              this.显示编辑区 = false;
              this.编辑区当前笔记 = null;
            },
            onSave: (fields: string[], tags: string[]): Promise<boolean> => {
              return this.保存编辑(fields, tags);
            }
          })
        }

        // T11 卡片信息弹层：非多选模式下点击行右侧 info 按钮 → 懒加载 CardStatsView
        if (this.显示卡片信息) {
          卡片信息({
            isDark: this.是否深色(),
            stats: this.卡片信息数据,
            errorMessage: this.卡片信息忙碌 && this.卡片信息错误 === ''
              ? this.取本地化文案($r('app.string.browser_info_loading'))
              : this.卡片信息错误,
            onClose: (): void => {
              this.关闭卡片信息();
            }
          })
        }

        // T9 查找替换弹层：顶部条按钮触发，支持仅选中笔记或全部笔记两种范围
        if (this.显示查找替换) {
          查找替换对话框({
            isDark: this.是否深色(),
            busy: this.查找替换忙碌,
            errorMessage: this.查找替换错误,
            有选中笔记: this.选中ID列表.length > 0,
            onCancel: (): void => {
              this.显示查找替换 = false;
              this.查找替换错误 = '';
            },
            onExecute: (
              查找: string,
              替换: string,
              字段名: string,
              正则: boolean,
              区分大小写: boolean,
              仅选中: boolean
            ): Promise<boolean> => {
              return this.执行查找替换(查找, 替换, 字段名, 正则, 区分大小写, 仅选中);
            }
          })
        }

        // T8 改牌组选择器弹层
        if (this.显示改牌组弹层) {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(this.是否深色() ? 'rgba(0,0,0,0.40)' : 'rgba(0,0,0,0.15)')
              .onClick((): void => {
                if (!this.批量忙碌) { this.显示改牌组弹层 = false; }
              })

            Column({ space: 应用尺寸.间距_14 }) {
              Text($r('app.string.browser_action_change_deck'))
                .fontSize(应用尺寸.字号_面板标题)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')

              Scroll() {
                Column({ space: 应用尺寸.间距_4 }) {
                  if (this.牌组树 !== null) {
                    ForEach(this.扁平化牌组树为列表(), (项: 牌组项) => {
                      Text(项.名)
                        .fontSize(应用尺寸.字号_正文)
                        .fontColor($r('app.color.text_primary'))
                        .padding({ left: 应用尺寸.间距_16, right: 应用尺寸.间距_16,
                          top: 应用尺寸.间距_12, bottom: 应用尺寸.间距_12 })
                        .width('100%')
                        .borderRadius(应用尺寸.圆角_面板)
                        .backgroundColor($r('app.color.surface_page'))
                        .onClick((): void => { this.执行批量改牌组(项.id); })
                    }, (项: 牌组项): string => `${项.id}`)
                  }
                }
                .width('100%')
              }
              .width('100%')
              .layoutWeight(1)
              .scrollBar(BarState.Auto)

              Button($r('app.string.browser_detail_cancel'))
                .width('100%')
                .height(应用尺寸.按钮高度)
                .fontSize(应用尺寸.字号_按钮)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor($r('app.color.surface_page'))
                .borderRadius(应用尺寸.圆角_胶囊)
                .enabled(!this.批量忙碌)
                .onClick((): void => { this.显示改牌组弹层 = false; })
            }
            .width('88%')
            .constraintSize({ maxWidth: 520, maxHeight: '80%' })
            .padding(应用尺寸.卡片内边距)
            .backgroundColor($r('app.color.surface_card'))
            .borderRadius(应用尺寸.圆角_卡片)
          }
        }

        // T8 标志选择器弹层（无/红/橙/绿/蓝）
        if (this.显示标志弹层) {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(this.是否深色() ? 'rgba(0,0,0,0.40)' : 'rgba(0,0,0,0.15)')
              .onClick((): void => {
                if (!this.批量忙碌) { this.显示标志弹层 = false; }
              })

            Column({ space: 应用尺寸.间距_14 }) {
              Text($r('app.string.browser_action_set_flag'))
                .fontSize(应用尺寸.字号_面板标题)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')

              ForEach([0, 1, 2, 3, 4], (flag: number) => {
                Row({ space: 应用尺寸.间距_12 }) {
                  // 标志色块：0=无（透明圆环）/1=红/2=橙/3=绿/4=蓝
                  Row()
                    .width(16)
                    .height(16)
                    .borderRadius(8)
                    .backgroundColor(this.标志颜色(flag))
                    .border({ width: flag === 0 ? 1 : 0, color: $r('app.color.border_input') })
                  Text(this.标志文案(flag))
                    .fontSize(应用尺寸.字号_按钮)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                }
                .width('100%')
                .height(应用尺寸.按钮高度)
                .padding({ left: 应用尺寸.间距_16, right: 应用尺寸.间距_16 })
                .borderRadius(应用尺寸.圆角_胶囊)
                .backgroundColor($r('app.color.surface_page'))
                .enabled(!this.批量忙碌)
                .onClick((): void => { this.执行批量设置标志(flag); })
              }, (flag: number): string => `${flag}`)

              Button($r('app.string.browser_detail_cancel'))
                .width('100%')
                .height(应用尺寸.按钮高度)
                .fontSize(应用尺寸.字号_按钮)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor($r('app.color.surface_page'))
                .borderRadius(应用尺寸.圆角_胶囊)
                .enabled(!this.批量忙碌)
                .onClick((): void => { this.显示标志弹层 = false; })
            }
            .width('78%')
            .constraintSize({ maxWidth: 420 })
            .padding(应用尺寸.卡片内边距)
            .backgroundColor($r('app.color.surface_card'))
            .borderRadius(应用尺寸.圆角_卡片)
          }
        }

        // T8 挂起确认弹层
        if (this.显示挂起确认) {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(this.是否深色() ? 'rgba(0,0,0,0.40)' : 'rgba(0,0,0,0.15)')
              .onClick((): void => {
                if (!this.批量忙碌) { this.显示挂起确认 = false; }
              })

            Column({ space: 应用尺寸.间距_14 }) {
              Text($r('app.string.browser_action_suspend_confirm'))
                .fontSize(应用尺寸.字号_正文)
                .fontColor($r('app.color.text_primary'))
                .width('100%')

              Row({ space: 应用尺寸.间距_10 }) {
                Button($r('app.string.browser_detail_cancel'))
                  .layoutWeight(1)
                  .height(应用尺寸.按钮高度)
                  .fontSize(应用尺寸.字号_按钮)
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor($r('app.color.surface_page'))
                  .borderRadius(应用尺寸.圆角_胶囊)
                  .enabled(!this.批量忙碌)
                  .onClick((): void => { this.显示挂起确认 = false; })
                Button($r('app.string.browser_detail_confirm'))
                  .layoutWeight(1)
                  .height(应用尺寸.按钮高度)
                  .fontSize(应用尺寸.字号_按钮)
                  .fontColor($r('app.color.action_on_primary'))
                  .backgroundColor(this.主色按钮背景色)
                  .borderRadius(应用尺寸.圆角_胶囊)
                  .enabled(!this.批量忙碌)
                  .onClick((): void => { this.执行批量挂起(); })
              }
              .width('100%')
            }
            .width('78%')
            .constraintSize({ maxWidth: 420 })
            .padding(应用尺寸.卡片内边距)
            .backgroundColor($r('app.color.surface_card'))
            .borderRadius(应用尺寸.圆角_卡片)
          }
        }

        // T8 删除确认弹层
        if (this.显示删除确认) {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(this.是否深色() ? 'rgba(0,0,0,0.40)' : 'rgba(0,0,0,0.15)')
              .onClick((): void => {
                if (!this.批量忙碌) { this.显示删除确认 = false; }
              })

            Column({ space: 应用尺寸.间距_14 }) {
              Text($r('app.string.browser_action_delete_confirm'))
                .fontSize(应用尺寸.字号_正文)
                .fontColor($r('app.color.text_primary'))
                .width('100%')

              Row({ space: 应用尺寸.间距_10 }) {
                Button($r('app.string.browser_detail_cancel'))
                  .layoutWeight(1)
                  .height(应用尺寸.按钮高度)
                  .fontSize(应用尺寸.字号_按钮)
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor($r('app.color.surface_page'))
                  .borderRadius(应用尺寸.圆角_胶囊)
                  .enabled(!this.批量忙碌)
                  .onClick((): void => { this.显示删除确认 = false; })
                Button($r('app.string.browser_detail_confirm'))
                  .layoutWeight(1)
                  .height(应用尺寸.按钮高度)
                  .fontSize(应用尺寸.字号_按钮)
                  .fontColor($r('app.color.action_on_primary'))
                  .backgroundColor(this.主色按钮背景色)
                  .borderRadius(应用尺寸.圆角_胶囊)
                  .enabled(!this.批量忙碌)
                  .onClick((): void => { this.执行批量删除(); })
              }
              .width('100%')
            }
            .width('78%')
            .constraintSize({ maxWidth: 420 })
            .padding(应用尺寸.卡片内边距)
            .backgroundColor($r('app.color.surface_card'))
            .borderRadius(应用尺寸.圆角_卡片)
          }
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .opacity(this.转场透明度)
  }
}
