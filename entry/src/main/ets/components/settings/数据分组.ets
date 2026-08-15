// SPDX-License-Identifier: AGPL-3.0-or-later

import { 设置面板色板, 设置面板色板_取 } from '../../utils/设置面板配色';
import { 颜色键 } from '../../model/颜色主题';

// ========================================================
// @块ID UI-DATA-GROUP-001
// @名称 数据管理分组
//
// @作用
// 渲染「导出/导入数据」+「已隐藏牌组」+「查找空卡」+「清除未用标签」四个入口行；点击上抛回调，由父组件打开对应面板。
// 纯回调传递，无内部状态；点「导出/导入数据」由父组件打开 DataTransferPanel，
// 用户在面板内 Select 下拉切换 exportDeck / exportPersonalData / importDeck / importPersonalData 四种模式。
// 点「清除未用标签」由父组件弹确认对话框并调后端。
// 点「查找空卡」由父组件打开 空卡列表面板。
//
// @输入
// 是否深色：当前是否深色模式（影响色板取值）。
// 是否展开：本分组是否展开。
// 切换展开回调 / 点击导出导入回调 / 点击已隐藏牌组回调 / 点击空卡回调 / 点击清除未用标签回调：父组件注入。
//
// @输出
// 渲染数据管理分组卡片；用户点击行时触发对应回调。
//
// @副作用
// 无（点击行为由父组件处理）。
// ========================================================
@Component
export struct 数据分组 {
  @Prop 是否深色: boolean = false;
  @Prop 是否展开: boolean = false;
  切换展开回调: () => void = (): void => {};
  点击导出导入回调: () => void = (): void => {};
  点击笔记类型回调: () => void = (): void => {};
  点击已隐藏牌组回调: () => void = (): void => {};
  // 简洁模式：true 时只显示导出导入+媒体管理，隐藏其余高级入口
  @Prop 简洁模式: boolean = true;
  点击空卡回调: () => void = (): void => {};
  点击查找重复回调: () => void = (): void => {};
  点击清除未用标签回调: () => void = (): void => {};
  点击媒体管理回调: () => void = (): void => {};

  // @StorageProp 触发颜色主题切换时重 build，让 设置面板色板_取(是否深色).主色 即时变化
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
          // 导出/导入数据行（合并原「导入数据」+「导出数据」两行；点开 DataTransferPanel 后用户在 Select 下拉切换四种模式）
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

          // 管理笔记类型行（简洁模式下隐藏）
          if (!this.简洁模式) {
            Row() {
              Column({ space: 2 }) {
                Text($r('app.string.notetype_mgmt_entry'))
                  .fontSize(15)
                  .fontColor(设置面板色板_取(this.是否深色).主文字)
                Text($r('app.string.notetype_mgmt_entry_subtitle'))
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
              this.点击笔记类型回调();
            })
          }

          // 已隐藏牌组行（简洁模式下隐藏）
          if (!this.简洁模式) {
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

          // 媒体管理行：检查未使用/缺失媒体 + 回收站操作
          Row() {
            Column({ space: 2 }) {
              Text($r('app.string.settings_media_management'))
                .fontSize(15)
                .fontColor(设置面板色板_取(this.是否深色).主文字)
              Text($r('app.string.settings_media_management_subtitle'))
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
            this.点击媒体管理回调();
          })

          // 查找空卡行（简洁模式下隐藏）
          if (!this.简洁模式) {
            Row() {
              Column({ space: 2 }) {
                Text($r('app.string.empty_cards_entry'))
                  .fontSize(15)
                  .fontColor(设置面板色板_取(this.是否深色).主文字)
                Text($r('app.string.empty_cards_entry_subtitle'))
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
              this.点击空卡回调();
            })
          }

          // 查找重复笔记行（简洁模式下隐藏）
          if (!this.简洁模式) {
            Row() {
              Column({ space: 2 }) {
                Text($r('app.string.find_dupes_entry'))
                  .fontSize(15)
                  .fontColor(设置面板色板_取(this.是否深色).主文字)
                Text($r('app.string.find_dupes_entry_subtitle'))
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
              this.点击查找重复回调();
            })
          }

          // 清除未用标签行（简洁模式下隐藏）
          if (!this.简洁模式) {
            Row() {
              Column({ space: 2 }) {
                Text($r('app.string.settings_clear_unused_tags'))
                  .fontSize(15)
                  .fontColor(设置面板色板_取(this.是否深色).主文字)
                Text($r('app.string.settings_clear_unused_tags_subtitle'))
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
              this.点击清除未用标签回调();
            })
          }
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
