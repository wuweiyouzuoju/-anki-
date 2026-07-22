// SPDX-License-Identifier: AGPL-3.0-or-later

import { listAllVoices, downloadVoiceForVoice, VoiceRow, DownloadResult } from '../../utils/TtsVoiceHelper';
import { SettingsPalette, settingsPalette } from '../../utils/SettingsColors';
import { loadVoicePerson, saveVoicePerson } from '../../model/TtsVoiceStore';
import { COLOR_KEYS } from '../../model/ColorTheme';

/**
 * 语音朗读分组：动态列出本机所有可用的 TTS 音色，每个 voice 单独成行，
 * 显示 description/gender/person + 安装状态 + 下载入口 + 音色选择。
 *
 * 数据来源：textToSpeech.listVoices（鸿蒙 CoreSpeechKit）。
 * - listVoices 返回所有 INSTALLED + GA（可下载未安装）音色；每个 voice 单独成行展示。
 * - INSTALLED 音色可点「选择」按钮设为该语种朗读用音色（存到 TtsVoiceStore）。
 * - GA 音色点「下载」按钮拉起系统下载弹窗。
 * - listVoices 失败时显示「读取失败」提示，引导用户去系统设置。
 *
 * 下载流程：用户点下载 → 系统下载弹窗 → complete/cancel/error 任一回调 settle。
 * 防重入：downloadingKey 记录当前下载中的 voice key（language+person），下载期间禁用其他下载按钮。
 */
@Component
export struct VoiceGroup {
  @Prop isDark: boolean = false;
  @Prop opened: boolean = false;
  onToggle: () => void = (): void => {};
  // ⓘ 按钮上抛：由父组件 SettingsPanel 统一渲染 FieldHelpPanel 浮层，避免嵌在分组卡片内
  onOpenHelp: (title: Resource, body: Resource) => void = (_title: Resource, _body: Resource): void => {};

  // @StorageLink 让本组件在 actionPrimary 变化时立即重渲染；resolvedPrimary() 直接引用此字段，
  // 让音色列表主色在颜色主题切换瞬间同步更新（与 AppearanceGroup 同款机制）。
  @StorageLink(COLOR_KEYS.actionPrimary) private actionPrimaryLink: string = '';

  /** 音色列表加载状态：'loading' / 'ready' / 'unsupported'。 */
  @State private listStatus: string = 'loading';
  /** listVoices 返回的音色行（每个 voice 一行）。 */
  @State private voiceRows: VoiceRow[] = [];
  /** 当前正在下载的 voice key（language+person，用于防重入 + UI 标记）。空字符串表示无下载进行中。 */
  @State private downloadingKey: string = '';
  /** 每个 language 用户选中的 person（从 TtsVoiceStore 加载）。key=language, value=person。 */
  @State private selectedPersonByLang: Map<string, number> = new Map<string, number>();
  /** 单次下载结果提示（成功/失败/取消），带音色描述前缀。 */
  @State private downloadMessage: string = '';
  /** downloadMessage 的语义类别：success/error/info。 */
  @State private downloadMessageKind: 'success' | 'error' | 'info' = 'info';

  async aboutToAppear(): Promise<void> {
    // 不阻塞面板打开：音色列表加载异步进行，UI 先显示"正在检查…"
    this.refreshVoiceList();
  }

  /**
   * 重新拉取 listVoices 音色列表 + 每个语种选中的 person。
   * 失败时标记 unsupported 让 UI 显示兜底提示。
   */
  private async refreshVoiceList(): Promise<void> {
    this.listStatus = 'loading';
    const rows: VoiceRow[] = await listAllVoices();
    // listVoices 返回空数组：要么系统无可用音色，要么 API 调用失败；统一显示 unsupported。
    if (rows.length === 0) {
      this.listStatus = 'unsupported';
      this.voiceRows = [];
      return;
    }
    this.voiceRows = rows;
    // 加载每个 language 用户选中的 person（并行加载，避免串行延迟）
    const langSet: Set<string> = new Set<string>();
    for (const row of rows) {
      langSet.add(row.language);
    }
    const nextMap: Map<string, number> = new Map<string, number>();
    const langArr: string[] = Array.from(langSet);
    for (const lang of langArr) {
      nextMap.set(lang, await loadVoicePerson(lang));
    }
    this.selectedPersonByLang = nextMap;
    this.listStatus = 'ready';
  }

  /** voice 唯一 key（language+person，用于防重入和 ForEach key）。 */
  private voiceKey(row: VoiceRow): string {
    return `${row.language}#${row.person}`;
  }

  /** 点击下载按钮：调 downloadVoiceForVoice 拉起系统下载弹窗，等回调 settle。 */
  private async onDownloadClick(row: VoiceRow): Promise<void> {
    if (this.downloadingKey !== '') {
      return;
    }
    const key: string = this.voiceKey(row);
    this.downloadingKey = key;
    this.downloadMessage = '';
    this.downloadMessageKind = 'info';
    try {
      const result: DownloadResult = await downloadVoiceForVoice(row.language, row.person);
      if (result.status === 'complete') {
        this.downloadMessageKind = 'success';
        this.downloadMessage = `${row.description} 下载成功`;
        // 下载完成立即重新探测，UI 自动从 not_installed 切到 installed
        this.refreshVoiceList();
      } else {
        // status === 'cancel'：用户取消不算错误
        this.downloadMessageKind = 'info';
        this.downloadMessage = `${row.description} 下载已取消`;
      }
    } catch (error) {
      this.downloadMessageKind = 'error';
      const errDetail: string = error instanceof Error ? error.message : `${error}`;
      this.downloadMessage = `${row.description} 下载失败：${errDetail}`;
    } finally {
      this.downloadingKey = '';
    }
  }

  /** 点击选择按钮：将该 language 的朗读用音色设为该 voice 的 person，存到 TtsVoiceStore。 */
  private async onSelectClick(row: VoiceRow): Promise<void> {
    await saveVoicePerson(row.language, row.person);
    const next: Map<string, number> = new Map<string, number>(this.selectedPersonByLang);
    next.set(row.language, row.person);
    this.selectedPersonByLang = next;
    this.downloadMessageKind = 'info';
    this.downloadMessage = `${row.description} 已设为 ${this.languageDisplayName(row.language)} 朗读音色`;
  }

  /** 判断该 voice 是否为当前语种选中的朗读音色。 */
  private isVoiceSelected(row: VoiceRow): boolean {
    const selected: number | undefined = this.selectedPersonByLang.get(row.language);
    return selected !== undefined && selected === row.person;
  }

  private localized(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  /** 选中态主色：直接引用 @StorageLink actionPrimaryLink 让颜色主题切换时 @Builder 重执行（与 AppearanceGroup 同款）。 */
  private resolvedPrimary(): string {
    return this.actionPrimaryLink !== '' ? this.actionPrimaryLink : settingsPalette(this.isDark).primary;
  }

  /** 把语种代码转成本地化显示名。 */
  private languageDisplayName(language: string): string {
    // 常见语种中文映射，避免依赖未确认的 i18n API。未覆盖的语种直接显示代码。
    const map: Record<string, string> = {
      'zh-CN': '中文（简体）',
      'zh-TW': '中文（繁體）',
      'zh-HK': '中文（香港）',
      'en-US': 'English (US)',
      'en-GB': 'English (UK)',
      'ja-JP': '日本語',
      'ko-KR': '한국어',
      'fr-FR': 'Français',
      'de-DE': 'Deutsch',
      'es-ES': 'Español',
      'es-MX': 'Español (México)',
      'it-IT': 'Italiano',
      'pt-BR': 'Português (Brasil)',
      'ru-RU': 'Русский',
      'ar-SA': 'العربية',
      'hi-IN': 'हिन्दी',
      'th-TH': 'ไทย',
      'vi-VN': 'Tiếng Việt',
      'id-ID': 'Bahasa Indonesia',
      'tr-TR': 'Türkçe',
      'pl-PL': 'Polski',
      'nl-NL': 'Nederlands',
      'sv-SE': 'Svenska'
    };
    const name: string | undefined = map[language];
    return name !== undefined ? name : language;
  }

  @Builder
  private groupHeader(palette: SettingsPalette) {
    Row() {
      Text(this.localized($r('app.string.settings_audio_voice')))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(palette.textSecondary)
      // 展开时才显示 ⓘ 按钮，点击弹出说明面板（替代原内联说明小字）
      if (this.opened) {
        Button($r('app.string.field_help_button'))
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontSize(14)
          .fontColor(palette.textTertiary)
          .width(28)
          .height(28)
          .padding(0)
          .onClick(() => {
            this.onOpenHelp($r('app.string.settings_audio_voice'), $r('app.string.settings_audio_voice_hint'));
          })
      }
      Blank()
      Text('▼')
        .fontSize(11)
        .fontColor(palette.textMuted)
        .rotate({ angle: this.opened ? 0 : -90 })
    }
    .width('100%')
    .height(40)
    .onClick(() => {
      animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.onToggle(); });
    })
  }

  @Builder
  private voiceRowBuilder(row: VoiceRow, palette: SettingsPalette) {
    Column({ space: 6 }) {
      Row() {
        Column({ space: 2 }) {
          // 音色描述（如 "中文 聆小珊女声" / "English US Voice"）
          Text(row.description !== '' ? row.description : this.languageDisplayName(row.language))
            .fontSize(14)
            .fontColor(palette.textPrimary)
          // 副信息：language + person + gender
          Row({ space: 6 }) {
            Text(row.language)
              .fontSize(11)
              .fontColor(palette.textMuted)
            Text(`person=${row.person}`)
              .fontSize(11)
              .fontColor(palette.textMuted)
            if (row.gender !== '') {
              Text(row.gender === 'Female' ? '女声' : row.gender === 'Male' ? '男声' : row.gender)
                .fontSize(11)
                .fontColor(palette.textMuted)
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 状态徽章
        Text(row.installed
          ? this.localized($r('app.string.settings_voice_status_installed'))
          : this.localized($r('app.string.settings_voice_status_not_installed')))
          .fontSize(12)
          .fontColor(row.installed ? this.resolvedPrimary() : palette.textTertiary)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(10)
          .backgroundColor(palette.chipBg)

        // 已安装：显示"选择"按钮（选中状态用 isVoiceSelected 判断）
        if (row.installed) {
          Button(this.isVoiceSelected(row) ? '已选中' : '选择')
            .height(30)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.isVoiceSelected(row) ? palette.textTertiary : this.resolvedPrimary())
            .borderRadius(15)
            .enabled(!this.isVoiceSelected(row))
            .opacity(this.isVoiceSelected(row) ? 0.6 : 1)
            .margin({ left: 8 })
            .onClick((): void => { this.onSelectClick(row); })
        } else {
          // 未安装：显示下载按钮
          Button(this.downloadingKey === this.voiceKey(row)
            ? this.localized($r('app.string.settings_voice_downloading'))
            : this.localized($r('app.string.settings_voice_download_btn_lang')))
            .height(30)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.resolvedPrimary())
            .borderRadius(15)
            .enabled(this.downloadingKey === '')
            .opacity(this.downloadingKey === '' ? 1 : 0.4)
            .margin({ left: 8 })
            .onClick((): void => { this.onDownloadClick(row); })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    Column() {
      this.groupHeader(settingsPalette(this.isDark))

      if (this.opened) {
        Column({ space: 10 }) {
          // 顶部说明小字已移到 groupHeader 的 ⓘ 按钮弹层中

          // 显式提示「按语种独立选音色」：避免用户在 zh-CN 选了凌飞哲期待英文也变男声
          // （2026-07-21 加：用户反馈「选中声音后英语卡片没改变」根因之一即此认知偏差）
          Text(this.localized($r('app.string.settings_voice_per_language_hint')))
            .fontSize(12)
            .fontColor(settingsPalette(this.isDark).textSecondary)
            .width('100%')
            .maxLines(3)
            .textAlign(TextAlign.Start)

          // 加载中
          if (this.listStatus === 'loading') {
            Row() {
              Text(this.localized($r('app.string.settings_voice_checking')))
                .fontSize(13)
                .fontColor(settingsPalette(this.isDark).textTertiary)
              Blank()
              LoadingProgress()
                .width(18)
                .height(18)
                .color(this.resolvedPrimary())
            }
            .width('100%')
          } else if (this.listStatus === 'unsupported') {
            // 系统不支持 listVoices：兜底提示
            Text($r('app.string.settings_voice_unsupported'))
              .fontSize(12)
              .fontColor(settingsPalette(this.isDark).textTertiary)
              .width('100%')
          } else if (this.voiceRows.length === 0) {
            // 边界：listVoices 成功但返回空
            Text($r('app.string.settings_voice_empty'))
              .fontSize(12)
              .fontColor(settingsPalette(this.isDark).textTertiary)
              .width('100%')
          } else {
            // 音色列表：key 用 voiceKey（language+person）避免同语种多音色冲突
            ForEach(this.voiceRows, (row: VoiceRow) => {
              this.voiceRowBuilder(row, settingsPalette(this.isDark))
            }, (row: VoiceRow): string => this.voiceKey(row))
          }

          // 下载结果提示（独立于语种列表显示在底部）
          if (this.downloadMessage !== '') {
            Text(this.downloadMessage)
              .fontSize(12)
              .fontColor(this.downloadMessageKind === 'success' ? this.resolvedPrimary()
                : this.downloadMessageKind === 'error' ? settingsPalette(this.isDark).error
                : settingsPalette(this.isDark).textTertiary)
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
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
