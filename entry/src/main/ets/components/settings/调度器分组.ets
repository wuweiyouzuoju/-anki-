// SPDX-License-Identifier: AGPL-3.0-or-later

import { 加载FSRS开启状态, 设置FSRS开启状态 } from '../../model/FSRS控制器';
import { 设置面板色板_取, 设置面板色板 } from '../../utils/设置面板配色';
import { 颜色键 } from '../../model/颜色主题';

@Component
export struct 调度器分组 {
  @Prop 是否深色: boolean = false;
  @Prop 是否展开: boolean = false;
  切换展开回调: () => void = (): void => {};
  打开说明回调: (标题: Resource, 正文: Resource) => void = (_标题: Resource, _正文: Resource): void => {};

  @StorageLink(颜色键.主色按钮背景) private 主色按钮背景链接: string = '';
  @StorageProp('themeMode') private 主题模式监听: string = 'system';

  @State private 是否启用FSRS: boolean | null = null;
  @State private FSRS操作中: boolean = false;
  @State private FSRS错误信息: string = '';

  async aboutToAppear(): Promise<void> {
    await this.刷新FSRS状态();
  }

  private async 刷新FSRS状态(): Promise<void> {
    this.FSRS错误信息 = '';
    const 值: boolean | null = await 加载FSRS开启状态();
    this.是否启用FSRS = 值;
    if (值 === null) {
      this.FSRS错误信息 = this.取本地化文本($r('app.string.settings_fsrs_load_error'));
    }
  }

  private async 切换FSRS开关(值: boolean): Promise<void> {
    if (this.FSRS操作中 || this.是否启用FSRS === null) {
      return;
    }
    const 先前值: boolean = this.是否启用FSRS;
    this.FSRS操作中 = true;
    this.是否启用FSRS = 值;
    this.FSRS错误信息 = '';
    try {
      await 设置FSRS开启状态(值);
    } catch (error) {
      this.是否启用FSRS = 先前值;
      this.FSRS错误信息 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.FSRS操作中 = false;
    }
  }

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  private 解析主色按钮背景(): string {
    return this.主色按钮背景链接 !== '' ? this.主色按钮背景链接 : 设置面板色板_取(this.是否深色).主色按钮背景;
  }

  @Builder
  private 分组头部() {
    Row() {
      Text(this.取本地化文本($r('app.string.settings_scheduler')))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(设置面板色板_取(this.是否深色).次文字)
      if (this.是否展开) {
        Button($r('app.string.field_help_button'))
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontSize(14)
          .fontColor(设置面板色板_取(this.是否深色).三级文字)
          .width(28)
          .height(28)
          .padding(0)
          .onClick(() => {
            this.打开说明回调($r('app.string.settings_fsrs_label'), $r('app.string.settings_fsrs_help'));
          })
      }
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
            Text($r('app.string.settings_fsrs_label'))
              .fontSize(15)
              .fontColor(设置面板色板_取(this.是否深色).主文字)
              .layoutWeight(1)
            Blank()
            if (this.是否启用FSRS === null) {
              Text($r('app.string.settings_fsrs_loading'))
                .fontSize(13)
                .fontColor(设置面板色板_取(this.是否深色).三级文字)
            } else {
              Toggle({ type: ToggleType.Switch, isOn: this.是否启用FSRS })
                .selectedColor(this.解析主色按钮背景())
                .enabled(!this.FSRS操作中)
                .onChange((值: boolean): void => {
                  this.切换FSRS开关(值);
                })
            }
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })

          if (this.FSRS错误信息 !== '') {
            Text(this.FSRS错误信息)
              .fontSize(12)
              .fontColor(设置面板色板_取(this.是否深色).错误色)
              .width('100%')
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
