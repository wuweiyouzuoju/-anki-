// SPDX-License-Identifier: AGPL-3.0-or-later

import { 保存学习提醒设置, 加载学习提醒设置, 提醒项 } from '../model/学习提醒存储';
import { 刷新学习提醒 } from '../model/学习提醒服务';
import { 设置面板色板_取 } from '../utils/设置面板配色';
import { 颜色键 } from '../model/颜色主题';
import { 解析是否深色, 主题模式 } from '../model/主题设置';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 按下态按钮 } from '../components/common/按下态按钮';

// ========================================================
// @块ID UI-STUDY-REMINDER-EDIT-001
// @名称 学习提醒编辑页（NavDestination）
//
// @作用
// 新建/编辑单个提醒项的独立页面。
// 时间选择 + 通知标题输入 + 通知内容输入（带占位符说明）。
// 底部"保存"按钮持久化并刷新提醒，"删除"按钮（仅编辑模式）删除该项。
//
// @输入
// 项: 提醒项（新建时由列表页生成带新 ID 的空项）
// 是否新建: true=新建模式（无删除按钮，标题"新建提醒"），false=编辑模式（有删除按钮，标题"编辑提醒"）
// ========================================================

export interface 学习提醒编辑参数 {
  项: 提醒项;
  是否新建: boolean;
}

@Component
export struct 学习提醒编辑页 {
  private pathStack?: NavPathStack;
  private 项?: 提醒项;
  private 是否新建: boolean = true;

  @StorageLink(颜色键.主色按钮背景) private 主色按钮背景链接: string = '';
  @StorageLink(颜色键.页面底色微染) private 页面底色微染值: string = '#F5F7FA';
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';
  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp('状态栏高度') private 状态栏高度: number = 0;
  @StorageLink('systemDarkMode') private 系统暗黑模式: boolean = false;
  @State private 主题模式值: 主题模式 = 'system';

  @State private 是否深色: boolean = false;
  @State private 小时: number = 21;
  @State private 分钟: number = 0;
  @State private 标题: string = '';
  @State private 内容: string = '';
  @State private 开启: boolean = true;
  @State private 错误信息: string = '';
  @State private 保存中: boolean = false;

  aboutToAppear(): void {
    this.是否深色 = 解析是否深色(this.主题模式值, this.系统暗黑模式);
    if (this.项 !== undefined) {
      this.小时 = this.项.小时;
      this.分钟 = this.项.分钟;
      this.标题 = this.项.标题;
      this.内容 = this.项.内容;
      this.开启 = this.项.开启;
    }
  }

  private 解析主色按钮背景(): string {
    return this.主色按钮背景链接 !== '' ? this.主色按钮背景链接 : 设置面板色板_取(this.是否深色).主色按钮背景;
  }

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  /** 点标签把占位符追加到内容末尾，免去手打花括号；token 走资源，中文 {{待学}} / 英文 {{new}}，服务层两种都识别 */
  private 插入占位符(token资源: Resource): void {
    this.内容 = this.内容 + this.取本地化文本(token资源);
  }

  private 小时选项(): SelectOption[] {
    const 选项: SelectOption[] = [];
    for (let i: number = 0; i < 24; i++) {
      选项.push({ value: i < 10 ? `0${i}` : `${i}` });
    }
    return 选项;
  }

  private 构建分钟选项(): SelectOption[] {
    const 选项: SelectOption[] = [];
    for (let i: number = 0; i < 60; i++) {
      选项.push({ value: i < 10 ? `0${i}` : `${i}` });
    }
    return 选项;
  }

  private async 保存(): Promise<void> {
    if (this.保存中 || this.项 === undefined) {
      return;
    }
    this.保存中 = true;
    this.错误信息 = '';
    try {
      // 加载现有列表，替换或追加当前项
      const 设置 = await 加载学习提醒设置();
      const 新列表: 提醒项[] = [];
      let 已存在: boolean = false;
      for (let i: number = 0; i < 设置.提醒项列表.length; i++) {
        if (设置.提醒项列表[i].唯一ID === this.项!.唯一ID) {
          新列表.push({
            唯一ID: this.项!.唯一ID,
            小时: this.小时,
            分钟: this.分钟,
            标题: this.标题,
            内容: this.内容,
            开启: this.开启
          });
          已存在 = true;
        } else {
          新列表.push(设置.提醒项列表[i]);
        }
      }
      if (!已存在) {
        新列表.push({
          唯一ID: this.项!.唯一ID,
          小时: this.小时,
          分钟: this.分钟,
          标题: this.标题,
          内容: this.内容,
          开启: this.开启
        });
      }
      await 保存学习提醒设置(新列表);
      await 刷新学习提醒();
      this.返回();
    } catch (错误) {
      this.错误信息 = 错误 instanceof Error ? 错误.message : `${错误}`;
    } finally {
      this.保存中 = false;
    }
  }

  private async 删除(): Promise<void> {
    if (this.项 === undefined) {
      return;
    }
    this.错误信息 = '';
    try {
      const 设置 = await 加载学习提醒设置();
      const 新列表: 提醒项[] = [];
      for (let i: number = 0; i < 设置.提醒项列表.length; i++) {
        if (设置.提醒项列表[i].唯一ID !== this.项!.唯一ID) {
          新列表.push(设置.提醒项列表[i]);
        }
      }
      await 保存学习提醒设置(新列表);
      await 刷新学习提醒();
      this.返回();
    } catch (错误) {
      this.错误信息 = 错误 instanceof Error ? 错误.message : `${错误}`;
    }
  }

  private 返回(): void {
    if (this.pathStack !== undefined && this.pathStack.size() > 0) {
      this.pathStack.pop();
    }
  }

  @Builder
  private 顶部条() {
    // 与设置页顶部条同款：底层居中标题，上层 左「返回」黑字 + 右「确认」主题色 按下态胶囊按钮
    Stack() {
      Text(this.是否新建 ? $r('app.string.reminder_edit_title_create') : $r('app.string.reminder_edit_title_edit'))
        .fontSize(应用尺寸.字号_面板标题)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)

      Row() {
        按下态按钮({
          文案: $r('app.string.study_back'),
          选中态背景: this.主色容器色,
          字色: $r('app.color.text_primary'),
          点击回调: (): void => { this.返回(); }
        })
        Blank()
          .hitTestBehavior(HitTestMode.Transparent)
        按下态按钮({
          文案: $r('app.string.settings_confirm'),
          选中态背景: this.主色容器色,
          字色: this.动作主色,
          点击回调: (): void => { this.保存(); }
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height(应用尺寸.工具栏高度 + this.状态栏高度)
    .padding({
      left: 应用尺寸.页面内边距_水平,
      right: 应用尺寸.页面内边距_水平,
      top: this.状态栏高度 + 应用尺寸.间距_8,
      bottom: 应用尺寸.间距_8
    })
    .backgroundColor(this.页面底色微染值)
    .alignContent(Alignment.Center)
  }

  @Builder
  private 时间区块() {
    Column() {
      Text($r('app.string.reminder_edit_time_label'))
        .fontSize(13)
        .fontColor(设置面板色板_取(this.是否深色).次文字)
        .width('100%')
        .margin({ bottom: 8 })

      Row() {
        Select(this.小时选项())
          .selected(this.小时)
          .value(this.小时 < 10 ? `0${this.小时}` : `${this.小时}`)
          .controlSize(ControlSize.NORMAL)
          .width(100)
          .onSelect((index: number): void => {
            this.小时 = index;
          })
        Text($r('app.string.reminder_edit_time_colon'))
          .fontSize(20)
          .fontColor(设置面板色板_取(this.是否深色).主文字)
          .margin({ left: 8, right: 8 })
        Select(this.构建分钟选项())
          .selected(this.分钟)
          .value(this.分钟 < 10 ? `0${this.分钟}` : `${this.分钟}`)
          .controlSize(ControlSize.NORMAL)
          .width(100)
          .onSelect((index: number): void => {
            this.分钟 = index;
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(设置面板色板_取(this.是否深色).背景)
    .borderRadius(12)
  }

  @Builder
  private 文案区块() {
    Column() {
      Text($r('app.string.reminder_edit_notification_title'))
        .fontSize(13)
        .fontColor(设置面板色板_取(this.是否深色).次文字)
        .width('100%')
        .margin({ bottom: 8 })
      TextInput({ text: this.标题, placeholder: $r('app.string.reminder_edit_title_placeholder') })
        .fontSize(15)
        .fontColor(设置面板色板_取(this.是否深色).主文字)
        .backgroundColor(设置面板色板_取(this.是否深色).输入框背景)
        .borderRadius(8)
        .height(44)
        .onChange((值: string): void => {
          this.标题 = 值;
        })

      Text($r('app.string.reminder_edit_notification_content'))
        .fontSize(13)
        .fontColor(设置面板色板_取(this.是否深色).次文字)
        .width('100%')
        .margin({ top: 16, bottom: 8 })
      TextArea({ text: this.内容, placeholder: $r('app.string.reminder_edit_content_placeholder') })
        .fontSize(15)
        .fontColor(设置面板色板_取(this.是否深色).主文字)
        .backgroundColor(设置面板色板_取(this.是否深色).输入框背景)
        .borderRadius(8)
        .height(80)
        .onChange((值: string): void => {
          this.内容 = 值;
        })

      // 快捷插入标签：点一下把占位符追加到内容末尾，免手打花括号
      Row({ space: 8 }) {
        Text($r('app.string.reminder_edit_insert_new'))
          .fontSize(13)
          .fontColor(this.解析主色按钮背景())
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .border({ width: 1, color: this.解析主色按钮背景() })
          .borderRadius(14)
          .onClick((): void => {
            this.插入占位符($r('app.string.reminder_edit_token_new'));
          })
        Text($r('app.string.reminder_edit_insert_review'))
          .fontSize(13)
          .fontColor(this.解析主色按钮背景())
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .border({ width: 1, color: this.解析主色按钮背景() })
          .borderRadius(14)
          .onClick((): void => {
            this.插入占位符($r('app.string.reminder_edit_token_review'));
          })
      }
      .width('100%')
      .margin({ top: 8 })

      Text($r('app.string.reminder_edit_placeholder_hint'))
        .fontSize(11)
        .fontColor(设置面板色板_取(this.是否深色).弱化文字)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(设置面板色板_取(this.是否深色).背景)
    .borderRadius(12)
  }

  build() {
    NavDestination() {
      Column() {
        this.顶部条()

        Scroll() {
          Column() {
            this.时间区块()
            this.文案区块()

            if (!this.是否新建) {
              Button($r('app.string.reminder_edit_delete'))
                .type(ButtonType.Normal)
                .backgroundColor(设置面板色板_取(this.是否深色).背景)
                .fontSize(15)
                .fontColor(设置面板色板_取(this.是否深色).错误色)
                .width('100%')
                .height(48)
                .borderRadius(12)
                .margin({ top: 16 })
                .onClick((): void => { this.删除(); })
            }

            if (this.错误信息 !== '') {
              Text(this.错误信息)
                .fontSize(12)
                .fontColor(设置面板色板_取(this.是否深色).错误色)
                .width('100%')
                .padding({ top: 16 })
            }
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.是否深色 ? '#0F172A' : '#F5F7FA')
    }
    .hideTitleBar(true)
  }
}
