// StudyPage：复习流程页（M7）。
// 链路：ensureOpen → SetCurrentDeck+GetQueuedCards → RenderExistingCard →
//       DescribeNextStates → Web 渲染正面 → 翻面 → AnswerCard → 取下一张。
// 媒体加载：自建域名（StudyCardHtmlBuilder.MEDIA_BASE_URL）+ onInterceptRequest
// 映射到沙箱 collection.media/，绕过 ArkWeb file 协议跨域拦截（官方推荐做法）。

import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { BackendSession } from '../backend/BackendSession';
import { SchedulerService } from '../backend/SchedulerService';
import { CardRenderingService } from '../backend/CardRenderingService';
import { CardsService } from '../backend/CardsService';
import { CollectionService } from '../backend/CollectionService';
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
import { buildCardHtml, MEDIA_BASE_URL, rawSideHtml } from '../model/StudyCardHtmlBuilder';
import { decodeFileName, mimeTypeOf, readMediaFile } from '../utils/MediaResponseHelper';
import { SoundPlayer } from '../utils/SoundPlayer';
import { TtsPlayer } from '../utils/TtsPlayer';
import { AppDimens } from '../utils/AppDimens';
import { StudyFloatingToolbar } from '../components/StudyFloatingToolbar';
import { StudyPhase } from '../utils/SnapCalculator';
import { loadStudyLayoutMode, StudyLayoutMode } from '../model/StudyLayoutStore';
import { loadThemeMode } from '../model/ThemeStore';
import { resolveIsDark, ThemeMode } from '../model/ThemeSettings';
import { COLOR_KEYS } from '../model/ColorTheme';
// KeyCode 枚举：用于 onKeyPreIme 键盘事件判断（API 12+）。物理键盘/蓝牙键盘/2in1 设备内置键盘事件统一派发。
import { KeyCode } from '@kit.InputKit';

/** 与上游 buildNextLearnMsg 一致：下一张学习卡 >=1 天后到期时，完成页不再提示学习卡 */
const SECONDS_PER_DAY: number = 86400;

// 评分按钮 + 辅助按钮共用 pressedRating 状态时用的"伪 rating" tag：
// RATING_AGAIN/HARD/GOOD/EASY 占 0/1/2/3，辅助按钮用 100/101 避免冲突。
// pressedRating=-1 表示无按钮被按下。仅用于 onTouch 视觉反馈，不会传给 rate()/buryOrSuspendCurrent()。
// 删除卡片按钮已移至 topBar，与 back/undo 同款无 pressed 反馈，故不再占用 tag。
const BURY_RATING_TAG: number = 100;
const SUSPEND_RATING_TAG: number = 101;

export interface StudyPageParams {
  deckId?: string;
  deckName?: string;
}

@Component
export struct StudyPage {
  /** Navigation 入栈参数（替代原路由取参方式） */
  pageDeckId: string = '';
  pageDeckName: string = '';
  /** 页面栈：返回主页时 pop */
  pathStack: NavPathStack = new NavPathStack();
  private readonly schedulerService: SchedulerService = new SchedulerService();
  private readonly cardRenderingService: CardRenderingService = new CardRenderingService();
  private readonly cardsService: CardsService = new CardsService();
  private readonly collectionService: CollectionService = new CollectionService();
  private readonly webController: webview.WebviewController = new webview.WebviewController();
  private readonly soundPlayer: SoundPlayer = new SoundPlayer();
  private readonly ttsPlayer: TtsPlayer = new TtsPlayer();
  private currentCard: StudyCard | null = null;
  private rendered: RenderedCard | null = null;
  private questionHtml: string = '';
  private answerHtml: string = '';
  private shownAtMillis: number = 0;
  private answering: boolean = false;
  private mediaDir: string = '';
  private fallbackTexts: string[] = [];
  @State private deckId: number = 0;
  @State private deckName: string = '';
  @State private phase: StudyPhase = 'loading';
  @State private errorDetail: string = '';
  @State private buttonTexts: string[] = [];
  @State private newRemaining: number = 0;
  @State private learnRemaining: number = 0;
  @State private reviewRemaining: number = 0;
  @State private undoAvailable: boolean = false;
  @State private soundAvailable: boolean = false;
  @State private congratsLoaded: boolean = false;
  @State private congratsLearnRemaining: number = 0;
  @State private congratsNextLearnMinutes: number = 0;
  @State private congratsReviewRemaining: boolean = false;
  @State private congratsNewRemaining: boolean = false;
  @State private congratsBuried: boolean = false;
  /** 复习页布局模式：bottom=底部固定（默认）；float=浮动可拖动两个工具栏。
   *  aboutToAppear 时从 preferences 加载，与 SettingsPanel 切换联动（通过 AppStorage 同步）。 */
  @State private studyLayoutMode: StudyLayoutMode = 'bottom';
  /** 主题模式 + 系统暗黑，用于浮动工具栏底色判断（与 Index.ets 同套机制）。 */
  @StorageLink('systemDarkMode') private systemDarkMode: boolean = false;
  @State private themeMode: ThemeMode = 'system';
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.actionPrimaryActive) private actionPrimaryActiveColor: string = '#1E4FB8';
  @StorageProp(COLOR_KEYS.primaryContainer) private primaryContainerColor: string = '#E8EEFC';
  @StorageProp(COLOR_KEYS.surfacePageTint) private surfacePageTint: string = '#F5F7FA';
  @State private showAnswerPressed: boolean = false;
  // 4 个评分按钮共用一个 pressed 状态：按下时记下对应 rating，松开恢复 -1。
  // 用单状态而非 4 个 boolean，避免 4 个 @State 字段爆炸；onTouch Up/Cancel 都恢复 -1 保证松手必复位。
  @State private pressedRating: number = -1;

  async aboutToAppear(): Promise<void> {
    this.deckId = this.pageDeckId === '' ? 0 : parseInt(this.pageDeckId);
    this.deckName = this.pageDeckName;
    // 布局模式与主题并行加载，避免阻塞 startSession；任一失败回退默认值。
    try {
      this.themeMode = await loadThemeMode();
    } catch (error) {
      this.themeMode = 'system';
    }
    try {
      this.studyLayoutMode = await loadStudyLayoutMode();
    } catch (error) {
      this.studyLayoutMode = 'bottom';
    }
    this.loadFallbackTexts();
    this.startSession();
  }

  /** 暗色模式判断：themeMode=system 时跟随系统，否则按显式选择。与 Index.ets 同语义。 */
  private isDark(): boolean {
    return resolveIsDark(this.themeMode, this.systemDarkMode);
  }

  aboutToDisappear(): void {
    // 页面销毁释放原生播放器与 TTS 引擎（fire-and-forget，不等释放完成）
    this.soundPlayer.release();
    this.ttsPlayer.release();
  }

  /** 评分按钮兜底文案（后端 DescribeNextStates 异常时可用），启动时从资源读一次 */
  private loadFallbackTexts(): void {
    const context: common.UIAbilityContext | null = this.abilityContext();
    if (context === null) {
      return;
    }
    this.fallbackTexts = [
      context.resourceManager.getStringSync($r('app.string.rating_again').id),
      context.resourceManager.getStringSync($r('app.string.rating_hard').id),
      context.resourceManager.getStringSync($r('app.string.rating_good').id),
      context.resourceManager.getStringSync($r('app.string.rating_easy').id)
    ];
  }

  private abilityContext(): common.UIAbilityContext | null {
    const context: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return context === undefined ? null : context;
  }

  private async startSession(): Promise<void> {
    const context: common.UIAbilityContext | null = this.abilityContext();
    if (context === null) {
      this.phase = 'error';
      this.errorDetail = getContext(this).resourceManager.getStringSync($r('app.string.ability_context_unavailable').id);
      return;
    }
    this.mediaDir = `${context.filesDir}/collection.media`;
    try {
      await BackendSession.getInstance().ensureOpen(context.filesDir);
      await this.loadNextCard();
    } catch (error) {
      this.phase = 'error';
      this.errorDetail = error instanceof Error ? error.message : `${error}`;
    }
  }

  /** 取队首卡片并渲染正面；队列为空进入完成态。进入页面与评分后都会走到这里，顺带刷新撤销状态。 */
  private async loadNextCard(): Promise<void> {
    this.phase = 'loading';
    this.congratsLoaded = false;
    try {
      await this.refreshUndoStatus();
      const queued = await this.schedulerService.getQueuedCards(this.deckId);
      this.newRemaining = queued.newCount;
      this.learnRemaining = queued.learningCount;
      this.reviewRemaining = queued.reviewCount;
      if (queued.cards.length === 0) {
        this.currentCard = null;
        this.soundAvailable = false;
        await this.soundPlayer.stop();
        await this.ttsPlayer.stop();
        this.phase = 'done';
        await this.loadCongratsInfo();
        return;
      }
      this.currentCard = queued.cards[0];
      this.rendered = await this.cardRenderingService.renderExistingCard(this.currentCard.cardId);
      this.buttonTexts = await this.schedulerService.describeNextStates(this.currentCard.states);
      this.questionHtml = buildCardHtml(this.rendered, 'question');
      this.answerHtml = buildCardHtml(this.rendered, 'answer');
      const rawQuestionHtml: string = rawSideHtml(this.rendered, 'question');
      const questionSounds: string[] = await this.extractSoundsSafe(rawQuestionHtml, true);
      const questionTtsItems: TtsItem[] = await this.extractTtsItemsSafe(rawQuestionHtml, true);
      this.webController.loadData(this.questionHtml, 'text/html', 'UTF-8', MEDIA_BASE_URL, ' ');
      this.shownAtMillis = Date.now();
      this.phase = 'question';
      this.soundAvailable = questionSounds.length > 0 || questionTtsItems.length > 0;
      await this.soundPlayer.playQueue(this.toSoundPaths(questionSounds));
      await this.ttsPlayer.playQueue(questionTtsItems);
    } catch (error) {
      this.soundAvailable = false;
      await this.soundPlayer.stop();
      await this.ttsPlayer.stop();
      this.phase = 'error';
      this.errorDetail = error instanceof Error ? error.message : `${error}`;
    }
  }

  /** 提取一侧音频文件名；失败降级为静音，不阻断学习流程 */
  private async extractSoundsSafe(rawHtml: string, questionSide: boolean): Promise<string[]> {
    try {
      return await this.cardRenderingService.extractSoundFiles(rawHtml, questionSide);
    } catch (error) {
      return [];
    }
  }

  /** 提取一侧 TTS 朗读项；失败降级为不朗读，不阻断学习流程 */
  private async extractTtsItemsSafe(rawHtml: string, questionSide: boolean): Promise<TtsItem[]> {
    try {
      return await this.cardRenderingService.extractTtsItems(rawHtml, questionSide);
    } catch (error) {
      return [];
    }
  }

  /**
   * 媒体文件名 → 沙箱 collection.media/ 绝对路径。
   * 文件名经 decodeURIComponent 还原（Anki 卡片中可能写作 [sound:%E4%B8%AD.mp3]，
   * 后端 extract_av_tags 提取的是字面字符串，需解码才能匹配磁盘上的中文文件名）；
   * 与 ArkWeb 图片拦截器（interceptMedia 中已调 decodeURIComponent）行为对齐。
   * 解码失败（如含非编码 %）时回退原字面名，避免抛错中断播放。
   */
  private toSoundPaths(files: string[]): string[] {
    return files.map((name: string): string => `${this.mediaDir}/${decodeFileName(name)}`);
  }

  /** 刷新撤销可用状态；查询失败不阻断学习流程，仅关闭撤销入口。 */
  private async refreshUndoStatus(): Promise<void> {
    try {
      const status = await this.collectionService.getUndoStatus();
      this.undoAvailable = status.undo.length > 0;
    } catch (error) {
      this.undoAvailable = false;
    }
  }

  /** 撤销上一次评分；被撤销的卡回到队列顶部，成功后重新取卡。复用 answering 防重入。 */
  private async undoLast(): Promise<void> {
    if (this.answering || !this.undoAvailable) {
      return;
    }
    this.answering = true;
    try {
      await this.collectionService.undo();
      await this.loadNextCard();
    } catch (error) {
      this.phase = 'error';
      this.errorDetail = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.answering = false;
    }
  }

  /**
   * 埋藏（BURY_USER，明天再见）或暂停（SUSPEND，手动恢复前不再出现）当前卡片。
   * 与上游 reviewer 的 bury_current_card/suspend_current_card 语义一致；
   * 成功后该卡即从今日队列移除，直接取下一张。复用 answering 防重入。
   */
  private async buryOrSuspendCurrent(mode: number): Promise<void> {
    if (this.answering || this.currentCard === null) {
      return;
    }
    if (this.phase !== 'question' && this.phase !== 'answer') {
      return;
    }
    this.answering = true;
    try {
      await this.schedulerService.buryOrSuspendCards(this.currentCard.cardId, mode);
      await this.loadNextCard();
    } catch (error) {
      this.phase = 'error';
      this.errorDetail = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.answering = false;
    }
  }

  /**
   * 请求删除当前卡片：先弹 AlertDialog 二次确认，确认后真正调用 removeCards。
   * 与 buryOrSuspendCurrent 同款防重入与 phase 守卫；删除后该卡从今日队列移除，直接取下一张。
   *
   * 删除语义：调用 backend RemoveCards([cardId]) 仅删当前一张卡。
   * - 若该笔记只剩这一张卡，笔记也会一并删除（笔记变空自动清理）
   * - 与 AnkiDroid 的 Delete Card 行为一致；与 Anki 桌面端 Delete Note（删整条笔记 + 所有卡）不同
   * - 可通过顶部撤销按钮恢复（undo 栈会记录 RemoveCards 操作）
   * - 入口在 topBar 右侧（与 back/undo 同区），bottom 与 float 两种布局模式都能触达；
   *   Anki 桌面端放在 More 菜单，jidecards 直接置顶更易触达。
   */
  private requestDeleteCurrentCard(): void {
    if (this.answering || this.currentCard === null) {
      return;
    }
    if (this.phase !== 'question' && this.phase !== 'answer') {
      return;
    }
    AlertDialog.show({
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
          this.confirmDeleteCurrentCard();
        }
      }
    });
  }

  private async confirmDeleteCurrentCard(): Promise<void> {
    if (this.currentCard === null) {
      return;
    }
    this.answering = true;
    try {
      await this.cardsService.removeCards([this.currentCard.cardId]);
      await this.loadNextCard();
    } catch (error) {
      this.phase = 'error';
      const reason: string = error instanceof Error ? error.message : `${error}`;
      this.errorDetail = getContext(this).resourceManager
        .getStringSync($r('app.string.study_delete_card_failed').id)
        .replace('%s', reason);
    } finally {
      this.answering = false;
    }
  }

  /** 完成页真实数据；拉取失败降级为静态完成文案（congratsLoaded=false），不进入错误态。 */
  private async loadCongratsInfo(): Promise<void> {
    try {
      const info = await this.schedulerService.congratsInfo();
      // 上游 buildNextLearnMsg：下一张学习卡 >=1 天后到期时不再提示
      this.congratsLearnRemaining = info.secsUntilNextLearn < SECONDS_PER_DAY ? info.learnRemaining : 0;
      this.congratsNextLearnMinutes = Math.max(1, Math.ceil(info.secsUntilNextLearn / 60));
      this.congratsReviewRemaining = info.reviewRemaining;
      this.congratsNewRemaining = info.newRemaining;
      this.congratsBuried = info.haveSchedBuried || info.haveUserBuried;
      this.congratsLoaded = true;
    } catch (error) {
      this.congratsLoaded = false;
    }
  }

  /**
   * 恢复本牌组被埋藏的卡片。CongratsInfo 只有布尔标记、不给卡片 id，
   * 故按牌组维度恢复（同桌面 overview 的 unbury，Mode.ALL），成功后重新取卡。
   */
  private async restoreBuried(): Promise<void> {
    if (this.answering) {
      return;
    }
    this.answering = true;
    try {
      await this.schedulerService.unburyDeck(this.deckId, UNBURY_MODE_ALL);
      await this.loadNextCard();
    } catch (error) {
      this.phase = 'error';
      this.errorDetail = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.answering = false;
    }
  }

  private async showAnswer(): Promise<void> {
    if (this.phase !== 'question' || this.rendered === null) {
      return;
    }
    try {
      this.webController.loadData(this.answerHtml, 'text/html', 'UTF-8', MEDIA_BASE_URL, ' ');
      this.phase = 'answer';
      const rawAnswerHtml: string = rawSideHtml(this.rendered, 'answer');
      const answerSounds: string[] = await this.extractSoundsSafe(rawAnswerHtml, false);
      const answerTtsItems: TtsItem[] = await this.extractTtsItemsSafe(rawAnswerHtml, false);
      this.soundAvailable = answerSounds.length > 0 || answerTtsItems.length > 0;
      await this.soundPlayer.playQueue(this.toSoundPaths(answerSounds));
      await this.ttsPlayer.playQueue(answerTtsItems);
    } catch (error) {
      this.phase = 'error';
      this.errorDetail = error instanceof Error ? error.message : `${error}`;
    }
  }

  /** 提交评分并取下一张；防重入避免双击连评。 */
  private async rate(rating: number): Promise<void> {
    if (this.answering || this.phase !== 'answer' || this.currentCard === null) {
      return;
    }
    this.answering = true;
    try {
      const states: SchedulingStatesRaw = this.currentCard.states;
      const newStates: Uint8Array[] = [states.again, states.hard, states.good, states.easy];
      await this.schedulerService.answerCard({
        cardId: this.currentCard.cardId,
        currentState: states.current,
        newState: newStates[rating],
        rating: rating,
        answeredAtMillis: Date.now(),
        millisecondsTaken: Math.max(0, Date.now() - this.shownAtMillis)
      });
      await this.loadNextCard();
    } catch (error) {
      this.phase = 'error';
      this.errorDetail = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.answering = false;
    }
  }

  /** 拦截自建域名请求 → 沙箱媒体文件；未命中返回 null 放行（裂图/静音可接受）。 */
  private interceptMedia(event: OnInterceptRequestEvent): WebResourceResponse | null {
    const url: string = event.request.getRequestUrl();
    if (!url.startsWith(MEDIA_BASE_URL)) {
      return null;
    }
    const fileName: string = decodeURIComponent(url.substring(MEDIA_BASE_URL.length));
    if (fileName.length === 0) {
      // Web 组件初始 src 占位：回一张空白页，避免 404 错误页闪现
      const blank: WebResourceResponse = new WebResourceResponse();
      blank.setResponseData('<!DOCTYPE html><html><body></body></html>');
      blank.setResponseMimeType('text/html');
      blank.setResponseEncoding('UTF-8');
      blank.setResponseCode(200);
      blank.setReasonMessage('OK');
      return blank;
    }
    const data: ArrayBuffer | null = readMediaFile(this.mediaDir, fileName);
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
    response.setResponseMimeType(mimeTypeOf(fileName));
    response.setResponseCode(200);
    response.setReasonMessage('OK');
    return response;
  }

  private buttonTextAt(index: number): string {
    if (index < this.buttonTexts.length && this.buttonTexts[index].length > 0) {
      return this.buttonTexts[index];
    }
    if (index < this.fallbackTexts.length) {
      return this.fallbackTexts[index];
    }
    return '';
  }

  private goBack(): void {
    this.pathStack.pop();
  }

  /** Ctrl 键按下状态（用于检测 Ctrl+Z 撤销）。
   *  HarmonyOS KeyEvent 没有 ctrlKey 字段，需在 onKeyPreIme 里自行维护。 */
  private ctrlPressed: boolean = false;

  /**
   * 物理键盘快捷键处理（Anki 桌面端标准键位）。
   * 挂在根 Stack 的 onKeyPreIme 上（API 12+），输入法消费前拦截，返回 true 表示已消费。
   *
   * 键位映射（与 Anki 桌面端一致）：
   * - Space / Enter：question 阶段=显示答案；answer 阶段=Good 评分
   * - 1 / 2 / 3 / 4：Again / Hard / Good / Easy 评分（仅 answer 阶段）
   * - `*`（Shift+8，KEYCODE_STAR）：埋藏当前卡（BURY_USER）
   * - `@`（Shift+2，KEYCODE_AT）：暂停当前卡（SUSPEND）
   * - Esc：返回上一页（任意阶段）
   * - Delete（KEYCODE_FORWARD_DEL）：删除当前卡（弹确认框）
   * - Ctrl+Z：撤销上一次评分
   *
   * 实现说明：
   * - 只在 KeyType.Down 执行业务（Up 不执行，避免一次按键触发两次）
   * - Ctrl/Shift 单独按下时只更新状态、不执行业务，并消费事件避免系统处理
   * - loading/done/error 阶段只允许 Esc，其他键不处理（让系统默认行为生效）
   * - 各业务方法内部已有 phase 守卫和 answering 防重入，重复调用是安全的
   */
  private handleKeyPress(event: KeyEvent): boolean {
    // KeyType.Up：仅更新 Ctrl 松开状态，不执行业务
    if (event.type !== KeyType.Down) {
      if (event.keyCode === KeyCode.KEYCODE_CTRL_LEFT || event.keyCode === KeyCode.KEYCODE_CTRL_RIGHT) {
        this.ctrlPressed = false;
      }
      return false;
    }
    // Ctrl 按下：更新状态并消费，避免系统处理
    if (event.keyCode === KeyCode.KEYCODE_CTRL_LEFT || event.keyCode === KeyCode.KEYCODE_CTRL_RIGHT) {
      this.ctrlPressed = true;
      return true;
    }
    // Ctrl+Z 撤销（任意阶段都生效，与 Anki 桌面端一致）
    if (this.ctrlPressed && event.keyCode === KeyCode.KEYCODE_Z) {
      this.undoLast();
      return true;
    }
    // Esc 返回（任意阶段都生效）
    if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
      this.goBack();
      return true;
    }
    // 仅 question/answer 阶段处理以下键
    if (this.phase !== 'question' && this.phase !== 'answer') {
      return false;
    }
    // Delete 删除当前卡（弹确认框，与按钮点击同流程）
    if (event.keyCode === KeyCode.KEYCODE_FORWARD_DEL) {
      this.requestDeleteCurrentCard();
      return true;
    }
    // `*` 或 `B` 埋藏当前卡（B 为字母替代键，更易按；两者并存以兼容 Anki 桌面端键位）
    if (event.keyCode === KeyCode.KEYCODE_STAR || event.keyCode === KeyCode.KEYCODE_B) {
      this.buryOrSuspendCurrent(BURY_SUSPEND_MODE_BURY_USER);
      return true;
    }
    // `@` 或 `S` 暂停当前卡（S 为字母替代键）
    if (event.keyCode === KeyCode.KEYCODE_AT || event.keyCode === KeyCode.KEYCODE_S) {
      this.buryOrSuspendCurrent(BURY_SUSPEND_MODE_SUSPEND);
      return true;
    }
    // `R` 重放音频（question/answer 阶段均生效，与 Anki 桌面端一致；无音频时 replay 静默无副作用）
    if (event.keyCode === KeyCode.KEYCODE_R) {
      this.soundPlayer.replay();
      this.ttsPlayer.replay();
      return true;
    }
    // question 阶段：Space/Enter 显示答案
    if (this.phase === 'question') {
      if (event.keyCode === KeyCode.KEYCODE_SPACE || event.keyCode === KeyCode.KEYCODE_ENTER) {
        this.showAnswer();
        return true;
      }
      return false;
    }
    // answer 阶段：1/2/3/4 评分；Space/Enter = Good（与 Anki 桌面端一致）
    if (event.keyCode === KeyCode.KEYCODE_1) {
      this.rate(RATING_AGAIN);
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_2) {
      this.rate(RATING_HARD);
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_3
      || event.keyCode === KeyCode.KEYCODE_SPACE
      || event.keyCode === KeyCode.KEYCODE_ENTER) {
      this.rate(RATING_GOOD);
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_4) {
      this.rate(RATING_EASY);
      return true;
    }
    return false;
  }

  @Builder
  private topBar() {
    Stack() {
      // 底层：牌组名称 + 剩余计数（仅显示，Stack 默认居中）。
      // hitTestBehavior None 让整列不参与命中测试，触摸事件穿透到顶层 Row 的按钮。
      Column() {
        Text(this.deckName)
          .fontSize(AppDimens.FONT_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '50%' })
          .textAlign(TextAlign.Center)

        Text($r('app.string.study_remaining_detail', this.newRemaining, this.learnRemaining, this.reviewRemaining))
          .fontSize(AppDimens.FONT_BODY_S)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.None)

      // 顶层：所有按钮放同一 Row，用 Blank() 撑开左右——
      // 不再分左右两个 width('100%') Row 叠层（之前 hitTestBehavior Transparent 仍被遮挡），
      // 单层 Row 内按钮天然不重叠，Blank() 占位区无 onClick 不消费触摸。
      Row() {
        // 左侧：返回 + 撤销
        Button($r('app.string.study_back'))
          .height(AppDimens.BUTTON_HEIGHT)
          .padding({ left: AppDimens.CARD_PADDING, right: AppDimens.CARD_PADDING })
          .constraintSize({ minWidth: 0 })
          .fontSize(AppDimens.FONT_BUTTON)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
          .borderRadius(AppDimens.RADIUS_PILL)
          .onClick(() => {
            this.goBack();
          })

        if (this.undoAvailable) {
          Button($r('app.string.study_undo'))
            .height(AppDimens.BUTTON_HEIGHT)
            .padding({ left: AppDimens.CARD_PADDING, right: AppDimens.CARD_PADDING })
            .constraintSize({ minWidth: 0 })
            .margin({ left: AppDimens.SPACE_8 })
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PILL)
            .onClick(() => {
              this.undoLast();
            })
        }

        // 中间空白撑开：让左侧按钮靠左、右侧按钮靠右
        Blank()

        // 右侧：删除（仅 question/answer 阶段显示）
        if (this.phase === 'question' || this.phase === 'answer') {
          Button($r('app.string.study_delete_card'))
            .height(AppDimens.BUTTON_HEIGHT)
            .padding({ left: AppDimens.CARD_PADDING, right: AppDimens.CARD_PADDING })
            .constraintSize({ minWidth: 0 })
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor($r('app.color.error_text'))
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PILL)
            .onClick(() => {
              this.requestDeleteCurrentCard();
            })
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(AppDimens.TOOLBAR_HEIGHT)
    .padding({
      left: AppDimens.PAGE_PADDING_H,
      right: AppDimens.PAGE_PADDING_H,
      top: AppDimens.SPACE_8,
      bottom: AppDimens.SPACE_8
    })
    .backgroundColor(this.surfacePageTint)
  }

  @Builder
  private cardArea() {
    Stack() {
      Web({ src: MEDIA_BASE_URL, controller: this.webController })
        .javaScriptAccess(true)
        .fileAccess(true)
        .domStorageAccess(true)
        // focusable(false)：Web 不抢键盘焦点，让根 Stack 的 onKeyPreIme 稳定接管所有物理键盘事件。
        // 卡片 HTML 的触摸/点击交互不受影响（ArkWeb 内部走 onTouch，不依赖组件焦点）。
        .focusable(false)
        .onInterceptRequest((event: OnInterceptRequestEvent): WebResourceResponse | null => {
          return this.interceptMedia(event);
        })
        .width('100%')
        .height('100%')

      if (this.soundAvailable) {
        Button($r('app.string.study_replay_sound'))
          .height(AppDimens.BUTTON_HEIGHT)
          .padding({ left: AppDimens.CARD_PADDING, right: AppDimens.CARD_PADDING })
          .margin(AppDimens.SPACE_12)
          .fontSize(AppDimens.FONT_BUTTON)
          .fontColor(this.actionPrimaryColor)
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
          .borderRadius(AppDimens.RADIUS_PILL)
          .onClick(() => {
            this.soundPlayer.replay();
            this.ttsPlayer.replay();
          })
      }

      if (this.phase === 'loading') {
        Column({ space: AppDimens.SPACE_8 }) {
          LoadingProgress()
            .width(AppDimens.LOADING_SIZE)
            .height(AppDimens.LOADING_SIZE)
            .color(this.actionPrimaryColor)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.surfacePageTint)
      }

      if (this.phase === 'error') {
        Column({ space: AppDimens.SPACE_8 }) {
          Text($r('app.string.study_load_error'))
            .fontSize(AppDimens.FONT_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.errorDetail)
            .fontSize(AppDimens.FONT_BODY_M)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
          Button($r('app.string.study_back'))
            .height(AppDimens.BUTTON_HEIGHT)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor(this.actionPrimaryColor)
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PILL)
            .onClick(() => {
              this.goBack();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(AppDimens.CARD_PADDING)
        .backgroundColor(this.surfacePageTint)
      }

      if (this.phase === 'done') {
        Column({ space: AppDimens.SPACE_8 }) {
          Text(this.congratsLoaded ? $r('app.string.study_congrats_title') : $r('app.string.study_finish_title'))
            .fontSize(AppDimens.FONT_PANEL_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          if (this.congratsLoaded) {
            if (this.congratsLearnRemaining > 0) {
              Text($r('app.string.study_congrats_learn_remaining', this.congratsLearnRemaining, this.congratsNextLearnMinutes))
                .fontSize(AppDimens.FONT_BODY_M)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            if (this.congratsReviewRemaining) {
              Text($r('app.string.study_congrats_review_limit'))
                .fontSize(AppDimens.FONT_BODY_M)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            if (this.congratsNewRemaining) {
              Text($r('app.string.study_congrats_new_limit'))
                .fontSize(AppDimens.FONT_BODY_M)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            if (this.congratsBuried) {
              Button($r('app.string.study_unbury'))
                .height(AppDimens.BUTTON_HEIGHT)
                .fontSize(AppDimens.FONT_BUTTON)
                .fontColor(this.actionPrimaryColor)
                .backgroundColor($r('app.color.surface_card'))
                .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
                .borderRadius(AppDimens.RADIUS_PILL)
                .margin({ top: AppDimens.SPACE_8 })
                .onClick(() => {
                  this.restoreBuried();
                })
            }
          } else {
            Text($r('app.string.study_finish_hint'))
              .fontSize(AppDimens.FONT_BODY_M)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
          }
          Button($r('app.string.study_back'))
            .height(AppDimens.BUTTON_HEIGHT)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor(this.actionPrimaryColor)
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PILL)
            .margin({ top: AppDimens.SPACE_12 })
            .onClick(() => {
              this.goBack();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(AppDimens.CARD_PADDING)
        .backgroundColor(this.surfacePageTint)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .alignContent(Alignment.BottomEnd)
  }

  @Builder
  private answerBar() {
    Column() {
      if (this.phase === 'question') {
        Button($r('app.string.study_show_answer'))
          .width('100%')
          .height(AppDimens.CTA_HEIGHT)
          .fontSize(AppDimens.FONT_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          // 渐变方案：默认 primary→primaryActive（凸起），按下纯 primaryActive（凹陷）
          .linearGradient({
            angle: 180,
            colors: this.showAnswerPressed
              ? [[this.actionPrimaryActiveColor as ResourceColor, 0.0], [this.actionPrimaryActiveColor as ResourceColor, 1.0]]
              : [[this.actionPrimaryColor as ResourceColor, 0.0], [this.actionPrimaryActiveColor as ResourceColor, 1.0]]
          })
          .borderRadius(AppDimens.RADIUS_CTA)
          .animation({ duration: 80, curve: Curve.EaseOut })
          .onTouch((event: TouchEvent): void => {
            if (event.type === TouchType.Down) {
              this.showAnswerPressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.showAnswerPressed = false;
            }
          })
          .onClick(() => {
            this.showAnswer();
          })
      }
      if (this.phase === 'question' || this.phase === 'answer') {
        Row({ space: AppDimens.SPACE_8 }) {
          Button($r('app.string.study_bury'))
            .layoutWeight(1)
            .height(AppDimens.BUTTON_HEIGHT)
            .fontSize(AppDimens.FONT_BODY_M)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor(this.pressedRating === BURY_RATING_TAG ? this.primaryContainerColor : $r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PANEL)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.pressedRating = BURY_RATING_TAG; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
            })
            .onClick(() => {
              this.buryOrSuspendCurrent(BURY_SUSPEND_MODE_BURY_USER);
            })
          Button($r('app.string.study_suspend'))
            .layoutWeight(1)
            .height(AppDimens.BUTTON_HEIGHT)
            .fontSize(AppDimens.FONT_BODY_M)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor(this.pressedRating === SUSPEND_RATING_TAG ? this.primaryContainerColor : $r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PANEL)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.pressedRating = SUSPEND_RATING_TAG; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
            })
            .onClick(() => {
              this.buryOrSuspendCurrent(BURY_SUSPEND_MODE_SUSPEND);
            })
        }
        .width('100%')
        .margin({ top: AppDimens.SPACE_8 })
      }
      if (this.phase === 'answer') {
        Row({ space: AppDimens.SPACE_8 }) {
          Button(this.buttonTextAt(RATING_AGAIN))
            .layoutWeight(1)
            .height(AppDimens.CTA_HEIGHT)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor($r('app.color.error_text'))
            .backgroundColor(this.pressedRating === RATING_AGAIN ? this.primaryContainerColor : $r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PANEL)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.pressedRating = RATING_AGAIN; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
            })
            .onClick(() => {
              this.rate(RATING_AGAIN);
            })
          Button(this.buttonTextAt(RATING_HARD))
            .layoutWeight(1)
            .height(AppDimens.CTA_HEIGHT)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(this.pressedRating === RATING_HARD ? this.primaryContainerColor : $r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PANEL)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.pressedRating = RATING_HARD; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
            })
            .onClick(() => {
              this.rate(RATING_HARD);
            })
          Button(this.buttonTextAt(RATING_GOOD))
            .layoutWeight(1)
            .height(AppDimens.CTA_HEIGHT)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor(this.actionPrimaryColor)
            .backgroundColor(this.pressedRating === RATING_GOOD ? this.primaryContainerColor : $r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: this.pressedRating === RATING_GOOD ? this.actionPrimaryColor : $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PANEL)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.pressedRating = RATING_GOOD; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
            })
            .onClick(() => {
              this.rate(RATING_GOOD);
            })
          Button(this.buttonTextAt(RATING_EASY))
            .layoutWeight(1)
            .height(AppDimens.CTA_HEIGHT)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(this.pressedRating === RATING_EASY ? this.primaryContainerColor : $r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PANEL)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.pressedRating = RATING_EASY; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
            })
            .onClick(() => {
              this.rate(RATING_EASY);
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({
      left: AppDimens.PAGE_PADDING_H,
      right: AppDimens.PAGE_PADDING_H,
      top: AppDimens.SPACE_8,
      bottom: AppDimens.PAGE_PADDING_H
    })
    .backgroundColor(this.surfacePageTint)
  }

  build() {
    NavDestination() {
      // 外层 Stack：浮层工具栏用 position 绝对定位，需要全屏父容器；底层是限宽居中的内容列。
      // bottom 模式下 answerBar 在内容列内，与原体验一致；float 模式下 answerBar 不渲染，两个浮动工具栏叠加在 Stack 上层。
      Stack() {
        Column() {
          Column() {
            this.topBar()
            this.cardArea()
            if (this.studyLayoutMode === 'bottom') {
              this.answerBar()
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: AppDimens.STUDY_CONTENT_MAX_WIDTH })
          .height('100%')
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.surfacePageTint)

        if (this.studyLayoutMode === 'float') {
          // 主操作浮动工具栏：question 阶段显示「显示答案」，answer 阶段切换为 4 个评分按钮。
          StudyFloatingToolbar({
            toolbarId: 'main',
            phase: this.phase,
            buttonTexts: this.buttonTexts,
            fallbackTexts: this.fallbackTexts,
            isDark: this.isDark(),
            onShowAnswer: (): void => {
              this.showAnswer();
            },
            onBury: (): void => {
              this.buryOrSuspendCurrent(BURY_SUSPEND_MODE_BURY_USER);
            },
            onSuspend: (): void => {
              this.buryOrSuspendCurrent(BURY_SUSPEND_MODE_SUSPEND);
            },
            onRate: (rating: number): void => {
              this.rate(rating);
            }
          })
          // 辅助操作浮动工具栏：question/answer 阶段都显示「埋藏 + 暂停」。
          StudyFloatingToolbar({
            toolbarId: 'aux',
            phase: this.phase,
            buttonTexts: this.buttonTexts,
            fallbackTexts: this.fallbackTexts,
            isDark: this.isDark(),
            onShowAnswer: (): void => {
              this.showAnswer();
            },
            onBury: (): void => {
              this.buryOrSuspendCurrent(BURY_SUSPEND_MODE_BURY_USER);
            },
            onSuspend: (): void => {
              this.buryOrSuspendCurrent(BURY_SUSPEND_MODE_SUSPEND);
            },
            onRate: (rating: number): void => {
              this.rate(rating);
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      // 物理键盘快捷键：挂在根 Stack 上，输入法消费前拦截（API 12+）。
      // focusable(true) + defaultFocus(true)：让根 Stack 默认获焦，确保 onKeyPreIme 稳定触发。
      //   按钮获焦时键盘事件会冒泡到根 Stack（ArkUI 事件冒泡机制），仍能触发。
      // Web 已 focusable(false)，不会抢焦点；浮动工具栏按钮如被触摸获焦，事件冒泡到根 Stack 处理。
      .focusable(true)
      .defaultFocus(true)
      .onKeyPreIme((event: KeyEvent): boolean => {
        return this.handleKeyPress(event);
      })
    }
    .hideTitleBar(true)
  }
}
