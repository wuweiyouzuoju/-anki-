// SPDX-License-Identifier: AGPL-3.0-or-later

import { ThemeMode } from '../../model/ThemeSettings';
import { currentLanguageMode, LanguageMode, setLanguageMode } from '../../model/LanguageStore';
import { settingsPalette } from '../../utils/SettingsColors';
import {
  ColorTheme,
  colorThemeLabel,
  colorThemeSwatchStops,
  COLOR_KEYS
} from '../../model/ColorTheme';

/**
 * 外观与语言分组：主题（system/light/dark）+ 颜色主题（6 色）+ 语言（zh-Hans/en）。
 * 内部用 expandedKey 控制 chip 子项展开（与原 SettingsPanel 同语义，仅作用于本分组）。
 *
 * 颜色主题：与 ThemeMode 正交的主色调选择。切换时由父组件（Index）回调 applyColorTheme +
 * saveColorTheme；本组件 @StorageLink 监听 actionPrimary，让 settingsPalette.primary 在
 * 主题切换瞬间立即重渲染（无需等待 isDark 变化）。
 */
@Component
export struct AppearanceGroup {
  @Prop isDark: boolean = false;
  @Prop themeMode: ThemeMode = 'system';
  @Prop colorTheme: ColorTheme = 'aurora';
  @Prop opened: boolean = false;
  onToggle: () => void = (): void => {};
  onThemeChange: (mode: ThemeMode) => void = (mode: ThemeMode): void => {};
  onColorThemeChange: (theme: ColorTheme) => void = (theme: ColorTheme): void => {};

  @State private expandedKey: string = '';
  // @StorageLink 让本组件在 actionPrimary 变化时立即重渲染；resolvedPrimary() 直接引用此字段，
  // 让 @Builder 内的选中态背景色在颜色主题切换时同步更新（ArkUI @Builder 追踪 this.xxx 依赖）。
  @StorageLink(COLOR_KEYS.actionPrimary) private actionPrimaryLink: string = '';

  private localized(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  private themeLabel(mode: ThemeMode): string {
    if (mode === 'light') {
      return this.localized($r('app.string.theme_light'));
    }
    if (mode === 'dark') {
      return this.localized($r('app.string.theme_dark'));
    }
    return this.localized($r('app.string.theme_system'));
  }

  private colorThemeLabelLocalized(theme: ColorTheme): string {
    return colorThemeLabel(theme);
  }

  private languageLabel(mode: LanguageMode): Resource {
    if (mode === 'en') return $r('app.string.language_english');
    return $r('app.string.language_chinese');
  }

  private chooseLanguage(mode: LanguageMode): void {
    setLanguageMode(mode);
    this.expandedKey = '';
  }

  private toggleExpand(key: string): void {
    this.expandedKey = this.expandedKey === key ? '' : key;
  }

  /** 选中态主色：直接引用 @StorageLink actionPrimaryLink 让颜色主题切换时 @Builder 重执行。 */
  private resolvedPrimary(): string {
    return this.actionPrimaryLink !== '' ? this.actionPrimaryLink : settingsPalette(this.isDark).primary;
  }

  @Builder
  private themeButton(mode: ThemeMode) {
    Button(this.themeLabel(mode))
      .height(36)
      .fontSize(13)
      .fontColor(this.themeMode === mode ? '#FFFFFF' : settingsPalette(this.isDark).textSecondary)
      .backgroundColor(this.themeMode === mode ? this.resolvedPrimary() : settingsPalette(this.isDark).chipBg)
      .borderRadius(18)
      .margin({ right: 8, bottom: 6 })
      .onClick(() => {
        this.onThemeChange(mode);
      })
  }

  /**
   * 颜色主题 chip：左侧渐变色条（3 档色阶预览）+ 文本，背景色选中态用主题色。
   * 色条用 colorThemeSwatchStops(theme) 返回的 [浅, 中, 深] 3 档 hex 做 linearGradient，
   * 让用户在选 chip 时就能看到该主题的色阶层次——蓝紫等冷色与绿橙黄等暖色都能通过渐变看出"颜色丰富度"。
   */
  @Builder
  private colorThemeButton(theme: ColorTheme) {
    Button() {
      Row({ space: 6 }) {
        // 渐变色条：18×12 圆角矩形，从浅到深 3 档色阶，替代原 12×12 纯色 Circle
        Row()
          .width(18)
          .height(12)
          .borderRadius(6)
          .linearGradient({
            angle: 90,
            colors: this.swatchColors(theme)
          })
        Text(this.colorThemeLabelLocalized(theme))
          .fontSize(13)
          .fontColor(this.colorTheme === theme ? '#FFFFFF' : settingsPalette(this.isDark).textSecondary)
      }
    }
    .type(ButtonType.Normal)
    .height(36)
    .padding({ left: 12, right: 14 })
    .backgroundColor(this.colorTheme === theme ? this.resolvedPrimary() : settingsPalette(this.isDark).chipBg)
    .borderRadius(18)
    .margin({ right: 8, bottom: 6 })
    .onClick(() => {
      this.onColorThemeChange(theme);
    })
  }

  /** 把 colorThemeSwatchStops 返回的 3 档 hex 转为 linearGradient 需要的 [color, stop] 数组。 */
  private swatchColors(theme: ColorTheme): Array<[ResourceColor, number]> {
    const stops: string[] = colorThemeSwatchStops(theme);
    return [
      [stops[0] as ResourceColor, 0.0],
      [stops[1] as ResourceColor, 0.5],
      [stops[2] as ResourceColor, 1.0]
    ];
  }

  @Builder
  private languageButton(mode: LanguageMode) {
    Button(this.languageLabel(mode))
      .height(36)
      .fontSize(13)
      .fontColor(currentLanguageMode() === mode ? '#FFFFFF' : settingsPalette(this.isDark).textSecondary)
      .backgroundColor(currentLanguageMode() === mode ? this.resolvedPrimary() : settingsPalette(this.isDark).chipBg)
      .borderRadius(18)
      .margin({ right: 8, bottom: 6 })
      .onClick((): void => this.chooseLanguage(mode))
  }

  @Builder
  private groupHeader() {
    Row() {
      Text(this.localized($r('app.string.settings_appearance_language')))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(settingsPalette(this.isDark).textSecondary)
      Blank()
      Text('▼')
        .fontSize(11)
        .fontColor(settingsPalette(this.isDark).textMuted)
        .rotate({ angle: this.opened ? 0 : -90 })
    }
    .width('100%')
    .height(40)
    .onClick(() => {
      animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.onToggle(); });
    })
  }

  build() {
    Column() {
      this.groupHeader()

      if (this.opened) {
        Column() {
          // 主题行（深浅色模式）
          Row() {
            Text($r('app.string.appearance_theme'))
              .fontSize(15)
              .fontColor(settingsPalette(this.isDark).textPrimary)
            Blank()
            Row({ space: 6 }) {
              Text(this.themeLabel(this.themeMode))
                .fontSize(13)
                .fontColor(settingsPalette(this.isDark).textTertiary)
              Text('▼')
                .fontSize(11)
                .fontColor(settingsPalette(this.isDark).textMuted)
                .rotate({ angle: this.expandedKey === 'themeMode' ? 0 : -90 })
            }
          }
          .width('100%')
          .height(48)
          .onClick(() => {
            animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.toggleExpand('themeMode'); });
          })

          if (this.expandedKey === 'themeMode') {
            Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
              this.themeButton('system');
              this.themeButton('light');
              this.themeButton('dark');
            }
            .width('100%')
            .padding({ top: 4, bottom: 8 })
          }

          // 颜色主题行（主色调：极光蓝/仙野绿/暗夜紫/碧涛青/活力橙/柠檬金）
          Row() {
            Text('颜色主题')
              .fontSize(15)
              .fontColor(settingsPalette(this.isDark).textPrimary)
            Blank()
            Row({ space: 6 }) {
              // 当前主题渐变色条预览（与 chip 内色条同款）
              Row()
                .width(18)
                .height(12)
                .borderRadius(6)
                .linearGradient({
                  angle: 90,
                  colors: this.swatchColors(this.colorTheme)
                })
              Text(this.colorThemeLabelLocalized(this.colorTheme))
                .fontSize(13)
                .fontColor(settingsPalette(this.isDark).textTertiary)
              Text('▼')
                .fontSize(11)
                .fontColor(settingsPalette(this.isDark).textMuted)
                .rotate({ angle: this.expandedKey === 'colorTheme' ? 0 : -90 })
            }
          }
          .width('100%')
          .height(48)
          .onClick(() => {
            animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.toggleExpand('colorTheme'); });
          })

          if (this.expandedKey === 'colorTheme') {
            Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
              this.colorThemeButton('aurora');
              this.colorThemeButton('forest');
              this.colorThemeButton('midnight');
              this.colorThemeButton('lagoon');
              this.colorThemeButton('sunset');
              this.colorThemeButton('lemon');
            }
            .width('100%')
            .padding({ top: 4, bottom: 8 })
          }

          // 语言行
          Row() {
            Text($r('app.string.settings_language'))
              .fontSize(15)
              .fontColor(settingsPalette(this.isDark).textPrimary)
            Blank()
            Text(this.languageLabel(currentLanguageMode()))
              .fontSize(13)
              .fontColor(settingsPalette(this.isDark).textTertiary)
          }
          .width('100%')
          .height(48)
          .onClick(() => this.toggleExpand('languageMode'))

          if (this.expandedKey === 'languageMode') {
            Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
              this.languageButton('zh-Hans');
              this.languageButton('en');
            }
            .width('100%')
            .padding({ top: 4, bottom: 8 })
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(settingsPalette(this.isDark).bg)
    .borderRadius(12)
  }
}
