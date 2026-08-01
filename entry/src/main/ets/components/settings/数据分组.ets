// SPDX-License-Identifier: AGPL-3.0-or-later

import { 设置面板色板, 设置面板色板_取 } from '../../utils/设置面板配色';
import { 颜色键 } from '../../model/颜色主题';

@Component
export struct 数据分组 {
  @Prop 是否深色: boolean = false;
  @Prop 是否展开: boolean = false;
  切换展开回调: () => void = (): void => {};
  点击导出导入回调: () => void = (): void => {};
  点击已隐藏牌组回调: () => void = (): void => {};

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  @Builder
  private 分组头部() {
    Row() {
      Text(this.取本地化文本($r('app.string.settings_data_management')))
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
        Column() {
          Row() {
            Column({ space: 2 }) {
              Text($r('app.string.settings_export_import_data'))
                .fontSize(15)
                .fontColor(设置面板色板_取(this.是否深色).主文字)
              Text($r('app.string.settings_export_import_data_subtitle'))
                .fontSize(12)
                .fontColor(设置面板色板_取(this.是否深色).弱化文字)
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text('›')
              .fontSize(20)
              .fontColor(设置面板色板_取(this.是否深色).弱化文字)
          }
          .width('100%')
          .height(58)
          .onClick(() => {
            this.点击导出导入回调();
          })

          Row() {
            Column({ space: 2 }) {
              Text($r('app.string.hidden_decks_entry'))
                .fontSize(15)
                .fontColor(设置面板色板_取(this.是否深色).主文字)
              Text($r('app.string.hidden_decks_entry_subtitle'))
                .fontSize(12)
                .fontColor(设置面板色板_取(this.是否深色).弱化文字)
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text('›')
              .fontSize(20)
              .fontColor(设置面板色板_取(this.是否深色).弱化文字)
          }
          .width('100%')
          .height(58)
          .onClick(() => {
            this.点击已隐藏牌组回调();
          })
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
