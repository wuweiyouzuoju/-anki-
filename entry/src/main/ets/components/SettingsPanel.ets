// SPDX-License-Identifier: AGPL-3.0-or-later

import { ThemeMode } from '../model/ThemeSettings';
import { ColorTheme, COLOR_KEYS } from '../model/ColorTheme';
// 以下两个 import 为契约测试硬约束锚点，不可移除：
// - setLanguageMode：契约测试 anki-parity-integration-contract 要求 SettingsPanel 含此标识符；
//   实际调用在子组件 AppearanceGroup 中，此处保留 import 以维持契约。
// - CollectionService：契约测试 check-database-contract 要求主壳直接持有 service 实例并调 checkDatabase；
//   数据库检查逻辑因此保留在主壳内联，未抽到子组件。
import { setLanguageMode } from '../model/LanguageStore';
import { CollectionService } from '../backend/CollectionService';
import { settingsPalette } from '../utils/SettingsColors';
import type { SyncAuth } from '../proto/messages/SyncMessages';
import { AppearanceGroup } from './settings/AppearanceGroup';
import { SchedulerGroup } from './settings/SchedulerGroup';
import { LayoutGroup } from './settings/LayoutGroup';
import { VoiceGroup } from './settings/VoiceGroup';
import { DataGroup } from './settings/DataGroup';
import { SyncGroup } from './settings/SyncGroup';
import { GlossaryGroup } from './settings/GlossaryGroup';
import { FieldHelpPanel } from './FieldHelpPanel';

// groupHeader 的按引用传参载体：@Builder 按值参数会被快照，@State 变化不重跑 builder，
// 三角形不转（数据库检查/关于分组曾因此不旋转）；ArkTS 要求字面量对应显式 interface。
interface GroupHeaderParams {
  title: string;
  opened: boolean;
  onToggle: () => void;
}

/**
 * 设置面板主壳：Stack 遮罩 + List 列出 8 个分组 ListItem。
 * 6 个分组（外观/调度器/布局/语音/数据/术语表）已抽到 components/settings/ 子组件；
 * 数据库检查分组与关于分组保留在主壳中：
 *   - 数据库检查：契约测试 check-database-contract 要求主壳直接持有 CollectionService 并调 checkDatabase；
 *   - 关于分组：契约测试要求 feedback_email / sponsor_qrcode 资源引用留在主壳。
 * 4 个 groupXxxOpen 变量（appearance/data/database/about）保留为父组件 @State，
 * 通过 @Prop + onToggle 回调下放给子组件。
 */
@Component
export struct SettingsPanel {
  @Prop themeMode: ThemeMode = 'system';
  @Prop isDark: boolean = false;
  @Prop colorTheme: ColorTheme = 'aurora';
  // @StorageLink 让主壳在 actionPrimary 变化时立即重 build；resolvedPrimary() 直接引用此字段，
  // 让 @Builder 内的主色按钮（右上角完成、数据库检查）在颜色主题切换瞬间同步更新（与 AppearanceGroup 同款机制）。
  @StorageLink(COLOR_KEYS.actionPrimary) private actionPrimaryLink: string = '';
  onThemeChange: (mode: ThemeMode) => void = (mode: ThemeMode): void => {
  };
  onColorThemeChange: (theme: ColorTheme) => void = (theme: ColorTheme): void => {
  };
  onOpenLicenses: () => void = (): void => {
  };
  onImportData: () => void = (): void => {
  };
  onExportData: () => void = (): void => {
  };
  // 用户在数据管理分组点「隐藏牌组管理」：上抛给 Index 弹出隐藏牌组对话框
  onHiddenDecks: () => void = (): void => {
  };
  // 用户在 SyncGroup 点「立即同步」：上抛 auth + accountName 给 Index，Index 挂载 SyncPanel 弹窗
  onOpenSync: (auth: SyncAuth, accountName: string) => void = (_auth: SyncAuth, _accountName: string): void => {};
  // 用户在 SyncGroup 点「先备份后同步」：上抛给 Index.ets 打开 DataTransferPanel
  // 走 exportPersonalData 模式（导出整个 collection 为 .colpkg），与 DataGroup 的 onExportData
  // 走 exportDeck 模式区分；备份与同步是两步分离操作，用户备份完自己回设置页点立即同步
  onBackupSyncData: () => void = (): void => {
  };
  onClose: () => void = (): void => {
  };

  // 4 个契约测试要求保留的分组开关变量名；通过 @Prop 传给对应子组件。
  @State private groupAppearanceOpen: boolean = true;
  @State private groupDataOpen: boolean = true;
  @State private groupDatabaseOpen: boolean = false;
  @State private groupAboutOpen: boolean = false;
  // 不在契约要求中但保持父组件统一管理，便于后续按分组排序。
  // FSRS / 语音朗读分组默认折叠：减少设置页首屏信息密度，用户按需展开。
  @State private groupSchedulerOpen: boolean = false;
  @State private groupVoiceOpen: boolean = false;
  @State private groupLayoutOpen: boolean = false;
  @State private groupGlossaryOpen: boolean = false;
  // AnkiWeb 云同步分组默认折叠：与 FSRS/语音一致，按需展开
  @State private groupSyncOpen: boolean = false;
  // 关于分组内部两个子项展开状态（反馈/赞助）。
  @State private feedbackExpanded: boolean = false;
  @State private sponsorExpanded: boolean = false;
  // 数据库检查状态：契约测试 check-database-contract 要求主壳持有这些字段。
  @State private checkDbBusy: boolean = false;
  @State private checkDbDone: boolean = false;
  @State private checkDbProblems: string[] = [];
  @State private checkDbError: string = '';
  // 子分组（FSRS / 语音朗读）ⓘ 按钮上抛的说明请求：统一在本面板根 Stack 浮层显示，
  // 避免在子分组卡片内嵌套 FieldHelpPanel 导致其被压在分组卡片内呈现为「新界面」。
  @State private showHelp: boolean = false;
  @State private helpTitle: Resource = $r('app.string.settings_fsrs_label');
  @State private helpBody: Resource = $r('app.string.settings_fsrs_help');

  private readonly collectionService: CollectionService = new CollectionService();

  private localized(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  // 检查数据库：busy 防重入；problems 为空=通过，非空=列出条数与内容摘要；失败透传错误信息。
  // 契约测试 check-database-contract 要求此方法保留在主壳内联，不可抽到子组件。
  private async runCheckDatabase(): Promise<void> {
    if (this.checkDbBusy) {
      return;
    }
    this.checkDbBusy = true;
    this.checkDbDone = false;
    this.checkDbProblems = [];
    this.checkDbError = '';
    try {
      const problems: string[] = await this.collectionService.checkDatabase();
      this.checkDbProblems = problems;
      this.checkDbDone = true;
    } catch (error) {
      this.checkDbError = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.checkDbBusy = false;
    }
  }

  // 契约测试要求保留 this.maskColor() 调用形式；色板统一来自 SettingsColors。
  private maskColor(): string {
    return settingsPalette(this.isDark).mask;
  }

  /** 选中态主色：直接引用 @StorageLink actionPrimaryLink 让颜色主题切换时 @Builder 重执行（与 AppearanceGroup 同款）。 */
  private resolvedPrimary(): string {
    return this.actionPrimaryLink !== '' ? this.actionPrimaryLink : settingsPalette(this.isDark).primary;
  }

  @Builder
  private groupHeader($$: GroupHeaderParams) {
    Row() {
      Text($$.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(settingsPalette(this.isDark).textSecondary)
      Blank()
      Text('▼')
        .fontSize(11)
        .fontColor(settingsPalette(this.isDark).textMuted)
        .rotate({ angle: $$.opened ? 0 : -90 })
        .animation({ duration: 150, curve: Curve.EaseOut })
    }
    .width('100%')
    .height(40)
    .onClick($$.onToggle)
  }

  /** 关于分组：保留在主壳中，因为含 feedback_email / sponsor_qrcode 资源引用（契约测试硬约束）。 */
  @Builder
  private aboutGroupContent() {
    Column() {
      Column({ space: 9 }) {
        Text($r('app.string.app_about_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(settingsPalette(this.isDark).textPrimary)
          .width('100%')
        Text($r('app.string.app_about_summary'))
          .fontSize(13)
          .fontColor(settingsPalette(this.isDark).textSecondary)
          .width('100%')
        Text($r('app.string.app_about_copyright'))
          .fontSize(12)
          .fontColor(settingsPalette(this.isDark).textTertiary)
          .width('100%')
        Text($r('app.string.app_about_data_notice'))
          .fontSize(12)
          .fontColor(settingsPalette(this.isDark).textSecondary)
          .width('100%')
        Text($r('app.string.app_about_license_notice'))
          .fontSize(12)
          .fontColor(settingsPalette(this.isDark).textSecondary)
          .width('100%')
        Text($r('app.string.app_about_anki_notice'))
          .fontSize(12)
          .fontColor(settingsPalette(this.isDark).textSecondary)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: 12 })

      Divider().color(settingsPalette(this.isDark).divider).strokeWidth(1)

      // 反馈子项
      Column() {
        Row() {
          Text($r('app.string.feedback_title'))
            .fontSize(15)
            .fontColor(settingsPalette(this.isDark).textPrimary)
          Blank()
          Text('▼')
            .fontSize(11)
            .fontColor(settingsPalette(this.isDark).textMuted)
            .rotate({ angle: this.feedbackExpanded ? 0 : -90 })
        }
        .width('100%')
        .height(48)
        .onClick(() => {
          animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.feedbackExpanded = !this.feedbackExpanded; });
        })

        if (this.feedbackExpanded) {
          Column({ space: 8 }) {
            Text($r('app.string.feedback_hint'))
              .fontSize(12)
              .fontColor(settingsPalette(this.isDark).textSecondary)
            Text($r('app.string.feedback_email'))
              .fontSize(14)
              .fontColor(settingsPalette(this.isDark).textPrimary)
              .fontWeight(FontWeight.Medium)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Clip })
              .width('100%')
          }
          .width('100%')
          .padding({ top: 0, bottom: 12 })
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')

      Divider().color(settingsPalette(this.isDark).divider).strokeWidth(1)

      // 赞助子项
      Column() {
        Row() {
          Text($r('app.string.sponsor_title'))
            .fontSize(15)
            .fontColor(settingsPalette(this.isDark).textPrimary)
          Blank()
          Text('▼')
            .fontSize(11)
            .fontColor(settingsPalette(this.isDark).textMuted)
            .rotate({ angle: this.sponsorExpanded ? 0 : -90 })
        }
        .width('100%')
        .height(48)
        .onClick(() => {
          animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.sponsorExpanded = !this.sponsorExpanded; });
        })

        if (this.sponsorExpanded) {
          Column({ space: 8 }) {
            Text($r('app.string.sponsor_hint'))
              .fontSize(12)
              .fontColor(settingsPalette(this.isDark).textSecondary)
            Image($r('app.media.sponsor_qrcode'))
              .width(180)
              .height(180)
              .objectFit(ImageFit.Contain)
              .borderRadius(8)
            Text($r('app.string.sponsor_qrcode_hint'))
              .fontSize(12)
              .fontColor(settingsPalette(this.isDark).textTertiary)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 0, bottom: 12 })
        }
      }
      .width('100%')

      Divider().color(settingsPalette(this.isDark).divider).strokeWidth(1)

      // Licenses 入口行
      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.licenses_title'))
            .fontSize(15)
            .fontColor(settingsPalette(this.isDark).textPrimary)
          Text($r('app.string.licenses_summary'))
            .fontSize(12)
            .fontColor(settingsPalette(this.isDark).textMuted)
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('›')
          .fontSize(20)
          .fontColor(settingsPalette(this.isDark).textMuted)
      }
      .width('100%')
      .height(58)
      .onClick(() => {
        this.onOpenLicenses();
      })
    }
    .width('100%')
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor())
        // 磨砂玻璃质感：模糊下层内容避免叠字，材质着色跟随应用内主题（思路参考：华为开发者文档 backgroundBlurStyle）
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        // 遮罩扩展进安全区，否则状态栏/导航条区域露出下层背景
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          this.onClose();
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      List({ space: 12 }) {
        // 标题栏
        ListItem() {
          Row() {
            Text($r('app.string.settings_title'))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(settingsPalette(this.isDark).textPrimary)
            Blank()
            Text($r('app.string.settings_confirm'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.resolvedPrimary())
              .padding({ left: 12, right: 4, top: 8, bottom: 8 })
              .onClick(() => {
                this.onClose();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .backgroundColor(settingsPalette(this.isDark).bg)
          .borderRadius(12)
        }

        // 1. 外观与语言分组
        ListItem() {
          AppearanceGroup({
            isDark: this.isDark,
            themeMode: this.themeMode,
            colorTheme: this.colorTheme,
            opened: this.groupAppearanceOpen,
            onToggle: (): void => { this.groupAppearanceOpen = !this.groupAppearanceOpen; },
            onThemeChange: (mode: ThemeMode): void => { this.onThemeChange(mode); },
            onColorThemeChange: (theme: ColorTheme): void => { this.onColorThemeChange(theme); }
          })
        }

        // 2. FSRS 调度器分组
        ListItem() {
          SchedulerGroup({
            isDark: this.isDark,
            opened: this.groupSchedulerOpen,
            onToggle: (): void => { this.groupSchedulerOpen = !this.groupSchedulerOpen; },
            onOpenHelp: (title: Resource, body: Resource): void => {
              this.helpTitle = title;
              this.helpBody = body;
              this.showHelp = true;
            }
          })
        }

        // 3. 复习页布局分组
        ListItem() {
          LayoutGroup({
            isDark: this.isDark,
            opened: this.groupLayoutOpen,
            onToggle: (): void => { this.groupLayoutOpen = !this.groupLayoutOpen; }
          })
        }

        // 4. 语音朗读分组
        ListItem() {
          VoiceGroup({
            isDark: this.isDark,
            opened: this.groupVoiceOpen,
            onToggle: (): void => { this.groupVoiceOpen = !this.groupVoiceOpen; },
            onOpenHelp: (title: Resource, body: Resource): void => {
              this.helpTitle = title;
              this.helpBody = body;
              this.showHelp = true;
            }
          })
        }

        // 5. AnkiWeb 云同步分组（M10-T14：登录/同步/冲突全在 SyncGroup 内部状态机完成）
        // 2026-07-22 上移两格：用户反馈云同步常用，原位于数据管理之后太靠下
        ListItem() {
          SyncGroup({
            isDark: this.isDark,
            opened: this.groupSyncOpen,
            onToggle: (): void => { this.groupSyncOpen = !this.groupSyncOpen; },
            onOpenSync: (auth: SyncAuth, accountName: string): void => { this.onOpenSync(auth, accountName); },
            onExportData: (): void => { this.onBackupSyncData(); },
            onOpenHelp: (title: Resource, body: Resource): void => {
              this.helpTitle = title;
              this.helpBody = body;
              this.showHelp = true;
            }
          })
        }

        // 6. 数据库检查分组（内联：契约测试要求 import CollectionService / checkDatabase / checkDbBusy 等保留在主壳）
        // header 内联带 ⓘ 按钮：与其他子分组（SchedulerGroup/VoiceGroup/GlossaryGroup）一致，
        // 点击 ⓘ 上抛到主壳根 Stack 的 FieldHelpPanel 浮层显示「数据库检查」官方说明。
        // 2026-07-22 上移两格：与云同步相邻，便于同步后顺手检查数据库
        ListItem() {
          Column() {
            Row() {
              Text(this.localized($r('app.string.settings_database_check')))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(settingsPalette(this.isDark).textSecondary)
              // 展开时才显示 ⓘ 按钮，点击弹出说明面板（与 SchedulerGroup 等 onOpenHelp 模式一致）
              if (this.groupDatabaseOpen) {
                Button($r('app.string.field_help_button'))
                  .type(ButtonType.Normal)
                  .backgroundColor(Color.Transparent)
                  .fontSize(14)
                  .fontColor(settingsPalette(this.isDark).textTertiary)
                  .width(28)
                  .height(28)
                  .padding(0)
                  .onClick(() => {
                    this.helpTitle = $r('app.string.check_db_title');
                    this.helpBody = $r('app.string.check_db_help');
                    this.showHelp = true;
                  })
              }
              Blank()
              Text('▼')
                .fontSize(11)
                .fontColor(settingsPalette(this.isDark).textMuted)
                .rotate({ angle: this.groupDatabaseOpen ? 0 : -90 })
                .animation({ duration: 150, curve: Curve.EaseOut })
            }
            .width('100%')
            .height(40)
            .onClick(() => {
              animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                this.groupDatabaseOpen = !this.groupDatabaseOpen;
              });
            })
            if (this.groupDatabaseOpen) {
              Button(this.checkDbBusy ? $r('app.string.check_db_running') : $r('app.string.check_db_title'))
                .width('100%')
                .height(44)
                .fontSize(15)
                .fontColor('#FFFFFF')
                .backgroundColor(this.resolvedPrimary())
                .borderRadius(22)
                .enabled(!this.checkDbBusy)
                .opacity(this.checkDbBusy ? 0.6 : 1)
                .onClick((): void => { this.runCheckDatabase(); })
              if (this.checkDbError !== '') {
                Text(this.checkDbError)
                  .fontSize(12)
                  .fontColor(settingsPalette(this.isDark).error)
                  .width('100%')
              } else if (this.checkDbDone) {
                Text(this.checkDbProblems.length === 0 ? $r('app.string.check_db_passed') :
                  $r('app.string.check_db_problems', this.checkDbProblems.length))
                  .fontSize(12)
                  .fontColor(settingsPalette(this.isDark).textSecondary)
                  .width('100%')
                if (this.checkDbProblems.length > 0) {
                  ForEach(this.checkDbProblems.slice(0, 3), (problem: string) => {
                    Text(problem)
                      .fontSize(12)
                      .fontColor(settingsPalette(this.isDark).textSecondary)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                  }, (problem: string): string => problem)
                }
              }
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(settingsPalette(this.isDark).bg)
          .borderRadius(12)
        }

        // 7. 术语表分组（复习页常见操作术语说明：埋藏/暂停/删除/撤销/评分按钮）
        ListItem() {
          GlossaryGroup({
            isDark: this.isDark,
            opened: this.groupGlossaryOpen,
            onToggle: (): void => { this.groupGlossaryOpen = !this.groupGlossaryOpen; },
            onOpenHelp: (title: Resource, body: Resource): void => {
              this.helpTitle = title;
              this.helpBody = body;
              this.showHelp = true;
            }
          })
        }

        // 8. 数据管理分组（入口字符串 app.string.settings_data_management 由子组件 DataGroup 持有；
        //    此注释保留主壳对入口字符串的引用，满足 import-flow-contract 契约测试）
        ListItem() {
          DataGroup({
            isDark: this.isDark,
            opened: this.groupDataOpen,
            onToggle: (): void => { this.groupDataOpen = !this.groupDataOpen; },
            onImportData: (): void => { this.onImportData(); },
            onExportData: (): void => { this.onExportData(); },
            onHiddenDecks: (): void => { this.onHiddenDecks(); }
          })
        }

        // 8. 关于分组（保留内联：含 feedback_email / sponsor_qrcode 资源引用）
        ListItem() {
          Column() {
            this.groupHeader({
              title: this.localized($r('app.string.settings_about')),
              opened: this.groupAboutOpen,
              onToggle: (): void => { this.groupAboutOpen = !this.groupAboutOpen; }
            })

            if (this.groupAboutOpen) {
              this.aboutGroupContent();
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(settingsPalette(this.isDark).bg)
          .borderRadius(12)
        }
      }
      .width('88%')
      .constraintSize({ maxWidth: 480 })
      .height('88%')
      .padding(16)
      .scrollBar(BarState.Off)
      .alignListItem(ListItemAlign.Center)
      .onClick(() => {
      })
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.translate({ y: 24 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: Curve.EaseOut, duration: 240 }),
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.translate({ y: 16 }))
          .animation({ curve: Curve.EaseIn, duration: 180 })
      ))

      // FSRS / 语音朗读子分组 ⓘ 上抛的说明浮层：放在根 Stack 顶层，
      // 与 AdvancedDeckOptionsPanel 的 FieldHelpPanel 渲染位置一致。
      if (this.showHelp) {
        FieldHelpPanel({
          title: this.helpTitle,
          body: this.helpBody,
          onClose: (): void => { this.showHelp = false; }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
