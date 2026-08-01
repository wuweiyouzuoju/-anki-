// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { 后端会话 } from '../backend/后端会话';
import { 调度器服务 } from '../backend/调度器服务';
import { 卡片渲染服务 } from '../backend/卡片渲染服务';
import { 卡片服务 } from '../backend/卡片服务';
import { 集合服务 } from '../backend/集合服务';
import { 笔记服务 } from '../backend/笔记服务';
import { 笔记类型服务 } from '../backend/笔记类型服务';
import { 比对答案 } from '../model/拼写比对器';
import { 提取拼写填空内容 } from '../model/填空解析器';
import type { RenderedCard, TtsItem } from '../proto/messages/CardRenderingMessages';
import {
  BURY_SUSPEND_MODE_BURY_USER,
  BURY_SUSPEND_MODE_SUSPEND,
  RATING_AGAIN,
  RATING_EASY,
  RATING_GOOD,
  RATING_HARD,
  UNBURY_MODE_ALL
} from '../proto/messages/SchedulerMessages';
import type { SchedulingStatesRaw, StudyCard } from '../proto/messages/SchedulerMessages';
import {
  构建卡片HTML,
  提取拼写标记,
  注入拼写结果,
  媒体基地址,
  原始侧HTML,
  剥除拼写标记
} from '../model/学习卡片HTML构建器';
import { 解码文件名, 取MIME类型, 读取媒体文件 } from '../utils/媒体响应助手';
import { 声音播放器 } from '../utils/声音播放器';
import { TTS播放器 } from '../utils/TTS播放器';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 学习浮动工具栏 } from '../components/学习浮动工具栏';
import { 学习阶段 } from '../utils/吸附计算器';
import { 加载学习布局模式, 学习布局模式 } from '../model/学习布局存储';
import { 加载主题模式 } from '../model/主题存储';
import { 解析是否深色, 主题模式 } from '../model/主题设置';
import { 颜色键 } from '../model/颜色主题';
import { KeyCode } from '@kit.InputKit';

const SECONDS_PER_DAY: number = 86400;

const BURY_RATING_TAG: number = 100;
const SUSPEND_RATING_TAG: number = 101;

export interface 学习页参数 {
  deckId?: string;
  deckName?: string;
}

@Component
export struct 学习页 {
  pageDeckId: string = '';
  pageDeckName: string = '';
  pathStack: NavPathStack = new NavPathStack();
  private readonly 调度器服务实例: 调度器服务 = new 调度器服务();
  private readonly 卡片渲染服务实例: 卡片渲染服务 = new 卡片渲染服务();
  private readonly 卡片服务实例: 卡片服务 = new 卡片服务();
  private readonly 集合服务实例: 集合服务 = new 集合服务();
  private readonly 笔记服务实例: 笔记服务 = new 笔记服务();
  private readonly 笔记类型服务实例: 笔记类型服务 = new 笔记类型服务();
  private readonly 网页控制器: webview.WebviewController = new webview.WebviewController();
  private readonly 声音播放器实例: 声音播放器 = new 声音播放器();
  private readonly TTS播放器实例: TTS播放器 = new TTS播放器();
  private 当前卡片: StudyCard | null = null;
  private 已渲染: RenderedCard | null = null;
  private 正面HTML: string = '';
  private 背面HTML: string = '';
  private 展示时刻毫秒: number = 0;
  private 评分中: boolean = false;
  private 媒体目录: string = '';
  private 兜底文案: string[] = [];
  @State private 牌组ID: number = 0;
  @State private 牌组名: string = '';
  @State private 阶段: 学习阶段 = 'loading';
  @State private 错误详情: string = '';
  @State private 按钮文案: string[] = [];
  @State private 新卡剩余: number = 0;
  @State private 学习中剩余: number = 0;
  @State private 复习剩余: number = 0;
  @State private 可撤销: boolean = false;
  @State private 有音频: boolean = false;
  @State private 完成页数据已加载: boolean = false;
  @State private 完成页学习剩余: number = 0;
  @State private 完成页下张学习分钟: number = 0;
  @State private 完成页复习受限: boolean = false;
  @State private 完成页新卡受限: boolean = false;
  @State private 完成页有埋藏: boolean = false;
  @State private 学习布局模式值: 学习布局模式 = 'bottom';
  @StorageLink('systemDarkMode') private 系统暗黑模式: boolean = false;
  @State private 主题模式值: 主题模式 = 'system';
  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.动作主色按下) private 动作主色按下色: string = '#1E4FB8';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下色: string = '#1E4FB8';
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';
  @StorageProp(颜色键.页面底色微染) private 页面底色微染值: string = '#F5F7FA';
  @State private 显示答案按下: boolean = false;
  @State private 按下评分: number = -1;
  @State private 已输入答案: string = '';
  @State private 拼写字段名: string = '';
  @State private 拼写组合: boolean = true;
  @State private 拼写填空: boolean = false;
  @State private 拼写卡片序号: number = 0;

  async aboutToAppear(): Promise<void> {
    this.牌组ID = this.pageDeckId === '' ? 0 : parseInt(this.pageDeckId);
    this.牌组名 = this.pageDeckName;
    try {
      this.主题模式值 = await 加载主题模式();
    } catch (error) {
      this.主题模式值 = 'system';
    }
    try {
      this.学习布局模式值 = await 加载学习布局模式();
    } catch (error) {
      this.学习布局模式值 = 'bottom';
    }
    this.加载兜底文案();
    this.启动会话();
  }

  private 是否深色(): boolean {
    return 解析是否深色(this.主题模式值, this.系统暗黑模式);
  }

  aboutToDisappear(): void {
    this.声音播放器实例.释放();
    this.TTS播放器实例.释放();
  }

  private 加载兜底文案(): void {
    const context: common.UIAbilityContext | null = this.取能力上下文();
    if (context === null) {
      return;
    }
    this.兜底文案 = [
      context.resourceManager.getStringSync($r('app.string.rating_again').id),
      context.resourceManager.getStringSync($r('app.string.rating_hard').id),
      context.resourceManager.getStringSync($r('app.string.rating_good').id),
      context.resourceManager.getStringSync($r('app.string.rating_easy').id)
    ];
  }

  private 取能力上下文(): common.UIAbilityContext | null {
    const context: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return context === undefined ? null : context;
  }

  private async 启动会话(): Promise<void> {
    const context: common.UIAbilityContext | null = this.取能力上下文();
    if (context === null) {
      this.阶段 = 'error';
      this.错误详情 = this.getUIContext().getHostContext()!.resourceManager.getStringSync($r('app.string.ability_context_unavailable').id);
      return;
    }
    this.媒体目录 = `${context.filesDir}/collection.media`;
    try {
      await 后端会话.获取实例().确保已打开(context.filesDir);
      await this.加载下一张卡();
    } catch (error) {
      this.阶段 = 'error';
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
    }
  }

  private async 加载下一张卡(): Promise<void> {
    this.阶段 = 'loading';
    this.完成页数据已加载 = false;
    this.已输入答案 = '';
    this.拼写字段名 = '';
    this.拼写组合 = true;
    this.拼写填空 = false;
    this.拼写卡片序号 = 0;
    try {
      await this.刷新撤销状态();
      const queued = await this.调度器服务实例.获取队首卡片(this.牌组ID);
      this.新卡剩余 = queued.newCount;
      this.学习中剩余 = queued.learningCount;
      this.复习剩余 = queued.reviewCount;
      if (queued.cards.length === 0) {
        this.当前卡片 = null;
        this.有音频 = false;
        await this.声音播放器实例.停止();
        await this.TTS播放器实例.停止();
        this.阶段 = 'done';
        await this.加载完成页信息();
        if (this.展示时刻毫秒 > 0) {
          AppStorage.setOrCreate('studyJustFinished', true);
        }
        return;
      }
      this.当前卡片 = queued.cards[0];
      this.已渲染 = await this.卡片渲染服务实例.渲染既有卡片(this.当前卡片.cardId);
      this.按钮文案 = await this.调度器服务实例.描述下一档状态(this.当前卡片.states);
      const marker = 提取拼写标记(this.已渲染.answerNodes)
        ?? 提取拼写标记(this.已渲染.questionNodes);
      if (marker !== null) {
        this.拼写字段名 = marker.fieldName;
        this.拼写组合 = marker.combining;
        this.拼写填空 = marker.cloze;
        this.拼写卡片序号 = this.当前卡片.templateIdx;
      }
      this.正面HTML = 剥除拼写标记(构建卡片HTML(this.已渲染, 'question'));
      this.背面HTML = this.拼写字段名 !== ''
        ? 构建卡片HTML(this.已渲染, 'answer')
        : 剥除拼写标记(构建卡片HTML(this.已渲染, 'answer'));
      const rawQuestionHtml: string = 原始侧HTML(this.已渲染, 'question');
      const questionSounds: string[] = await this.安全提取音频(rawQuestionHtml, true);
      const questionTtsItems: TtsItem[] = await this.安全提取TTS项(rawQuestionHtml, true);
      this.网页控制器.loadData(this.正面HTML, 'text/html', 'UTF-8', 媒体基地址, ' ');
      this.展示时刻毫秒 = Date.now();
      this.阶段 = 'question';
      this.有音频 = questionSounds.length > 0 || questionTtsItems.length > 0;
      await this.声音播放器实例.播放队列(this.转音频路径(questionSounds));
      await this.TTS播放器实例.播放队列(questionTtsItems);
    } catch (error) {
      this.有音频 = false;
      await this.声音播放器实例.停止();
      await this.TTS播放器实例.停止();
      this.阶段 = 'error';
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
    }
  }

  private async 安全提取音频(rawHtml: string, questionSide: boolean): Promise<string[]> {
    try {
      return await this.卡片渲染服务实例.提取音频文件(rawHtml, questionSide);
    } catch (error) {
      return [];
    }
  }

  private async 安全提取TTS项(rawHtml: string, questionSide: boolean): Promise<TtsItem[]> {
    try {
      return await this.卡片渲染服务实例.提取TTS项(rawHtml, questionSide);
    } catch (error) {
      return [];
    }
  }

  private 转音频路径(files: string[]): string[] {
    return files.map((name: string): string => `${this.媒体目录}/${解码文件名(name)}`);
  }

  private async 刷新撤销状态(): Promise<void> {
    try {
      const status = await this.集合服务实例.获取撤销状态();
      this.可撤销 = status.undo.length > 0;
    } catch (error) {
      this.可撤销 = false;
    }
  }

  private async 撤销上次(): Promise<void> {
    if (this.评分中 || !this.可撤销) {
      return;
    }
    this.评分中 = true;
    try {
      await this.集合服务实例.撤销();
      await this.加载下一张卡();
    } catch (error) {
      this.阶段 = 'error';
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.评分中 = false;
    }
  }

  private 取文案(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  private 更多菜单(): MenuElement[] {
    return [
      { value: this.取文案($r('app.string.study_undo')), action: () => { this.撤销上次(); }, enabled: this.可撤销 },
      { value: this.取文案($r('app.string.study_delete_card')), action: () => { this.请求删除当前卡(); }, enabled: this.阶段 === 'question' || this.阶段 === 'answer' }
    ];
  }

  private async 埋藏或暂停当前卡(mode: number): Promise<void> {
    if (this.评分中 || this.当前卡片 === null) {
      return;
    }
    if (this.阶段 !== 'question' && this.阶段 !== 'answer') {
      return;
    }
    this.评分中 = true;
    try {
      await this.调度器服务实例.埋藏或暂停卡片(this.当前卡片.cardId, mode);
      await this.加载下一张卡();
    } catch (error) {
      this.阶段 = 'error';
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.评分中 = false;
    }
  }

  private 请求删除当前卡(): void {
    if (this.评分中 || this.当前卡片 === null) {
      return;
    }
    if (this.阶段 !== 'question' && this.阶段 !== 'answer') {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: $r('app.string.study_delete_card_confirm_title'),
      message: $r('app.string.study_delete_card_confirm_message'),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.cancel'),
        action: (): void => {}
      },
      secondaryButton: {
        value: $r('app.string.study_delete_card'),
        fontColor: $r('app.color.error_text'),
        action: (): void => {
          this.确认删除当前卡();
        }
      }
    });
  }

  private async 确认删除当前卡(): Promise<void> {
    if (this.当前卡片 === null) {
      return;
    }
    this.评分中 = true;
    try {
      await this.卡片服务实例.删除卡片([this.当前卡片.cardId]);
      await this.加载下一张卡();
    } catch (error) {
      this.阶段 = 'error';
      const reason: string = error instanceof Error ? error.message : `${error}`;
      this.错误详情 = this.getUIContext().getHostContext()!.resourceManager
        .getStringSync($r('app.string.study_delete_card_failed').id)
        .replace('%s', reason);
    } finally {
      this.评分中 = false;
    }
  }

  private async 加载完成页信息(): Promise<void> {
    try {
      const info = await this.调度器服务实例.获取完成页信息();
      this.完成页学习剩余 = info.secsUntilNextLearn < SECONDS_PER_DAY ? info.learnRemaining : 0;
      this.完成页下张学习分钟 = Math.max(1, Math.ceil(info.secsUntilNextLearn / 60));
      this.完成页复习受限 = info.reviewRemaining;
      this.完成页新卡受限 = info.newRemaining;
      this.完成页有埋藏 = info.haveSchedBuried || info.haveUserBuried;
      this.完成页数据已加载 = true;
    } catch (error) {
      this.完成页数据已加载 = false;
    }
  }

  private async 恢复埋藏(): Promise<void> {
    if (this.评分中) {
      return;
    }
    this.评分中 = true;
    try {
      await this.调度器服务实例.按牌组恢复埋藏(this.牌组ID, UNBURY_MODE_ALL);
      await this.加载下一张卡();
    } catch (error) {
      this.阶段 = 'error';
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.评分中 = false;
    }
  }

  private async 显示答案(): Promise<void> {
    if (this.阶段 !== 'question' || this.已渲染 === null) {
      return;
    }
    try {
      if (this.拼写字段名 !== '') {
        this.背面HTML = await this.构建拼写答案HTML(this.背面HTML);
      }
      this.网页控制器.loadData(this.背面HTML, 'text/html', 'UTF-8', 媒体基地址, ' ');
      this.阶段 = 'answer';
      const rawAnswerHtml: string = 原始侧HTML(this.已渲染, 'answer');
      const answerSounds: string[] = await this.安全提取音频(rawAnswerHtml, false);
      const answerTtsItems: TtsItem[] = await this.安全提取TTS项(rawAnswerHtml, false);
      this.有音频 = answerSounds.length > 0 || answerTtsItems.length > 0;
      await this.声音播放器实例.播放队列(this.转音频路径(answerSounds));
      await this.TTS播放器实例.播放队列(answerTtsItems);
    } catch (error) {
      this.阶段 = 'error';
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
    }
  }

  private async 构建拼写答案HTML(answerHtml: string): Promise<string> {
    if (this.当前卡片 === null) {
      return 剥除拼写标记(answerHtml);
    }
    try {
      const note = await this.笔记服务实例.获取笔记(this.当前卡片.noteId);
      const notetype = await this.笔记类型服务实例.获取笔记类型(note.notetypeId);
      const fieldIdx = notetype.fieldNames.indexOf(this.拼写字段名);
      const fieldValue = fieldIdx >= 0 && fieldIdx < note.fields.length ? note.fields[fieldIdx] : '';
      let expected: string;
      if (this.拼写填空) {
        expected = 提取拼写填空内容(fieldValue, this.拼写卡片序号 + 1);
        if (expected === '') {
          return 剥除拼写标记(answerHtml);
        }
      } else {
        expected = fieldValue;
      }
      const resultHtml = 比对答案(expected, this.已输入答案, this.拼写组合);
      const injected = 注入拼写结果(answerHtml, resultHtml);
      if (injected === answerHtml) {
        return `${answerHtml}<hr><code id=typeans>${resultHtml}</code>`;
      }
      return injected;
    } catch (error) {
      return 剥除拼写标记(answerHtml);
    }
  }

  private async 评分(rating: number): Promise<void> {
    if (this.评分中 || this.阶段 !== 'answer' || this.当前卡片 === null) {
      return;
    }
    this.评分中 = true;
    try {
      const states: SchedulingStatesRaw = this.当前卡片.states;
      const newStates: Uint8Array[] = [states.again, states.hard, states.good, states.easy];
      await this.调度器服务实例.提交评分({
        cardId: this.当前卡片.cardId,
        currentState: states.current,
        newState: newStates[rating],
        rating: rating,
        answeredAtMillis: Date.now(),
        millisecondsTaken: Math.max(0, Date.now() - this.展示时刻毫秒)
      });
      await this.加载下一张卡();
    } catch (error) {
      this.阶段 = 'error';
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.评分中 = false;
    }
  }

  private 拦截媒体(event: OnInterceptRequestEvent): WebResourceResponse | null {
    const url: string = event.request.getRequestUrl();
    if (!url.startsWith(媒体基地址)) {
      return null;
    }
    const fileName: string = decodeURIComponent(url.substring(媒体基地址.length));
    if (fileName.length === 0) {
      const blank: WebResourceResponse = new WebResourceResponse();
      blank.setResponseData('<!DOCTYPE html><html><body></body></html>');
      blank.setResponseMimeType('text/html');
      blank.setResponseEncoding('UTF-8');
      blank.setResponseCode(200);
      blank.setReasonMessage('OK');
      return blank;
    }
    const data: ArrayBuffer | null = 读取媒体文件(this.媒体目录, fileName);
    if (data === null) {
      const notFound: WebResourceResponse = new WebResourceResponse();
      notFound.setResponseCode(404);
      notFound.setReasonMessage('Not Found');
      notFound.setResponseData('');
      notFound.setResponseMimeType('text/plain');
      notFound.setResponseEncoding('UTF-8');
      return notFound;
    }
    const response: WebResourceResponse = new WebResourceResponse();
    response.setResponseData(data);
    response.setResponseMimeType(取MIME类型(fileName));
    response.setResponseCode(200);
    response.setReasonMessage('OK');
    return response;
  }

  private 按钮文案位(index: number): string {
    if (index < this.按钮文案.length && this.按钮文案[index].length > 0) {
      return this.按钮文案[index];
    }
    if (index < this.兜底文案.length) {
      return this.兜底文案[index];
    }
    return '';
  }

  private 返回(): void {
    this.pathStack.pop();
  }

  private Ctrl按下: boolean = false;

  private 处理按键(event: KeyEvent): boolean {
    if (event.type !== KeyType.Down) {
      if (event.keyCode === KeyCode.KEYCODE_CTRL_LEFT || event.keyCode === KeyCode.KEYCODE_CTRL_RIGHT) {
        this.Ctrl按下 = false;
      }
      return false;
    }
    if (event.keyCode === KeyCode.KEYCODE_CTRL_LEFT || event.keyCode === KeyCode.KEYCODE_CTRL_RIGHT) {
      this.Ctrl按下 = true;
      return true;
    }
    if (this.Ctrl按下 && event.keyCode === KeyCode.KEYCODE_Z) {
      this.撤销上次();
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
      this.返回();
      return true;
    }
    if (this.阶段 !== 'question' && this.阶段 !== 'answer') {
      return false;
    }
    if (event.keyCode === KeyCode.KEYCODE_FORWARD_DEL) {
      this.请求删除当前卡();
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_STAR || event.keyCode === KeyCode.KEYCODE_B) {
      this.埋藏或暂停当前卡(BURY_SUSPEND_MODE_BURY_USER);
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_AT || event.keyCode === KeyCode.KEYCODE_S) {
      this.埋藏或暂停当前卡(BURY_SUSPEND_MODE_SUSPEND);
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_R) {
      this.声音播放器实例.重播();
      this.TTS播放器实例.重播();
      return true;
    }
    if (this.阶段 === 'question') {
      if (event.keyCode === KeyCode.KEYCODE_SPACE || event.keyCode === KeyCode.KEYCODE_ENTER) {
        this.显示答案();
        return true;
      }
      return false;
    }
    if (event.keyCode === KeyCode.KEYCODE_1) {
      this.评分(RATING_AGAIN);
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_2) {
      this.评分(RATING_HARD);
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_3
      || event.keyCode === KeyCode.KEYCODE_SPACE
      || event.keyCode === KeyCode.KEYCODE_ENTER) {
      this.评分(RATING_GOOD);
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_4) {
      this.评分(RATING_EASY);
      return true;
    }
    return false;
  }

  @Builder
  private 顶部条() {
    Stack() {
      Column() {
        Text(this.牌组名)
          .fontSize(应用尺寸.字号_标题)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '50%' })
          .textAlign(TextAlign.Center)

        Text($r('app.string.study_remaining_detail', this.新卡剩余, this.学习中剩余, this.复习剩余))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.None)

      Row() {
        Button($r('app.string.study_back'))
          .height(应用尺寸.按钮高度)
          .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
          .constraintSize({ minWidth: 0 })
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_胶囊)
          .onClick(() => {
            this.返回();
          })

        Blank()

        Button($r('app.string.study_more'))
          .height(应用尺寸.按钮高度)
          .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
          .constraintSize({ minWidth: 0 })
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_胶囊)
          .bindMenu(this.更多菜单())
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(应用尺寸.工具栏高度)
    .padding({
      left: 应用尺寸.页面内边距_水平,
      right: 应用尺寸.页面内边距_水平,
      top: 应用尺寸.间距_8,
      bottom: 应用尺寸.间距_8
    })
    .backgroundColor(this.页面底色微染值)
  }

  @Builder
  private 卡片区() {
    Column() {
      Stack() {
        Web({ src: '', controller: this.网页控制器 })
        .javaScriptAccess(true)
        .fileAccess(true)
        .domStorageAccess(true)
        .focusable(false)
        .onInterceptRequest((event: OnInterceptRequestEvent): WebResourceResponse | null => {
          return this.拦截媒体(event);
        })
        .onPageEnd((event: OnPageEndEvent) => {
          this.网页控制器.runJavaScript('anki.imageOcclusion.setup()');
          if (this.阶段 === 'answer') {
            this.网页控制器.runJavaScript(
              'setTimeout(function(){ var a=document.getElementById("answer"); if(a){ a.scrollIntoView({block:"start"}); } else { window.scrollTo(0, document.body.scrollHeight); } }, 100);'
            );
          }
        })
        .width('100%')
        .height('100%')

      if (this.有音频) {
        Button($r('app.string.study_replay_sound'))
          .height(应用尺寸.按钮高度)
          .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
          .margin(应用尺寸.间距_12)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor(this.动作主色)
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_胶囊)
          .onClick(() => {
            this.声音播放器实例.重播();
            this.TTS播放器实例.重播();
          })
      }

      if (this.阶段 === 'loading') {
        Column({ space: 应用尺寸.间距_8 }) {
          LoadingProgress()
            .width(应用尺寸.加载指示器尺寸)
            .height(应用尺寸.加载指示器尺寸)
            .color(this.动作主色)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.页面底色微染值)
      }

      if (this.阶段 === 'error') {
        Column({ space: 应用尺寸.间距_8 }) {
          Text($r('app.string.study_load_error'))
            .fontSize(应用尺寸.字号_标题)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.错误详情)
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
          Button($r('app.string.study_back'))
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor(this.动作主色)
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_胶囊)
            .onClick(() => {
              this.返回();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(应用尺寸.卡片内边距)
        .backgroundColor(this.页面底色微染值)
      }

      if (this.阶段 === 'done') {
        Column({ space: 应用尺寸.间距_8 }) {
          Text(this.完成页数据已加载 ? $r('app.string.study_congrats_title') : $r('app.string.study_finish_title'))
            .fontSize(应用尺寸.字号_面板标题)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          if (this.完成页数据已加载) {
            if (this.完成页学习剩余 > 0) {
              Text($r('app.string.study_congrats_learn_remaining', this.完成页学习剩余, this.完成页下张学习分钟))
                .fontSize(应用尺寸.字号_正文_中)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            if (this.完成页复习受限) {
              Text($r('app.string.study_congrats_review_limit'))
                .fontSize(应用尺寸.字号_正文_中)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            if (this.完成页新卡受限) {
              Text($r('app.string.study_congrats_new_limit'))
                .fontSize(应用尺寸.字号_正文_中)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            if (this.完成页有埋藏) {
              Button($r('app.string.study_unbury'))
                .height(应用尺寸.按钮高度)
                .fontSize(应用尺寸.字号_按钮)
                .fontColor(this.动作主色)
                .backgroundColor($r('app.color.surface_card'))
                .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
                .borderRadius(应用尺寸.圆角_胶囊)
                .margin({ top: 应用尺寸.间距_8 })
                .onClick(() => {
                  this.恢复埋藏();
                })
            }
          } else {
            Text($r('app.string.study_finish_hint'))
              .fontSize(应用尺寸.字号_正文_中)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
          }
          Button($r('app.string.study_back'))
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor(this.动作主色)
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_胶囊)
            .margin({ top: 应用尺寸.间距_12 })
            .onClick(() => {
              this.返回();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(应用尺寸.卡片内边距)
        .backgroundColor(this.页面底色微染值)
      }
      }
      .width('100%')
      .layoutWeight(1)
      .alignContent(Alignment.BottomEnd)

      if (this.阶段 === 'question' && this.拼写字段名 !== '') {
        TextInput({ placeholder: $r('app.string.study_type_answer_placeholder'), text: this.已输入答案 })
          .width('100%')
          .height(应用尺寸.行动按钮高度)
          .margin({ top: 应用尺寸.间距_8 })
          .fontSize(应用尺寸.字号_按钮)
          .borderRadius(应用尺寸.圆角_面板)
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
          .backgroundColor($r('app.color.surface_card'))
          .onChange((value: string) => {
            this.已输入答案 = value;
          })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private 答案条() {
    Column() {
      if (this.阶段 === 'question') {
        Button($r('app.string.study_show_answer'))
          .width('100%')
          .height(应用尺寸.行动按钮高度)
          .fontSize(应用尺寸.字号_标题)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .linearGradient({
              angle: 180,
              colors: this.显示答案按下
                ? [[this.主色按钮按下色 as ResourceColor, 0.0], [this.主色按钮按下色 as ResourceColor, 1.0]]
                : [[this.主色按钮背景色 as ResourceColor, 0.0], [this.主色按钮按下色 as ResourceColor, 1.0]]
            })
          .borderRadius(应用尺寸.圆角_行动按钮)
          .animation({ duration: 80, curve: Curve.EaseOut })
          .onTouch((event: TouchEvent): void => {
            if (event.type === TouchType.Down) {
              this.显示答案按下 = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.显示答案按下 = false;
            }
          })
          .onClick(() => {
            this.显示答案();
          })
      }
      if (this.阶段 === 'question' || this.阶段 === 'answer') {
        Row({ space: 应用尺寸.间距_8 }) {
          Button($r('app.string.study_bury'))
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor(this.按下评分 === BURY_RATING_TAG ? this.主色容器色 : $r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_面板)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.按下评分 = BURY_RATING_TAG; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下评分 = -1; }
            })
            .onClick(() => {
              this.埋藏或暂停当前卡(BURY_SUSPEND_MODE_BURY_USER);
            })
          Button($r('app.string.study_suspend'))
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor(this.按下评分 === SUSPEND_RATING_TAG ? this.主色容器色 : $r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_面板)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.按下评分 = SUSPEND_RATING_TAG; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下评分 = -1; }
            })
            .onClick(() => {
              this.埋藏或暂停当前卡(BURY_SUSPEND_MODE_SUSPEND);
            })
        }
        .width('100%')
        .margin({ top: 应用尺寸.间距_8 })
      }
      if (this.阶段 === 'answer') {
        Row({ space: 应用尺寸.间距_8 }) {
          Button(this.按钮文案位(RATING_AGAIN))
            .layoutWeight(1)
            .height(应用尺寸.行动按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.error_text'))
            .backgroundColor(this.按下评分 === RATING_AGAIN ? this.主色容器色 : $r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_面板)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.按下评分 = RATING_AGAIN; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下评分 = -1; }
            })
            .onClick(() => {
              this.评分(RATING_AGAIN);
            })
          Button(this.按钮文案位(RATING_HARD))
            .layoutWeight(1)
            .height(应用尺寸.行动按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(this.按下评分 === RATING_HARD ? this.主色容器色 : $r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_面板)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.按下评分 = RATING_HARD; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下评分 = -1; }
            })
            .onClick(() => {
              this.评分(RATING_HARD);
            })
          Button(this.按钮文案位(RATING_GOOD))
            .layoutWeight(1)
            .height(应用尺寸.行动按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor(this.动作主色)
            .backgroundColor(this.按下评分 === RATING_GOOD ? this.主色容器色 : $r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: this.按下评分 === RATING_GOOD ? this.动作主色 : $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_面板)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.按下评分 = RATING_GOOD; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下评分 = -1; }
            })
            .onClick(() => {
              this.评分(RATING_GOOD);
            })
          Button(this.按钮文案位(RATING_EASY))
            .layoutWeight(1)
            .height(应用尺寸.行动按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(this.按下评分 === RATING_EASY ? this.主色容器色 : $r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_面板)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.按下评分 = RATING_EASY; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下评分 = -1; }
            })
            .onClick(() => {
              this.评分(RATING_EASY);
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({
      left: 应用尺寸.页面内边距_水平,
      right: 应用尺寸.页面内边距_水平,
      top: 应用尺寸.间距_8,
      bottom: 应用尺寸.页面内边距_水平
    })
    .backgroundColor(this.页面底色微染值)
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          Column() {
            this.顶部条()
            this.卡片区()
            if (this.学习布局模式值 === 'bottom') {
              this.答案条()
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: 应用尺寸.复习页内容最大宽度 })
          .height('100%')
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.页面底色微染值)

        if (this.学习布局模式值 === 'float') {
          学习浮动工具栏({
            工具栏类型: 'main',
            当前阶段: this.阶段,
            评分按钮文案: this.按钮文案,
            兜底文案: this.兜底文案,
            是否深色: this.是否深色(),
            显示答案回调: (): void => {
              this.显示答案();
            },
            埋藏回调: (): void => {
              this.埋藏或暂停当前卡(BURY_SUSPEND_MODE_BURY_USER);
            },
            暂停回调: (): void => {
              this.埋藏或暂停当前卡(BURY_SUSPEND_MODE_SUSPEND);
            },
            评分回调: (rating: number): void => {
              this.评分(rating);
            }
          })
          学习浮动工具栏({
            工具栏类型: 'aux',
            当前阶段: this.阶段,
            评分按钮文案: this.按钮文案,
            兜底文案: this.兜底文案,
            是否深色: this.是否深色(),
            显示答案回调: (): void => {
              this.显示答案();
            },
            埋藏回调: (): void => {
              this.埋藏或暂停当前卡(BURY_SUSPEND_MODE_BURY_USER);
            },
            暂停回调: (): void => {
              this.埋藏或暂停当前卡(BURY_SUSPEND_MODE_SUSPEND);
            },
            评分回调: (rating: number): void => {
              this.评分(rating);
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .focusable(true)
      .defaultFocus(true)
      .onKeyPreIme((event: KeyEvent): boolean => {
        return this.处理按键(event);
      })
    }
    .hideTitleBar(true)
  }
}
