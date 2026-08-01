// SPDX-License-Identifier: AGPL-3.0-or-later

import { common, Want } from '@kit.AbilityKit';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { commentManager } from '@kit.AppGalleryKit';
import { 主题模式 } from '../model/主题设置';
import { 颜色主题, 颜色键 } from '../model/颜色主题';
import { 设置语言模式 } from '../model/语言存储';
import { 集合服务 } from '../backend/集合服务';
import { 设置面板色板_取 } from '../utils/设置面板配色';
import type { SyncAuth } from '../proto/messages/SyncMessages';
import { 外观分组 } from './settings/外观分组';
import { 调度器分组 } from './settings/调度器分组';
import { 布局分组 } from './settings/布局分组';
import { 数据分组 } from './settings/数据分组';
import { 同步分组 } from './settings/同步分组';
import { 术语分组 } from './settings/术语分组';
import { 字段帮助面板 } from './字段帮助面板';

interface 分组头部参数 {
  标题: string;
  已展开: boolean;
  切换回调: () => void;
}

@Component
export struct 设置面板 {
  @Prop 当前主题模式: 主题模式 = 'system';
  @Prop 是否深色: boolean = false;
  @Prop 当前颜色主题: 颜色主题 = 'aurora';
  @StorageLink(颜色键.动作主色) private 动作主色链接: string = '';
  @StorageLink(颜色键.主色按钮背景) private 主色按钮背景链接: string = '';
  主题模式切换回调: (模式: 主题模式) => void = (模式: 主题模式): void => {
  };
  颜色主题切换回调: (主题: 颜色主题) => void = (主题: 颜色主题): void => {
  };
  打开许可证回调: () => void = (): void => {
  };
  private readonly AnkiWeb网址: string = 'https://ankiweb.net/shared/decks';
  private readonly 本应用包名: string = 'com.jide.kapian';
  导入数据回调: () => void = (): void => {
  };
  导出数据回调: () => void = (): void => {
  };
  点击已隐藏牌组回调: () => void = (): void => {
  };
  打开同步弹窗回调: (凭证: SyncAuth, 账号名: string) => void = (_凭证: SyncAuth, _账号名: string): void => {};
  先备份后同步回调: () => void = (): void => {
  };
  关闭回调: () => void = (): void => {
  };

  @State private 外观分组展开: boolean = true;
  @State private 数据分组展开: boolean = true;
  @State private 数据库分组展开: boolean = false;
  @State private 关于分组展开: boolean = false;
  @State private 调度器分组展开: boolean = false;
  @State private 布局分组展开: boolean = false;
  @State private 术语分组展开: boolean = false;
  @State private 同步分组展开: boolean = false;
  @State private 反馈子项展开: boolean = false;
  @State private 赞助子项展开: boolean = false;
  @State private 数据库检查中: boolean = false;
  @State private 数据库检查完成: boolean = false;
  @State private 数据库问题列表: string[] = [];
  @State private 数据库错误信息: string = '';
  @State private 显示说明浮层: boolean = false;
  @State private 说明标题: Resource = $r('app.string.settings_fsrs_label');
  @State private 说明正文: Resource = $r('app.string.settings_fsrs_help');

  private readonly 集合服务实例: 集合服务 = new 集合服务();

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  private async 执行数据库检查(): Promise<void> {
    if (this.数据库检查中) {
      return;
    }
    this.数据库检查中 = true;
    this.数据库检查完成 = false;
    this.数据库问题列表 = [];
    this.数据库错误信息 = '';
    try {
      const 问题列表: string[] = await this.集合服务实例.检查数据库();
      this.数据库问题列表 = 问题列表;
      this.数据库检查完成 = true;
    } catch (error) {
      this.数据库错误信息 = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.数据库检查中 = false;
    }
  }

  private 遮罩色(): string {
    return 设置面板色板_取(this.是否深色).遮罩;
  }

  private 解析主色(): string {
    return this.动作主色链接 !== '' ? this.动作主色链接 : 设置面板色板_取(this.是否深色).主色;
  }

  private 解析主色按钮背景(): string {
    return this.主色按钮背景链接 !== '' ? this.主色按钮背景链接 : 设置面板色板_取(this.是否深色).主色按钮背景;
  }

  @Builder
  private 分组头部($$: 分组头部参数) {
    Row() {
      Text($$.标题)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(设置面板色板_取(this.是否深色).次文字)
      Blank()
      Text('▼')
        .fontSize(11)
        .fontColor(设置面板色板_取(this.是否深色).弱化文字)
        .rotate({ angle: $$.已展开 ? 0 : -90 })
        .animation({ duration: 150, curve: Curve.EaseOut })
    }
    .width('100%')
    .height(40)
    .onClick($$.切换回调)
  }

  private 打开AnkiWeb网址(): void {
    const 上下文: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    上下文.startAbility({
      action: 'ohos.want.action.viewData',
      uri: this.AnkiWeb网址
    }).catch((错误: Error): void => {
      this.复制AnkiWeb网址到剪贴板();
    });
  }

  private async 复制AnkiWeb网址到剪贴板(): Promise<void> {
    try {
      const 剪贴数据: pasteboard.PasteData =
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.AnkiWeb网址);
      const 系统剪贴板: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await 系统剪贴板.setData(剪贴数据);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.about_ankiweb_open_failed')
      });
    } catch (错误) {
    }
  }

  private 打开好评弹窗(): void {
    const 上下文: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      commentManager.showCommentDialog(上下文).then(() => {
        hilog.info(0x0001, '设置面板', 'showCommentDialog 成功');
      }).catch((错误: BusinessError) => {
        this.处理好评失败(错误);
      });
    } catch (错误) {
      this.处理好评失败(错误);
    }
  }

  private 处理好评失败(错误: BusinessError): void {
    hilog.error(0x0001, '设置面板', `showCommentDialog 失败 code=${错误.code} msg=${错误.message}`);
    this.跳转应用市场详情页();
  }

  private 跳转应用市场详情页(): void {
    const 上下文: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = {
      uri: `store://appgallery.huawei.com/app/detail?id=${this.本应用包名}`
    };
    上下文.startAbility(want).then(() => {
      hilog.info(0x0001, '设置面板', '回退 DeepLink 拉起应用市场成功');
    }).catch((错误: BusinessError) => {
      hilog.error(0x0001, '设置面板', `回退 DeepLink 失败 code=${错误.code} msg=${错误.message}`);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.about_rate_failed_fallback'),
        duration: 3000
      });
    });
  }

  @Builder
  private 关于分组内容() {
    Column() {
      Column({ space: 9 }) {
        Text($r('app.string.app_about_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(设置面板色板_取(this.是否深色).主文字)
          .width('100%')
        Text($r('app.string.app_about_copyright'))
          .fontSize(12)
          .fontColor(设置面板色板_取(this.是否深色).三级文字)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: 12 })

      Divider().color(设置面板色板_取(this.是否深色).分隔线).strokeWidth(1)

      Column() {
        Row() {
          Text($r('app.string.feedback_title'))
            .fontSize(15)
            .fontColor(设置面板色板_取(this.是否深色).主文字)
          Blank()
          Text('▼')
            .fontSize(11)
            .fontColor(设置面板色板_取(this.是否深色).弱化文字)
            .rotate({ angle: this.反馈子项展开 ? 0 : -90 })
        }
        .width('100%')
        .height(48)
        .onClick(() => {
          this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.反馈子项展开 = !this.反馈子项展开; });
        })

        if (this.反馈子项展开) {
          Column({ space: 8 }) {
            Text($r('app.string.feedback_hint'))
              .fontSize(12)
              .fontColor(设置面板色板_取(this.是否深色).次文字)
            Text($r('app.string.feedback_email'))
              .fontSize(14)
              .fontColor(设置面板色板_取(this.是否深色).主文字)
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

      Divider().color(设置面板色板_取(this.是否深色).分隔线).strokeWidth(1)

      Column() {
        Row() {
          Text($r('app.string.sponsor_title'))
            .fontSize(15)
            .fontColor(设置面板色板_取(this.是否深色).主文字)
          Blank()
          Text('▼')
            .fontSize(11)
            .fontColor(设置面板色板_取(this.是否深色).弱化文字)
            .rotate({ angle: this.赞助子项展开 ? 0 : -90 })
        }
        .width('100%')
        .height(48)
        .onClick(() => {
          this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.赞助子项展开 = !this.赞助子项展开; });
        })

        if (this.赞助子项展开) {
          Column({ space: 8 }) {
            Text($r('app.string.sponsor_hint'))
              .fontSize(12)
              .fontColor(设置面板色板_取(this.是否深色).次文字)
            Image($r('app.media.sponsor_qrcode'))
              .width(180)
              .height(180)
              .objectFit(ImageFit.Contain)
              .borderRadius(8)
            Text($r('app.string.sponsor_qrcode_hint'))
              .fontSize(12)
              .fontColor(设置面板色板_取(this.是否深色).三级文字)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 0, bottom: 12 })
        }
      }
      .width('100%')

      Divider().color(设置面板色板_取(this.是否深色).分隔线).strokeWidth(1)

      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.about_rate_title'))
            .fontSize(15)
            .fontColor(设置面板色板_取(this.是否深色).主文字)
          Text($r('app.string.about_rate_summary'))
            .fontSize(12)
            .fontColor(设置面板色板_取(this.是否深色).弱化文字)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Blank()
        Text('›')
          .fontSize(20)
          .fontColor(设置面板色板_取(this.是否深色).弱化文字)
      }
      .width('100%')
      .height(58)
      .onClick(() => {
        this.打开好评弹窗();
      })

      Divider().color(设置面板色板_取(this.是否深色).分隔线).strokeWidth(1)

      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.about_ankiweb_title'))
            .fontSize(15)
            .fontColor(设置面板色板_取(this.是否深色).主文字)
          Text(this.AnkiWeb网址)
            .fontSize(12)
            .fontColor(设置面板色板_取(this.是否深色).弱化文字)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Blank()
        Text('›')
          .fontSize(20)
          .fontColor(设置面板色板_取(this.是否深色).弱化文字)
      }
      .width('100%')
      .height(58)
      .onClick(() => {
        this.打开AnkiWeb网址();
      })

      Divider().color(设置面板色板_取(this.是否深色).分隔线).strokeWidth(1)

      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.licenses_title'))
            .fontSize(15)
            .fontColor(设置面板色板_取(this.是否深色).主文字)
          Text($r('app.string.licenses_summary'))
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
        this.打开许可证回调();
      })
    }
    .width('100%')
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.遮罩色())
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.是否深色 ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          this.关闭回调();
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      List({ space: 12 }) {
        ListItem() {
          Row() {
            Text($r('app.string.settings_title'))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(设置面板色板_取(this.是否深色).主文字)
            Blank()
            Text($r('app.string.settings_confirm'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.解析主色())
              .padding({ left: 12, right: 4, top: 8, bottom: 8 })
              .onClick(() => {
                this.关闭回调();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .backgroundColor(设置面板色板_取(this.是否深色).背景)
          .borderRadius(12)
        }

        ListItem() {
          外观分组({
            是否深色: this.是否深色,
            当前主题模式: this.当前主题模式,
            当前颜色主题: this.当前颜色主题,
            是否展开: this.外观分组展开,
            切换展开回调: (): void => { this.外观分组展开 = !this.外观分组展开; },
            主题模式切换回调: (模式: 主题模式): void => { this.主题模式切换回调(模式); },
            颜色主题切换回调: (主题: 颜色主题): void => { this.颜色主题切换回调(主题); }
          })
        }

        ListItem() {
          调度器分组({
            是否深色: this.是否深色,
            是否展开: this.调度器分组展开,
            切换展开回调: (): void => { this.调度器分组展开 = !this.调度器分组展开; },
            打开说明回调: (标题: Resource, 正文: Resource): void => {
              this.说明标题 = 标题;
              this.说明正文 = 正文;
              this.显示说明浮层 = true;
            }
          })
        }

        ListItem() {
          布局分组({
            是否深色: this.是否深色,
            是否展开: this.布局分组展开,
            切换展开回调: (): void => { this.布局分组展开 = !this.布局分组展开; }
          })
        }

        ListItem() {
          同步分组({
            是否深色: this.是否深色,
            是否展开: this.同步分组展开,
            切换展开回调: (): void => { this.同步分组展开 = !this.同步分组展开; },
            打开同步弹窗回调: (凭证: SyncAuth, 账号名: string): void => { this.打开同步弹窗回调(凭证, 账号名); },
            点击导出数据回调: (): void => { this.先备份后同步回调(); },
            打开说明回调: (标题: Resource, 正文: Resource): void => {
              this.说明标题 = 标题;
              this.说明正文 = 正文;
              this.显示说明浮层 = true;
            }
          })
        }

        ListItem() {
          Column() {
            Row() {
              Text(this.取本地化文本($r('app.string.settings_database_check')))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(设置面板色板_取(this.是否深色).次文字)
              if (this.数据库分组展开) {
                Button($r('app.string.field_help_button'))
                  .type(ButtonType.Normal)
                  .backgroundColor(Color.Transparent)
                  .fontSize(14)
                  .fontColor(设置面板色板_取(this.是否深色).三级文字)
                  .width(28)
                  .height(28)
                  .padding(0)
                  .onClick(() => {
                    this.说明标题 = $r('app.string.check_db_title');
                    this.说明正文 = $r('app.string.check_db_help');
                    this.显示说明浮层 = true;
                  })
              }
              Blank()
              Text('▼')
                .fontSize(11)
                .fontColor(设置面板色板_取(this.是否深色).弱化文字)
                .rotate({ angle: this.数据库分组展开 ? 0 : -90 })
                .animation({ duration: 150, curve: Curve.EaseOut })
            }
            .width('100%')
            .height(40)
            .onClick(() => {
              this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                this.数据库分组展开 = !this.数据库分组展开;
              });
            })
            if (this.数据库分组展开) {
              Button(this.数据库检查中 ? $r('app.string.check_db_running') : $r('app.string.check_db_title'))
                .width('100%')
                .height(44)
                .fontSize(15)
                .fontColor('#FFFFFF')
                .backgroundColor(this.解析主色按钮背景())
                .borderRadius(22)
                .enabled(!this.数据库检查中)
                .opacity(this.数据库检查中 ? 0.6 : 1)
                .onClick((): void => { this.执行数据库检查(); })
              if (this.数据库错误信息 !== '') {
                Text(this.数据库错误信息)
                  .fontSize(12)
                  .fontColor(设置面板色板_取(this.是否深色).错误色)
                  .width('100%')
                  .margin({ top: 10 })
              } else if (this.数据库检查完成) {
                Text(this.数据库问题列表.length === 0 ? $r('app.string.check_db_passed') :
                  $r('app.string.check_db_problems', this.数据库问题列表.length))
                  .fontSize(12)
                  .fontColor(设置面板色板_取(this.是否深色).次文字)
                  .width('100%')
                  .margin({ top: 10 })
                if (this.数据库问题列表.length > 0) {
                  ForEach(this.数据库问题列表.slice(0, 3), (问题: string) => {
                    Text(问题)
                      .fontSize(12)
                      .fontColor(设置面板色板_取(this.是否深色).次文字)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                  }, (问题: string): string => 问题)
                }
              }
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(设置面板色板_取(this.是否深色).背景)
          .borderRadius(12)
        }

        ListItem() {
          术语分组({
            是否深色: this.是否深色,
            是否展开: this.术语分组展开,
            切换展开回调: (): void => { this.术语分组展开 = !this.术语分组展开; },
            打开说明回调: (标题: Resource, 正文: Resource): void => {
              this.说明标题 = 标题;
              this.说明正文 = 正文;
              this.显示说明浮层 = true;
            }
          })
        }

        ListItem() {
          数据分组({
            是否深色: this.是否深色,
            是否展开: this.数据分组展开,
            切换展开回调: (): void => { this.数据分组展开 = !this.数据分组展开; },
            点击导出导入回调: (): void => { this.导出数据回调(); },
            点击已隐藏牌组回调: (): void => { this.点击已隐藏牌组回调(); }
          })
        }

        ListItem() {
          Column() {
            this.分组头部({
              标题: this.取本地化文本($r('app.string.settings_about')),
              已展开: this.关于分组展开,
              切换回调: (): void => { this.关于分组展开 = !this.关于分组展开; }
            })

            if (this.关于分组展开) {
              this.关于分组内容();
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(设置面板色板_取(this.是否深色).背景)
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

      if (this.显示说明浮层) {
        字段帮助面板({
          标题: this.说明标题,
          正文: this.说明正文,
          onClose: (): void => { this.显示说明浮层 = false; }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
