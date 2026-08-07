// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-STATS-PREFS-001
// @名称 图表偏好面板
//
// @作用
// 统计页 ⚙ 按钮弹出的偏好面板。支持：
// - 统计天数（30/90/365/全部）—— 本地存储，不走后端
// - 周首日（周日/周一/周五/周六）—— 走 GraphPreferences
// - 卡片计数分离暂停 —— 走 GraphPreferences
// - 预测显示积压 —— 走 GraphPreferences
//
// @输入
// @Prop 偏好: GraphPreferences —— 当前后端偏好
// @Prop 统计天数: number —— 当地统计天数
// onClose: () => void —— 关闭面板
// onSaved: (偏好, 天数) => void —— 保存回调（父级负责调后端 + 刷新）
//
// @输出
// 渲染偏好面板浮层
//
// @业务规则
// 保存时先更新本地副本，再上抛 onSaved 让父级落盘。
// 取消时不修改任何状态。
//
// @副作用
// 无（纯展示层，保存由父级处理）。
// ========================================================

import { common } from '@kit.AbilityKit';
import type { GraphPreferences } from '../../proto/messages/StatsMessages';
import { Weekday } from '../../proto/messages/StatsMessages';
import { 统计服务 } from '../../backend/统计服务';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 取全屏转场时长, 取全屏转场曲线 } from '../../utils/转场时长';
import { 颜色键 } from '../../model/颜色主题';
import { curves } from '@kit.ArkUI';

interface 天数选项 {
  标签: Resource;
  值: number;
}

interface 周首日选项 {
  标签: string;
  值: Weekday;
}

@Component
export struct 图表偏好面板 {
  @Prop 偏好: GraphPreferences;
  @Prop 统计天数: number;
  /** 是否深色主题（控制遮罩色与磨砂风格，与 创建牌组面板 同款） */
  @Prop 是否深色: boolean = false;
  统计服务实例: 统计服务 = new 统计服务();
  onClose: () => void = (): void => {};
  onSaved: (偏好: GraphPreferences, 天数: number) => void = (): void => {};
  /**
   * 帮助回调：点击各项 ⓘ 时由父级（统计页）页面级 Stack 统一弹字段帮助面板。
   * Invariants: 本面板不再嵌套渲染字段帮助面板，避免嵌套层级导致遮罩 expandSafeArea
   * 失效（遮罩只覆盖安全区内局部 + 浮层居中在遮罩中而非屏幕中央）。
   */
  onHelp: (标题: Resource, 正文: Resource) => void = (): void => {};

  @State private 编辑偏好: GraphPreferences = {
    calendarFirstDayOfWeek: Weekday.SUNDAY,
    cardCountsSeparateInactive: false,
    browserLinksSupported: false,
    futureDueShowBacklog: false
  };
  @State private 编辑天数: number = 365;
  @State private 保存中: boolean = false;
  @State private 错误信息: string = '';

  @StorageProp(颜色键.动作主色) private 主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 容器色: string = '#E8EEFC';
  @StorageProp(颜色键.页面底色微染) private 页面底色: string = '#F5F7FA';

  private readonly 天数列表: 天数选项[] = [
    { 标签: $r('app.string.stats_prefs_days_30'), 值: 30 },
    { 标签: $r('app.string.stats_prefs_days_90'), 值: 90 },
    { 标签: $r('app.string.stats_prefs_days_365'), 值: 365 },
    { 标签: $r('app.string.stats_prefs_days_all'), 值: 0 }
  ];

  private readonly 周首日列表: 周首日选项[] = [
    { 标签: '周日', 值: Weekday.SUNDAY },
    { 标签: '周一', 值: Weekday.MONDAY },
    { 标签: '周五', 值: Weekday.FRIDAY },
    { 标签: '周六', 值: Weekday.SATURDAY }
  ];

  private 取能力上下文(): common.UIAbilityContext | null {
    const ctx: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return ctx === undefined ? null : ctx;
  }

  private 显示提示(文案: Resource): void {
    const ctx = this.取能力上下文();
    if (ctx !== null) {
      ctx.resourceManager.getStringValue(文案).then((str: string) => {
        this.getUIContext().getPromptAction().showToast({
          message: str,
          duration: 2000
        });
      });
    }
  }

  aboutToAppear(): void {
    // 复制 prop 到本地编辑状态
    this.编辑偏好 = {
      calendarFirstDayOfWeek: this.偏好.calendarFirstDayOfWeek,
      cardCountsSeparateInactive: this.偏好.cardCountsSeparateInactive,
      browserLinksSupported: this.偏好.browserLinksSupported,
      futureDueShowBacklog: this.偏好.futureDueShowBacklog
    };
    this.编辑天数 = this.统计天数;
  }

  private async 保存(): Promise<void> {
    this.保存中 = true;
    this.错误信息 = '';
    try {
      await this.统计服务实例.设置图表偏好(this.编辑偏好);
      this.显示提示($r('app.string.stats_prefs_saved'));
      this.onSaved(this.编辑偏好, this.编辑天数);
    } catch (错误) {
      this.错误信息 = `${错误}`;
      this.显示提示($r('app.string.stats_prefs_save_failed'));
    } finally {
      this.保存中 = false;
    }
  }

  @Builder
  private 天数选项行(选项: 天数选项) {
    Row({ space: 应用尺寸.间距_8 }) {
      Radio({ value: `${选项.值}`, group: 'statsDays' })
        .checked(this.编辑天数 === 选项.值)
        .radioStyle({ checkedBackgroundColor: this.主色按钮背景 })
        .onChange((选中: boolean) => {
          if (选中) {
            this.编辑天数 = 选项.值;
          }
        })
      Text(选项.标签)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ top: 应用尺寸.间距_8, bottom: 应用尺寸.间距_8 })
  }

  @Builder
  private 周首日选项行(选项: 周首日选项) {
    Row({ space: 应用尺寸.间距_8 }) {
      Radio({ value: `${选项.值}`, group: 'statsFirstDay' })
        .checked(this.编辑偏好.calendarFirstDayOfWeek === 选项.值)
        .radioStyle({ checkedBackgroundColor: this.主色按钮背景 })
        .onChange((选中: boolean) => {
          if (选中) {
            this.编辑偏好.calendarFirstDayOfWeek = 选项.值;
          }
        })
      Text(选项.标签)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ top: 应用尺寸.间距_8, bottom: 应用尺寸.间距_8 })
  }

  @Builder
  private 开关行(标签: Resource, 选中: boolean, 回调: (值: boolean) => void) {
    Row() {
      Text(标签)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: 选中 })
        .selectedColor(this.主色按钮背景)
        .onChange((值: boolean) => {
          回调(值);
        })
    }
    .width('100%')
    .padding({ top: 应用尺寸.间距_8, bottom: 应用尺寸.间距_8 })
  }

  @Builder
  private 开关行带帮助(
    标签: Resource,
    选中: boolean,
    回调: (值: boolean) => void,
    帮助标题: Resource,
    帮助正文: Resource
  ) {
    Row({ space: 应用尺寸.间距_4 }) {
      Text(标签)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
      Button($r('app.string.field_help_button'))
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontColor(this.主色)
        .fontSize(应用尺寸.字号_正文)
        .onClick((): void => {
          this.onHelp(帮助标题, 帮助正文);
        })
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: 选中 })
        .selectedColor(this.主色按钮背景)
        .onChange((值: boolean) => {
          回调(值);
        })
    }
    .width('100%')
    .padding({ top: 应用尺寸.间距_8, bottom: 应用尺寸.间距_8 })
  }

  build() {
    Stack() {
      // 遮罩：磨砂玻璃质感 + 深浅色区分（与 创建牌组面板 同款）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.是否深色 ? 'rgba(0,0,0,0.40)' : 'rgba(0,0,0,0.15)')
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.是否深色 ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          if (!this.保存中) {
            this.onClose();
          }
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }))

      // 面板：居中浮卡（与创建牌组面板同款）
      Column() {
        // 标题行：标题居中（右上角取消按钮已移除，底部已有取消按钮）
        Row() {
          Text($r('app.string.stats_prefs_title'))
            .fontSize(应用尺寸.字号_面板标题)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 应用尺寸.间距_12 })

        Scroll() {
          Column({ space: 应用尺寸.间距_16 }) {
            // 统计天数
            Column({ space: 应用尺寸.间距_4 }) {
              Row({ space: 应用尺寸.间距_4 }) {
                Text($r('app.string.stats_prefs_days'))
                  .fontSize(应用尺寸.字号_正文)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Button($r('app.string.field_help_button'))
                  .type(ButtonType.Normal)
                  .backgroundColor(Color.Transparent)
                  .fontColor(this.主色)
                  .fontSize(应用尺寸.字号_正文)
                  .onClick((): void => {
                    this.onHelp($r('app.string.stats_prefs_days'), $r('app.string.stats_prefs_days_help'));
                  })
              }
              .width('100%')
              ForEach(this.天数列表, (选项: 天数选项) => {
                this.天数选项行(选项)
              }, (选项: 天数选项) => `${选项.值}`)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 周首日
            Column({ space: 应用尺寸.间距_4 }) {
              Text($r('app.string.stats_prefs_first_day'))
                .fontSize(应用尺寸.字号_正文)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              ForEach(this.周首日列表, (选项: 周首日选项) => {
                this.周首日选项行(选项)
              }, (选项: 周首日选项) => `${选项.值}`)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 卡片计数分离暂停
            this.开关行带帮助(
              $r('app.string.stats_prefs_separate_inactive'),
              this.编辑偏好.cardCountsSeparateInactive,
              (值: boolean) => {
                this.编辑偏好.cardCountsSeparateInactive = 值;
              },
              $r('app.string.stats_prefs_separate_inactive'),
              $r('app.string.stats_prefs_separate_inactive_help')
            )

            // 预测显示积压
            this.开关行带帮助(
              $r('app.string.stats_prefs_show_backlog'),
              this.编辑偏好.futureDueShowBacklog,
              (值: boolean) => {
                this.编辑偏好.futureDueShowBacklog = 值;
              },
              $r('app.string.stats_prefs_show_backlog'),
              $r('app.string.stats_prefs_show_backlog_help')
            )

            // 错误提示
            if (this.错误信息 !== '') {
              Text(this.错误信息)
                .fontSize(应用尺寸.字号_正文_小)
                .fontColor('#D32F2F')
                .width('100%')
            }
          }
          .width('100%')
          .padding({ bottom: 应用尺寸.间距_16 })
        }
        .constraintSize({ maxHeight: '60%' })
        .scrollBar(BarState.Off)

        // 底部双按钮 Row（取消 + 保存，与 创建牌组面板 同款）
        Row({ space: 应用尺寸.间距_10 }) {
          Button($r('app.string.cancel'))
            .height(应用尺寸.按钮高度)
            .layoutWeight(1)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_page'))
            .borderRadius(应用尺寸.圆角_胶囊)
            .enabled(!this.保存中)
            .onClick(() => {
              this.onClose();
            })

          Button($r('app.string.stats_prefs_save'))
            .height(应用尺寸.按钮高度)
            .layoutWeight(1)
            .fontSize(应用尺寸.字号_按钮)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.主色)
            .borderRadius(应用尺寸.圆角_胶囊)
            .enabled(!this.保存中)
            .onClick(() => {
              this.保存();
            })
        }
        .width('100%')
      }
      .width('88%')
      .constraintSize({ maxWidth: 480, maxHeight: '88%' })
      .padding(应用尺寸.面板内边距)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(应用尺寸.圆角_卡片)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        // 阻断点击穿透到遮罩
      })
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }),
        TransitionEffect.opacity(0)
          .animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() })
      ))
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
