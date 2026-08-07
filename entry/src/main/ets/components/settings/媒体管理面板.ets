// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-MEDIA-MGMT-001
// @名称 媒体管理面板
//
// @作用
// 媒体管理弹层面板：检查 unused/missing 媒体 + 回收站操作（进回收站/清空/恢复）。
// 持有 媒体服务 实例直接调后端，与 设置面板 持有 集合服务 调 检查数据库 同款模式。
// 不上抛数据意图；操作结果在本面板内实时呈现。
//
// @输入
// isDark: 是否深色主题
// onClose: 关闭回调
//
// @输出
// 渲染媒体管理面板；用户操作时调 媒体服务 并更新本地 @State。
//
// @业务规则
// 检查媒体返回 unused/missing 列表 + have_trash 标记；unused 可勾选后批量进回收站；
// 清空回收站需二次确认（不可撤销）；恢复回收站将文件移回 collection.media。
// 所有用户可见文案走 $r('app.string.media_*')，禁止硬编码中文。
// 失败时错误信息显示在面板内（红字），不弹 toast。
//
// @副作用
// 持有 媒体服务实例；点击按钮时调后端媒体服务 RPC（经 后端会话 → NAPI 桥）。
// ========================================================

import { 媒体服务 } from '../../backend/媒体服务';
import { 同步服务 } from '../../backend/同步服务';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 设置面板色板_取 } from '../../utils/设置面板配色';
import { 颜色键 } from '../../model/颜色主题';
import { 取全屏转场时长, 取全屏转场曲线 } from '../../utils/转场时长';
import type { CheckMediaResponse } from '../../proto/messages/MediaMessages';

@Component
export struct 媒体管理面板 {
  @Prop isDark: boolean = false;
  onClose: () => void = (): void => {};

  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  @State private 检查中: boolean = false;
  @State private 处理中: boolean = false;
  @State private 已检查: boolean = false;
  @State private 未使用列表: string[] = [];
  @State private 缺失列表: string[] = [];
  @State private 选中状态: boolean[] = [];
  @State private 回收站有内容: boolean = false;
  @State private 错误信息: string = '';
  @State private 媒体同步中: boolean = false;

  private readonly 媒体服务实例: 媒体服务 = new 媒体服务();
  private readonly 同步服务实例: 同步服务 = new 同步服务();

  aboutToAppear(): void {
    this.检查媒体同步状态();
  }

  /**
   * 查询后端媒体同步是否进行中；active=true 时面板顶部显示警告条。
   * 媒体同步是后台异步任务（关闭同步弹窗不会中止），同步中检查 unused 会得到不稳定结果
   * （新落地的文件还未被笔记引用前临时算 unused，或引用关系还在更新）。
   */
  private async 检查媒体同步状态(): Promise<void> {
    try {
      const 状态 = await this.同步服务实例.媒体同步状态();
      this.媒体同步中 = 状态.active;
    } catch {
      this.媒体同步中 = false;
    }
  }

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  private 取本地化带参文本(资源: Resource, 参数: Array<string | number>): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id, ...参数);
  }

  private 选中数量(): number {
    let 计数 = 0;
    for (let i = 0; i < this.选中状态.length; i++) {
      if (this.选中状态[i]) {
        计数++;
      }
    }
    return 计数;
  }

  private 全选状态(): boolean {
    if (this.未使用列表.length === 0) {
      return false;
    }
    return this.选中数量() === this.未使用列表.length;
  }

  private 切换全选(): void {
    const 全选 = !this.全选状态();
    const 新状态: boolean[] = [];
    for (let i = 0; i < this.未使用列表.length; i++) {
      新状态.push(全选);
    }
    this.选中状态 = 新状态;
  }

  private 切换选中(索引: number): void {
    const 新状态: boolean[] = [];
    for (let i = 0; i < this.选中状态.length; i++) {
      新状态.push(i === 索引 ? !this.选中状态[i] : this.选中状态[i]);
    }
    this.选中状态 = 新状态;
  }

  /**
   * 刷新媒体状态：调 CheckMedia RPC 并更新本地 @State（unused/missing/have_trash/选中状态/已检查）。
   * 无防重入；调用方负责防重入（检查中/处理中）。
   * Invariants: 选中状态长度始终与 未使用列表 长度对齐（全 false 重置）。
   * 失败时错误信息写入 @State 错误信息，不抛出。
   */
  private async 刷新媒体状态(): Promise<void> {
    this.错误信息 = '';
    try {
      const 响应: CheckMediaResponse = await this.媒体服务实例.检查媒体();
      this.未使用列表 = 响应.unused;
      this.缺失列表 = 响应.missing;
      this.回收站有内容 = 响应.haveTrash;
      const 初始选中: boolean[] = [];
      for (let i = 0; i < 响应.unused.length; i++) {
        初始选中.push(false);
      }
      this.选中状态 = 初始选中;
      this.已检查 = true;
    } catch (error) {
      this.错误信息 = error instanceof Error ? error.message : `${error}`;
    }
  }

  /**
   * 执行检查媒体：检查中/处理中防重入壳，内部委托 刷新媒体状态。
   * 同时刷新媒体同步状态（用户可能在面板开着时同步开始/结束）。
   */
  private async 执行检查媒体(): Promise<void> {
    if (this.检查中 || this.处理中) {
      return;
    }
    this.检查中 = true;
    this.检查媒体同步状态();
    await this.刷新媒体状态();
    this.检查中 = false;
  }

  private async 执行进回收站(): Promise<void> {
    const 选中文件: string[] = [];
    for (let i = 0; i < this.未使用列表.length; i++) {
      if (this.选中状态[i]) {
        选中文件.push(this.未使用列表[i]);
      }
    }
    if (选中文件.length === 0 || this.处理中) {
      return;
    }
    this.处理中 = true;
    this.错误信息 = '';
    try {
      await this.媒体服务实例.媒体文件进回收站(选中文件);
      await this.刷新媒体状态();
    } catch (error) {
      this.错误信息 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.处理中 = false;
    }
  }

  private 确认清空回收站(): void {
    if (this.处理中 || !this.回收站有内容) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: this.取本地化文本($r('app.string.media_empty_trash')),
      message: this.取本地化文本($r('app.string.media_confirm_empty_trash')),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: this.取本地化文本($r('app.string.cancel')),
        action: (): void => {}
      },
      secondaryButton: {
        value: this.取本地化文本($r('app.string.media_empty_trash')),
        fontColor: '#D32F2F',
        action: (): void => { this.执行清空回收站(); }
      }
    });
  }

  private async 执行清空回收站(): Promise<void> {
    if (this.处理中) {
      return;
    }
    this.处理中 = true;
    this.错误信息 = '';
    try {
      await this.媒体服务实例.清空回收站();
      this.回收站有内容 = false;
    } catch (error) {
      this.错误信息 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.处理中 = false;
    }
  }

  private async 执行恢复回收站(): Promise<void> {
    if (this.处理中 || !this.回收站有内容) {
      return;
    }
    this.处理中 = true;
    this.错误信息 = '';
    try {
      await this.媒体服务实例.恢复回收站();
      await this.刷新媒体状态();
    } catch (error) {
      this.错误信息 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.处理中 = false;
    }
  }

  @Builder
  private 未使用项行(索引: number) {
    Row({ space: 应用尺寸.间距_8 }) {
      // 直接读 this.选中状态[索引] 建立响应式依赖；通过 @Builder 参数传值不响应式
      Toggle({ type: ToggleType.Checkbox, isOn: this.选中状态[索引] })
        .selectedColor(this.主色按钮背景)
        .onChange((值: boolean): void => { this.切换选中(索引); })
      Text(this.未使用列表[索引])
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor(设置面板色板_取(this.isDark).主文字)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(36)
  }

  @Builder
  private 缺失项行(文件名: string) {
    Row({ space: 应用尺寸.间距_8 }) {
      Text('⚠')
        .fontSize(应用尺寸.字号_正文)
        .fontColor('#D32F2F')
      Text(文件名)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor(设置面板色板_取(this.isDark).主文字)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(36)
  }

  build() {
    Stack() {
      // 磨砂玻璃遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(设置面板色板_取(this.isDark).遮罩)
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          if (!this.检查中 && !this.处理中) {
            this.onClose();
          }
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }))

      Column({ space: 应用尺寸.间距_16 }) {
        // Header：标题 + 右上角 ×
        Row() {
          Text($r('app.string.settings_media_management'))
            .fontSize(应用尺寸.字号_面板标题)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
          if (!this.检查中 && !this.处理中) {
            Text('×')
              .fontSize(24)
              .fontColor($r('app.color.text_secondary'))
              .width(32)
              .height(32)
              .textAlign(TextAlign.Center)
              .onClick(() => { this.onClose(); })
          }
        }
        .width('100%')

        // 媒体同步进行中警告条
        if (this.媒体同步中) {
          Row({ space: 应用尺寸.间距_8 }) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color('#E65100')
            Text($r('app.string.media_sync_in_progress'))
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor('#E65100')
              .layoutWeight(1)
          }
          .width('100%')
          .padding({
            left: 应用尺寸.间距_12,
            right: 应用尺寸.间距_12,
            top: 应用尺寸.间距_8,
            bottom: 应用尺寸.间距_8
          })
          .backgroundColor(this.isDark ? 'rgba(230, 81, 0, 0.15)' : 'rgba(230, 81, 0, 0.08)')
          .borderRadius(应用尺寸.圆角_卡片)
        }

        // 检查按钮
        Button(this.检查中 ? $r('app.string.media_checking') : $r('app.string.media_check'))
          .width('100%')
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.action_on_primary'))
          .backgroundColor(this.主色按钮背景)
          .borderRadius(应用尺寸.圆角_胶囊)
          .enabled(!this.检查中 && !this.处理中)
          .opacity(this.检查中 ? 0.6 : 1)
          .onClick(() => { this.执行检查媒体(); })

        // busy 指示
        if (this.检查中) {
          Row({ space: 应用尺寸.间距_8 }) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color($r('app.color.action_primary'))
            Text($r('app.string.media_checking'))
              .fontSize(应用尺寸.字号_正文_中)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }

        // 错误信息
        if (this.错误信息 !== '') {
          Text(this.错误信息)
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor('#D32F2F')
            .width('100%')
        }

        // 检查结果
        if (this.已检查) {
          Scroll() {
            Column({ space: 应用尺寸.间距_12 }) {
              // 未使用媒体区
              Column({ space: 应用尺寸.间距_4 }) {
                Row() {
                  Text(this.取本地化带参文本($r('app.string.media_unused_count'), [this.未使用列表.length]))
                    .fontSize(应用尺寸.字号_正文)
                    .fontColor($r('app.color.text_primary'))
                    .fontWeight(FontWeight.Medium)
                    .layoutWeight(1)
                  if (this.未使用列表.length > 0) {
                    Button(this.全选状态() ? $r('app.string.media_deselect_all') : $r('app.string.media_select_all'))
                      .type(ButtonType.Normal)
                      .backgroundColor(Color.Transparent)
                      .fontColor(this.主色按钮背景)
                      .fontSize(应用尺寸.字号_正文_小)
                      .onClick(() => { this.切换全选(); })
                  }
                }
                .width('100%')
                if (this.未使用列表.length === 0) {
                  Text($r('app.string.media_no_unused'))
                    .fontSize(应用尺寸.字号_正文_小)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                }
                ForEach(this.未使用列表, (文件名: string, 索引: number) => {
                  this.未使用项行(索引)
                // keyItem 纳入选中状态：选中变化时让 ForEach 重建该项，Toggle 拿到最新 isOn
                }, (文件名: string, 索引: number): string => `${文件名}|${this.选中状态[索引] ? 1 : 0}`)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // 缺失媒体区
              Column({ space: 应用尺寸.间距_4 }) {
                Text(this.取本地化带参文本($r('app.string.media_missing_count'), [this.缺失列表.length]))
                  .fontSize(应用尺寸.字号_正文)
                  .fontColor($r('app.color.text_primary'))
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                if (this.缺失列表.length === 0) {
                  Text($r('app.string.media_no_missing'))
                    .fontSize(应用尺寸.字号_正文_小)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                }
                ForEach(this.缺失列表, (文件名: string) => {
                  this.缺失项行(文件名)
                }, (文件名: string): string => 文件名)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // 回收站状态
              Row() {
                Text($r('app.string.media_trash_status'))
                  .fontSize(应用尺寸.字号_正文)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text(this.回收站有内容 ? $r('app.string.media_trash_has_items') : $r('app.string.media_trash_empty'))
                  .fontSize(应用尺寸.字号_正文_小)
                  .fontColor(this.回收站有内容 ? '#D32F2F' : $r('app.color.text_secondary'))
              }
              .width('100%')
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 280 })
          .scrollBar(BarState.Auto)

          // 操作按钮区
          Row({ space: 应用尺寸.间距_8 }) {
            Button($r('app.string.media_trash_selected'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(应用尺寸.按钮高度)
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor($r('app.color.action_on_primary'))
              .backgroundColor(this.主色按钮背景)
              .borderRadius(应用尺寸.圆角_胶囊)
              .enabled(this.选中数量() > 0 && !this.处理中)
              .opacity(this.选中数量() > 0 && !this.处理中 ? 1 : 0.4)
              .onClick(() => { this.执行进回收站(); })
          }
          .width('100%')

          Row({ space: 应用尺寸.间距_8 }) {
            Button($r('app.string.media_restore_trash'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(应用尺寸.按钮高度)
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
              .borderRadius(应用尺寸.圆角_胶囊)
              .enabled(this.回收站有内容 && !this.处理中)
              .opacity(this.回收站有内容 && !this.处理中 ? 1 : 0.4)
              .onClick(() => { this.执行恢复回收站(); })

            Button($r('app.string.media_empty_trash'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(应用尺寸.按钮高度)
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor('#D32F2F')
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 应用尺寸.卡片边框, color: '#D32F2F' })
              .borderRadius(应用尺寸.圆角_胶囊)
              .enabled(this.回收站有内容 && !this.处理中)
              .opacity(this.回收站有内容 && !this.处理中 ? 1 : 0.4)
              .onClick(() => { this.确认清空回收站(); })
          }
          .width('100%')

          // 处理中指示
          if (this.处理中) {
            Row({ space: 应用尺寸.间距_8 }) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color($r('app.color.action_primary'))
              Text($r('app.string.media_processing'))
                .fontSize(应用尺寸.字号_正文_中)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
        }
      }
      .width('88%')
      .constraintSize({ maxWidth: 480, maxHeight: '88%' })
      .padding(应用尺寸.面板内边距)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(应用尺寸.圆角_卡片)
      .onClick(() => {})
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
  }
}
