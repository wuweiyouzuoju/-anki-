// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-PAGE-STATS-001
// @名称 统计页
//
// @作用
// 全库统计图表页（对标 Anki Stats）。展示今日计数、预测、卡片状态分布、
// 小时分布、难度分布、间隔分布、真实保留率、记忆率等完整统计信息。
// 手机端单栏布局：顶部条（返回 + ⚙ 偏好）+ 滚动统计内容。
//
// @输入
// pathStack: Navigation 页面栈，用于返回主页
//
// @输出
// 渲染统计页 NavDestination
//
// @Invariants
// - 统计页注册 CustomTransition（name='StatsPage'），与浏览页同模式实现淡入淡出转场
// - 未注册时首页 .customNavContentTransition 导致 NavDestination 卡在 opacity=0（ArkUI bug）
//
// @Extension Points
// - 图表组件可替换为更丰富的可视化
// - 统计数据范围可扩展（按牌组/按时间）
//
// @副作用
// 通过 统计服务 调用后端 RPC，读取 Anki collection。
// ========================================================

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { 后端会话 } from '../backend/后端会话';
import { 统计服务 } from '../backend/统计服务';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';
import { 解析是否深色, 主题模式 } from '../model/主题设置';
import { 加载主题模式 } from '../model/主题存储';
import { CustomTransition } from '../utils/自定义转场';
import { 按下态按钮 } from '../components/common/按下态按钮';
import { 统计图表分区 } from '../components/stats/统计图表分区';
import { 今日计数卡 } from '../components/stats/今日计数卡';
import { 预测卡 } from '../components/stats/预测卡';
import { 日历卡 } from '../components/stats/日历卡';
import { 复习卡 } from '../components/stats/复习卡';
import { 卡片状态分布 } from '../components/stats/卡片状态分布';
import { 小时分布卡 } from '../components/stats/小时分布卡';
import { 难度分布卡 } from '../components/stats/难度分布卡';
import { 间隔分布卡 } from '../components/stats/间隔分布卡';
import { 稳定度分布卡 } from '../components/stats/稳定度分布卡';
import { 真实保留率卡 } from '../components/stats/真实保留率卡';
import { 记忆率卡 } from '../components/stats/记忆率卡';
import { 回答按钮卡 } from '../components/stats/回答按钮卡';
import { 新增卡 } from '../components/stats/新增卡';
import { 图表偏好面板 } from '../components/stats/图表偏好面板';
import { 字段帮助面板 } from '../components/字段帮助面板';
import { 提取卡片数据, 保存卡片数据, 加载小时分布窗口, 保存小时分布窗口 } from '../model/桌面卡片数据存储';
import { 牌组服务 } from '../backend/牌组服务';
import { 平铺牌组树 } from '../model/牌组层级';
import type { 牌组汇总 } from '../model/主页模型';
import type { DeckTreeNode } from '../proto/messages/DeckMessages';
import type { GraphsView, GraphPreferences } from '../proto/messages/StatsMessages';
import { Weekday } from '../proto/messages/StatsMessages';

/** 统计页阶段状态机：loading=加载中，content=展示数据，error=出错 */
type 统计阶段 = 'loading' | 'content' | 'error';

/** 图表偏好默认值（后端首次无偏好时回退用）。 */
function 默认偏好(): GraphPreferences {
  return {
    calendarFirstDayOfWeek: Weekday.SUNDAY,
    cardCountsSeparateInactive: false,
    browserLinksSupported: false,
    futureDueShowBacklog: false
  };
}

@Component
export struct 统计页 {
  /** 页面栈：返回主页时 pop */
  pathStack: NavPathStack = new NavPathStack();
  private readonly 统计服务实例: 统计服务 = new 统计服务();

  @State private 阶段: 统计阶段 = 'loading';
  @State private 错误详情: string = '';
  @State private 图表数据: GraphsView | null = null;
  @State private 图表偏好: GraphPreferences = 默认偏好();
  @State private 统计天数: number = 365;
  // 牌组选择（顶部条内嵌下拉）：索引 0 = 全部牌组（搜索串空），>0 对应 牌组名列表[索引-1]
  @State private 牌组选项: SelectOption[] = [];
  @State private 选中牌组索引: number = 0;
  private 牌组名列表: string[] = [];
  // 小时分布时间段（0=近1月 1=近3月 2=近1年 3=全部）：与首页卡片/桌面卡片共用同一偏好
  @State private 小时分布窗口: number = 0;
  @State private 显示偏好面板: boolean = false;
  // 分区帮助浮层：点击各分区 i 时由 onHelp 回调设置标题/正文，页面级 Stack 统一弹字段帮助面板
  @State private 显示分区帮助: boolean = false;
  @State private 分区帮助标题: Resource = $r('app.string.stats_no_data');
  @State private 分区帮助正文: Resource = $r('app.string.stats_no_data');
  /** NavDestination 透明度（由 customNavContentTransition 回调控制，实现淡入淡出转场）。 */
  @State private 转场透明度: number = 1;

  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';
  @StorageProp(颜色键.页面底色微染) private 页面底色微染值: string = '#F5F7FA';
  @StorageProp('状态栏高度') private 状态栏高度: number = 0;
  // 手势导航条高度（统计内容滚到底时需完整滚出导航条区域）
  @StorageProp('导航条高度') private 导航条高度: number = 0;
  @StorageLink('systemDarkMode') private 系统暗黑模式: boolean = false;
  @State private 主题模式值: 主题模式 = 'system';

  /** 是否深色（与浏览页同款：解析主题模式 + 系统暗黑模式） */
  private 是否深色(): boolean {
    return 解析是否深色(this.主题模式值, this.系统暗黑模式);
  }

  async aboutToAppear(): Promise<void> {
    // 注册自定义转场回调：首页 Navigation.customNavContentTransition 通过此 name 查找回调，
    // 在 animateTo 内调用起点/终点回调修改 转场透明度，实现淡入淡出（替代系统默认左右平移）。
    // key 用 'StatsPage'（NavPathStack pushPath 时传的 name，与 from.name / to.name 一致）。
    CustomTransition.getInstance().注册NavParam('StatsPage',
      (isPush: boolean, isExit: boolean): void => {
        this.转场透明度 = isExit ? 1 : 0;
      },
      (isPush: boolean, isExit: boolean): void => {
        this.转场透明度 = isExit ? 0 : 1;
      }
    );
    // 恢复主题模式（与浏览页同款，供 是否深色() 判断）
    this.主题模式值 = await 加载主题模式();
    // 恢复小时分布窗口选择（首页卡片/桌面卡片跟随同一偏好）
    this.小时分布窗口 = await 加载小时分布窗口();
    this.加载牌组列表();
    await this.加载统计数据();
  }

  /** 顶部条牌组下拉选项：全部牌组 + 全库牌组全名（平铺牌组树前序） */
  private 加载牌组列表(): void {
    const 牌组服务实例 = new 牌组服务();
    牌组服务实例.获取牌组树().then((tree: DeckTreeNode) => {
      const 名列表: string[] = [];
      平铺牌组树(tree).forEach((行: 牌组汇总) => {
        名列表.push(行.fullName);
      });
      this.牌组名列表 = 名列表;
      const 选项: SelectOption[] = [];
      选项.push({ value: $r('app.string.stats_deck_all') } as SelectOption);
      for (let i = 0; i < 名列表.length; i++) {
        选项.push({ value: 名列表[i] } as SelectOption);
      }
      this.牌组选项 = 选项;
    }).catch((_错误: Object): void => {
      // 牌组列表加载失败时仅保留"全部牌组"，不阻塞统计
    });
  }

  /** 当前统计搜索串：全部牌组 = 空串（全库）；选中牌组 = deck:"全名" */
  private 取搜索串(): string {
    if (this.选中牌组索引 <= 0 || this.选中牌组索引 > this.牌组名列表.length) {
      return '';
    }
    const 名: string = this.牌组名列表[this.选中牌组索引 - 1];
    return `deck:"${名}"`;
  }

  /** 牌组下拉切换：重选牌组后重新加载统计 */
  private on牌组切换(索引: number): void {
    if (索引 === this.选中牌组索引) {
      return;
    }
    this.选中牌组索引 = 索引;
    this.加载统计数据();
  }

  /** 预测卡积压复选框切换：即时写偏好并本地生效（Anki autoSavingPrefs 行为） */
  private on积压变更(值: boolean): void {
    const 新偏好: GraphPreferences = {
      calendarFirstDayOfWeek: this.图表偏好.calendarFirstDayOfWeek,
      cardCountsSeparateInactive: this.图表偏好.cardCountsSeparateInactive,
      browserLinksSupported: this.图表偏好.browserLinksSupported,
      futureDueShowBacklog: 值
    };
    this.图表偏好 = 新偏好;
    this.统计服务实例.设置图表偏好(新偏好).catch((_错误: Object): void => {
      // 写偏好失败不阻塞展示，下次打开回读旧值
    });
  }

  /**
   * 系统返回键 / 屏幕边缘滑动返回：偏好面板打开时优先关闭，否则走 NavPathStack 默认 pop。
   * Invariants: 仅当 显示偏好面板=true 时消费返回手势关面板；否则 return false。
   */
  onBackPress(): boolean {
    if (this.显示偏好面板) { this.显示偏好面板 = false; return true; }
    return false;
  }

  private 取能力上下文(): common.UIAbilityContext | null {
    const context: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return context === undefined ? null : context;
  }

  /**
   * 用当前 图表数据 + 小时分布窗口 提取卡片数据并保存推送。
   * 拉牌组树算待学数/牌组数，供桌面卡片今日进度页（失败时传0，桌面卡片显示"-"）。
   */
  private async 刷新卡片快照(): Promise<void> {
    const 图表: GraphsView | null = this.图表数据;
    if (图表 === null) {
      return;
    }
    try {
      const 牌组服务实例 = new 牌组服务();
      const tree: DeckTreeNode = await 牌组服务实例.获取牌组树();
      let 总待学: number = 0;
      for (const 子节点 of tree.children) {
        总待学 += 子节点.newCount + 子节点.learnCount + 子节点.reviewCount;
      }
      const 牌组总数: number = 平铺牌组树(tree).length;
      保存卡片数据(提取卡片数据(图表, 总待学, 牌组总数, this.小时分布窗口)).catch((e: Object): void => {
        hilog.error(0xFFFE, '统计页', `保存卡片数据失败 ${e}`);
      });
    } catch (_牌组错误) {
      保存卡片数据(提取卡片数据(图表, 0, 0, this.小时分布窗口)).catch((e: Object): void => {
        hilog.error(0xFFFE, '统计页', `保存卡片数据失败 ${e}`);
      });
    }
  }

  private async 加载统计数据(): Promise<void> {
    this.阶段 = 'loading';
    try {
      const context: common.UIAbilityContext | null = this.取能力上下文();
      if (context === null) {
        this.阶段 = 'error';
        this.错误详情 = '能力上下文不可用';
        return;
      }
      await 后端会话.获取实例().确保已打开(context.filesDir);
      // 图表统计是主数据，偏好加载失败不阻塞（回退默认值）。
      // 搜索串为空 = 全库统计；选中牌组时传 deck:"全名"（后端 graph_data_for_search 牌组分支）
      const 图表: GraphsView = await this.统计服务实例.获取图表统计(this.统计天数, this.取搜索串());
      this.图表数据 = 图表;
      try {
        this.图表偏好 = await this.统计服务实例.获取图表偏好();
      } catch (_偏好错误) {
        this.图表偏好 = 默认偏好();
      }
      this.阶段 = 'content';
      // 顺带刷新桌面卡片数据（仅全库口径；选中单牌组时不覆盖首页/桌面卡片）：
      // 用户进入统计页时把最新 GraphsView 推送到桌面卡片，
      // 避免桌面卡片长期显示旧数据（FSRS 切换、复习后未回首页等场景）。
      if (this.取搜索串() === '') {
        await this.刷新卡片快照();
      }
    } catch (error) {
      this.阶段 = 'error';
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
      hilog.error(0xFFFE, '统计页', `加载失败: ${this.错误详情}`);
    }
  }

  /** 偏好面板保存回调：写后端 + 重新加载图表。 */
  private async 保存偏好(偏好: GraphPreferences, 天数: number): Promise<void> {
    try {
      await this.统计服务实例.设置图表偏好(偏好);
      this.图表偏好 = 偏好;
      this.统计天数 = 天数;
      this.显示偏好面板 = false;
      await this.加载统计数据();
    } catch (error) {
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
      hilog.error(0xFFFE, '统计页', `保存偏好后加载失败: ${this.错误详情}`);
    }
  }

  /** 返回主页。 */
  private 返回(): void {
    this.pathStack.pop();
  }

  /**
   * 分区/偏好面板帮助回调：统一由本页页面级 Stack 渲染字段帮助面板。
   * Invariants:
   * - 字段帮助面板必须在本页 build() Stack 顶层渲染，避免嵌套层级导致遮罩
   *   expandSafeArea 失效（曾出现：嵌套在图表偏好面板内时遮罩仅覆盖安全区内局部，
   *   浮层居中在遮罩中而非屏幕中央）
   * - 任何子组件（统计图表分区 / 图表偏好面板）的 ⓘ 按钮均通过此回调上抛，
   *   不在子组件内部渲染字段帮助面板
   */
  private on分区帮助(标题: Resource, 正文: Resource): void {
    this.分区帮助标题 = 标题;
    this.分区帮助正文 = 正文;
    this.显示分区帮助 = true;
  }

  @Builder
  private 顶部条() {
    // 与浏览页顶部条同款：左返回 + 右图表偏好 用按下态按钮（胶囊样式 + 淡色边框）。
    // 中间为牌组选择下拉（对齐 Anki RangeBox 的牌组选择；索引 0=全部牌组）；
    // 牌组列表未加载完成 / 仅全库无牌组时回退显示「统计」标题。
    // Invariants:
    // - 标题 Text（铺满宽度）必须声明在 Row 之前的下层，避免盖住左右按钮点击
    // - Select 声明在 Row 之后的上层（Stack 后声明者在上），限宽 50% 居中不挡左右按钮
    Stack() {
      if (this.牌组选项.length <= 1) {
        Text($r('app.string.stats_page_title'))
          .fontSize(应用尺寸.字号_面板标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      Row() {
        按下态按钮({
          文案: $r('app.string.study_back'),
          选中态背景: this.主色容器色,
          字色: $r('app.color.text_primary'),
          点击回调: (): void => this.返回()
        })

        Blank()

        按下态按钮({
          文案: $r('app.string.stats_prefs_title'),
          选中态背景: this.主色容器色,
          字色: $r('app.color.text_primary'),
          点击回调: (): void => { this.显示偏好面板 = true; }
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)

      if (this.牌组选项.length > 1) {
        Select(this.牌组选项)
          .selected(this.选中牌组索引)
          .value(this.选中牌组索引 === 0
            ? (this.牌组选项[0].value as ResourceStr)
            : (this.牌组选项[this.选中牌组索引].value as ResourceStr))
          .fontColor($r('app.color.text_primary'))
          .font({ size: 应用尺寸.字号_正文_小 })
          .selectedOptionFontColor($r('app.color.text_primary'))
          .optionFontColor($r('app.color.text_primary'))
          .backgroundColor(this.主色容器色)
          .borderRadius(应用尺寸.圆角_进度条)
          .constraintSize({ maxWidth: '50%' })
          .onSelect((索引: number) => {
            this.on牌组切换(索引);
          })
      }
    }
    .width('100%')
    .height(应用尺寸.工具栏高度 + this.状态栏高度)
    .alignContent(Alignment.Center)
    .padding({
      left: 应用尺寸.页面内边距_水平,
      right: 应用尺寸.页面内边距_水平,
      top: this.状态栏高度 + 应用尺寸.间距_8,
      bottom: 应用尺寸.间距_8
    })
    .backgroundColor(this.页面底色微染值)
  }

  @Builder
  private 统计内容() {
    Scroll() {
      Column({ space: 应用尺寸.间距_12 }) {
        // FSRS 标志
        if (this.图表数据 !== null) {
          Text(this.图表数据.fsrs ? $r('app.string.stats_fsrs_enabled') : $r('app.string.stats_fsrs_disabled'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .padding({
              left: 应用尺寸.间距_8, right: 应用尺寸.间距_8,
              top: 应用尺寸.间距_4, bottom: 应用尺寸.间距_4
            })
            .backgroundColor(this.主色容器色)
            .borderRadius(应用尺寸.间距_8)
        }

        // 1. 今日计数（Anki TodayStats）
        统计图表分区({
          标题: $r('app.string.stats_section_today'),
          有数据: this.图表数据 !== null && this.图表数据.today !== null,
          帮助标题: $r('app.string.stats_section_today'),
          帮助正文: $r('app.string.stats_help_today'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          今日计数卡({
            今日数据: this.图表数据 !== null ? this.图表数据.today : null
          })
        }

        // 2. 预测（Anki FutureDue）
        统计图表分区({
          标题: $r('app.string.stats_section_forecast'),
          有数据: this.图表数据 !== null && this.图表数据.futureDue !== null,
          帮助标题: $r('app.string.stats_section_forecast'),
          帮助正文: $r('app.string.stats_help_forecast'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          预测卡({
            预测数据: this.图表数据 !== null ? this.图表数据.futureDue : null,
            显示积压: this.图表偏好.futureDueShowBacklog,
            是否显示全部: this.统计天数 === 0,
            on积压变更: (值: boolean): void => {
              this.on积压变更(值);
            }
          })
        }

        // 3. 日历（Anki CalendarGraph，年历热力图）
        统计图表分区({
          标题: $r('app.string.stats_section_calendar'),
          有数据: this.图表数据 !== null && this.图表数据.reviewCountsByDaysAgo !== null,
          帮助标题: $r('app.string.stats_section_calendar'),
          帮助正文: $r('app.string.stats_help_calendar'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          日历卡({
            复习计数: this.图表数据 !== null ? this.图表数据.reviewCountsByDaysAgo : null,
            日切小时: this.图表数据 !== null ? this.图表数据.rolloverHour : 0,
            周首日: this.图表偏好.calendarFirstDayOfWeek,
            统计天数: this.统计天数,
            是否深色: this.是否深色()
          })
        }

        // 4. 复习（Anki ReviewsGraph，5 系列堆叠柱）
        统计图表分区({
          标题: $r('app.string.stats_section_reviews'),
          有数据: this.图表数据 !== null && this.图表数据.reviewCountsByDaysAgo !== null,
          帮助标题: $r('app.string.stats_section_reviews'),
          帮助正文: $r('app.string.stats_help_reviews'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          复习卡({
            复习计数: this.图表数据 !== null ? this.图表数据.reviewCountsByDaysAgo : null,
            复习时间: this.图表数据 !== null ? this.图表数据.reviewTimesByDaysAgo : null,
            是否显示全部: this.统计天数 === 0
          })
        }

        // 5. 卡片数量（Anki CardCounts）
        统计图表分区({
          标题: $r('app.string.stats_section_card_counts'),
          有数据: this.图表数据 !== null && this.图表数据.cardCounts !== null,
          帮助标题: $r('app.string.stats_section_card_counts'),
          帮助正文: $r('app.string.stats_help_card_counts'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          卡片状态分布({
            卡片计数: this.图表数据 !== null ? this.图表数据.cardCounts : null,
            分离暂停: this.图表偏好.cardCountsSeparateInactive
          })
        }

        // 6. 间隔分布（Anki IntervalsGraph）
        统计图表分区({
          标题: $r('app.string.stats_section_interval'),
          有数据: this.图表数据 !== null && this.图表数据.intervals !== null,
          帮助标题: $r('app.string.stats_section_interval'),
          帮助正文: $r('app.string.stats_help_interval'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          间隔分布卡({
            间隔数据: this.图表数据 !== null ? this.图表数据.intervals : null
          })
        }

        // 7. 稳定度分布（Anki StabilityGraph，仅 FSRS）
        if (this.图表数据 !== null && this.图表数据.fsrs) {
          统计图表分区({
            标题: $r('app.string.stats_section_stability'),
            有数据: this.图表数据.stability !== null,
            帮助标题: $r('app.string.stats_section_stability'),
            帮助正文: $r('app.string.stats_help_stability'),
            onHelp: this.on分区帮助.bind(this)
          }) {
            稳定度分布卡({
              稳定度数据: this.图表数据.stability
            })
          }
        }

        // 8. 难度分布（Anki EaseGraph/DifficultyGraph 互斥合一：FSRS→difficulty，SM-2→eases）
        统计图表分区({
          标题: this.图表数据 !== null && this.图表数据.fsrs
            ? $r('app.string.stats_section_ease')
            : $r('app.string.stats_section_ease_sm2'),
          有数据: this.图表数据 !== null
            && (this.图表数据.eases !== null || this.图表数据.difficulty !== null),
          帮助标题: $r('app.string.stats_section_ease'),
          帮助正文: $r('app.string.stats_help_ease'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          难度分布卡({
            难度数据: this.图表数据 !== null ? this.图表数据.eases : null,
            FSRS难度: this.图表数据 !== null ? this.图表数据.difficulty : null,
            是否FSRS: this.图表数据 !== null ? this.图表数据.fsrs : false
          })
        }

        // 9. 记忆率（Anki RetrievabilityGraph，仅 FSRS）
        if (this.图表数据 !== null && this.图表数据.fsrs) {
          统计图表分区({
            标题: $r('app.string.stats_section_retrievability'),
            有数据: this.图表数据.retrievability !== null,
            帮助标题: $r('app.string.stats_section_retrievability'),
            帮助正文: $r('app.string.stats_help_retrievability'),
            onHelp: this.on分区帮助.bind(this)
          }) {
            记忆率卡({
              记忆率数据: this.图表数据.retrievability
            })
          }
        }

        // 10. 真实保留率（Anki TrueRetention）
        统计图表分区({
          标题: $r('app.string.stats_section_retention'),
          有数据: this.图表数据 !== null && this.图表数据.trueRetention !== null,
          帮助标题: $r('app.string.stats_section_retention'),
          帮助正文: $r('app.string.stats_help_retention'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          真实保留率卡({
            保留率数据: this.图表数据 !== null ? this.图表数据.trueRetention : null,
            是否显示全部: this.统计天数 === 0
          })
        }

        // 11. 小时分布（Anki HourGraph）
        统计图表分区({
          标题: $r('app.string.stats_section_hours'),
          有数据: this.图表数据 !== null && this.图表数据.hours !== null,
          帮助标题: $r('app.string.stats_section_hours'),
          帮助正文: $r('app.string.stats_help_hours'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          小时分布卡({
            小时数据: this.图表数据 !== null ? this.图表数据.hours : null,
            时间段索引: this.小时分布窗口,
            是否深色: this.是否深色(),
            onRangeChange: (索引: number): void => {
              this.小时分布窗口 = 索引;
              保存小时分布窗口(索引).catch((): void => {});
              // 切换窗口后立即把对应窗口数据推送到首页/桌面卡片
              this.刷新卡片快照();
            }
          })
        }

        // 12. 回答按钮（Anki ButtonsGraph）
        统计图表分区({
          标题: $r('app.string.stats_section_buttons'),
          有数据: this.图表数据 !== null && this.图表数据.buttons !== null,
          帮助标题: $r('app.string.stats_section_buttons'),
          帮助正文: $r('app.string.stats_help_buttons'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          回答按钮卡({
            按钮数据: this.图表数据 !== null ? this.图表数据.buttons : null,
            是否显示全部: this.统计天数 === 0
          })
        }

        // 13. 新增（Anki AddedGraph）
        统计图表分区({
          标题: $r('app.string.stats_section_added'),
          有数据: this.图表数据 !== null && this.图表数据.added !== null,
          帮助标题: $r('app.string.stats_section_added'),
          帮助正文: $r('app.string.stats_help_added'),
          onHelp: this.on分区帮助.bind(this)
        }) {
          新增卡({
            新增数据: this.图表数据 !== null ? this.图表数据.added : null,
            是否显示全部: this.统计天数 === 0
          })
        }
      }
      .width('100%')
      .padding({
        left: 应用尺寸.间距_16,
        right: 应用尺寸.间距_16,
        top: 应用尺寸.间距_12,
        // 抬高避让手势导航条（AppGallery 导航栏适配要求）
        bottom: 应用尺寸.间距_12 + this.导航条高度
      })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          this.顶部条()

          if (this.阶段 === 'loading' && this.图表数据 === null) {
            Text($r('app.string.stats_loading'))
              .fontSize(应用尺寸.字号_正文)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(40)
          }

          if (this.阶段 === 'error') {
            Text(this.错误详情)
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor($r('app.color.error_text'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(40)
          }

          // 切换牌组重载时保留旧图表（Anki 数据不闪空行为）
          if (this.阶段 === 'content' || (this.阶段 === 'loading' && this.图表数据 !== null)) {
            this.统计内容()
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.页面底色微染值)

        // 偏好面板浮层
        if (this.显示偏好面板) {
          图表偏好面板({
            偏好: this.图表偏好,
            统计天数: this.统计天数,
            是否深色: this.是否深色(),
            onClose: (): void => { this.显示偏好面板 = false; },
            onSaved: (偏好: GraphPreferences, 天数: number): void => {
              this.保存偏好(偏好, 天数);
            },
            onHelp: this.on分区帮助.bind(this)
          })
        }

        // 页面级字段帮助浮层：所有子组件（统计图表分区 / 图表偏好面板）的 ⓘ
        // 按钮均通过 onHelp 回调上抛，由本页 Stack 顶层统一渲染。
        // Invariants: 必须在 NavDestination 直接子 Stack 顶层渲染，避免嵌套层级
        // 导致遮罩 expandSafeArea 失效（遮罩仅覆盖局部 + 浮层居中在遮罩中而非屏幕中央）。
        if (this.显示分区帮助) {
          字段帮助面板({
            标题: this.分区帮助标题,
            正文: this.分区帮助正文,
            是否深色: this.是否深色(),
            onClose: (): void => {
              this.显示分区帮助 = false;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .opacity(this.转场透明度)
  }
}

/** 统计页入栈参数（目前无参数，保留接口供未来扩展按牌组统计） */
export interface 统计页参数 {}
