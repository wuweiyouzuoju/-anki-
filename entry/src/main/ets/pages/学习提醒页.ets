// SPDX-License-Identifier: AGPL-3.0-or-later

import { 加载学习提醒设置, 保存学习提醒设置, 提醒项, 生成提醒项ID } from '../model/学习提醒存储';
import { 刷新学习提醒 } from '../model/学习提醒服务';
import { 设置面板色板_取 } from '../utils/设置面板配色';
import { 颜色键 } from '../model/颜色主题';
import { 解析是否深色, 主题模式 } from '../model/主题设置';
import { 字段帮助面板 } from '../components/字段帮助面板';
import { 学习提醒编辑页, 学习提醒编辑参数 } from './学习提醒编辑页';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 按下态按钮 } from '../components/common/按下态按钮';

// ========================================================
// @块ID UI-STUDY-REMINDER-PAGE-001
// @名称 学习提醒页（NavDestination 列表页）
//
// @作用
// 从首页"更多"菜单点"提醒"推入的独立页面。
// 列表式展示所有提醒项，每项有独立开关。
// 右上角"+"按钮 push 新建提醒编辑页。
// 点击卡片（非开关区域）push 编辑提醒页。
//
// @前置条件
// - module.json5 已声明 ohos.permission.PUBLISH_AGENT_REMINDER 权限
// - AGC 后台已通过"代理提醒"权限审核
// ========================================================

@Component
export struct 学习提醒页 {
  private pathStack?: NavPathStack;

  @StorageLink(颜色键.主色按钮背景) private 主色按钮背景链接: string = '';
  @StorageLink(颜色键.页面底色微染) private 页面底色微染值: string = '#F5F7FA';
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';
  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp('状态栏高度') private 状态栏高度: number = 0;
  @StorageLink('systemDarkMode') private 系统暗黑模式: boolean = false;
  @State private 主题模式值: 主题模式 = 'system';

  @State private 是否深色: boolean = false;
  @State private 提醒项列表: 提醒项[] = [];
  @State private 操作中: boolean = false;
  @State private 错误信息: string = '';
  @State private 已加载: boolean = false;
  @State private 显示帮助: boolean = false;

  async aboutToAppear(): Promise<void> {
    this.是否深色 = 解析是否深色(this.主题模式值, this.系统暗黑模式);
    await this.加载列表();
  }

  // 从编辑页返回时刷新列表（被 NavPathStack pop 回调触发）
  onPageShow(): void {
    if (this.已加载) {
      this.加载列表();
    }
  }

  private async 加载列表(): Promise<void> {
    const 设置 = await 加载学习提醒设置();
    this.提醒项列表 = 设置.提醒项列表;
    this.已加载 = true;
  }

  private 解析主色按钮背景(): string {
    return this.主色按钮背景链接 !== '' ? this.主色按钮背景链接 : 设置面板色板_取(this.是否深色).主色按钮背景;
  }

  private 格式化时间(小时: number, 分钟: number): string {
    const h: string = 小时 < 10 ? `0${小时}` : `${小时}`;
    const m: string = 分钟 < 10 ? `0${分钟}` : `${分钟}`;
    return `${h}:${m}`;
  }

  private 预览内容(项: 提醒项): string {
    const 模板: string = 项.内容.length > 0 ? 项.内容 : '今日待学习 {{待学}} 张，待复习 {{待复习}} 张';
    return 模板
      .replace('{{待学}}', 'X')
      .replace('{{待复习}}', 'Y');
  }

  private 预览标题(项: 提醒项): string {
    return 项.标题.length > 0 ? 项.标题 : 'jidecards 学习提醒';
  }

  private async 切换单项开关(项ID: number, 值: boolean): Promise<void> {
    const 新列表: 提醒项[] = [];
    for (let i: number = 0; i < this.提醒项列表.length; i++) {
      if (this.提醒项列表[i].唯一ID === 项ID) {
        新列表.push({
          唯一ID: this.提醒项列表[i].唯一ID,
          小时: this.提醒项列表[i].小时,
          分钟: this.提醒项列表[i].分钟,
          标题: this.提醒项列表[i].标题,
          内容: this.提醒项列表[i].内容,
          开启: 值
        });
      } else {
        新列表.push(this.提醒项列表[i]);
      }
    }
    this.提醒项列表 = 新列表;
    await 保存学习提醒设置(this.提醒项列表);
    await this.重新发布();
  }

  private async 重新发布(): Promise<void> {
    this.操作中 = true;
    this.错误信息 = '';
    try {
      await 刷新学习提醒();
    } catch (错误) {
      this.错误信息 = 错误 instanceof Error ? 错误.message : `${错误}`;
    } finally {
      this.操作中 = false;
    }
  }

  private 新建提醒(): void {
    const 新项: 提醒项 = {
      唯一ID: 生成提醒项ID(),
      小时: 21,
      分钟: 0,
      标题: '',
      内容: '',
      开启: true
    };
    const 参数: 学习提醒编辑参数 = {
      项: 新项,
      是否新建: true
    };
    this.pathStack?.pushPath({ name: 'ReminderEditPage', param: 参数 });
  }

  private 编辑提醒(项: 提醒项): void {
    const 参数: 学习提醒编辑参数 = {
      项: 项,
      是否新建: false
    };
    this.pathStack?.pushPath({ name: 'ReminderEditPage', param: 参数 });
  }

  private 返回(): void {
    if (this.pathStack !== undefined && this.pathStack.size() > 0) {
      this.pathStack.pop();
    }
  }

  @Builder
  private 顶部条() {
    // 与统计页顶部条同款：标题在底层绝对居中，按钮行在顶层铺满。
    // 标题 + ⓘ 用 Row 组合，整体水平居中。上层 Row 用 Transparent 让空白区域穿透，ⓘ 可点击。
    Stack() {
      // 下层：标题 + ⓘ 帮助按钮，整体居中
      Row() {
        Text($r('app.string.reminder_list_title'))
          .fontSize(应用尺寸.字号_面板标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .hitTestBehavior(HitTestMode.Transparent)
        Text($r('app.string.reminder_help_icon'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor(this.解析主色按钮背景())
          .margin({ left: 6 })
          .onClick((): void => {
            this.显示帮助 = true;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .hitTestBehavior(HitTestMode.Transparent)

      // 上层：左返回 + 右新建按钮，铺满
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
          文案: $r('app.string.reminder_list_create_button'),
          选中态背景: this.主色容器色,
          字色: this.动作主色,
          点击回调: (): void => { this.新建提醒(); }
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
  private 提醒项卡片(项: 提醒项) {
    Row() {
      // 左侧时间大字
      Column() {
        Text(this.格式化时间(项.小时, 项.分钟))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(项.开启 ? this.解析主色按钮背景() : 设置面板色板_取(this.是否深色).弱化文字)
      }
      .alignItems(HorizontalAlign.Center)
      .width(90)

      // 中间文案
      Column() {
        Text(this.预览标题(项))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(项.开启 ? 设置面板色板_取(this.是否深色).主文字 : 设置面板色板_取(this.是否深色).弱化文字)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.预览内容(项))
          .fontSize(13)
          .fontColor(项.开启 ? 设置面板色板_取(this.是否深色).次文字 : 设置面板色板_取(this.是否深色).弱化文字)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      // 右侧开关
      Toggle({ type: ToggleType.Switch, isOn: 项.开启 })
        .selectedColor(this.解析主色按钮背景())
        .enabled(!this.操作中)
        .onChange((值: boolean): void => {
          this.切换单项开关(项.唯一ID, 值);
        })
    }
    .width('100%')
    .padding(应用尺寸.卡片内边距)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
    .margin({ bottom: 应用尺寸.间距_8 })
    .onClick((): void => {
      this.编辑提醒(项);
    })
  }

  @Builder
  private 空状态() {
    Column() {
      Text($r('app.string.reminder_list_empty'))
        .fontSize(16)
        .fontColor(设置面板色板_取(this.是否深色).次文字)
        .margin({ bottom: 8 })
      Text($r('app.string.reminder_list_empty_hint'))
        .fontSize(13)
        .fontColor(设置面板色板_取(this.是否深色).弱化文字)
    }
    .width('100%')
    .padding({ top: 120 })
    .justifyContent(FlexAlign.Center)
  }

  build() {
    NavDestination() {
      Stack() {
        // 下层：主内容
        Column() {
          this.顶部条()

          if (this.已加载) {
            Scroll() {
              Column() {
                if (this.提醒项列表.length === 0) {
                  this.空状态()
                } else {
                  ForEach(this.提醒项列表, (项: 提醒项) => {
                    this.提醒项卡片(项)
                  }, (项: 提醒项) => `${项.唯一ID}`)
                }

                if (this.错误信息 !== '') {
                  Text(this.错误信息)
                    .fontSize(12)
                    .fontColor(设置面板色板_取(this.是否深色).错误色)
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 8 })
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 8 })
            }
            .layoutWeight(1)
            .align(Alignment.Top)
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.页面底色微染值)

        // 顶层：帮助浮层（复用统一字段帮助面板，与设置面板/浏览页同款整屏覆盖）
        if (this.显示帮助) {
          字段帮助面板({
            标题: '关于提醒文案',
            正文: '1. 文案中的 {{待学}} 和 {{待复习}} 会在发送提醒时自动替换成当时的实际卡片数量。\n\n2. 数量在 App 切到后台时生成快照，到点触发显示的是该时刻的数量，不是触发时的实时数量。\n\n3. 关于文案中的待学，待复习数量，会在每次APP退出后自动读取刷新。\n\n4. 可以不使用占位符，自定义文案。',
            是否深色: this.是否深色,
            onClose: (): void => {
              this.显示帮助 = false;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
    }
    .hideTitleBar(true)
  }
}
