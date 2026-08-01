// SPDX-License-Identifier: AGPL-3.0-or-later

import { 主题模式 } from '../../model/主题设置';
import { 当前语言模式, 语言模式, 设置语言模式 } from '../../model/语言存储';
import { 设置面板色板_取 } from '../../utils/设置面板配色';
import {
  颜色主题,
  颜色主题渐变档
} from '../../model/颜色主题';

@Component
export struct 外观分组 {
  @Prop 是否深色: boolean = false;
  @Prop 当前主题模式: 主题模式 = 'system';
  @Prop 当前颜色主题: 颜色主题 = 'aurora';
  @Prop 是否展开: boolean = false;
  @StorageProp('themeMode') private 主题模式监听: string = 'system';
  切换展开回调: () => void = (): void => {};
  主题模式切换回调: (模式: 主题模式) => void = (模式: 主题模式): void => {};
  颜色主题切换回调: (主题: 颜色主题) => void = (主题: 颜色主题): void => {};

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  private 主题模式标签(模式: 主题模式): string {
    if (模式 === 'light') {
      return this.取本地化文本($r('app.string.theme_light'));
    }
    if (模式 === 'dark') {
      return this.取本地化文本($r('app.string.theme_dark'));
    }
    return this.取本地化文本($r('app.string.theme_system'));
  }

  private 颜色主题展示名文本(主题: 颜色主题): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringByNameSync('theme_color_' + 主题);
  }

  private 语言模式标签(模式: 语言模式): Resource {
    if (模式 === 'en') return $r('app.string.language_english');
    return $r('app.string.language_chinese');
  }

  private 选择语言(模式: 语言模式): void {
    const 切换前: 语言模式 = 当前语言模式();
    if (切换前 === 模式) {
      return;
    }
    设置语言模式(模式);
  }

  private 主题模式选项(): SelectOption[] {
    return [
      { value: this.取本地化文本($r('app.string.theme_system')) },
      { value: this.取本地化文本($r('app.string.theme_light')) },
      { value: this.取本地化文本($r('app.string.theme_dark')) }
    ];
  }

  private 主题模式索引(): number {
    if (this.当前主题模式 === 'light') return 1;
    if (this.当前主题模式 === 'dark') return 2;
    return 0;
  }

  private 颜色主题选项(): SelectOption[] {
    const 主题列表: 颜色主题[] = ['aurora', 'forest', 'midnight', 'lagoon', 'sunset', 'lemon'];
    return 主题列表.map((主题: 颜色主题): SelectOption => ({ value: this.颜色主题展示名文本(主题) }));
  }

  private 颜色主题索引(): number {
    const 主题列表: 颜色主题[] = ['aurora', 'forest', 'midnight', 'lagoon', 'sunset', 'lemon'];
    const 索引 = 主题列表.indexOf(this.当前颜色主题);
    return 索引 >= 0 ? 索引 : 0;
  }

  private 语言选项(): SelectOption[] {
    return [
      { value: this.取本地化文本($r('app.string.language_chinese')) },
      { value: this.取本地化文本($r('app.string.language_english')) }
    ];
  }

  private 语言索引(): number {
    return 当前语言模式() === 'en' ? 1 : 0;
  }

  private 色样档位(主题: 颜色主题): Array<[ResourceColor, number]> {
    const 色档: string[] = 颜色主题渐变档(主题);
    return [
      [色档[0] as ResourceColor, 0.0],
      [色档[1] as ResourceColor, 0.5],
      [色档[2] as ResourceColor, 1.0]
    ];
  }

  @Builder
  private 分组头部() {
    Row() {
      Text(this.取本地化文本($r('app.string.settings_appearance_language')))
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
        Column({ space: 4 }) {
          Row() {
            Text($r('app.string.appearance_theme'))
              .fontSize(15)
              .fontColor(设置面板色板_取(this.是否深色).主文字)
              .layoutWeight(1)
            Select(this.主题模式选项())
              .selected(this.主题模式索引())
              .value(this.主题模式标签(this.当前主题模式))
              .controlSize(ControlSize.SMALL)
              .onSelect((索引: number): void => {
                const 模式列表: 主题模式[] = ['system', 'light', 'dark'];
                this.主题模式切换回调(模式列表[索引]);
              })
          }
          .width('100%')
          .height(48)

          Row() {
            Text($r('app.string.appearance_color_theme'))
              .fontSize(15)
              .fontColor(设置面板色板_取(this.是否深色).主文字)
              .layoutWeight(1)
            Row()
              .width(18)
              .height(12)
              .borderRadius(6)
              .linearGradient({
                angle: 90,
                colors: this.色样档位(this.当前颜色主题)
              })
            Select(this.颜色主题选项())
              .selected(this.颜色主题索引())
              .value(this.颜色主题展示名文本(this.当前颜色主题))
              .controlSize(ControlSize.SMALL)
              .margin({ left: 8 })
              .onSelect((索引: number): void => {
                const 主题列表: 颜色主题[] = ['aurora', 'forest', 'midnight', 'lagoon', 'sunset', 'lemon'];
                this.颜色主题切换回调(主题列表[索引]);
              })
          }
          .width('100%')
          .height(48)

          Row() {
            Text($r('app.string.settings_language'))
              .fontSize(15)
              .fontColor(设置面板色板_取(this.是否深色).主文字)
              .layoutWeight(1)
            Select(this.语言选项())
              .selected(this.语言索引())
              .value(this.取本地化文本(this.语言模式标签(当前语言模式())))
              .controlSize(ControlSize.SMALL)
              .onSelect((索引: number): void => {
                const 模式列表: 语言模式[] = ['zh-Hans', 'en'];
                this.选择语言(模式列表[索引]);
              })
          }
          .width('100%')
          .height(48)
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
