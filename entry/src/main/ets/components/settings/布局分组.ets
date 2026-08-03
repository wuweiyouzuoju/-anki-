// SPDX-License-Identifier: AGPL-3.0-or-later

import { 加载学习布局模式, 保存学习布局模式, 学习布局模式 } from '../../model/学习布局存储';
import { 保存显示今日进度卡, 主页今日进度卡AppStorage键 } from '../../model/主页偏好';
import { 设置面板色板, 设置面板色板_取, 标签文字色 } from '../../utils/设置面板配色';
import { 颜色键 } from '../../model/颜色主题';

// ========================================================
// @块ID UI-LAYOUT-001
// @名称 复习页布局分组
//
// @作用
// 提供底部固定 / 浮动可拖 两种复习页布局模式切换，
// 以及主页「今日进度卡片」显示开关（B12-Y3 2026-07-25）。
// 当前布局模式 = null 表示加载中；加载失败回退 'bottom'。
// 切换后立即生效（下次进入复习页）。
//
// @输入
// 是否深色：当前是否深色模式（影响色板取值）。
// 是否展开：本分组是否展开。
// 切换展开回调：父组件注入。
//
// @输出
// 渲染布局分组卡片；用户选择模式时持久化并更新当前布局模式；
// 用户切换今日进度卡开关时持久化 + 同步写 AppStorage 触发首页 @StorageLink 重渲染。
//
// @副作用
// 调用 加载学习布局模式 / 保存学习布局模式 读写本地持久化；
// 调用 保存显示今日进度卡 读写本地持久化 + 写 AppStorage 触发首页重渲染；
// 持久化失败仅丢失下次启动后的值，不回滚 UI。
// ========================================================
@Component
export struct 布局分组 {
  @Prop 是否深色: boolean = false;
  @Prop 是否展开: boolean = false;
  切换展开回调: () => void = (): void => {};

  // @StorageLink 让本组件在 主色按钮背景 变化时立即重渲染；解析主色按钮背景() 直接引用此字段，
  // 让布局选中态主色在颜色主题切换瞬间同步更新（与 外观分组 同款机制）。
  @StorageLink(颜色键.主色按钮背景) private 主色按钮背景链接: string = '';
  // 主页今日进度卡开关：与 首页.ets 同款 @StorageLink，
  // 用户切 Toggle 后由 切换今日进度卡 写 AppStorage 触发首页重渲染。
  @StorageLink(主页今日进度卡AppStorage键) private 显示今日进度卡: boolean = true;
  // B12-Y5 2026-07-29 修复 Bug 1：@StorageProp('themeMode') 让主题模式切换直接触发重 build，
  // 不依赖 @Prop 是否深色 传播（aurora 主题 主色按钮背景 深浅色相同，@StorageLink 可能不触发）。
  @StorageProp('themeMode') private 主题模式监听: string = 'system';

  @State private 当前布局模式: 学习布局模式 | null = null;

  async aboutToAppear(): Promise<void> {
    // 失败回退到 'bottom'（默认），保证 chip 一直可选。
    try {
      this.当前布局模式 = await 加载学习布局模式();
    } catch (error) {
      this.当前布局模式 = 'bottom';
    }
  }

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  /** 按钮背景专用主色（配 #FFFFFF 文字 ≥ 4.5:1）。2.1.4.1 深色模式修复。 */
  private 解析主色按钮背景(): string {
    return this.主色按钮背景链接 !== '' ? this.主色按钮背景链接 : 设置面板色板_取(this.是否深色).主色按钮背景;
  }

  /** 复习页布局模式标签：bottom=底部固定；float=浮动可拖。 */
  private 布局模式标签(模式: 学习布局模式): string {
    if (模式 === 'float') {
      return this.取本地化文本($r('app.string.settings_study_layout_float'));
    }
    return this.取本地化文本($r('app.string.settings_study_layout_bottom'));
  }

  /** 切换布局模式：乐观更新 UI + 异步持久化；持久化失败仅丢失下次启动后的值，不回滚 UI。 */
  private async 切换布局(模式: 学习布局模式): Promise<void> {
    if (this.当前布局模式 === 模式) {
      return;
    }
    this.当前布局模式 = 模式;
    try {
      await 保存学习布局模式(模式);
    } catch (error) {
      // 持久化失败可接受：UI 已切换，下次启动会回退到上次保存的值。
    }
  }

  // ========================================================
  // @块ID UI-LAYOUT-003
  // @名称 切换今日进度卡开关
  //
  // @作用
  // 用户在布局分组末尾切「显示今日进度卡片」Toggle 时持久化新值
  // 并同步写 AppStorage，让首页 @StorageLink(显示今日进度卡) 立即响应：
  // - true → 主页摘要分页 重新渲染显示
  // - false → 主页摘要分页 从 Column 移除
  //
  // @输入
  // 开启: boolean - Toggle 新状态
  //
  // @输出
  // 写 preferences 的 home_show_today_summary；
  // 写 AppStorage 的 'homeShowTodaySummary' 触发首页重渲染。
  //
  // @副作用
  // 调用 保存显示今日进度卡 间接读写 preferences + 写 AppStorage。
  // ========================================================
  private 切换今日进度卡(开启: boolean): void {
    // 乐观更新：@StorageLink 双向绑定已自动写本地字段；
    // 这里只负责持久化 + 显式广播给首页（首页同款 @StorageLink 会自动响应）。
    保存显示今日进度卡(开启);
  }

  // ========================================================
  // @块ID UI-LAYOUT-002
  // @名称 布局模式按钮
  //
  // @作用
  // 渲染单个布局模式 chip 按钮（bottom / float）；选中态用主色背景。
  // 加载中（当前布局模式 === null）时按钮可见但禁用点击。
  //
  // @输入
  // 色板：当前色板。
  // 模式：学习布局模式枚举值。
  //
  // @输出
  // 渲染单个布局模式按钮；点击时调用 切换布局。
  //
  // @副作用
  // 调用 切换布局 间接持久化（见 切换布局 副作用）。
  // ========================================================
  @Builder
  private 布局模式按钮(色板: 设置面板色板, 模式: 学习布局模式) {
    Button(this.布局模式标签(模式))
      .height(36)
      .fontSize(13)
      .fontColor(标签文字色(色板, this.当前布局模式 === 模式))
      .backgroundColor(this.当前布局模式 === 模式 ? this.解析主色按钮背景() : 色板.标签背景)
      .borderRadius(18)
      .margin({ right: 8, bottom: 6 })
      .onClick((): void => {
        if (this.当前布局模式 !== null) {
          this.切换布局(模式);
        }
      })
  }

  @Builder
  private 分组头部() {
    Row() {
      Text(this.取本地化文本($r('app.string.settings_study_layout')))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(设置面板色板_取(this.是否深色).次文字)
      Blank()
      Text('▼')
        .fontSize(11)
        .fontColor(设置面板色板_取(this.是否深色).弱化文字)
        .rotate({ angle: this.是否展开 ? 0 : -90 })
    }
    .width('100%')
    .height(40)
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.切换展开回调(); });
    })
  }

  build() {
    Column() {
      this.分组头部()

      if (this.是否展开) {
        Column({ space: 8 }) {
          // 模式 chip：加载中（null）时也渲染但不可点；切换后立即生效（下次进入复习页）。
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
            this.布局模式按钮(设置面板色板_取(this.是否深色), 'bottom');
            this.布局模式按钮(设置面板色板_取(this.是否深色), 'float');
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })

          // 拖动提示：仅 float 模式下显示，告诉用户工具栏可以拖到侧边。
          if (this.当前布局模式 === 'float') {
            Text($r('app.string.study_toolbar_drag_hint'))
              .fontSize(12)
              .fontColor(设置面板色板_取(this.是否深色).三级文字)
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          // 主页今日进度卡开关（B12-Y3 2026-07-25）：Divider 分隔 + 标题 + Toggle。
          // 与复习页布局模式并列在「布局」分组下，因两者都属于「页面布局」范畴。
          Divider()
            .color(设置面板色板_取(this.是否深色).分隔线)
            .strokeWidth(1)
            .margin({ top: 4, bottom: 4 })

          Row() {
            Column({ space: 2 }) {
              Text($r('app.string.settings_home_today_summary'))
                .fontSize(15)
                .fontColor(设置面板色板_取(this.是否深色).主文字)
              Text($r('app.string.settings_home_today_summary_hint'))
                .fontSize(12)
                .fontColor(设置面板色板_取(this.是否深色).三级文字)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.显示今日进度卡 })
              .selectedColor(this.解析主色按钮背景())
              .onChange((值: boolean): void => {
                this.切换今日进度卡(值);
              })
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(设置面板色板_取(this.是否深色).背景)
    .borderRadius(12)
  }
}
