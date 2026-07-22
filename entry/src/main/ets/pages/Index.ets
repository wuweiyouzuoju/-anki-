import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { BackendSession } from '../backend/BackendSession';
import { DeckService } from '../backend/DeckService';
import { StatsService } from '../backend/StatsService';
import { NoteService, NoteFieldValidationError } from '../backend/NoteService';
import { NotetypeService } from '../backend/NotetypeService';
import { exportCollection, exportDeck, finalizeExport, runImportDeck, stageImportFile, replaceCollection } from '../backend/DataTransferService';
import { SettingsPanel } from '../components/SettingsPanel';
import { TodaySummaryCard } from '../components/TodaySummaryCard';
import { MonthCalendarCard } from '../components/MonthCalendarCard';
import { DeckListItem } from '../components/DeckListItem';
import { DeckDetailPane } from '../components/DeckDetailPane';
import { StartStudyButton } from '../components/StartStudyButton';
import { LicensesPanel } from '../components/LicensesPanel';
import { CreateDeckPanel } from '../components/CreateDeckPanel';
import { HomeActionPanel } from '../components/HomeActionPanel';
import { DeckCustomizePanel, DeckCustomizeResult } from '../components/DeckCustomizePanel';
import { DeckOptionsPanel } from '../components/DeckOptionsPanel';
import { AddNotePanel, AddNoteDeckOption, AddNoteNotetypeOption } from '../components/AddNotePanel';
import { DataTransferIntent, DataTransferMode, DataTransferPanel, ExportDeckOption } from '../components/DataTransferPanel';
import { SyncPanel } from '../components/SyncPanel';
import type { SyncAuth } from '../proto/messages/SyncMessages';
import { DeckConfigService } from '../backend/DeckConfigService';
import type {
  DeckConfig,
  DeckConfigsForUpdateView,
  UpdateDeckConfigsInput
} from '../proto/messages/DeckConfigMessages';
import { UPDATE_DECK_CONFIGS_MODE_NORMAL } from '../proto/messages/DeckConfigMessages';
import { DeckConfigForm, ValidationIssue } from '../model/DeckConfigForm';
import { DeckOptionsEdit } from '../model/DeckOptionsEdit';
import { StudyPage, StudyPageParams } from './StudyPage';
import { buildMonthCalendar, MonthCalendar } from '../model/CalendarModels';
import { buildHomeSnapshot } from '../model/HomeSnapshotMapper';
import type { GraphsView } from '../proto/messages/StatsMessages';
import {
  DeckDataSource,
  DeckSummary,
  DeckTone,
  EMPTY_DECK_SUMMARY,
  EMPTY_HOME_SNAPSHOT,
  HomeLoadState,
  HomeSnapshot,
  deckDisplayName,
  pendingCount
} from '../model/HomeModels';
import { resolveIsDark, ThemeMode } from '../model/ThemeSettings';
import { loadThemeMode, saveThemeMode } from '../model/ThemeStore';
import { ColorTheme, COLOR_KEYS, DEFAULT_COLOR_THEME } from '../model/ColorTheme';
import { loadColorTheme, saveColorTheme } from '../model/ColorThemeStore';
import { applyColorTheme } from '../utils/ColorThemeManager';
import { loadDeckDisplayNames, loadDeckTones, saveDeckDisplayName, saveDeckTone,
  loadDeckBackgroundImages, saveDeckBackgroundImage, clearDeckBackgroundImage } from '../model/DeckMetaStore';
import { loadAllDeckOrders, saveDeckOrder } from '../model/DeckOrderStore';
import { loadHiddenDeckIds, saveHiddenDeck, unhideAllDecks } from '../model/HiddenDeckStore';
import { ensureFsrsEnabledOnce, loadFsrsEnabled, setFsrsEnabled } from '../model/FsrsController';
import { applyTheme } from '../utils/ThemeController';
import { AppDimens } from '../utils/AppDimens';
import { pickDataFile } from '../utils/FileImportHelper';
import { visibleDeckRows, flattenDeckTree } from '../model/DeckHierarchy';
import type { EditableNote } from '../proto/messages/NoteMessages';
import type { NotetypeNameId, NotetypeView } from '../proto/messages/NotetypeMessages';

/** 窄屏详情页推栈参数：牌组 id 经 param 传递，页面内按 id 取最新快照数据 */
interface DeckDetailPageParams {
  deckId?: string;
}

@Entry
@Component
struct Index {
  private readonly deckScroller: Scroller = new Scroller();
  private readonly pathStack: NavPathStack = new NavPathStack();
  private readonly deckDataSource: DeckDataSource = new DeckDataSource([]);
  private readonly deckService: DeckService = new DeckService();
  private readonly statsService: StatsService = new StatsService();
  private readonly noteService: NoteService = new NoteService();
  private readonly notetypeService: NotetypeService = new NotetypeService();
  private readonly deckConfigService: DeckConfigService = new DeckConfigService();
  @StorageLink('systemDarkMode') private systemDarkMode: boolean = false;
  // 用 @Provide 暴露给宽屏 GridCol 路径下的 DeckDetailPane：
  // ArkUI @Prop 对已挂载组件的字段更新不可靠（即使拆成基本类型也不响应后续 selectedDeck 变化），
  // 改用 @Provide/@Consume 让 DeckDetailPane 内部根据 selectedDeckId 自查 snapshot，
  // 保证 selectedDeckId 或 snapshot 变化时 DeckDetailPane 能重新渲染。
  @Provide('selectedDeckId') private selectedDeckId: string = '';
  @Provide('snapshot') private snapshot: HomeSnapshot = EMPTY_HOME_SNAPSHOT;
  @State private loadState: HomeLoadState = 'loading';
  @State private currentBreakpoint: string = 'xs';
  @State private themeMode: ThemeMode = 'system';
  @State private colorTheme: ColorTheme = DEFAULT_COLOR_THEME;
  // 跟随用户选择的颜色主题（极光蓝/仙野绿/暗夜紫/碧涛青/活力橙/柠檬金）
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.primaryContainer) private primaryContainerColor: string = '#E8EEFC';
  @StorageProp(COLOR_KEYS.surfacePageTint) private surfacePageTint: string = '#F5F7FA';
  // 顶部 topSettings/createDeck 两按钮共用一个 pressed 状态：0=无，1=settings，2=createDeck
  @State private toolbarPressed: number = 0;
  @State private showSettings: boolean = false;
  @State private showLicenses: boolean = false;
  @State private showCreateDeck: boolean = false;
  @State private createParentId: string = '';
  @State private showHomeActions: boolean = false;
  @State private createDeckBusy: boolean = false;
  @State private createDeckError: string = '';
  @State private expandedDeckIds: Set<string> = new Set<string>();
  @State private deckExpandInitialized: boolean = false;
  // 用户主动隐藏的 deck id 集合：loadHomeData 时从 preferences 加载，visibleDeckRows 过滤掉这些 id。
  // 隐藏入口在 DeckListItem 长按菜单「隐藏牌组」；恢复入口在设置页「已隐藏牌组」。
  @State private hiddenDeckIds: Set<string> = new Set<string>();
  @State private showAddNote: boolean = false;
  @State private addNoteBusy: boolean = false;
  @State private addNoteError: string = '';
  @State private addNoteDeckId: number = 0;
  @State private addNoteNotetypeId: number = 0;
  @State private addNoteFieldNames: string[] = [];
  @State private addNoteNotetypes: AddNoteNotetypeOption[] = [];
  @State private showDataTransfer: boolean = false;
  @State private transferInitialMode: DataTransferMode = 'exportDeck';
  @State private transferInitialDeckId: number = 0;
  @State private transferAllowDeckSelection: boolean = false;
  @State private transferBusy: boolean = false;
  @State private transferError: string = '';
  @State private transferStage: number = -1;
  @State private personalReplacementStep: number = 0;
  // SyncPanel 弹窗（B14 2026-07-22）：从 SyncGroup 点「立即同步」后挂载
  // 同步中关闭守卫由 SyncPanel 内部 canClose() 控制，Index 不拦
  @State private showSyncPanel: boolean = false;
  @State private syncPanelAuth: SyncAuth | null = null;
  @State private syncPanelAccountName: string = '';
  @State private showCustomizeDeck: boolean = false;
  @State private customizeDeckId: string = '';
  @State private customizeDeckBusy: boolean = false;
  @State private customizeDeckError: string = '';
  // 牌组选项：在根 Stack 中挂载以实现平板下的全局磨砂覆盖（与 CreateDeckPanel 同款）
  @State private showDeckOptions: boolean = false;
  @State private deckOptionsLoading: boolean = false;
  @State private deckOptionsBusy: boolean = false;
  @State private deckOptionsError: string = '';
  @State private deckOptionsDeckId: number = 0;
  @State private deckOptionsDeckName: string = '';
  private editingView: DeckConfigsForUpdateView | null = null;
  private editingConfig: DeckConfig | null = null;
  @State private editingForm: DeckConfigForm | null = null;
  @State private editingOptions: DeckOptionsEdit | null = null;
  @State private calendar: MonthCalendar = buildMonthCalendar(new Date(), new Map<string, number>());
  /** 下拉刷新状态：与 Refresh 组件双向绑定；loadHomeData 完成后置回 false 收起指示器。 */
  @State private isRefreshing: boolean = false;
  // 同级子牌组拖拽排序模式：true 时所有 DeckListItem 进入可拖态、顶部显示「完成排序」Bar、onClick 不选牌。
  // 通过长按某 DeckListItem 弹菜单 → 选「拖动排序」进入；点「完成」按钮退出并重新拉取数据。
  @State private isReorderMode: boolean = false;
  // 主页今日进度折叠态（B12-Y2 2026-07-21）：默认折叠，点击展开后渲染完整 Swiper
  @State private summaryCollapsed: boolean = true;

  aboutToAppear(): void {
    this.restoreTheme();
    this.restoreColorTheme();
  }

  /** 页面每次可见都刷新（含从复习页返回），保证今日计数与队列状态同步。 */
  onPageShow(): void {
    this.loadHomeData();
  }

  /** 打开本地 collection 并拉取牌组树；失败时进入 error 态并提示。 */
  private async loadHomeData(): Promise<void> {
    this.loadState = 'loading';
    const context: common.UIAbilityContext | null = this.abilityContext();
    if (context === null) {
      this.loadState = 'error';
      return;
    }
    try {
      await BackendSession.getInstance().ensureOpen(context.filesDir);
      // 首次启动自动开启 FSRS（用户决策：默认开启可关闭）。ensureFsrsEnabledOnce
      // 内部有 initialized 标记，只在首次跑一次；后续用户在设置页关掉就保持关闭。
      // 放在 ensureOpen 之后、拉取 tree 之前，避免与 deckTree/graphs 并发冲突。
      await ensureFsrsEnabledOnce();
      const tree = await this.deckService.getDeckTree();
      const graphs: GraphsView | null = await this.loadGraphsQuietly();
      const allDecks: DeckSummary[] = flattenDeckTree(tree);
      const deckIds: string[] = allDecks.map((deck: DeckSummary): string => deck.id);
      const toneOverrides: Map<string, DeckTone> = await loadDeckTones(deckIds);
      const displayNameOverrides: Map<string, string> = await loadDeckDisplayNames(deckIds);
      // 收集所有 parent id（含顶层 ''）：用于按 parent 加载子牌组顺序覆盖
      const parentIds: string[] = allDecks
        .map((deck: DeckSummary): string => deck.parentId)
        .filter((pid: string, index: number, self: string[]): boolean => self.indexOf(pid) === index);
      // allDecks 不含 root，但顶层 parent='' 总要尝试加载（若用户拖过顶层）
      if (parentIds.indexOf('') < 0) {
        parentIds.push('');
      }
      const orderOverrides: Map<string, string[]> = await loadAllDeckOrders(parentIds);
      const backgroundImageOverrides: Map<string, string> = await loadDeckBackgroundImages(deckIds);
      // 加载用户隐藏的 deck id 集合，visibleDeckRows 会过滤掉这些 id
      const hiddenIds: string[] = await loadHiddenDeckIds();
      this.hiddenDeckIds = new Set<string>(hiddenIds);
      const snapshot: HomeSnapshot =
        buildHomeSnapshot(tree, graphs, new Date(), toneOverrides, displayNameOverrides,
          orderOverrides, backgroundImageOverrides);
      this.snapshot = snapshot;
      // 首次加载时默认展开所有含子节点的父牌组；用 initialized 标记而非 size 判断，避免用户全折叠后被刷新重置
      if (!this.deckExpandInitialized) {
        this.deckExpandInitialized = true;
        const next: Set<string> = new Set<string>();
        for (const deck of snapshot.decks) {
          if (deck.hasChildren) next.add(deck.id);
        }
        this.expandedDeckIds = next;
      }
      this.deckDataSource.replaceAll(visibleDeckRows(snapshot.decks, this.expandedDeckIds, this.hiddenDeckIds));
      this.calendar = buildMonthCalendar(new Date(), snapshot.reviewCountsByDate);
      this.loadState = snapshot.decks.length > 0 ? 'ready' : 'empty';
    } catch (error) {
      this.loadState = 'error';
      this.showNotice($r('app.string.home_load_error'));
    } finally {
      // 无论成功或失败都收起下拉刷新指示器；onPageShow 触发时本来即为 false，无副作用。
      this.isRefreshing = false;
    }
  }

  /** 月历热力/记忆率/今日完成：回看当月天数；失败静默降级为空态，不阻断首页其余数据。 */
  private async loadGraphsQuietly(): Promise<GraphsView | null> {
    try {
      return await this.statsService.getGraphs(new Date().getDate());
    } catch (error) {
      return null;
    }
  }

  /**
   * 同步完成后检查 FSRS 状态：若云端 collection 的 fsrs=false 覆盖了本地，弹窗让用户决策。
   *
   * 触发场景：AnkiWeb 云端在桌面端等关掉了 FSRS，syncCollection/fullDownload 把 fsrs=false
   * 写到本地 collection；本地 ensureFsrsEnabledOnce 因 fsrs_initialized=true 不会自动重开。
   *
   * 弹窗用 promptAction.showDialog（系统原生）：按钮 0 = 重新开启（回写 fsrs=true），
   * 按钮 1 = 保持关闭（不动）。失败静默降级，不阻断同步完成后的 snapshot 重载。
   */
  private async checkFsrsAfterSync(): Promise<void> {
    try {
      const fsrsEnabled: boolean | null = await loadFsrsEnabled();
      if (fsrsEnabled === false) {
        await promptAction.showDialog({
          title: getContext(this).resourceManager.getStringSync($r('app.string.sync_fsrs_disabled_title').id),
          message: getContext(this).resourceManager.getStringSync($r('app.string.sync_fsrs_disabled_message').id),
          buttons: [
            {
              text: getContext(this).resourceManager.getStringSync($r('app.string.sync_fsrs_disabled_reenable').id),
              color: '#2F5FD0'
            },
            {
              text: getContext(this).resourceManager.getStringSync($r('app.string.sync_fsrs_disabled_keep').id),
              color: '#666666'
            }
          ]
        }).then((result: promptAction.ShowDialogSuccessResponse): void => {
          if (result.index === 0) {
            // 选「重新开启」：回写 fsrs=true；失败静默降级（用户可在设置页手动重开）
            setFsrsEnabled(true).catch((): void => {});
          }
        });
      }
    } catch (error) {
      // 拉取 FSRS 状态失败或弹窗失败都不阻断，静默降级
    }
  }

  /**
   * 进入排序模式：用户在 DeckListItem 长按菜单选「拖动排序」时触发。
   * 全局进入 isReorderMode=true，所有 DeckListItem 显示≡手柄、行描边高亮、onClick 不选牌、
   * LongPressGesture 等效禁用（duration 改到 99999999），让 List.onMove 接管长按拖动事件。
   * 若父牌组未展开，提示用户先展开父牌组才能拖子牌组。
   */
  private enterReorderMode(): void {
    this.isReorderMode = true;
  }

  /**
   * 退出排序模式：用户点顶部「完成」按钮时触发。
   * 退出后立即 reload，确保 LazyForEach 按 orderOverrides 重新渲染顺序（onMove 期间内存态
   * 已通过 deckDataSource.moveItem 更新，但落盘 saveDeckOrder 后下次 build 仍按 OrderOverrides 重排，
   * 视觉上不会跳动；reload 主要用于把 mode 标志清掉、重新计算 LazyForEach key）。
   */
  private exitReorderMode(): void {
    this.isReorderMode = false;
    this.loadHomeData();
  }

  /**
   * 处理 List.onMove 回调：校验 from/to 在同一 parent 后，调用 deckDataSource.moveItem
   * 同步内存顺序，并立即落盘到 DeckOrderStore。
   *
   * 跨 parent（不同 depth 或不同 ancestorIds）的拖动直接拒绝，避免破坏树结构。
   * 例如：顶层牌组不能拖到子牌组下面，子牌组不能拖到顶层。
   *
   * 注意：onMove 在用户拖动期间会持续触发（from/to 实时更新），每次都立即落盘以保证
   * 用户中途退出排序模式不丢失中间状态。落盘是 async，但 fire-and-forget，不阻塞 UI。
   */
  private handleDeckMove(from: number, to: number): void {
    if (!this.isReorderMode) {
      return;
    }
    if (from === to || from < 0 || to < 0) {
      return;
    }
    const decks: DeckSummary[] = this.deckDataSource.snapshotDecks();
    if (from >= decks.length || to >= decks.length) {
      return;
    }
    const fromDeck: DeckSummary = decks[from];
    const toDeck: DeckSummary = decks[to];
    // 同 parent 校验：parentId 相同即可（不同 depth 但同 parentId 不存在，因为 depth 由 parentId 决定）
    if (fromDeck.parentId !== toDeck.parentId) {
      return;
    }
    this.deckDataSource.moveItem(from, to);
    // 计算 parent 下最新子牌组顺序并落盘
    const updatedDecks: DeckSummary[] = this.deckDataSource.snapshotDecks();
    const childIds: string[] = [];
    for (let i: number = 0; i < updatedDecks.length; i++) {
      if (updatedDecks[i].parentId === fromDeck.parentId) {
        childIds.push(updatedDecks[i].id);
      }
    }
    saveDeckOrder(fromDeck.parentId, childIds);
  }

  private async restoreTheme(): Promise<void> {
    const restored: ThemeMode = await loadThemeMode();
    this.themeMode = restored;
    this.applyActiveTheme(restored);
  }

  /** 加载持久化的颜色主题并应用到 AppStorage；启动时调用一次。 */
  private async restoreColorTheme(): Promise<void> {
    const restored: ColorTheme = await loadColorTheme();
    this.colorTheme = restored;
    AppStorage.setOrCreate<ColorTheme>('colorTheme', restored);
    applyColorTheme(restored, this.isDark());
  }

  private abilityContext(): common.UIAbilityContext | null {
    const context: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return context === undefined ? null : context;
  }

  private applyActiveTheme(mode: ThemeMode): void {
    AppStorage.setOrCreate<ThemeMode>('themeMode', mode);
    const context: common.UIAbilityContext | null = this.abilityContext();
    if (context !== null) {
      applyTheme(context, mode, this.systemDarkMode);
    }
    // 深浅色变化时颜色主题的浅色/深色套也要同步刷新
    applyColorTheme(this.colorTheme, this.isDark());
  }

  private changeTheme(mode: ThemeMode): void {
    this.themeMode = mode;
    this.applyActiveTheme(mode);
    saveThemeMode(mode);
  }

  /** 切换颜色主题：写入 AppStorage 触发全局 @StorageProp 重渲染 + 持久化。 */
  private changeColorTheme(theme: ColorTheme): void {
    this.colorTheme = theme;
    AppStorage.setOrCreate<ColorTheme>('colorTheme', theme);
    applyColorTheme(theme, this.isDark());
    saveColorTheme(theme);
  }

  private isDark(): boolean {
    return resolveIsDark(this.themeMode, this.systemDarkMode);
  }

  private deckById(deckId: string): DeckSummary {
    for (let index: number = 0; index < this.snapshot.decks.length; index++) {
      const deck: DeckSummary = this.snapshot.decks[index];
      if (deck.id === deckId) {
        return deck;
      }
    }
    return EMPTY_DECK_SUMMARY;
  }

  private selectedDeck(): DeckSummary {
    return this.deckById(this.selectedDeckId);
  }

  private hasSelectedDeck(): boolean {
    return this.selectedDeckId !== '' && this.selectedDeck().id !== '';
  }

  private showNotice(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (error) {
      // 页面销毁或系统提示服务不可用时，不影响主界面的连续操作。
    }
  }

  private showUnavailableNotice(): void {
    this.showNotice($r('app.string.shell_notice'));
  }

  /** 进入复习页：仅当前选中牌组有效时入栈；返回（pop）时通过 onPop 刷新主页数据。 */
  private startStudy(): void {
    if (!this.hasSelectedDeck()) {
      return;
    }
    const params: StudyPageParams = {
      deckId: this.selectedDeckId,
      deckName: deckDisplayName(this.selectedDeck())
    };
    this.pathStack.pushPath({
      name: 'StudyPage',
      param: params,
      onPop: (): void => {
        this.loadHomeData();
      }
    });
  }

  /** 新建牌组全链路：ensureOpen → NewDeck → AddDeck → 刷新主页并选中新牌组。 */
  private expandDeckPath(deck: DeckSummary): void {
    const next: Set<string> = new Set<string>(this.expandedDeckIds);
    for (const ancestorId of deck.ancestorIds) next.add(ancestorId);
    this.expandedDeckIds = next;
  }

  private selectDeck(deckId: string): void {
    this.selectedDeckId = deckId;
    const deck: DeckSummary = this.selectedDeck();
    if (deck.id === '') {
      return;
    }
    this.expandDeckPath(deck);
    // 窄屏（手机）：点牌组推全屏详情页，避免列表被内联详情挤没、统计卡占半屏
    if (this.currentBreakpoint === 'xs') {
      const params: DeckDetailPageParams = { deckId: deckId };
      this.pathStack.pushPath({
        name: 'DeckDetailPage',
        param: params,
        onPop: (): void => {
          this.loadHomeData();
        }
      });
    }
  }

  private toggleDeck(deckId: string): void {
    const next: Set<string> = new Set<string>(this.expandedDeckIds);
    if (next.has(deckId)) next.delete(deckId); else next.add(deckId);
    this.expandedDeckIds = next;
    this.deckDataSource.replaceAll(visibleDeckRows(this.snapshot.decks, this.expandedDeckIds, this.hiddenDeckIds));
  }

  /** 长按牌组色条切换 tone：先持久化、再就地替换当前 snapshot 中对应行的 tone 并刷新列表，避免重拉后端数据。 */
  private async changeDeckTone(deckId: string, tone: DeckTone): Promise<void> {
    await saveDeckTone(deckId, tone);
    const oldDecks: DeckSummary[] = this.snapshot.decks;
    const newDecks: DeckSummary[] = oldDecks.map((deck: DeckSummary): DeckSummary => {
      if (deck.id !== deckId) {
        return deck;
      }
      return {
        id: deck.id,
        name: deck.name,
        fullName: deck.fullName,
        depth: deck.depth,
        parentId: deck.parentId,
        hasChildren: deck.hasChildren,
        ancestorIds: deck.ancestorIds,
        description: deck.description,
        newCount: deck.newCount,
        learningCount: deck.learningCount,
        reviewCount: deck.reviewCount,
        totalCards: deck.totalCards,
        tone: tone,
        displayName: deck.displayName,
        backgroundImage: deck.backgroundImage
      };
    });
    this.snapshot = {
      today: this.snapshot.today,
      decks: newDecks,
      reviewCountsByDate: this.snapshot.reviewCountsByDate,
      memory: this.snapshot.memory
    };
    this.deckDataSource.replaceAll(visibleDeckRows(newDecks, this.expandedDeckIds));
  }

  /** 长按牌组 → 自定义牌组：打开改名面板。 */
  private openCustomizeDeck(deckId: string): void {
    const deck: DeckSummary = this.deckById(deckId);
    if (deck.id === '') {
      return;
    }
    this.customizeDeckId = deckId;
    this.customizeDeckError = '';
    this.showCustomizeDeck = true;
  }

  /** 长按牌组 → 删除牌组：先弹 AlertDialog 二次确认，确认后真正调 deckService.removeDecks。
   *  后端语义（rslib/src/decks/remove.rs:remove_decks_and_child_decks）：递归删除所有子牌组及其卡片，
   *  卡片移到「已删除」状态（可通过 undo 恢复）。删除后刷新主页并清空选中态（防止详情页指向已删牌组）。 */
  private requestDeleteDeck(deckId: string): void {
    const deck: DeckSummary = this.deckById(deckId);
    if (deck.id === '') {
      return;
    }
    const displayName: string = deckDisplayName(deck);
    const title: string = getContext(this).resourceManager.getStringSync(
      $r('app.string.deck_delete_confirm_title').id).replace('%s', displayName);
    const message: string = getContext(this).resourceManager.getStringSync(
      $r('app.string.deck_delete_confirm_message').id);
    AlertDialog.show({
      title: title,
      message: message,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.cancel'),
        action: (): void => {}
      },
      secondaryButton: {
        value: $r('app.string.deck_menu_delete'),
        fontColor: $r('app.color.error_text'),
        action: (): void => {
          this.confirmDeleteDeck(deckId);
        }
      }
    });
  }

  private async confirmDeleteDeck(deckId: string): Promise<void> {
    try {
      const count: number = await this.deckService.removeDecks([Number(deckId)]);
      // 选中态/详情页若指向已删牌组，清空避免悬空引用
      if (this.selectedDeckId === deckId) {
        this.selectedDeckId = '';
      }
      await this.loadHomeData();
      const successMsg: string = getContext(this).resourceManager.getStringSync(
        $r('app.string.deck_delete_success').id).replace('%d', count.toString());
      this.getUIContext().getPromptAction().showToast({ message: successMsg });
    } catch (error) {
      const reason: string = error instanceof Error ? error.message : `${error}`;
      const failMsg: string = getContext(this).resourceManager.getStringSync(
        $r('app.string.deck_delete_failed').id).replace('%s', reason);
      this.getUIContext().getPromptAction().showToast({ message: failMsg });
    }
  }

  /** 长按牌组 → 隐藏牌组：写入 hiddenDeckIds 持久化 + 更新内存态 + 重新过滤列表。
   *  与删除不同：隐藏只在前端列表里过滤掉，不动后端数据；可在设置页「已隐藏牌组」恢复。
   *  选中态/详情页若指向已隐藏牌组，清空避免悬空引用。 */
  private async hideDeck(deckId: string): Promise<void> {
    try {
      await saveHiddenDeck(deckId);
      if (this.selectedDeckId === deckId) {
        this.selectedDeckId = '';
      }
      const next: Set<string> = new Set<string>(this.hiddenDeckIds);
      next.add(deckId);
      this.hiddenDeckIds = next;
      this.deckDataSource.replaceAll(visibleDeckRows(this.snapshot.decks, this.expandedDeckIds, this.hiddenDeckIds));
      this.getUIContext().getPromptAction().showToast({
        message: getContext(this).resourceManager.getStringSync($r('app.string.deck_hide_success').id)
      });
    } catch (error) {
      // 持久化失败仅 Toast 提示，不阻断
      this.getUIContext().getPromptAction().showToast({
        message: getContext(this).resourceManager.getStringSync($r('app.string.deck_hide_failed').id)
      });
    }
  }

  /** 设置页「已隐藏牌组」入口：弹 AlertDialog 展示数量 + 全部恢复。
   *  简版方案（AlertDialog 只支持两个按钮）：全部恢复 / 取消。
   *  逐个恢复需 CustomDialog，后续按需升级。 */
  private showHiddenDecksDialog(): void {
    const count: number = this.hiddenDeckIds.size;
    if (count === 0) {
      this.getUIContext().getPromptAction().showToast({
        message: getContext(this).resourceManager.getStringSync($r('app.string.hidden_decks_empty').id)
      });
      return;
    }
    const title: string = getContext(this).resourceManager.getStringSync($r('app.string.hidden_decks_title').id);
    const message: string = `${count}`;
    AlertDialog.show({
      title: title,
      message: message,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.cancel'),
        action: (): void => {}
      },
      secondaryButton: {
        value: $r('app.string.hidden_decks_unhide'),
        fontColor: $r('app.color.action_primary'),
        action: (): void => {
          this.confirmUnhideAll();
        }
      }
    });
  }

  private async confirmUnhideAll(): Promise<void> {
    try {
      await unhideAllDecks();
      this.hiddenDeckIds = new Set<string>();
      this.deckDataSource.replaceAll(visibleDeckRows(this.snapshot.decks, this.expandedDeckIds, this.hiddenDeckIds));
    } catch (error) {
      // 恢复失败静默降级，下次 loadHomeData 会重新加载
    }
  }

  /** 面板内点「保存」：写入本地 displayName 覆盖 + 处理背景图动作 + 刷新主页。
   *  走 UI 覆盖路线（不动后端 rename_deck）：避免重名/层级冲突 BackendError、避免子牌组前缀级联改名、
   *  避免 LazyForKey 不含 name 导致 UI 不刷新。代价：导出 apkg/同步到其他设备时仍显示后端原名。
   *  背景图动作：keep 不动；remove 删沙盒文件 + preferences 键；replace 编码 PixelMap 写入沙盒 + preferences。 */
  private async applyDeckCustomization(result: DeckCustomizeResult): Promise<void> {
    if (this.customizeDeckBusy) return;
    const trimmedName: string = result.newName.trim();
    if (trimmedName === '') {
      this.customizeDeckError = getContext(this).resourceManager.getStringSync(
        $r('app.string.deck_customize_name_empty').id);
      return;
    }
    const deckId: string = this.customizeDeckId;
    const deck: DeckSummary = this.deckById(deckId);
    this.customizeDeckBusy = true;
    this.customizeDeckError = '';
    try {
      // 用户输入等于后端真实 name：清除覆盖（恢复显示后端原名）；
      // 否则写入新覆盖。saveDeckDisplayName 内部对空串会 delete 键。
      const effectiveName: string = trimmedName === deck.name ? '' : trimmedName;
      if (effectiveName !== deck.displayName) {
        await saveDeckDisplayName(deckId, effectiveName);
      }

      // 背景图动作
      if (result.backgroundAction === 'remove') {
        await clearDeckBackgroundImage(deckId);
      } else if (result.backgroundAction === 'replace'
        && result.backgroundPixelMap !== null) {
        try {
          await saveDeckBackgroundImage(deckId, result.backgroundPixelMap);
        } catch (saveError) {
          // 背景图保存失败：不阻断改名保存流程，单独提示
          this.customizeDeckError = getContext(this).resourceManager.getStringSync(
            $r('app.string.deck_customize_background_save_failed').id);
          this.customizeDeckBusy = false;
          return;
        }
      }

      this.showCustomizeDeck = false;
      await this.loadHomeData();
      this.showNotice($r('app.string.deck_customize_save_done'));
    } catch (error) {
      this.customizeDeckError = error instanceof Error ? error.message : `${error}`;
      if (this.customizeDeckError === '') {
        this.customizeDeckError = getContext(this).resourceManager.getStringSync(
          $r('app.string.deck_customize_rename_failed').id);
      }
    } finally {
      this.customizeDeckBusy = false;
    }
  }

  private async importDeckFromPicker(): Promise<void> {
    if (this.transferBusy) return;
    const context: common.UIAbilityContext | null = this.abilityContext();
    if (context === null) return;
    const uri: string | null = await pickDataFile(context, ['.apkg']);
    if (uri === null) return;
    if (!this.showDataTransfer) {
      this.openDataTransfer('importDeck', 0, false);
    }
    this.transferBusy = true;
    this.transferError = '';
    this.transferStage = 0; // 准备文件中
    try {
      await BackendSession.getInstance().ensureOpen(context.filesDir);
      const stagedPath: string = stageImportFile(context.filesDir, uri);
      this.transferStage = 1; // 导入数据中
      await runImportDeck(stagedPath);
      this.transferStage = 2; // 刷新列表中
      const oldDeckIds: Set<string> = new Set(this.snapshot.decks.map((d: DeckSummary): string => d.id));
      await this.loadHomeData();
      // 展开新导入的含子牌组的父牌组
      const nextExpanded: Set<string> = new Set(this.expandedDeckIds);
      for (const deck of this.snapshot.decks) {
        if (deck.hasChildren && !oldDeckIds.has(deck.id)) {
          nextExpanded.add(deck.id);
        }
      }
      if (nextExpanded.size > this.expandedDeckIds.size) {
        this.expandedDeckIds = nextExpanded;
        this.deckDataSource.replaceAll(visibleDeckRows(this.snapshot.decks, this.expandedDeckIds, this.hiddenDeckIds));
      }
      this.showNotice($r('app.string.transfer_done'));
      // B13 2026-07-22：导入成功后关闭弹窗（原仅 showNotice，弹窗残留）
      this.showDataTransfer = false;
      this.personalReplacementStep = 0;
    } catch (error) {
      const failureDetail: string = error instanceof Error ? error.message : `${error}`;
      this.openDataTransfer('importDeck', 0, false);
      this.transferError = failureDetail;
      this.showNotice($r('app.string.transfer_failed'));
    } finally {
      this.transferBusy = false;
      this.transferStage = -1;
    }
  }

  private async confirmPersonalDataReplacement(): Promise<void> {
    if (this.transferBusy) return;
    if (this.personalReplacementStep === 0) {
      this.personalReplacementStep = 1;
      return;
    }
    const context: common.UIAbilityContext | null = this.abilityContext();
    if (context === null) return;
    const uri: string | null = await pickDataFile(context, ['.colpkg']);
    if (uri === null) return;
    this.transferBusy = true;
    this.transferError = '';
    try {
      await replaceCollection(context.filesDir, uri, true, (stage: number) => { this.transferStage = stage; });
      this.transferStage = 4; // 刷新列表中
      await this.loadHomeData();
      this.personalReplacementStep = 0;
      this.showNotice($r('app.string.transfer_done'));
      // B13 2026-07-22：替换成功后关闭弹窗（原仅 showNotice，弹窗残留）
      this.showDataTransfer = false;
    } catch (error) {
      this.transferError = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.transferBusy = false;
      this.transferStage = -1;
    }
  }

  private deckOptionsForAddNote(): AddNoteDeckOption[] {
    return this.snapshot.decks.map((deck: DeckSummary): AddNoteDeckOption => ({ id: Number(deck.id), name: deck.fullName }));
  }

  private exportDeckOptions(): ExportDeckOption[] {
    return this.snapshot.decks.map((deck: DeckSummary): ExportDeckOption => ({
      id: Number(deck.id), name: deck.fullName
    }));
  }

  private openDataTransfer(mode: DataTransferMode, deckId: number, allowDeckSelection: boolean): void {
    this.transferInitialMode = mode;
    this.transferInitialDeckId = deckId;
    this.transferAllowDeckSelection = allowDeckSelection;
    this.transferError = '';
    this.personalReplacementStep = 0;
    this.showDataTransfer = true;
  }

  private async loadAddNoteNotetype(notetypeId: number): Promise<void> {
    const view: NotetypeView = await this.notetypeService.getNotetype(notetypeId);
    this.addNoteNotetypeId = notetypeId;
    this.addNoteFieldNames = view.fieldNames;
  }

  private async openAddNote(): Promise<void> {
    if (!this.hasSelectedDeck() || this.addNoteBusy) return;
    this.addNoteBusy = true;
    this.addNoteError = '';
    try {
      const defaults = await this.noteService.defaultsForAdding();
      const names: NotetypeNameId[] = await this.notetypeService.getNotetypeNames();
      this.addNoteDeckId = Number(this.selectedDeck().id);
      this.addNoteNotetypes = names.map((item: NotetypeNameId): AddNoteNotetypeOption => ({ id: item.id, name: item.name }));
      await this.loadAddNoteNotetype(defaults.notetypeId);
      this.showAddNote = true;
    } catch (error) {
      this.addNoteError = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.addNoteBusy = false;
    }
  }

  private async saveNote(fields: string[], tags: string[], notetypeId: number): Promise<number> {
    if (this.addNoteBusy) throw new Error('busy');
    this.addNoteBusy = true;
    this.addNoteError = '';
    try {
      const note: EditableNote = await this.noteService.newNote(notetypeId);
      note.fields = fields;
      note.tags = tags;
      return await this.noteService.addNote(note, this.addNoteDeckId);
    } catch (error) {
      if (error instanceof NoteFieldValidationError) {
        if (error.messageKey === 'add_note_empty_error') {
          this.addNoteError = getContext(this).resourceManager.getStringSync($r('app.string.add_note_empty_error').id);
        } else if (error.messageKey === 'add_note_duplicate_error') {
          this.addNoteError = getContext(this).resourceManager.getStringSync($r('app.string.add_note_duplicate_error').id);
        } else {
          this.addNoteError = getContext(this).resourceManager.getStringSync($r('app.string.add_note_invalid_cloze_error').id);
        }
      } else {
        this.addNoteError = error instanceof Error ? error.message : `${error}`;
      }
      throw new Error(this.addNoteError);
    } finally {
      this.addNoteBusy = false;
    }
  }

  private async handleDataTransfer(intent: DataTransferIntent): Promise<void> {
    if (this.transferBusy) return;
    if (intent.kind === 'importDeck') {
      await this.importDeckFromPicker();
      return;
    }
    if (intent.kind === 'replacePersonalData') {
      await this.confirmPersonalDataReplacement();
      return;
    }
    const context: common.UIAbilityContext | null = this.abilityContext();
    if (context === null) return;
    this.transferBusy = true;
    this.transferError = '';
    this.transferStage = 0; // 导出数据中
    try {
      const path: string = intent.kind === 'exportDeck'
        ? await exportDeck(context.filesDir, intent.deckId, intent.options)
        : await exportCollection(context.filesDir, intent.options);
      this.transferStage = 1; // 保存文件中
      const extension: string = intent.kind === 'exportDeck' ? '.apkg' : '.colpkg';
      const fileName: string = intent.kind === 'exportDeck' ? 'jidecards-deck.apkg' : 'jidecards-data.colpkg';
      const savedPath: string | null = await finalizeExport(context, path, fileName, extension);
      if (savedPath !== null) {
        this.showNotice($r('app.string.transfer_done'));
        this.showDataTransfer = false;
        this.personalReplacementStep = 0;
      }
    } catch (error) {
      this.transferError = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.transferBusy = false;
      this.transferStage = -1;
    }
  }

  private async createDeck(name: string): Promise<void> {
    if (this.createDeckBusy) {
      return;
    }
    this.createDeckBusy = true;
    this.createDeckError = '';
    try {
      const context: common.UIAbilityContext | null = this.abilityContext();
      if (context === null) {
        throw new Error(getContext(this).resourceManager.getStringSync(
          $r('app.string.ability_context_unavailable').id));
      }
      await BackendSession.getInstance().ensureOpen(context.filesDir);
      const newDeckId: number = await this.deckService.createDeck(name);
      this.showCreateDeck = false;
      this.selectedDeckId = newDeckId.toString();
      await this.loadHomeData();
      this.expandDeckPath(this.selectedDeck());
      this.deckDataSource.replaceAll(visibleDeckRows(this.snapshot.decks, this.expandedDeckIds, this.hiddenDeckIds));
      this.showNotice($r('app.string.create_deck_done'));
    } catch (error) {
      this.createDeckError = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.createDeckBusy = false;
    }
  }

  /** 牌组选项：拉取配置视图后弹出全屏磨砂面板（与 CreateDeckPanel 同款全局覆盖） */
  private async openDeckOptions(): Promise<void> {
    if (this.deckOptionsLoading || this.deckOptionsBusy || this.showDeckOptions) {
      return;
    }
    const deck: DeckSummary = this.selectedDeck();
    const deckId: number = Number(deck.id);
    if (!Number.isFinite(deckId) || deckId <= 0) {
      return;
    }
    this.deckOptionsLoading = true;
    this.deckOptionsError = '';
    this.deckOptionsDeckId = deckId;
    this.deckOptionsDeckName = deckDisplayName(deck);
    try {
      const view: DeckConfigsForUpdateView = await this.deckConfigService.getDeckConfigsForUpdate(deckId);
      const config: DeckConfig | null = this.findCurrentConfig(view);
      if (config === null || config.config === null) {
        throw new Error('deck config not found');
      }
      this.editingView = view;
      this.editingConfig = config;
      this.editingForm = DeckConfigForm.fromSettings(config.config);
      this.editingOptions = DeckOptionsEdit.fromView(view.currentDeck === null ? null : view.currentDeck.limits, view.newCardsIgnoreReviewLimit, view.fsrs, view.applyAllParentLimits, view.fsrsHealthCheck);
      this.showDeckOptions = true;
    } catch (error) {
      const msg: string = error instanceof Error ? error.message : `${error}`;
      const stack: string = error instanceof Error && error.stack !== undefined ? error.stack : '';
      console.error(`[jidecards] openDeckOptions failed: deckId=${deckId} msg=${msg} stack=${stack}`);
      this.deckOptionsError = msg;
    } finally {
      this.deckOptionsLoading = false;
    }
  }

  private findCurrentConfig(view: DeckConfigsForUpdateView): DeckConfig | null {
    if (view.currentDeck === null) {
      return null;
    }
    const configId: number = view.currentDeck.configId;
    for (const entry of view.allConfigs) {
      if (entry.config.id === configId) {
        return entry.config;
      }
    }
    return null;
  }

  private closeDeckOptions(): void {
    this.showDeckOptions = false;
    this.deckOptionsError = '';
    this.editingView = null;
    this.editingConfig = null;
    this.editingForm = null;
    this.editingOptions = null;
  }

  private deckOptionsValidationMessage(issue: ValidationIssue): string {
    let resource: Resource = $r('app.string.deck_learn_steps_validation_error');
    switch (issue.messageKey) {
      case 'deck_relearn_steps_validation_error': resource = $r('app.string.deck_relearn_steps_validation_error'); break;
      case 'deck_limit_validation_error': resource = $r('app.string.deck_limit_validation_error'); break;
      case 'deck_retention_validation_error': resource = $r('app.string.deck_retention_validation_error'); break;
      case 'deck_nonnegative_validation_error': resource = $r('app.string.deck_nonnegative_validation_error'); break;
      case 'deck_enum_validation_error': resource = $r('app.string.deck_enum_validation_error'); break;
      case 'deck_date_validation_error': resource = $r('app.string.deck_date_validation_error'); break;
      default: resource = $r('app.string.deck_learn_steps_validation_error');
    }
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  private async saveDeckOptions(form: DeckConfigForm, options: DeckOptionsEdit): Promise<void> {
    if (this.deckOptionsBusy) {
      return;
    }
    const view: DeckConfigsForUpdateView | null = this.editingView;
    const config: DeckConfig | null = this.editingConfig;
    if (view === null || config === null || config.config === null) {
      return;
    }
    const issues = form.validate();
    if (issues.length > 0 || options.validate().length > 0 || !form.applyToSettings(config.config) || !options.apply()) {
      const issue: ValidationIssue = issues.length > 0 ? issues[0] : {
        key: 'learnSteps', messageKey: 'deck_learn_steps_validation_error'
      };
      this.deckOptionsError = this.deckOptionsValidationMessage(issue);
      return;
    }
    this.deckOptionsBusy = true;
    this.deckOptionsError = '';
    try {
      const edited = options.toRequestFields();
      const request: UpdateDeckConfigsInput = {
        targetDeckId: this.deckOptionsDeckId,
        configs: [config],
        removedConfigIds: [],
        mode: UPDATE_DECK_CONFIGS_MODE_NORMAL,
        cardStateCustomizer: view.cardStateCustomizer,
        limits: edited.limits,
        newCardsIgnoreReviewLimit: edited.newCardsIgnoreReviewLimit,
        fsrs: edited.fsrs,
        applyAllParentLimits: edited.applyAllParentLimits,
        fsrsReschedule: edited.fsrsReschedule,
        fsrsHealthCheck: edited.fsrsHealthCheck
      };
      await this.deckConfigService.updateDeckConfigs(request);
      this.closeDeckOptions();
      await this.loadHomeData();
    } catch (error) {
      const msg: string = error instanceof Error ? error.message : `${error}`;
      const stack: string = error instanceof Error && error.stack !== undefined ? error.stack : '';
      console.error(`[jidecards] saveDeckOptions failed: deckId=${this.deckOptionsDeckId} msg=${msg} stack=${stack}`);
      this.deckOptionsError = msg;
    } finally {
      this.deckOptionsBusy = false;
    }
  }

  @Builder
  private topToolbar() {
    Row() {
      Button($r('app.string.top_settings'))
        .height(AppDimens.BUTTON_HEIGHT)
        .padding({ left: AppDimens.CARD_PADDING, right: AppDimens.CARD_PADDING })
        .constraintSize({ minWidth: 0 })
        .fontSize(AppDimens.FONT_BUTTON)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor(this.toolbarPressed === 1 ? this.primaryContainerColor : $r('app.color.surface_card'))
        .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
        .borderRadius(AppDimens.RADIUS_PILL)
        .animation({ duration: 80, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent): void => {
          if (event.type === TouchType.Down) { this.toolbarPressed = 1; }
          else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.toolbarPressed = 0; }
        })
        .onClick(() => {
          this.showSettings = true;
        })

      Blank()

      Button($r('app.string.create_deck'))
        .height(AppDimens.BUTTON_HEIGHT)
        .padding({ left: AppDimens.CARD_PADDING, right: AppDimens.CARD_PADDING })
        .constraintSize({ minWidth: 0 })
        .fontSize(AppDimens.FONT_BUTTON)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.actionPrimaryColor)
        .backgroundColor(this.toolbarPressed === 2 ? this.primaryContainerColor : $r('app.color.surface_card'))
        .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
        .borderRadius(AppDimens.RADIUS_PILL)
        .animation({ duration: 80, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent): void => {
          if (event.type === TouchType.Down) { this.toolbarPressed = 2; }
          else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.toolbarPressed = 0; }
        })
        .onClick(() => {
          this.showHomeActions = true;
        })
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
  private summaryPager() {
    Swiper() {
      TodaySummaryCard({
        completedCount: this.snapshot.today.completedCount,
        pendingCount: this.snapshot.today.pendingCount,
        deckCount: this.snapshot.today.deckCount,
        // today_answered 时显示今日回忆率%；其余态（today_empty/load_error）传 -1 显示 "-"
        todayRecallRate: this.snapshot.memory.state === 'today_answered'
          ? 1 - this.snapshot.memory.todayAgainRate : -1,
        // B12-Y2 2026-07-22：始终渲染同一实例，collapsed Prop 变化时 ▼ 旋转 .animation 生效
        // （if 分支切换会销毁/重建组件，.animation 对组件销毁/重建无效）
        collapsed: this.summaryCollapsed,
        onToggleExpand: (): void => {
          this.summaryCollapsed = !this.summaryCollapsed;
        }
      })
      MonthCalendarCard({
        title: this.calendar.title,
        days: this.calendar.days,
        weekCount: this.calendar.weekCount,
        hasActivity: this.snapshot.reviewCountsByDate.size > 0,
        // B12-Y2 2026-07-22：折叠态支持（与 TodaySummaryCard 统一）
        collapsed: this.summaryCollapsed,
        onToggleExpand: (): void => {
          this.summaryCollapsed = !this.summaryCollapsed;
        }
      })
    }
    .width('100%')
    // B12-Y2 2026-07-22：Swiper 高度随 summaryCollapsed 变化（折叠 82/展开 272）
    // 始终渲染 Swiper 让 TodaySummaryCard 是同一实例，collapsed Prop 变化时 ▼ 旋转 .animation 生效
    .height(this.summaryCollapsed ? 82 : AppDimens.SWIPER_HEIGHT)
    .animation({ duration: 300, curve: Curve.EaseOut })
    // B12-Y2 2026-07-22：折叠态禁用 Swiper 滑动——hitTestBehavior(None) 让 Swiper 不参与触摸测试
    // （panGesture 不触发，无法左右滑动），但事件穿透到子组件（TodaySummaryCard 的 onClick 仍触发）
    // 展开态恢复 Default，允许左右滑动切换三卡
    .hitTestBehavior(this.summaryCollapsed ? HitTestMode.None : HitTestMode.Default)
    // loop=false：3 张卡用户左右切换即可，无需首末循环；旧值 loop=true 在 3 页边界
    // 依赖 cachedCount，未设时首末衔接可能短暂白屏。HarmonyOS Swiper 官方文档明确：
    // loop=true 且 children<3 时不循环；children=3 边界表现取决于 cachedCount。
    // 取消循环最稳，3 张卡也不需要无限轮播。
    .autoPlay(false)
    .loop(false)
    .indicator(this.summaryCollapsed ? false : true)
    .itemSpace(AppDimens.SPACE_10)
  }

  @Builder
  private deckList() {
    Column({ space: AppDimens.SPACE_10 }) {
      Row({ space: AppDimens.SPACE_8 }) {
        Text($r('app.string.deck_section_title'))
          .fontSize(AppDimens.FONT_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        // 排序模式切换按钮：仅在非排序模式下显示，让用户随时可进入排序模式。
        // 排序模式期间，顶部不显示该按钮（避免与「完成」按钮重复），改由「完成」按钮退出。
        if (this.isReorderMode) {
          Button($r('app.string.deck_reorder_done'))
            .height(AppDimens.BUTTON_HEIGHT)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor($r('app.color.surface_page'))
            .backgroundColor(this.actionPrimaryColor)
            .borderRadius(AppDimens.RADIUS_PILL)
            .onClick(() => {
              this.exitReorderMode();
            })
        }
      }
      .width('100%')
      // 排序模式提示条：用户进入排序模式后告知「长按卡片拖动，仅同级可拖」
      if (this.isReorderMode) {
        Text($r('app.string.deck_reorder_hint'))
          .fontSize(AppDimens.FONT_BODY_S)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .maxLines(2)
      }
      // 下拉刷新：用户决策「取消按钮改下拉刷新」，故顶部工具栏不再放刷新按钮，
      // 改用 Refresh 容器；触发 onRefreshing 时调用 loadHomeData，完成后 isRefreshing=false 收起指示器。
      Refresh({ refreshing: $$this.isRefreshing }) {
        List({ scroller: this.deckScroller, space: AppDimens.LIST_SPACE }) {
        LazyForEach(this.deckDataSource, (deck: DeckSummary) => {
          ListItem() {
            DeckListItem({
              deck: deck,
              selected: deck.id === this.selectedDeckId,
              reorderMode: this.isReorderMode,
              onSelect: (deckId: string): void => {
                this.selectDeck(deckId);
              },
              expanded: this.expandedDeckIds.has(deck.id),
              onToggle: (deckId: string): void => {
                this.toggleDeck(deckId);
              },
              onToneChange: (deckId: string, tone: DeckTone): void => {
                this.changeDeckTone(deckId, tone);
              },
              onCustomizeDeck: (deckId: string): void => {
                this.openCustomizeDeck(deckId);
              },
              onEnterReorder: (deckId: string): void => {
                this.enterReorderMode();
              },
              onDeleteDeck: (deckId: string): void => {
                this.requestDeleteDeck(deckId);
              },
              onHideDeck: (deckId: string): void => {
                this.hideDeck(deckId);
              }
            })
          }
        }, (deck: DeckSummary) => `${deck.id}_${deck.tone}_${deck.displayName}_${deck.newCount}_${deck.learningCount}_${deck.reviewCount}_${deck.totalCards}_${deck.backgroundImage}_${this.isReorderMode ? 1 : 0}`)
        .onMove((from: number, to: number): void => {
          this.handleDeckMove(from, to);
        })
        if (this.loadState === 'loading') {
          ListItem() {
            Row() {
              LoadingProgress()
                .width(AppDimens.LOADING_SIZE)
                .height(AppDimens.LOADING_SIZE)
                .color(this.actionPrimaryColor)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: AppDimens.EMPTY_PADDING_V, bottom: AppDimens.EMPTY_PADDING_V })
          }
        }
        if (this.loadState === 'error') {
          ListItem() {
            Column({ space: AppDimens.SPACE_8 }) {
              Text($r('app.string.home_load_error'))
                .fontSize(AppDimens.FONT_BODY_M)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
              Button($r('app.string.home_retry'))
                .height(AppDimens.BUTTON_HEIGHT)
                .fontSize(AppDimens.FONT_BUTTON)
                .fontColor(this.actionPrimaryColor)
                .backgroundColor($r('app.color.surface_card'))
                .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
                .borderRadius(AppDimens.RADIUS_PILL)
                .onClick(() => {
                  this.loadHomeData();
                })
            }
            .width('100%')
            .padding({ top: AppDimens.EMPTY_PADDING_V, bottom: AppDimens.EMPTY_PADDING_V })
          }
        }
        if (this.loadState === 'empty') {
          ListItem() {
            Column({ space: AppDimens.SPACE_8 }) {
              Text($r('app.string.empty_decks_title'))
                .fontSize(AppDimens.FONT_TITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text($r('app.string.empty_decks_hint'))
                .fontSize(AppDimens.FONT_BODY_M)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ top: AppDimens.EMPTY_PADDING_V, bottom: AppDimens.EMPTY_PADDING_V })
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      }
      .onRefreshing(() => {
        // 用户下拉到阈值后触发；loadHomeData 完成后 isRefreshing 置 false 收起指示器。
        this.loadHomeData();
      })
      .layoutWeight(1)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private mainPane() {
    Column({ space: AppDimens.SPACE_12 }) {
      // B12-Y2 2026-07-22：始终渲染 summaryPager，让 TodaySummaryCard 是同一实例
      // collapsed Prop 变化时 ▼ 旋转 .animation 生效（if 分支切换会销毁/重建组件，.animation 无效）
      // 折叠态 Swiper 高度 82 + hitTestBehavior(None) 禁用滑动，只显示 TodaySummaryCard 折叠态
      this.summaryPager()
      this.deckList()
    }
    .width('100%')
    // B12-Y2 2026-07-22：PC 端宽屏适配——md 下限宽 600vp（外层 Stack alignContent=Center 居中）
    // 避免 Swiper 三卡在 800vp 宽下宽高比 3:1 偏扁、DeckListItem 行宽 776vp 大量空白
    // xs/sm 不限宽（'100%'），不影响手机
    .constraintSize({ maxWidth: this.currentBreakpoint === 'md' ? 600 : '100%' })
    .height('100%')
    .padding({
      left: AppDimens.PAGE_PADDING_H,
      right: AppDimens.PAGE_PADDING_H,
      top: AppDimens.SPACE_4,
      bottom: AppDimens.PAGE_PADDING_H
    })
    .backgroundColor(this.surfacePageTint)
  }

  /** 详情页可达的弹层（新建牌组/添加卡片/数据互传）：窄屏下详情页以 NavDestination 盖在根 Stack 之上，
   *  故同一份弹层需在详情页内再渲染一次，否则手机上点「新建子牌组/添加卡片/导出」看似无反应。 */
  @Builder
  private detailTriggeredOverlays() {
    if (this.showCreateDeck) {
      CreateDeckPanel({
        isDark: this.isDark(),
        busy: this.createDeckBusy,
        errorMessage: this.createDeckError,
        parentOptions: this.snapshot.decks,
        initialParentId: this.createParentId,
        onCancel: (): void => {
          this.showCreateDeck = false;
        },
        onConfirm: (name: string): void => {
          this.createDeck(name);
        }
      })
    }

    if (this.showAddNote) {
      AddNotePanel({
        isDark: this.isDark(),
        busy: this.addNoteBusy,
        errorMessage: this.addNoteError,
        selectedDeckId: this.addNoteDeckId,
        deckOptions: this.deckOptionsForAddNote(),
        selectedNotetypeId: this.addNoteNotetypeId,
        notetypeOptions: this.addNoteNotetypes,
        fieldNames: this.addNoteFieldNames,
        onCancel: (): void => {
          if (!this.addNoteBusy) this.showAddNote = false;
        },
        onSelectDeck: (deckId: number): void => {
          this.addNoteDeckId = deckId;
        },
        onSelectNotetype: (notetypeId: number): void => {
          this.loadAddNoteNotetype(notetypeId);
        },
        onSave: (fields: string[], tags: string[], notetypeId: number): Promise<number> =>
          this.saveNote(fields, tags, notetypeId),
        onSaved: (_noteId: number): void => {
          this.showAddNote = false;
          this.loadHomeData();
        }
      })
    }

    if (this.showDataTransfer) {
      DataTransferPanel({
        deckId: this.transferInitialDeckId,
        initialMode: this.transferInitialMode,
        deckOptions: this.exportDeckOptions(),
        allowDeckSelection: this.transferAllowDeckSelection,
        busy: this.transferBusy,
        errorMessage: this.transferError,
        personalReplacementStep: this.personalReplacementStep,
        stage: this.transferStage,
        isDark: this.isDark(),
        onIntent: (intent: DataTransferIntent): void => {
          this.handleDataTransfer(intent);
        },
        onClose: (): void => {
          if (!this.transferBusy) {
            this.showDataTransfer = false;
            this.personalReplacementStep = 0;
          }
        }
      })
    }

    if (this.showDeckOptions && this.editingForm !== null && this.editingOptions !== null) {
      DeckOptionsPanel({
        isDark: this.isDark(),
        deckName: this.deckOptionsDeckName,
        form: this.editingForm,
        options: this.editingOptions,
        busy: this.deckOptionsBusy,
        errorMessage: this.deckOptionsError,
        onCancel: (): void => {
          if (!this.deckOptionsBusy) this.closeDeckOptions();
        },
        onSave: (form: DeckConfigForm, options: DeckOptionsEdit): void => {
          this.saveDeckOptions(form, options);
        }
      })
    }
  }

  /** Navigation 目的地映射：StudyPage / 窄屏 DeckDetailPage 以 NavDestination 形式入栈展示 */
  @Builder
  private pageMap(name: string, param: ESObject) {
    if (name === 'StudyPage') {
      StudyPage({
        pageDeckId: (param as StudyPageParams).deckId ?? '',
        pageDeckName: (param as StudyPageParams).deckName ?? '',
        pathStack: this.pathStack
      })
    }
    if (name === 'DeckDetailPage') {
      NavDestination() {
        Stack() {
          Column() {
          Row() {
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
                this.pathStack.pop();
              })
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

          DeckDetailPane({
            isDark: this.isDark(),
            deckOptionsLoading: this.deckOptionsLoading,
            deckOptionsError: this.deckOptionsError,
            onStart: (): void => {
              this.startStudy();
            },
            onAddCard: (): void => {
              this.openAddNote();
            },
            onCreateSubdeck: (): void => {
              this.createParentId = this.selectedDeckId;
              this.showCreateDeck = true;
            },
            onExportDeck: (): void => {
              this.openDataTransfer('exportDeck', Number(this.selectedDeckId), false);
            },
            onOpenDeckOptions: (): void => {
              this.openDeckOptions();
            }
          })
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.surfacePageTint)

          this.detailTriggeredOverlays()
        }
        .width('100%')
        .height('100%')
      }
      .hideTitleBar(true)
    }
  }

  build() {
    Navigation(this.pathStack) {
      Stack() {
        Column() {
          this.topToolbar()
          GridRow({
            columns: { xs: 4, sm: 8, md: 12 },
            breakpoints: {
              value: ['600vp', '840vp'],
              reference: BreakpointsReference.WindowSize
            },
            gutter: 0
          }) {
            GridCol({ span: { xs: 4, sm: 5, md: 8 } }) {
              // B12-Y2 2026-07-22：PC 端宽屏适配——md 下 mainPane 限宽 600vp 居中
              // 避免 Swiper 三卡和 DeckListItem 在 800vp 宽下过扁/过空（不影响手机 xs/sm）
              Stack({ alignContent: Alignment.Center }) {
                this.mainPane()
              }
              .width('100%')
              .height('100%')
            }
            if (this.currentBreakpoint !== 'xs') {
              GridCol({ span: { xs: 0, sm: 3, md: 4 } }) {
                DeckDetailPane({
                  isDark: this.isDark(),
                  deckOptionsLoading: this.deckOptionsLoading,
                  deckOptionsError: this.deckOptionsError,
                  onStart: (): void => {
                    this.startStudy();
                  },
                  onAddCard: (): void => { this.openAddNote(); },
                  onCreateSubdeck: (): void => {
                    this.createParentId = this.selectedDeckId;
                    this.showCreateDeck = true;
                  },
                  onExportDeck: (): void => {
                    this.openDataTransfer('exportDeck', Number(this.selectedDeckId), false);
                  },
                  onOpenDeckOptions: (): void => {
                    this.openDeckOptions();
                  }
                })
              }
            }
          }
          .layoutWeight(1)
          .onBreakpointChange((breakpoint: string) => {
            this.currentBreakpoint = breakpoint;
          })
        }
        .width('100%')
        .constraintSize({ maxWidth: AppDimens.CONTENT_MAX_WIDTH })
        .height('100%')
        .backgroundColor(this.surfacePageTint)

        if (this.showSettings) {
          SettingsPanel({
            themeMode: this.themeMode,
            isDark: this.isDark(),
            colorTheme: this.colorTheme,
            onThemeChange: (mode: ThemeMode): void => {
              this.changeTheme(mode);
            },
            onColorThemeChange: (theme: ColorTheme): void => {
              this.changeColorTheme(theme);
            },
            onOpenLicenses: (): void => {
              this.showLicenses = true;
            },
            onImportData: (): void => {
              this.showSettings = false;
              this.openDataTransfer('importDeck', 0, true);
            },
            onExportData: (): void => {
              this.showSettings = false;
              this.openDataTransfer('exportDeck', this.hasSelectedDeck() ? Number(this.selectedDeckId) : 0, true);
            },
            onHiddenDecks: (): void => {
              this.showHiddenDecksDialog();
            },
            // 用户在 SyncGroup 点「先备份后同步」：导出整个 collection 为 .colpkg
            // 用户备份完手动回设置页点「立即同步」—— 备份与同步两步分离
            onBackupSyncData: (): void => {
              this.showSettings = false;
              this.openDataTransfer('exportPersonalData', 0, false);
            },
            // 用户在 SyncGroup 点「立即同步」：暂存 auth + 账号名，挂载 SyncPanel 弹窗
            onOpenSync: (auth: SyncAuth, accountName: string): void => {
              this.syncPanelAuth = auth;
              this.syncPanelAccountName = accountName;
              this.showSyncPanel = true;
            },
            onClose: (): void => {
              this.showSettings = false;
            }
          })
        }

        if (this.showSyncPanel) {
          SyncPanel({
            isDark: this.isDark(),
            accountName: this.syncPanelAccountName,
            initialAuth: this.syncPanelAuth,
            onSyncCompleted: (): void => {
              this.loadHomeData();
              this.checkFsrsAfterSync();
            },
            onClose: (): void => {
              this.showSyncPanel = false;
              this.syncPanelAuth = null;
              this.syncPanelAccountName = '';
            }
          })
        }

        if (this.showLicenses) {
          LicensesPanel({
            isDark: this.isDark(),
            onClose: (): void => {
              this.showLicenses = false;
            }
          })
        }

        if (this.showHomeActions) {
          HomeActionPanel({
            onCreateDeck: (): void => {
              this.showHomeActions = false;
              this.createDeckError = '';
              this.createParentId = '';
              this.showCreateDeck = true;
            },
            onImportDeck: (): void => {
              this.showHomeActions = false;
              this.importDeckFromPicker();
            },
            onClose: (): void => {
              this.showHomeActions = false;
            }
          })
        }

        this.detailTriggeredOverlays()

        if (this.showCustomizeDeck) {
          DeckCustomizePanel({
            isDark: this.isDark(),
            deck: this.deckById(this.customizeDeckId),
            busy: this.customizeDeckBusy,
            errorMessage: this.customizeDeckError,
            onClose: (): void => {
              if (!this.customizeDeckBusy) {
                this.showCustomizeDeck = false;
              }
            },
            onSave: (result: DeckCustomizeResult): void => {
              this.applyDeckCustomization(result);
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.surfacePageTint)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pageMap)
  }
}
