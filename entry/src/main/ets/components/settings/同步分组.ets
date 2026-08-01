// SPDX-License-Identifier: AGPL-3.0-or-later

import { 同步服务 } from '../../backend/同步服务';
import { 后端错误 } from '../../backend/错误类型';
import type { SyncAuth } from '../../proto/messages/SyncMessages';
import {
  清除同步凭证,
  加载同步凭证,
  保存同步凭证
} from '../../model/同步凭证存储';
import type { 同步凭证信息 } from '../../model/同步凭证存储';
import { 分类同步错误 } from '../../model/同步流程';
import { 设置面板色板, 设置面板色板_取 } from '../../utils/设置面板配色';
import { 颜色键 } from '../../model/颜色主题';

@Component
export struct 同步分组 {
  @Prop 是否深色: boolean = false;
  @Prop 是否展开: boolean = false;
  切换展开回调: () => void = (): void => {};
  打开同步弹窗回调: (凭证: SyncAuth, 账号名: string) => void = (_凭证: SyncAuth, _账号名: string): void => {};
  点击导出数据回调: () => void = (): void => {};
  打开说明回调: (标题: Resource, 正文: Resource) => void = (_标题: Resource, _正文: Resource): void => {};

  @StorageLink(颜色键.主色按钮背景) private 主色按钮背景链接: string = '';
  @StorageProp('themeMode') private 主题模式监听: string = 'system';

  @State private 当前状态: '未登录' | '已登录' = '未登录';
  @State private 用户名输入: string = '';
  @State private 密码输入: string = '';
  @State private 登录中: boolean = false;
  @State private 账号名: string = '';
  @State private 错误文本: string = '';

  private 鉴权凭证: SyncAuth | null = null;

  private readonly 同步服务实例: 同步服务 = new 同步服务();

  aboutToAppear(): void {
    const 信息: 同步凭证信息 | null = 加载同步凭证();
    if (信息 !== null) {
      const 凭证: SyncAuth = {
        hkey: 信息.hkey,
        endpoint: 信息.endpoint,
        ioTimeoutSecs: 0
      };
      this.鉴权凭证 = 凭证;
      this.账号名 = 信息.username;
      this.当前状态 = '已登录';
    } else {
      this.当前状态 = '未登录';
    }
  }

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  private 解析主色按钮背景(): string {
    return this.主色按钮背景链接 !== '' ? this.主色按钮背景链接 : 设置面板色板_取(this.是否深色).主色按钮背景;
  }

  private async 点击登录(): Promise<void> {
    if (this.登录中) {
      return;
    }
    this.登录中 = true;
    this.错误文本 = '';
    try {
      const 凭证: SyncAuth = await this.同步服务实例.同步登录(this.用户名输入, this.密码输入);
      const 信息: 同步凭证信息 = {
        hkey: 凭证.hkey,
        username: this.用户名输入,
        endpoint: 凭证.endpoint
      };
      保存同步凭证(信息);
      this.鉴权凭证 = 凭证;
      this.账号名 = this.用户名输入;
      this.密码输入 = '';
      this.错误文本 = '';
      this.当前状态 = '已登录';
    } catch (error) {
      const 错误对象: Error = error instanceof Error ? error : new Error(`${error}`);
      const 后端错误类别编号: number | undefined = 错误对象 instanceof 后端错误 ? 错误对象.kind : undefined;
      const 类别 = 分类同步错误(错误对象, 后端错误类别编号);
      if (类别 === 'auth') {
        this.错误文本 = `${this.取本地化文本($r('app.string.sync_error_auth'))} [kind=${后端错误类别编号 ?? -1}]：${错误对象.message}`;
      } else if (类别 === 'network') {
        this.错误文本 = `${this.取本地化文本($r('app.string.sync_error_network'))} [kind=${后端错误类别编号 ?? -1}]：${错误对象.message}`;
      } else {
        this.错误文本 = `${this.取本地化文本($r('app.string.sync_error_generic'))} [kind=${后端错误类别编号 ?? -1}]：${错误对象.message}`;
      }
    } finally {
      this.登录中 = false;
    }
  }

  private 点击注销(): void {
    this.getUIContext().showAlertDialog({
      title: this.取本地化文本($r('app.string.sync_logout')),
      message: this.取本地化文本($r('app.string.sync_logout_confirm_message')),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.cancel'),
        action: (): void => {}
      },
      secondaryButton: {
        value: $r('app.string.sync_logout'),
        fontColor: $r('app.color.error_text'),
        action: (): void => {
          this.确认注销();
        }
      }
    });
  }

  private 确认注销(): void {
    清除同步凭证();
    this.鉴权凭证 = null;
    this.账号名 = '';
    this.错误文本 = '';
    this.用户名输入 = '';
    this.密码输入 = '';
    this.当前状态 = '未登录';
  }

  private 点击立即同步(): void {
    const 信息: 同步凭证信息 | null = 加载同步凭证();
    if (信息 === null) {
      this.错误文本 = this.取本地化文本($r('app.string.sync_error_session_expired'));
      this.当前状态 = '未登录';
      return;
    }
    const 凭证: SyncAuth = {
      hkey: 信息.hkey,
      endpoint: 信息.endpoint,
      ioTimeoutSecs: 0
    };
    this.鉴权凭证 = 凭证;
    this.错误文本 = '';
    this.打开同步弹窗回调(凭证, this.账号名);
  }

  @Builder
  private 分组头部() {
    Row() {
      Text(this.取本地化文本($r('app.string.settings_sync_group')))
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
            this.打开说明回调($r('app.string.settings_sync_group'), $r('app.string.sync_help_text'));
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
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.切换展开回调();
      });
    })
  }

  @Builder
  private 未登录内容(色板: 设置面板色板) {
    Text($r('app.string.sync_subtitle_logged_out'))
      .fontSize(12)
      .fontColor(色板.次文字)
      .width('100%')
    TextInput({ placeholder: $r('app.string.sync_username_hint'), text: this.用户名输入 })
      .width('100%')
      .height(44)
      .fontSize(14)
      .fontColor(色板.主文字)
      .placeholderColor(色板.弱化文字)
      .backgroundColor(色板.标签背景)
      .borderRadius(8)
      .padding({ left: 12, right: 12 })
      .enabled(!this.登录中)
      .onChange((值: string) => {
        this.用户名输入 = 值;
      })
    TextInput({ placeholder: $r('app.string.sync_password_hint'), text: this.密码输入 })
      .width('100%')
      .height(44)
      .fontSize(14)
      .fontColor(色板.主文字)
      .placeholderColor(色板.弱化文字)
      .backgroundColor(色板.标签背景)
      .borderRadius(8)
      .padding({ left: 12, right: 12 })
      .type(InputType.Password)
      .enabled(!this.登录中)
      .onChange((值: string) => {
        this.密码输入 = 值;
      })
      .onSubmit((): void => {
        this.点击登录();
      })
    Button(this.登录中 ? $r('app.string.sync_logging_in') : $r('app.string.sync_login'))
      .width('100%')
      .height(44)
      .fontSize(15)
      .fontColor('#FFFFFF')
      .backgroundColor(this.解析主色按钮背景())
      .borderRadius(22)
      .enabled(!this.登录中)
      .opacity(this.登录中 ? 0.6 : 1)
      .onClick((): void => {
        this.点击登录();
      })
    if (this.错误文本 !== '') {
      Text(this.错误文本)
        .fontSize(12)
        .fontColor(色板.错误色)
        .width('100%')
        .maxLines(8)
    }
  }

  @Builder
  private 已登录内容(色板: 设置面板色板) {
    Text(this.账号名)
      .fontSize(15)
      .fontColor(色板.主文字)
      .width('100%')
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    Row({ space: 8 }) {
      Button($r('app.string.sync_backup_first'))
        .layoutWeight(1)
        .height(40)
        .fontSize(12)
        .padding({ left: 4, right: 4 })
        .fontColor(色板.主文字)
        .backgroundColor(色板.标签背景)
        .borderRadius(20)
        .onClick((): void => {
          this.点击导出数据回调();
        })
      Button($r('app.string.sync_now'))
        .layoutWeight(1)
        .height(40)
        .fontSize(12)
        .padding({ left: 4, right: 4 })
        .fontColor(色板.主文字)
        .backgroundColor(色板.标签背景)
        .borderRadius(20)
        .onClick((): void => {
          this.点击立即同步();
        })
      Button($r('app.string.sync_logout'))
        .layoutWeight(1)
        .height(40)
        .fontSize(12)
        .padding({ left: 4, right: 4 })
        .fontColor(色板.主文字)
        .backgroundColor(色板.标签背景)
        .borderRadius(20)
        .onClick((): void => {
          this.点击注销();
        })
    }
    .width('100%')
    if (this.错误文本 !== '') {
      Text(this.错误文本)
        .fontSize(12)
        .fontColor(色板.错误色)
        .width('100%')
        .maxLines(8)
    }
  }

  build() {
    Column() {
      this.分组头部()

      if (this.是否展开) {
        Column({ space: 10 }) {
          if (this.当前状态 === '未登录') {
            this.未登录内容(设置面板色板_取(this.是否深色))
          } else {
            this.已登录内容(设置面板色板_取(this.是否深色))
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
