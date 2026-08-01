// SPDX-License-Identifier: AGPL-3.0-or-later

import { 加载学习布局模式, 保存学习布局模式, 学习布局模式 } from '../../model/学习布局存储';
import { 保存显示今日进度卡, 主页今日进度卡AppStorage键 } from '../../model/主页偏好';
import { 设置面板色板, 设置面板色板_取, 标签文字色 } from '../../utils/设置面板配色';
import { 颜色键 } from '../../model/颜色主题';

@Component
export struct 布局分组 {
  @Prop 是否深色: boolean = false;
  @Prop 是否展开: boolean = false;
  切换展开回调: () => void = (): void => {};

  @StorageLink(颜色键.主色按钮背景) private 主色按钮背景链接: string = '';
  @StorageLink(主页今日进度卡AppStorage键) private 显示今日进度卡: boolean = true;
  @StorageProp('themeMode') private 主题模式监听: string = 'system';

  @State private 当前布局模式: 学习布局模式 | null = null;

  async aboutToAppear(): Promise<void> {
    try {
      this.当前布局模式 = await 加载学习布局模式();
    } catch (error) {
      this.当前布局模式 = 'bottom';
    }
  }

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  private 解析主色按钮背景(): string {
    return this.主色按钮背景链接 !== '' ? this.主色按钮背景链接 : 设置面板色板_取(this.是否深色).主色按钮背景;
  }

  private 布局模式标签(模式: 学习布局模式): string {
    if (模式 === 'float') {
      return this.取本地化文本($r('app.string.settings_study_layout_float'));
    }
    return this.取本地化文本($r('app.string.settings_study_layout_bottom'));
  }

  private async 切换布局(模式: 学习布局模式): Promise<void> {
    if (this.当前布局模式 === 模式) {
      return;
    }
    this.当前布局模式 = 模式;
    try {
      await 保存学习布局模式(模式);
    } catch (error) {
    }
  }

  private 切换今日进度卡(开启: boolean): void {
    保存显示今日进度卡(开启);
  }

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
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
            this.布局模式按钮(设置面板色板_取(this.是否深色), 'bottom');
            this.布局模式按钮(设置面板色板_取(this.是否深色), 'float');
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })

          if (this.当前布局模式 === 'float') {
            Text($r('app.string.study_toolbar_drag_hint'))
              .fontSize(12)
              .fontColor(设置面板色板_取(this.是否深色).三级文字)
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

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
