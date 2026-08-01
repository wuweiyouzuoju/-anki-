// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { 后端会话 } from '../backend/后端会话';
import { 牌组服务 } from '../backend/牌组服务';
import { 统计服务 } from '../backend/统计服务';
import { 导出集合, 导出牌组, 完成导出, 执行牌组导入, 暂存导入文件, 替换集合 } from '../backend/数据迁移服务';
import { 设置面板 } from '../components/设置面板';
import { 牌组详情面板 } from '../components/牌组详情面板';
import { 许可证面板 } from '../components/许可证面板';
import { 主页操作面板 } from '../components/主页操作面板';
import { 牌组定制面板, 牌组定制结果 } from '../components/牌组定制面板';
import { 添加笔记页, 添加笔记页参数, 添加笔记牌组选项 } from './添加笔记页';
import { 数据迁移意图, 数据迁移模式, 导出牌组选项 } from '../components/数据迁移面板';
import { 同步面板 } from '../components/同步面板';
import { 主页顶部工具栏 } from '../components/home/主页顶部工具栏';
import { 主页摘要分页 } from '../components/home/主页摘要分页';
import { 主页牌组列表 } from '../components/home/主页牌组列表';
import { 牌组选项协调器 } from '../components/home/牌组选项协调器';
import { 数据迁移协调器 } from '../components/home/数据迁移协调器';
import { 创建牌组协调器 } from '../components/home/创建牌组协调器';
import type { SyncAuth } from '../proto/messages/SyncMessages';
import { 牌组配置服务 } from '../backend/牌组配置服务';
import type {
  DeckConfig,
  DeckConfigsForUpdateView,
  UpdateDeckConfigsInput
} from '../proto/messages/DeckConfigMessages';
import { UPDATE_DECK_CONFIGS_MODE_NORMAL } from '../proto/messages/DeckConfigMessages';
import { 牌组配置表单, 校验问题 } from '../model/牌组配置表单';
import { 牌组选项编辑 } from '../model/牌组选项编辑';
import { 学习页, 学习页参数 } from './学习页';
import { 构建月历, 月历数据 } from '../model/日历模型';
import { 构建主页快照 } from '../model/主页快照映射器';
import type { GraphsView } from '../proto/messages/StatsMessages';
import {
  牌组列表数据源,
  牌组汇总,
  牌组色调,
  空牌组汇总,
  空主页快照,
  主页加载状态,
  主页快照,
  牌组显示名
} from '../model/主页模型';
import { 解析是否深色, 主题模式 } from '../model/主题设置';
import { 加载主题模式, 保存主题模式 } from '../model/主题存储';
import { 颜色主题, 颜色键, 默认颜色主题 } from '../model/颜色主题';
import { 加载颜色主题, 保存颜色主题 } from '../model/颜色主题存储';
import { 应用颜色主题 } from '../utils/颜色主题管理器';
import { 加载牌组别名映射, 加载牌组色调映射, 保存牌组别名, 保存牌组色调,
  加载牌组背景图映射, 保存牌组背景图, 清除牌组背景图 } from '../model/牌组元数据存储';
import { 加载全部牌组顺序, 保存牌组顺序 } from '../model/牌组顺序存储';
import { 加载已隐藏牌组ID列表, 隐藏牌组, 取消隐藏全部牌组 } from '../model/隐藏牌组存储';
import { 加载上次牌组ID, 保存上次牌组ID, 清除上次牌组ID } from '../model/上次牌组存储';
import { 确保FSRS已开启一次, 加载FSRS开启状态, 设置FSRS开启状态 } from '../model/FSRS控制器';
import { 是否已展示AnkiWeb引导, 标记已展示AnkiWeb引导 } from '../model/AnkiWeb引导存储';
import { 是否已展示好评引导, 标记已展示好评引导 } from '../model/好评引导存储';
import { 加载显示今日进度卡, 保存摘要展开状态, 加载摘要展开状态, 主页今日进度卡AppStorage键 } from '../model/主页偏好';
import { AnkiWeb引导对话框 } from '../components/AnkiWeb引导对话框';
import { 好评引导对话框 } from '../components/好评引导对话框';
import { 应用主题 } from '../utils/主题控制器';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 选取数据文件 } from '../utils/文件导入助手';
import { 可见牌组行, 平铺牌组树 } from '../model/牌组层级';

interface 牌组详情页参数 {
  deckId?: string;
}

@Entry
@Component
struct 首页 {
  private readonly 牌组列表滚动器: Scroller = new Scroller();
  private readonly 页面栈: NavPathStack = new NavPathStack();
  private readonly 牌组数据源: 牌组列表数据源 = new 牌组列表数据源([]);
  private readonly 牌组服务实例: 牌组服务 = new 牌组服务();
  private readonly 统计服务实例: 统计服务 = new 统计服务();
  private readonly 牌组配置服务实例: 牌组配置服务 = new 牌组配置服务();
  @StorageLink('systemDarkMode') private 系统暗黑模式: boolean = false;
  @StorageLink('noteAddedTick') @Watch('笔记添加广播_回调') private 笔记添加标记: number = 0;
  @StorageLink(主页今日进度卡AppStorage键) private 显示今日进度卡: boolean = true;
  @Provide('selectedDeckId') private 选中的牌组ID: string = '';
  @Provide('snapshot') private 主页快照数据: 主页快照 = 空主页快照;
  @State private 加载状态: 主页加载状态 = 'loading';
  @State private 当前断点: string = 'xs';
  @State private 主题模式值: 主题模式 = 'system';
  @State private 颜色主题值: 颜色主题 = 默认颜色主题;
  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';
  @StorageProp(颜色键.页面底色微染) private 页面底色微染值: string = '#F5F7FA';
  @State private 工具栏按下状态: number = 0;
  @State private 显示设置: boolean = false;
  @State private 显示许可证: boolean = false;
  @State private 显示创建牌组: boolean = false;
  @State private 创建父牌组ID: string = '';
  @State private 显示主页操作: boolean = false;
  @State private 创建牌组中: boolean = false;
  @State private 创建牌组错误: string = '';
  @State private 展开的牌组ID集合: Set<string> = new Set<string>();
  @State private 牌组展开已初始化: boolean = false;
  private 已知牌组ID集合: Set<string> = new Set<string>();
  @State private 隐藏的牌组ID集合: Set<string> = new Set<string>();
  @State private 显示数据迁移: boolean = false;
  @State private 数据迁移初始模式: 数据迁移模式 = 'exportDeck';
  @State private 数据迁移初始牌组ID: number = 0;
  @State private 数据迁移允许选牌组: boolean = false;
  @State private 数据迁移中: boolean = false;
  @State private 数据迁移错误: string = '';
  @State private 数据迁移阶段: number = -1;
  @State private 个人数据替换步骤: number = 0;
  @State private 显示同步面板: boolean = false;
  @State private 同步面板认证: SyncAuth | null = null;
  @State private 同步面板账号名: string = '';
  @State private 显示牌组定制: boolean = false;
  @State private 定制牌组ID: string = '';
  @State private 定制牌组中: boolean = false;
  @State private 定制牌组错误: string = '';
  @State private 显示牌组选项: boolean = false;
  @State private 牌组选项加载中: boolean = false;
  @State private 牌组选项中: boolean = false;
  @State private 牌组选项错误: string = '';
  @State private 牌组选项牌组ID: number = 0;
  @State private 牌组选项牌组名: string = '';
  private 编辑视图: DeckConfigsForUpdateView | null = null;
  private 编辑配置: DeckConfig | null = null;
  @State private 编辑表单: 牌组配置表单 | null = null;
  @State private 编辑选项: 牌组选项编辑 | null = null;
  @State private 月历: 月历数据 = 构建月历(new Date(), new Map<string, number>());
  @State private 刷新中: boolean = false;
  @State private 排序模式中: boolean = false;
  @State private 摘要折叠: boolean = true;
  private 上次牌组已恢复: boolean = false;
  @State private 显示AnkiWeb引导: boolean = false;
  @State private 显示好评引导: boolean = false;
  @State private 显示牌组详情: boolean = false;

  aboutToAppear(): void {
    this.恢复主题();
    this.恢复颜色主题();
    this.恢复今日进度卡开关();
    this.恢复摘要展开状态();
    this.显示AnkiWeb引导一次();
  }

  private async 显示AnkiWeb引导一次(): Promise<void> {
    const 已展示: boolean = await 是否已展示AnkiWeb引导();
    if (已展示) {
      return;
    }
    await 标记已展示AnkiWeb引导();
    this.显示AnkiWeb引导 = true;
  }

  onPageShow(): void {
    this.加载主页数据();
  }

  onBackPress(): boolean {
    if (this.显示牌组详情) {
      this.显示牌组详情 = false;
      return true;
    }
    return false;
  }

  private 笔记添加广播_回调(): void {
    this.加载主页数据();
  }

  private async 加载主页数据(): Promise<void> {
    this.加载状态 = 'loading';
    const context: common.UIAbilityContext | null = this.取能力上下文();
    if (context === null) {
      this.加载状态 = 'error';
      return;
    }
    try {
      await 后端会话.获取实例().确保已打开(context.filesDir);
      await 确保FSRS已开启一次();
      const tree = await this.牌组服务实例.获取牌组树();
      const graphs: GraphsView | null = await this.静默加载图表();
      const allDecks: 牌组汇总[] = 平铺牌组树(tree);
      const deckIds: string[] = allDecks.map((deck: 牌组汇总): string => deck.id);
      const toneOverrides: Map<string, 牌组色调> = await 加载牌组色调映射(deckIds);
      const displayNameOverrides: Map<string, string> = await 加载牌组别名映射(deckIds);
      const parentIds: string[] = allDecks
        .map((deck: 牌组汇总): string => deck.parentId)
        .filter((pid: string, index: number, self: string[]): boolean => self.indexOf(pid) === index);
      if (parentIds.indexOf('') < 0) {
        parentIds.push('');
      }
      const orderOverrides: Map<string, string[]> = await 加载全部牌组顺序(parentIds);
      const backgroundImageOverrides: Map<string, string> = await 加载牌组背景图映射(deckIds);
      const hiddenIds: string[] = await 加载已隐藏牌组ID列表();
      this.隐藏的牌组ID集合 = new Set<string>(hiddenIds);
      const snapshot: 主页快照 =
        构建主页快照(tree, graphs, new Date(), toneOverrides, displayNameOverrides,
          orderOverrides, backgroundImageOverrides);
      this.主页快照数据 = snapshot;
      if (!this.牌组展开已初始化) {
        this.牌组展开已初始化 = true;
        const next: Set<string> = new Set<string>();
        for (const deck of snapshot.decks) {
          if (deck.hasChildren) next.add(deck.id);
        }
        this.展开的牌组ID集合 = next;
      } else {
        const next: Set<string> = new Set<string>(this.展开的牌组ID集合);
        for (const deck of snapshot.decks) {
          if (deck.hasChildren && !this.已知牌组ID集合.has(deck.id)) {
            next.add(deck.id);
          }
        }
        this.展开的牌组ID集合 = next;
      }
      const newKnown: Set<string> = new Set<string>();
      for (const deck of snapshot.decks) {
        newKnown.add(deck.id);
      }
      this.已知牌组ID集合 = newKnown;
      this.牌组数据源.replaceAll(可见牌组行(snapshot.decks, this.展开的牌组ID集合, this.隐藏的牌组ID集合));
      this.月历 = 构建月历(new Date(), snapshot.reviewCountsByDate);
      this.加载状态 = snapshot.decks.length > 0 ? 'ready' : 'empty';
      if (!this.上次牌组已恢复 && this.当前断点 !== 'xs') {
        await this.尝试恢复上次牌组();
      }
    } catch (error) {
      this.加载状态 = 'error';
      this.显示提示($r('app.string.home_load_error'));
    } finally {
      this.刷新中 = false;
    }
  }

  private async 尝试恢复上次牌组(): Promise<void> {
    if (this.上次牌组已恢复) {
      return;
    }
    if (this.主页快照数据.decks.length === 0) {
      return;
    }
    this.上次牌组已恢复 = true;
    const lastDeckId: string = await 加载上次牌组ID();
    if (lastDeckId !== ''
        && !this.隐藏的牌组ID集合.has(lastDeckId)
        && this.按ID查牌组(lastDeckId).id !== '') {
      this.选中的牌组ID = lastDeckId;
      this.展开牌组路径(this.选中牌组());
      this.牌组数据源.replaceAll(可见牌组行(this.主页快照数据.decks, this.展开的牌组ID集合, this.隐藏的牌组ID集合));
    }
  }

  private async 静默加载图表(): Promise<GraphsView | null> {
    try {
      return await this.统计服务实例.获取图表统计(new Date().getDate());
    } catch (error) {
      return null;
    }
  }

  private async 同步后检查FSRS(): Promise<void> {
    try {
      const fsrsEnabled: boolean | null = await 加载FSRS开启状态();
      if (fsrsEnabled === false) {
        await this.getUIContext().getPromptAction().showDialog({
          title: this.getUIContext().getHostContext()!.resourceManager.getStringSync($r('app.string.sync_fsrs_disabled_title').id),
          message: this.getUIContext().getHostContext()!.resourceManager.getStringSync($r('app.string.sync_fsrs_disabled_message').id),
          buttons: [
            {
              text: this.getUIContext().getHostContext()!.resourceManager.getStringSync($r('app.string.sync_fsrs_disabled_reenable').id),
              color: '#2F5FD0'
            },
            {
              text: this.getUIContext().getHostContext()!.resourceManager.getStringSync($r('app.string.sync_fsrs_disabled_keep').id),
              color: '#666666'
            }
          ]
        }).then((result: promptAction.ShowDialogSuccessResponse): void => {
          if (result.index === 0) {
            设置FSRS开启状态(true).catch((): void => {});
          }
        });
      }
    } catch (error) {
    }
  }

  private 进入排序模式(): void {
    this.排序模式中 = true;
  }

  private 退出排序模式(): void {
    this.排序模式中 = false;
    this.加载主页数据();
  }

  private 处理牌组移动(from: number, to: number): void {
    if (!this.排序模式中) {
      return;
    }
    if (from === to || from < 0 || to < 0) {
      return;
    }
    const decks: 牌组汇总[] = this.牌组数据源.snapshotDecks();
    if (from >= decks.length || to >= decks.length) {
      return;
    }
    const fromDeck: 牌组汇总 = decks[from];
    const toDeck: 牌组汇总 = decks[to];
    if (fromDeck.parentId !== toDeck.parentId) {
      return;
    }
    this.牌组数据源.moveItem(from, to);
    const updatedDecks: 牌组汇总[] = this.牌组数据源.snapshotDecks();
    const childIds: string[] = [];
    for (let i: number = 0; i < updatedDecks.length; i++) {
      if (updatedDecks[i].parentId === fromDeck.parentId) {
        childIds.push(updatedDecks[i].id);
      }
    }
    保存牌组顺序(fromDeck.parentId, childIds);
  }

  private async 恢复主题(): Promise<void> {
    const restored: 主题模式 = await 加载主题模式();
    this.主题模式值 = restored;
    this.应用激活主题(restored);
  }

  private async 恢复颜色主题(): Promise<void> {
    const restored: 颜色主题 = await 加载颜色主题();
    this.颜色主题值 = restored;
    AppStorage.setOrCreate<颜色主题>('colorTheme', restored);
    应用颜色主题(restored, this.是否深色());
  }

  private async 恢复今日进度卡开关(): Promise<void> {
    const 开启: boolean = await 加载显示今日进度卡();
    AppStorage.setOrCreate<boolean>(主页今日进度卡AppStorage键, 开启);
  }

  private async 恢复摘要展开状态(): Promise<void> {
    const 展开: boolean = await 加载摘要展开状态();
    this.摘要折叠 = !展开;
  }

  private 取能力上下文(): common.UIAbilityContext | null {
    const context: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return context === undefined ? null : context;
  }

  private 应用激活主题(mode: 主题模式): void {
    AppStorage.setOrCreate<主题模式>('themeMode', mode);
    const context: common.UIAbilityContext | null = this.取能力上下文();
    if (context !== null) {
      应用主题(context, mode, this.系统暗黑模式);
    }
    应用颜色主题(this.颜色主题值, this.是否深色());
  }

  private 切换主题(mode: 主题模式): void {
    this.主题模式值 = mode;
    this.应用激活主题(mode);
    保存主题模式(mode);
  }

  private 切换颜色主题(theme: 颜色主题): void {
    this.颜色主题值 = theme;
    AppStorage.setOrCreate<颜色主题>('colorTheme', theme);
    应用颜色主题(theme, this.是否深色());
    保存颜色主题(theme);
  }

  private 是否深色(): boolean {
    return 解析是否深色(this.主题模式值, this.系统暗黑模式);
  }

  private 按ID查牌组(deckId: string): 牌组汇总 {
    for (let index: number = 0; index < this.主页快照数据.decks.length; index++) {
      const deck: 牌组汇总 = this.主页快照数据.decks[index];
      if (deck.id === deckId) {
        return deck;
      }
    }
    return 空牌组汇总;
  }

  private 选中牌组(): 牌组汇总 {
    return this.按ID查牌组(this.选中的牌组ID);
  }

  private 已选中牌组(): boolean {
    return this.选中的牌组ID !== '' && this.选中牌组().id !== '';
  }

  private 显示提示(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (error) {
    }
  }

  private 开始学习(): void {
    if (!this.已选中牌组()) {
      return;
    }
    const params: 学习页参数 = {
      deckId: this.选中的牌组ID,
      deckName: 牌组显示名(this.选中牌组())
    };
    this.页面栈.pushPath({
      name: 'StudyPage',
      param: params,
      onPop: (): void => {
        this.加载主页数据();
        this.检查学习完成标记();
      }
    });
  }

  private async 检查学习完成标记(): Promise<void> {
    const studyCompleted: boolean | undefined = AppStorage.get<boolean>('studyJustFinished');
    AppStorage.setOrCreate('studyJustFinished', false);
    if (!studyCompleted) {
      return;
    }
    if (await 是否已展示好评引导()) {
      return;
    }
    await 标记已展示好评引导();
    this.显示好评引导 = true;
  }

  private 展开牌组路径(deck: 牌组汇总): void {
    const next: Set<string> = new Set<string>(this.展开的牌组ID集合);
    for (const ancestorId of deck.ancestorIds) next.add(ancestorId);
    this.展开的牌组ID集合 = next;
  }

  private 选择牌组(deckId: string): void {
    this.选中的牌组ID = deckId;
    const deck: 牌组汇总 = this.选中牌组();
    if (deck.id === '') {
      return;
    }
    this.展开牌组路径(deck);
    保存上次牌组ID(deckId).catch((): void => {});
    if (this.当前断点 === 'xs') {
      this.显示牌组详情 = true;
    }
  }

  private 切换牌组展开(deckId: string): void {
    const next: Set<string> = new Set<string>(this.展开的牌组ID集合);
    if (next.has(deckId)) next.delete(deckId); else next.add(deckId);
    this.展开的牌组ID集合 = next;
    this.牌组数据源.replaceAll(可见牌组行(this.主页快照数据.decks, this.展开的牌组ID集合, this.隐藏的牌组ID集合));
  }

  private 递归切换牌组(deckId: string): void {
    const isExpanded: boolean = this.展开的牌组ID集合.has(deckId);
    const next: Set<string> = new Set<string>(this.展开的牌组ID集合);
    for (const deck of this.主页快照数据.decks) {
      if (deck.id === deckId || deck.ancestorIds.includes(deckId)) {
        if (deck.hasChildren) {
          if (isExpanded) {
            next.delete(deck.id);
          } else {
            next.add(deck.id);
          }
        }
      }
    }
    this.展开的牌组ID集合 = next;
    this.牌组数据源.replaceAll(可见牌组行(this.主页快照数据.decks, this.展开的牌组ID集合, this.隐藏的牌组ID集合));
  }

  private async 更改牌组色调(deckId: string, tone: 牌组色调): Promise<void> {
    await 保存牌组色调(deckId, tone);
    const oldDecks: 牌组汇总[] = this.主页快照数据.decks;
    const newDecks: 牌组汇总[] = oldDecks.map((deck: 牌组汇总): 牌组汇总 => {
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
    this.主页快照数据 = {
      today: this.主页快照数据.today,
      decks: newDecks,
      reviewCountsByDate: this.主页快照数据.reviewCountsByDate,
      memory: this.主页快照数据.memory
    };
    this.牌组数据源.replaceAll(可见牌组行(newDecks, this.展开的牌组ID集合));
  }

  private 打开牌组定制(deckId: string): void {
    const deck: 牌组汇总 = this.按ID查牌组(deckId);
    if (deck.id === '') {
      return;
    }
    this.定制牌组ID = deckId;
    this.定制牌组错误 = '';
    this.显示牌组定制 = true;
  }

  private 请求删除牌组(deckId: string): void {
    const deck: 牌组汇总 = this.按ID查牌组(deckId);
    if (deck.id === '') {
      return;
    }
    const displayName: string = 牌组显示名(deck);
    const title: string = this.getUIContext().getHostContext()!.resourceManager.getStringSync(
      $r('app.string.deck_delete_confirm_title').id).replace('%s', displayName);
    const message: string = this.getUIContext().getHostContext()!.resourceManager.getStringSync(
      $r('app.string.deck_delete_confirm_message').id);
    this.getUIContext().showAlertDialog({
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
          this.确认删除牌组(deckId);
        }
      }
    });
  }

  private async 确认删除牌组(deckId: string): Promise<void> {
    try {
      const count: number = await this.牌组服务实例.删除牌组([Number(deckId)]);
      if (this.选中的牌组ID === deckId) {
        this.选中的牌组ID = '';
        await 清除上次牌组ID();
      }
      await this.加载主页数据();
      const successMsg: string = this.getUIContext().getHostContext()!.resourceManager.getStringSync(
        $r('app.string.deck_delete_success').id).replace('%d', count.toString());
      this.getUIContext().getPromptAction().showToast({ message: successMsg });
    } catch (error) {
      const reason: string = error instanceof Error ? error.message : `${error}`;
      const failMsg: string = this.getUIContext().getHostContext()!.resourceManager.getStringSync(
        $r('app.string.deck_delete_failed').id).replace('%s', reason);
      this.getUIContext().getPromptAction().showToast({ message: failMsg });
    }
  }

  private async 隐藏牌组(deckId: string): Promise<void> {
    try {
      await 隐藏牌组(deckId);
      if (this.选中的牌组ID === deckId) {
        this.选中的牌组ID = '';
        await 清除上次牌组ID();
      }
      const next: Set<string> = new Set<string>(this.隐藏的牌组ID集合);
      next.add(deckId);
      this.隐藏的牌组ID集合 = next;
      this.牌组数据源.replaceAll(可见牌组行(this.主页快照数据.decks, this.展开的牌组ID集合, this.隐藏的牌组ID集合));
      this.getUIContext().getPromptAction().showToast({
        message: this.getUIContext().getHostContext()!.resourceManager.getStringSync($r('app.string.deck_hide_success').id)
      });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({
        message: this.getUIContext().getHostContext()!.resourceManager.getStringSync($r('app.string.deck_hide_failed').id)
      });
    }
  }

  private 显示隐藏牌组对话框(): void {
    const count: number = this.隐藏的牌组ID集合.size;
    if (count === 0) {
      this.getUIContext().getPromptAction().showToast({
        message: this.getUIContext().getHostContext()!.resourceManager.getStringSync($r('app.string.hidden_decks_empty').id)
      });
      return;
    }
    const title: string = this.getUIContext().getHostContext()!.resourceManager.getStringSync($r('app.string.hidden_decks_title').id);
    const message: string = `${count}`;
    this.getUIContext().showAlertDialog({
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
          this.确认全部取消隐藏();
        }
      }
    });
  }

  private async 确认全部取消隐藏(): Promise<void> {
    try {
      await 取消隐藏全部牌组();
      this.隐藏的牌组ID集合 = new Set<string>();
      this.牌组数据源.replaceAll(可见牌组行(this.主页快照数据.decks, this.展开的牌组ID集合, this.隐藏的牌组ID集合));
    } catch (error) {
    }
  }

  private async 应用牌组定制(result: 牌组定制结果): Promise<void> {
    if (this.定制牌组中) return;
    const trimmedName: string = result.新名.trim();
    if (trimmedName === '') {
      this.定制牌组错误 = this.getUIContext().getHostContext()!.resourceManager.getStringSync(
        $r('app.string.deck_customize_name_empty').id);
      return;
    }
    const deckId: string = this.定制牌组ID;
    const deck: 牌组汇总 = this.按ID查牌组(deckId);
    this.定制牌组中 = true;
    this.定制牌组错误 = '';
    try {
      const effectiveName: string = trimmedName === deck.name ? '' : trimmedName;
      if (effectiveName !== deck.displayName) {
        await 保存牌组别名(deckId, effectiveName);
      }

      if (result.背景动作 === 'remove') {
        await 清除牌组背景图(deckId);
      } else if (result.背景动作 === 'replace'
        && result.背景像素图 !== null) {
        try {
          await 保存牌组背景图(deckId, result.背景像素图);
        } catch (saveError) {
          this.定制牌组错误 = this.getUIContext().getHostContext()!.resourceManager.getStringSync(
            $r('app.string.deck_customize_background_save_failed').id);
          this.定制牌组中 = false;
          return;
        }
      }

      this.显示牌组定制 = false;
      await this.加载主页数据();
      this.显示提示($r('app.string.deck_customize_save_done'));
    } catch (error) {
      this.定制牌组错误 = error instanceof Error ? error.message : `${error}`;
      if (this.定制牌组错误 === '') {
        this.定制牌组错误 = this.getUIContext().getHostContext()!.resourceManager.getStringSync(
          $r('app.string.deck_customize_rename_failed').id);
      }
    } finally {
      this.定制牌组中 = false;
    }
  }

  private async 从选择器导入牌组(): Promise<void> {
    if (this.数据迁移中) return;
    const context: common.UIAbilityContext | null = this.取能力上下文();
    if (context === null) return;
    const uri: string | null = await 选取数据文件(context, ['.apkg']);
    if (uri === null) return;
    if (!this.显示数据迁移) {
      this.打开数据迁移('importDeck', 0, false);
    }
    this.数据迁移中 = true;
    this.数据迁移错误 = '';
    this.数据迁移阶段 = 0;
    try {
      await 后端会话.获取实例().确保已打开(context.filesDir);
      const stagedPath: string = 暂存导入文件(context.filesDir, uri);
      this.数据迁移阶段 = 1;
      await 执行牌组导入(stagedPath);
      this.数据迁移阶段 = 2;
      const oldDeckIds: Set<string> = new Set(this.主页快照数据.decks.map((d: 牌组汇总): string => d.id));
      await this.加载主页数据();
      const nextExpanded: Set<string> = new Set(this.展开的牌组ID集合);
      for (const deck of this.主页快照数据.decks) {
        if (deck.hasChildren && !oldDeckIds.has(deck.id)) {
          nextExpanded.add(deck.id);
        }
      }
      if (nextExpanded.size > this.展开的牌组ID集合.size) {
        this.展开的牌组ID集合 = nextExpanded;
        this.牌组数据源.replaceAll(可见牌组行(this.主页快照数据.decks, this.展开的牌组ID集合, this.隐藏的牌组ID集合));
      }
      this.显示提示($r('app.string.transfer_done'));
      this.显示数据迁移 = false;
      this.个人数据替换步骤 = 0;
    } catch (error) {
      const failureDetail: string = error instanceof Error ? error.message : `${error}`;
      this.打开数据迁移('importDeck', 0, false);
      this.数据迁移错误 = failureDetail;
      this.显示提示($r('app.string.transfer_failed'));
    } finally {
      this.数据迁移中 = false;
      this.数据迁移阶段 = -1;
    }
  }

  private async 确认个人数据替换(): Promise<void> {
    if (this.数据迁移中) return;
    if (this.个人数据替换步骤 === 0) {
      this.个人数据替换步骤 = 1;
      return;
    }
    const context: common.UIAbilityContext | null = this.取能力上下文();
    if (context === null) return;
    const uri: string | null = await 选取数据文件(context, ['.colpkg']);
    if (uri === null) return;
    this.数据迁移中 = true;
    this.数据迁移错误 = '';
    try {
      await 替换集合(context.filesDir, uri, true, (stage: number) => { this.数据迁移阶段 = stage; });
      this.数据迁移阶段 = 4;
      await this.加载主页数据();
      this.个人数据替换步骤 = 0;
      this.显示提示($r('app.string.transfer_done'));
      this.显示数据迁移 = false;
    } catch (error) {
      this.数据迁移错误 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.数据迁移中 = false;
      this.数据迁移阶段 = -1;
    }
  }

  private 添加笔记的牌组选项(): 添加笔记牌组选项[] {
    return this.主页快照数据.decks.map((deck: 牌组汇总): 添加笔记牌组选项 => ({ id: Number(deck.id), name: deck.fullName }));
  }

  private 导出牌组选项列表(): 导出牌组选项[] {
    return this.主页快照数据.decks.map((deck: 牌组汇总): 导出牌组选项 => ({
      id: Number(deck.id), name: deck.fullName
    }));
  }

  private 打开数据迁移(mode: 数据迁移模式, deckId: number, allowDeckSelection: boolean): void {
    this.数据迁移初始模式 = mode;
    this.数据迁移初始牌组ID = deckId;
    this.数据迁移允许选牌组 = allowDeckSelection;
    this.数据迁移错误 = '';
    this.个人数据替换步骤 = 0;
    this.显示数据迁移 = true;
  }

  private 打开添加笔记(): void {
    if (!this.已选中牌组()) {
      return;
    }
    const params: 添加笔记页参数 = {
      deckId: this.选中的牌组ID,
      deckName: 牌组显示名(this.选中牌组()),
      deckOptions: this.添加笔记的牌组选项()
    };
    this.页面栈.pushPath({
      name: 'AddNotePage',
      param: params,
      onPop: (): void => {
        this.加载主页数据();
      }
    });
  }

  private async 处理数据迁移(intent: 数据迁移意图): Promise<void> {
    if (this.数据迁移中) return;
    if (intent.kind === 'importDeck') {
      await this.从选择器导入牌组();
      return;
    }
    if (intent.kind === 'replacePersonalData') {
      await this.确认个人数据替换();
      return;
    }
    const context: common.UIAbilityContext | null = this.取能力上下文();
    if (context === null) return;
    this.数据迁移中 = true;
    this.数据迁移错误 = '';
    this.数据迁移阶段 = 0;
    try {
      const path: string = intent.kind === 'exportDeck'
        ? await 导出牌组(context.filesDir, intent.deckId, intent.options)
        : await 导出集合(context.filesDir, intent.options);
      this.数据迁移阶段 = 1;
      const extension: string = intent.kind === 'exportDeck' ? '.apkg' : '.colpkg';
      const fileName: string = intent.kind === 'exportDeck' ? 'jidecards-deck.apkg' : 'jidecards-data.colpkg';
      const savedPath: string | null = await 完成导出(context, path, fileName, extension);
      if (savedPath !== null) {
        this.显示提示($r('app.string.transfer_done'));
        this.显示数据迁移 = false;
        this.个人数据替换步骤 = 0;
      }
    } catch (error) {
      this.数据迁移错误 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.数据迁移中 = false;
      this.数据迁移阶段 = -1;
    }
  }

  private async 创建牌组(name: string): Promise<void> {
    if (this.创建牌组中) {
      return;
    }
    this.创建牌组中 = true;
    this.创建牌组错误 = '';
    try {
      const context: common.UIAbilityContext | null = this.取能力上下文();
      if (context === null) {
        throw new Error(this.getUIContext().getHostContext()!.resourceManager.getStringSync(
          $r('app.string.ability_context_unavailable').id));
      }
      await 后端会话.获取实例().确保已打开(context.filesDir);
      const newDeckId: number = await this.牌组服务实例.创建牌组(name);
      this.显示创建牌组 = false;
      this.选中的牌组ID = newDeckId.toString();
      await 保存上次牌组ID(newDeckId.toString());
      await this.加载主页数据();
      this.展开牌组路径(this.选中牌组());
      this.牌组数据源.replaceAll(可见牌组行(this.主页快照数据.decks, this.展开的牌组ID集合, this.隐藏的牌组ID集合));
      this.显示提示($r('app.string.create_deck_done'));
    } catch (error) {
      this.创建牌组错误 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.创建牌组中 = false;
    }
  }

  private async 打开牌组选项(): Promise<void> {
    if (this.牌组选项加载中 || this.牌组选项中 || this.显示牌组选项) {
      return;
    }
    const deck: 牌组汇总 = this.选中牌组();
    const deckId: number = Number(deck.id);
    if (!Number.isFinite(deckId) || deckId <= 0) {
      return;
    }
    this.牌组选项加载中 = true;
    this.牌组选项错误 = '';
    this.牌组选项牌组ID = deckId;
    this.牌组选项牌组名 = 牌组显示名(deck);
    try {
      const view: DeckConfigsForUpdateView = await this.牌组配置服务实例.获取牌组配置编辑视图(deckId);
      const config: DeckConfig | null = this.查找当前配置(view);
      if (config === null || config.config === null) {
        throw new Error('deck config not found');
      }
      this.编辑视图 = view;
      this.编辑配置 = config;
      this.编辑表单 = 牌组配置表单.从配置创建(config.config);
      this.编辑选项 = 牌组选项编辑.从视图创建(view.currentDeck === null ? null : view.currentDeck.limits, view.newCardsIgnoreReviewLimit, view.fsrs, view.applyAllParentLimits, view.fsrsHealthCheck);
      this.显示牌组选项 = true;
    } catch (error) {
      const msg: string = error instanceof Error ? error.message : `${error}`;
      const stack: string = error instanceof Error && error.stack !== undefined ? error.stack : '';
      console.error(`[jidecards] 打开牌组选项 failed: deckId=${deckId} msg=${msg} stack=${stack}`);
      this.牌组选项错误 = msg;
    } finally {
      this.牌组选项加载中 = false;
    }
  }

  private 查找当前配置(view: DeckConfigsForUpdateView): DeckConfig | null {
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

  private 关闭牌组选项(): void {
    this.显示牌组选项 = false;
    this.牌组选项错误 = '';
    this.编辑视图 = null;
    this.编辑配置 = null;
    this.编辑表单 = null;
    this.编辑选项 = null;
  }

  private 牌组选项校验消息(issue: 校验问题): string {
    let resource: Resource = $r('app.string.deck_learn_steps_validation_error');
    switch (issue.消息键) {
      case 'deck_relearn_steps_validation_error': resource = $r('app.string.deck_relearn_steps_validation_error'); break;
      case 'deck_limit_validation_error': resource = $r('app.string.deck_limit_validation_error'); break;
      case 'deck_retention_validation_error': resource = $r('app.string.deck_retention_validation_error'); break;
      case 'deck_nonnegative_validation_error': resource = $r('app.string.deck_nonnegative_validation_error'); break;
      case 'deck_enum_validation_error': resource = $r('app.string.deck_enum_validation_error'); break;
      case 'deck_date_validation_error': resource = $r('app.string.deck_date_validation_error'); break;
      default: resource = $r('app.string.deck_learn_steps_validation_error');
    }
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(resource.id);
  }

  private async 保存牌组选项(form: 牌组配置表单, options: 牌组选项编辑): Promise<void> {
    if (this.牌组选项中) {
      console.warn('[jidecards] 保存牌组选项 被跳过：正在保存中');
      return;
    }
    const view: DeckConfigsForUpdateView | null = this.编辑视图;
    const config: DeckConfig | null = this.编辑配置;
    if (view === null || config === null || config.config === null) {
      console.error('[jidecards] 保存牌组选项 失败：编辑视图或配置为空');
      this.牌组选项错误 = '保存失败：数据未就绪，请关闭后重试';
      return;
    }
    const issues = form.校验();
    if (issues.length > 0 || options.校验().length > 0 || !form.应用到配置(config.config) || !options.应用()) {
      const issue: 校验问题 = issues.length > 0 ? issues[0] : {
        字段键: 'learnSteps', 消息键: 'deck_learn_steps_validation_error'
      };
      this.牌组选项错误 = this.牌组选项校验消息(issue);
      return;
    }
    this.牌组选项中 = true;
    this.牌组选项错误 = '';
    try {
      const edited = options.转换为请求字段();
      const request: UpdateDeckConfigsInput = {
        targetDeckId: this.牌组选项牌组ID,
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
      await this.牌组配置服务实例.更新牌组配置(request);
      this.关闭牌组选项();
      await this.加载主页数据();
    } catch (error) {
      const msg: string = error instanceof Error ? error.message : `${error}`;
      const stack: string = error instanceof Error && error.stack !== undefined ? error.stack : '';
      console.error(`[jidecards] 保存牌组选项 failed: deckId=${this.牌组选项牌组ID} msg=${msg} stack=${stack}`);
      this.牌组选项错误 = msg;
    } finally {
      this.牌组选项中 = false;
    }
  }

  @Builder
  private 页面映射(name: string, param: ESObject) {
    if (name === 'StudyPage') {
      学习页({
        pageDeckId: (param as 学习页参数).deckId ?? '',
        pageDeckName: (param as 学习页参数).deckName ?? '',
        pathStack: this.页面栈
      })
    }
    if (name === 'AddNotePage') {
      添加笔记页({
        pageDeckId: (param as 添加笔记页参数).deckId ?? '',
        pageDeckName: (param as 添加笔记页参数).deckName ?? '',
        pageDeckOptions: (param as 添加笔记页参数).deckOptions ?? [],
        pathStack: this.页面栈
      })
    }
  }

  build() {
    Navigation(this.页面栈) {
      Stack() {
        Column() {
          主页顶部工具栏({
            on设置点击: (): void => {
              this.显示设置 = true;
            },
            on创建牌组点击: (): void => {
              this.显示主页操作 = true;
            },
            主色容器色: this.主色容器色,
            页面底色微染值: this.页面底色微染值,
            动作主色: this.动作主色
          })
          GridRow({
            columns: { xs: 4, sm: 8, md: 12 },
            breakpoints: {
              value: ['600vp', '840vp'],
              reference: BreakpointsReference.WindowSize
            },
            gutter: 0
          }) {
            GridCol({ span: { xs: 4, sm: 5, md: 8 } }) {
              Column({ space: 应用尺寸.间距_12 }) {
                if (this.显示今日进度卡) {
                  主页摘要分页({
                    摘要折叠: this.摘要折叠,
                    onToggleExpand: (): void => {
                      this.摘要折叠 = !this.摘要折叠;
                      保存摘要展开状态(!this.摘要折叠);
                    },
                    主页快照数据: this.主页快照数据,
                    月历: this.月历
                  })
                }
                主页牌组列表({
                  牌组数据源: this.牌组数据源,
                  牌组列表滚动器: this.牌组列表滚动器,
                  展开的牌组ID集合: this.展开的牌组ID集合,
                  选中的牌组ID: this.选中的牌组ID,
                  排序模式中: this.排序模式中,
                  加载状态: this.加载状态,
                  刷新中: this.刷新中,
                  动作主色: this.动作主色,
                  主色按钮背景色: this.主色按钮背景色,
                  onMove: (from: number, to: number): void => {
                    this.处理牌组移动(from, to);
                  },
                  onItemSelect: (deckId: string): void => {
                    this.选择牌组(deckId);
                  },
                  onItemToggle: (deckId: string): void => {
                    this.切换牌组展开(deckId);
                  },
                  onItemToneChange: (deckId: string, tone: 牌组色调): void => {
                    this.更改牌组色调(deckId, tone);
                  },
                  onItemCustomize: (deckId: string): void => {
                    this.打开牌组定制(deckId);
                  },
                  onItemEnterReorder: (deckId: string): void => {
                    this.进入排序模式();
                  },
                  onItemDelete: (deckId: string): void => {
                    this.请求删除牌组(deckId);
                  },
                  onItemHide: (deckId: string): void => {
                    this.隐藏牌组(deckId);
                  },
                  onItemDoubleTap: (deckId: string): void => {
                    this.递归切换牌组(deckId);
                  },
                  onExitReorder: (): void => {
                    this.退出排序模式();
                  },
                  onRefresh: (): void => {
                    this.刷新中 = true;
                    this.加载主页数据();
                  },
                  onRetry: (): void => {
                    this.加载主页数据();
                  }
                })
              }
              .width('100%')
              .height('100%')
              .padding({
                left: 应用尺寸.页面内边距_水平,
                right: 应用尺寸.页面内边距_水平,
                top: 应用尺寸.间距_4,
                bottom: 应用尺寸.页面内边距_水平
              })
              .backgroundColor(this.页面底色微染值)
            }
            if (this.当前断点 !== 'xs') {
              GridCol({ span: { xs: 0, sm: 3, md: 4 } }) {
                牌组详情面板({
                  是否深色: this.是否深色(),
                  牌组选项加载中: this.牌组选项加载中,
                  牌组选项错误: this.牌组选项错误,
                  开始学习: (): void => {
                    this.开始学习();
                  },
                  添加卡片: (): void => { this.打开添加笔记(); },
                  创建子牌组: (): void => {
                    this.创建父牌组ID = this.选中的牌组ID;
                    this.显示创建牌组 = true;
                  },
                  导出牌组: (): void => {
                    this.打开数据迁移('exportDeck', Number(this.选中的牌组ID), false);
                  },
                  打开牌组选项: (): void => {
                    this.打开牌组选项();
                  }
                })
              }
            }
          }
          .layoutWeight(1)
          .onBreakpointChange((breakpoint: string) => {
            this.当前断点 = breakpoint;
            if (!this.上次牌组已恢复 && breakpoint !== 'xs') {
              this.尝试恢复上次牌组();
            }
          })
        }
        .width('100%')
        .constraintSize({ maxWidth: 应用尺寸.内容最大宽度 })
        .height('100%')
        .backgroundColor(this.页面底色微染值)

        if (this.显示设置) {
          设置面板({
            当前主题模式: this.主题模式值,
            是否深色: this.是否深色(),
            当前颜色主题: this.颜色主题值,
            主题模式切换回调: (mode: 主题模式): void => {
              this.切换主题(mode);
            },
            颜色主题切换回调: (theme: 颜色主题): void => {
              this.切换颜色主题(theme);
            },
            打开许可证回调: (): void => {
              this.显示许可证 = true;
            },
            导入数据回调: (): void => {
              this.显示设置 = false;
              this.打开数据迁移('importDeck', 0, true);
            },
            导出数据回调: (): void => {
              this.显示设置 = false;
              this.打开数据迁移('exportDeck', this.已选中牌组() ? Number(this.选中的牌组ID) : 0, true);
            },
            点击已隐藏牌组回调: (): void => {
              this.显示隐藏牌组对话框();
            },
            先备份后同步回调: (): void => {
              this.显示设置 = false;
              this.打开数据迁移('exportPersonalData', 0, false);
            },
            打开同步弹窗回调: (auth: SyncAuth, accountName: string): void => {
              this.同步面板认证 = auth;
              this.同步面板账号名 = accountName;
              this.显示同步面板 = true;
            },
            关闭回调: (): void => {
              this.显示设置 = false;
            }
          })
        }

        if (this.显示同步面板) {
          同步面板({
            是否深色: this.是否深色(),
            账号名: this.同步面板账号名,
            初始鉴权: this.同步面板认证,
            同步完成回调: (): void => {
              this.加载主页数据();
              this.同步后检查FSRS();
            },
            关闭回调: (): void => {
              this.显示同步面板 = false;
              this.同步面板认证 = null;
              this.同步面板账号名 = '';
            }
          })
        }

        if (this.显示许可证) {
          许可证面板({
            isDark: this.是否深色(),
            onClose: (): void => {
              this.显示许可证 = false;
            }
          })
        }

        if (this.显示主页操作) {
          主页操作面板({
            创建牌组回调: (): void => {
              this.显示主页操作 = false;
              this.创建牌组错误 = '';
              this.创建父牌组ID = '';
              this.显示创建牌组 = true;
            },
            导入牌组回调: (): void => {
              this.显示主页操作 = false;
              this.从选择器导入牌组();
            },
            关闭回调: (): void => {
              this.显示主页操作 = false;
            }
          })
        }

        if (this.当前断点 === 'xs' && this.显示牌组详情) {
          Column() {
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
                  this.显示牌组详情 = false;
                  this.加载主页数据();
                })
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

            牌组详情面板({
              是否深色: this.是否深色(),
              牌组选项加载中: this.牌组选项加载中,
              牌组选项错误: this.牌组选项错误,
              开始学习: (): void => {
                this.开始学习();
              },
              添加卡片: (): void => {
                this.打开添加笔记();
              },
              创建子牌组: (): void => {
                this.创建父牌组ID = this.选中的牌组ID;
                this.显示创建牌组 = true;
              },
              导出牌组: (): void => {
                this.打开数据迁移('exportDeck', Number(this.选中的牌组ID), false);
              },
              打开牌组选项: (): void => {
                this.打开牌组选项();
              }
            })
            .layoutWeight(1)
          }
          .width('100%')
          .height('100%')
          .backgroundColor(this.页面底色微染值)
        }

        创建牌组协调器({
          显示: this.显示创建牌组,
          进行中: this.创建牌组中,
          错误: this.创建牌组错误,
          父牌组ID: this.创建父牌组ID,
          牌组选项列表: this.主页快照数据.decks,
          是否深色: this.是否深色(),
          onCancel: (): void => {
            this.显示创建牌组 = false;
          },
          onConfirm: (name: string): void => {
            this.创建牌组(name);
          }
        })

        数据迁移协调器({
          显示: this.显示数据迁移,
          进行中: this.数据迁移中,
          错误: this.数据迁移错误,
          阶段: this.数据迁移阶段,
          个人数据替换步骤: this.个人数据替换步骤,
          初始模式: this.数据迁移初始模式,
          初始牌组ID: this.数据迁移初始牌组ID,
          允许选牌组: this.数据迁移允许选牌组,
          牌组选项列表: this.导出牌组选项列表(),
          是否深色: this.是否深色(),
          onIntent: (intent: 数据迁移意图): void => {
            this.处理数据迁移(intent);
          },
          onClose: (): void => {
            if (!this.数据迁移中) {
              this.显示数据迁移 = false;
              this.个人数据替换步骤 = 0;
            }
          }
        })

        if (this.显示牌组选项 && this.编辑表单 !== null && this.编辑选项 !== null) {
          牌组选项协调器({
            进行中: this.牌组选项中,
            错误: this.牌组选项错误,
            牌组名: this.牌组选项牌组名,
            编辑表单: this.编辑表单,
            编辑选项: this.编辑选项,
            是否深色: this.是否深色(),
            onCancel: (): void => {
              if (!this.牌组选项中) this.关闭牌组选项();
            },
            onSave: (form: 牌组配置表单, options: 牌组选项编辑): void => {
              this.保存牌组选项(form, options);
            }
          })
        }

        if (this.显示牌组定制) {
          牌组定制面板({
            isDark: this.是否深色(),
            deck: this.按ID查牌组(this.定制牌组ID),
            busy: this.定制牌组中,
            errorMessage: this.定制牌组错误,
            onClose: (): void => {
              if (!this.定制牌组中) {
                this.显示牌组定制 = false;
              }
            },
            onSave: (result: 牌组定制结果): void => {
              this.应用牌组定制(result);
            }
          })
        }

        if (this.显示AnkiWeb引导) {
          AnkiWeb引导对话框({
            isDark: this.是否深色(),
            onClose: (): void => {
              this.显示AnkiWeb引导 = false;
            }
          })
        }

        if (this.显示好评引导) {
          好评引导对话框({
            isDark: this.是否深色(),
            onClose: (): void => {
              this.显示好评引导 = false;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.页面底色微染值)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.页面映射)
  }
}
