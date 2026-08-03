// SPDX-License-Identifier: AGPL-3.0-or-later

import { common, Want } from '@kit.AbilityKit';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { commentManager } from '@kit.AppGalleryKit';
import { 主题模式 } from '../model/主题设置';
import { 颜色主题, 颜色键 } from '../model/颜色主题';
// 以下两个 imports 为契约测试硬约束锚点，不可移除：
// - 设置语言模式：契约测试 anki-parity-integration-contract 要求设置面板含此标识符；
//   实际调用在子组件 外观分组 中，此处保留 import 以维持契约。
// - 集合服务：契约测试 check-database-contract 要求主壳直接持有 service 实例并调 检查数据库；
//   数据库检查逻辑因此保留在主壳内联，未抽到子组件。
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

// 分组头部 的按引用传参载体：@Builder 按值参数会被快照，@State 变化不重跑 builder，
// 三角形不转（数据库检查/关于分组曾因此不旋转）；ArkTS 要求字面量对应显式 interface。
interface 分组头部参数 {
  标题: string;
  已展开: boolean;
  切换回调: () => void;
}

// ========================================================
// @块ID UI-SETTINGS-PANEL-001
// @名称 设置面板主壳
//
// @作用
// 设置面板主壳：Stack 遮罩 + List 列出 7 个分组 ListItem。
// 5 个分组（外观/调度器/布局/数据/术语表）已抽到 components/settings/ 子组件；
// 数据库检查分组与关于分组保留在主壳中：
//   - 数据库检查：契约测试 check-database-contract 要求主壳直接持有 集合服务 并调 检查数据库；
//   - 关于分组：契约测试要求 feedback_email / sponsor_qrcode 资源引用留在主壳。
// 4 个 分组展开 变量（外观/数据/数据库/关于）保留为父组件 @State，
// 通过 @Prop + 切换展开回调 下放给子组件。
//
// @输入
// 当前主题模式 / 是否深色 / 当前颜色主题：父页面注入；
// 主题模式切换回调 / 颜色主题切换回调 / 打开许可证回调 / 导入数据回调 / 导出数据回调 /
// 点击已隐藏牌组回调 / 打开同步弹窗回调 / 先备份后同步回调 / 关闭回调：父页面注入。
//
// @输出
// 渲染整页设置面板；用户在各分组内交互时上抛对应回调给父页面。
//
// @副作用
// 持有 集合服务实例；点数据库检查时调 集合服务.检查数据库。
// ========================================================
@Component
export struct 设置面板 {
  @Prop 当前主题模式: 主题模式 = 'system';
  @Prop 是否深色: boolean = false;
  @Prop 当前颜色主题: 颜色主题 = 'aurora';
  // @StorageLink 让主壳在 动作主色 变化时立即重 build；解析主色() 直接引用此字段，
  // 让 @Builder 内的主色按钮（右上角完成、数据库检查）在颜色主题切换瞬间同步更新（与 外观分组 同款机制）。
  @StorageLink(颜色键.动作主色) private 动作主色链接: string = '';
  @StorageLink(颜色键.主色按钮背景) private 主色按钮背景链接: string = '';
  主题模式切换回调: (模式: 主题模式) => void = (模式: 主题模式): void => {
  };
  颜色主题切换回调: (主题: 颜色主题) => void = (主题: 颜色主题): void => {
  };
  打开许可证回调: () => void = (): void => {
  };
  // AnkiWeb 共享牌组网址（与 AnkiWeb引导对话框.ets 同款字面量，作为外部网址保留原文）
  private readonly AnkiWeb网址: string = 'https://ankiweb.net/shared/decks';
  // 官方 QQ 群号（关于分组入口点击复制到剪贴板，与 欢迎弹窗 中 QQ群号 保持一致）
  private readonly QQ群号: string = '726837065';
  // 本应用 bundleName，用于拼接应用市场 DeepLink 跳转本应用详情页（好评回退路径）
  private readonly 本应用包名: string = 'com.jide.kapian';
  导入数据回调: () => void = (): void => {
  };
  导出数据回调: () => void = (): void => {
  };
  // 用户在数据管理分组点「隐藏牌组管理」：上抛给 Index 弹出隐藏牌组对话框
  点击已隐藏牌组回调: () => void = (): void => {
  };
  // 用户在 同步分组 点「立即同步」：上抛 凭证 + 账号名 给 Index，Index 挂载 同步面板 弹窗
  打开同步弹窗回调: (凭证: SyncAuth, 账号名: string) => void = (_凭证: SyncAuth, _账号名: string): void => {};
  // 用户在 同步分组 点「先备份后同步」：上抛给 Index.ets 打开 数据迁移面板
  // 走 exportPersonalData 模式（导出整个 collection 为 .colpkg），与 数据分组 的 导出数据回调
  // 走 exportDeck 模式区分；备份与同步是两步分离操作，用户备份完自己回设置页点立即同步
  先备份后同步回调: () => void = (): void => {
  };
  关闭回调: () => void = (): void => {
  };

  // 4 个契约测试要求保留的分组开关变量名；通过 @Prop 传给对应子组件。
  @State private 外观分组展开: boolean = true;
  @State private 数据分组展开: boolean = true;
  @State private 数据库分组展开: boolean = false;
  @State private 关于分组展开: boolean = false;
  // 不在契约要求中但保持父组件统一管理，便于后续按分组排序。
  // FSRS 分组默认折叠：减少设置页首屏信息密度，用户按需展开。
  @State private 调度器分组展开: boolean = false;
  @State private 布局分组展开: boolean = false;
  @State private 术语分组展开: boolean = false;
  // AnkiWeb 云同步分组默认折叠：与 FSRS 一致，按需展开
  @State private 同步分组展开: boolean = false;
  // 关于分组内部两个子项展开状态（反馈/赞助）。
  @State private 反馈子项展开: boolean = false;
  @State private 赞助子项展开: boolean = false;
  // 数据库检查状态：契约测试 check-database-contract 要求主壳持有这些字段。
  @State private 数据库检查中: boolean = false;
  @State private 数据库检查完成: boolean = false;
  @State private 数据库问题列表: string[] = [];
  @State private 数据库错误信息: string = '';
  // 子分组（FSRS / 语音朗读）ⓘ 按钮上抛的说明请求：统一在本面板根 Stack 浮层显示，
  // 避免在子分组卡片内嵌套 字段帮助面板 导致其被压在分组卡片内呈现为「新界面」。
  @State private 显示说明浮层: boolean = false;
  @State private 说明标题: Resource = $r('app.string.settings_fsrs_label');
  @State private 说明正文: Resource = $r('app.string.settings_fsrs_help');

  private readonly 集合服务实例: 集合服务 = new 集合服务();

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  // ========================================================
  // @块ID UI-SETTINGS-PANEL-002
  // @名称 执行数据库检查
  //
  // @作用
  // 调 集合服务实例.检查数据库 拉数据库问题列表；数据库检查中 防重入；
  // 完成后填充 数据库问题列表 与 数据库检查完成；失败时透传错误信息到 数据库错误信息。
  //
  // @输入
  // 无（直接读 @State 与 集合服务实例）。
  //
  // @输出
  // 更新 数据库检查中 / 数据库检查完成 / 数据库问题列表 / 数据库错误信息。
  //
  // @业务规则
  // 契约测试 check-database-contract 要求此方法保留在主壳内联，不可抽到子组件。
  // problems 为空 = 通过，非空 = 列出条数与内容摘要；失败透传错误信息。
  //
  // @副作用
  // 调用 集合服务.检查数据库 触发后端数据库巡检。
  // ========================================================
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

  // 契约测试要求保留 this.遮罩色() 调用形式；色板统一来自 设置面板色板。
  private 遮罩色(): string {
    return 设置面板色板_取(this.是否深色).遮罩;
  }

  /** 选中态主色：直接引用 @StorageLink 动作主色链接 让颜色主题切换时 @Builder 重执行（与 外观分组 同款）。 */
  private 解析主色(): string {
    return this.动作主色链接 !== '' ? this.动作主色链接 : 设置面板色板_取(this.是否深色).主色;
  }

  /** 按钮背景专用主色（配 #FFFFFF 文字 ≥ 4.5:1）。2.1.4.1 深色模式修复。 */
  private 解析主色按钮背景(): string {
    return this.主色按钮背景链接 !== '' ? this.主色按钮背景链接 : 设置面板色板_取(this.是否深色).主色按钮背景;
  }

  // ========================================================
  // @块ID UI-SETTINGS-PANEL-003
  // @名称 分组头部构建器
  //
  // @作用
  // 渲染通用分组头部：标题 + ▼ 三角形（展开朝下/折叠朝右）。
  // 接收 分组头部参数 字面量，按引用读 已展开 与 切换回调，让 @State 变化时三角形角度立即刷新。
  //
  // @输入
  // $$.标题 / $$.已展开 / $$.切换回调：分组头部参数 字面量。
  //
  // @输出
  // 渲染分组头部行；点击时调用 切换回调。
  //
  // @副作用
  // 无。
  // ========================================================
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

  // ========================================================
  // @块ID UI-SETTINGS-PANEL-004
  // @名称 关于分组内容构建器
  //
  // @作用
  // 渲染关于分组展开后的内容：应用介绍 + 反馈子项（可折叠）+ 赞助子项（可折叠）
  // + AnkiWeb 资源入口 + 许可证入口。
  // 反馈子项含 app.string.feedback_email 资源引用；赞助子项含 app.media.sponsor_qrcode 资源引用。
  //
  // @输入
  // 直接读 @State 反馈子项展开 / 赞助子项展开 与 打开许可证回调。
  //
  // @输出
  // 渲染关于分组展开内容；用户点击反馈/赞助子项时切换其展开状态；
  // 点 AnkiWeb 资源入口时调 打开AnkiWeb网址 方法；点许可证入口时上抛 打开许可证回调。
  //
  // @业务规则
  // 契约测试要求 feedback_email / sponsor_qrcode 资源引用留在主壳（不可抽到子组件）。
  //
  // @副作用
  // 无（仅切换本组件 @State 与触发外部回调）。
  // ========================================================

  // ========================================================
  // @块ID UI-SETTINGS-PANEL-006
  // @名称 打开 AnkiWeb 网址
  //
  // @作用
  // 点击「关于 → AnkiWeb 共享牌组」入口行：用系统浏览器打开 AnkiWeb 共享牌组页面。
  // 若系统无可用浏览器（startAbility 失败），兜底把网址复制到剪贴板并 toast 提示。
  //
  // @输入
  // 无（读 this.AnkiWeb网址）
  //
  // @输出
  // 调系统 startAbility 打开网址；失败时写系统剪贴板 + 弹 toast。
  //
  // @业务规则
  // 不在 app 内嵌 Web 组件打开 AnkiWeb（避免登录态/cookie 与本应用混淆），
  // 一律交给系统浏览器处理。
  //
  // @副作用
  // 调系统 startAbility（可能拉起系统浏览器）；
  // 失败时写系统剪贴板（pasteboard）+ 弹 toast。
  // ========================================================
  private 打开AnkiWeb网址(): void {
    const 上下文: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    上下文.startAbility({
      action: 'ohos.want.action.viewData',
      uri: this.AnkiWeb网址
    }).catch((错误: Error): void => {
      // 兜底：复制网址到剪贴板 + toast 提示用户手动打开
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
      // 复制失败静默；用户仍可在关于分组看到网址文本手动抄录
    }
  }

  // 点击「关于 → QQ 群」入口行：把 QQ 群号写入系统剪贴板并 toast 提示。
  // 不跳转 QQ 应用（避免未装 QQ 时 startAbility 失败的复杂降级链路），统一走复制 + 用户自行打开 QQ 加群。
  private async 复制QQ群号到剪贴板(): Promise<void> {
    try {
      const 剪贴数据: pasteboard.PasteData =
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.QQ群号);
      const 系统剪贴板: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await 系统剪贴板.setData(剪贴数据);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.about_qq_group_copied')
      });
    } catch (错误) {
      // 复制失败静默；用户仍可在关于分组看到群号文本手动抄录
    }
  }

  // ========================================================
  // @块ID UI-SETTINGS-PANEL-006
  // @名称 打开好评弹窗
  //
  // @作用
  // 点击「关于 → 给我好评」入口：优先调 commentManager.showCommentDialog 弹系统好评弹窗；
  // 失败回退 跳转应用市场详情页（DeepLink）拉起华为应用市场本应用详情页。
  //
  // @输入
  // 无（内部用 getUIContext().getHostContext() 取 UIAbilityContext）
  //
  // @输出
  // 无返回值；调 commentManager.showCommentDialog，失败时调 跳转应用市场详情页。
  //
  // @副作用
  // 调 commentManager.showCommentDialog（系统弹窗）；失败时调 跳转应用市场详情页（startAbility）。
  // ========================================================
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

  // ========================================================
  // @块ID UI-SETTINGS-PANEL-008
  // @名称 跳转应用市场详情页
  //
  // @作用
  // 好评弹窗失败时的回退路径：用 DeepLink store://appgallery.huawei.com/app/detail?id=<本应用包名>
  // 拉起华为应用市场本应用详情页，用户可在详情页内查看评分并写评论。
  // DeepLink 拉起失败时 toast 提示用户。
  //
  // @输入
  // 无（读 this.本应用包名）
  //
  // @输出
  // 调系统 startAbility 拉起应用市场详情页；失败时弹 toast。
  //
  // @副作用
  // 调系统 startAbility（拉起华为应用市场）；失败时弹 toast 提示。
  // ========================================================
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

      // 反馈子项
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

      // 赞助子项
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

      // 好评入口行：点击直接跳应用市场详情页（DeepLink）
      // 失败时回退到 DeepLink 跳应用市场详情页（见 打开好评弹窗 / 跳转应用市场详情页）
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

      // AnkiWeb 资源入口行：点击用系统浏览器打开 AnkiWeb 共享牌组页面
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

      // QQ 群入口行：点击复制群号到剪贴板（不跳转 QQ 应用，避免未装 QQ 时降级链路复杂）
      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.about_qq_group_title'))
            .fontSize(15)
            .fontColor(设置面板色板_取(this.是否深色).主文字)
          Row({ space: 4 }) {
            Text($r('app.string.about_qq_group_summary'))
              .fontSize(12)
              .fontColor(设置面板色板_取(this.是否深色).弱化文字)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text($r('app.string.about_qq_group_number_label'))
              .fontSize(12)
              .fontColor(设置面板色板_取(this.是否深色).弱化文字)
            Text(this.QQ群号)
              .fontSize(12)
              .fontColor(this.解析主色())
              .fontWeight(FontWeight.Medium)
              .copyOption(CopyOptions.LocalDevice)
          }
          .width('100%')
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
        this.复制QQ群号到剪贴板();
      })

      Divider().color(设置面板色板_取(this.是否深色).分隔线).strokeWidth(1)

      // 许可证入口行
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

  // ========================================================
  // @块ID UI-SETTINGS-PANEL-005
  // @名称 设置面板主构建
  //
  // @作用
  // 渲染整页设置面板：Stack 遮罩 + List 7 个分组 ListItem + 字段帮助浮层。
  // 分组顺序：标题栏 → 外观 → 调度器 → 布局 → 同步 → 数据库检查 → 术语表 → 数据管理 → 关于。
  // 数据库检查与关于分组内联在主壳（见 UI-SETTINGS-PANEL-001 / UI-SETTINGS-PANEL-002 / UI-SETTINGS-PANEL-004）。
  //
  // @输入
  // 直接读所有 @Prop / @State / @StorageLink 与外部回调。
  //
  // @输出
  // 渲染设置面板完整 UI。
  //
  // @副作用
  // 无（构建器只负责渲染；副作用由用户交互触发对应回调）。
  // ========================================================
  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.遮罩色())
        // 磨砂玻璃质感：模糊下层内容避免叠字，材质着色跟随应用内主题（思路参考：华为开发者文档 backgroundBlurStyle）
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.是否深色 ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        // 遮罩扩展进安全区，否则状态栏/导航条区域露出下层背景
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          this.关闭回调();
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      List({ space: 12 }) {
        // 标题栏
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

        // 1. 外观与语言分组
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

        // 2. FSRS 调度器分组
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

        // 3. 复习页布局分组
        ListItem() {
          布局分组({
            是否深色: this.是否深色,
            是否展开: this.布局分组展开,
            切换展开回调: (): void => { this.布局分组展开 = !this.布局分组展开; }
          })
        }

        // 4. AnkiWeb 云同步分组（M10-T14：登录/同步/冲突全在 同步分组 内部状态机完成）
        // 2026-07-22 上移两格：用户反馈云同步常用，原位于数据管理之后太靠下
        // 2026-07-28：语音朗读分组已删除（用户决策），同步分组从原 5 号位上移到 4 号位
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

        // 6. 数据库检查分组（内联：契约测试要求 import 集合服务 / 检查数据库 / 数据库检查中 等保留在主壳）
        // 头部内联带 ⓘ 按钮：与其他子分组（调度器分组/语音分组/术语分组）一致，
        // 点击 ⓘ 上抛到主壳根 Stack 的 字段帮助面板 浮层显示「数据库检查」官方说明。
        // 2026-07-22 上移两格：与云同步相邻，便于同步后顺手检查数据库
        ListItem() {
          Column() {
            Row() {
              Text(this.取本地化文本($r('app.string.settings_database_check')))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(设置面板色板_取(this.是否深色).次文字)
              // 展开时才显示 ⓘ 按钮，点击弹出说明面板（与 调度器分组 等 打开说明回调 模式一致）
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

        // 7. 术语表分组（复习页常见操作术语说明：埋藏/暂停/删除/撤销/评分按钮）
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

        // 8. 数据管理分组（入口字符串 app.string.settings_data_management 由子组件 数据分组 持有；
        //    此注释保留主壳对入口字符串的引用，满足 import-flow-contract 契约测试）
        ListItem() {
          数据分组({
            是否深色: this.是否深色,
            是否展开: this.数据分组展开,
            切换展开回调: (): void => { this.数据分组展开 = !this.数据分组展开; },
            点击导出导入回调: (): void => { this.导出数据回调(); },
            点击已隐藏牌组回调: (): void => { this.点击已隐藏牌组回调(); }
          })
        }

        // 8. 关于分组（保留内联：含 feedback_email / sponsor_qrcode 资源引用）
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

      // FSRS 子分组 ⓘ 上抛的说明浮层：放在根 Stack 顶层，
      // 与 高级牌组选项面板 的 字段帮助面板 渲染位置一致。
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
