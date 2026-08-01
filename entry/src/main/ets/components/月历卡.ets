// SPDX-License-Identifier: AGPL-3.0-or-later

import { 日历单日 } from '../model/日历模型';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';

@Component
export struct 月历卡 {
  @Prop 标题: Resource = $r('app.string.calendar_month_title', 0, 0);
  @Prop 日期列表: 日历单日[] = [];
  @Prop 周数: number = 6;
  @Prop 有学习记录: boolean = false;
  @Prop 已折叠: boolean = false;
  切换展开回调: (() => void) | null = null;

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.热力1) private 热力1色: string = '#DCE8FF';
  @StorageProp(颜色键.热力2) private 热力2色: string = '#B8CEFA';
  @StorageProp(颜色键.热力3) private 热力3色: string = '#7EA3EE';
  @StorageProp(颜色键.热力4) private 热力4色: string = '#2F5FD0';

  private readonly 星期表头: Resource[] = [
    $r('app.string.weekday_1'), $r('app.string.weekday_2'), $r('app.string.weekday_3'),
    $r('app.string.weekday_4'), $r('app.string.weekday_5'), $r('app.string.weekday_6'),
    $r('app.string.weekday_7')
  ];

  private 取热力色(强度: number): ResourceColor {
    switch (强度) {
      case 1:
        return this.热力1色;
      case 2:
        return this.热力2色;
      case 3:
        return this.热力3色;
      case 4:
        return this.热力4色;
      case 0:
      default:
        return Color.Transparent;
    }
  }

  private 取热力文字色(日: 日历单日): Resource {
    if (!日.是否当月) {
      return $r('app.color.text_tertiary');
    }
    return 日.热力强度 >= 4 ?
      $r('app.color.action_on_primary') : $r('app.color.text_primary');
  }

  private 行模板(): string {
    const 行数组: string[] = [];
    for (let i: number = 0; i < this.周数; i++) {
      行数组.push('1fr');
    }
    return 行数组.join(' ');
  }

  private 网格高度(): number {
    return this.周数 * 应用尺寸.日历_单元格高度
      + (this.周数 - 1) * 应用尺寸.日历_行间距;
  }

  private 卡片高度(): number {
    const 标题行: number = 36;
    const 空态行: number = this.有学习记录 ? 0 : 16;
    const 周表头行: number = 14;
    const 内边距: number = 应用尺寸.间距_14 * 2;
    const 列间距: number = 应用尺寸.间距_7 * 3;
    return 标题行 + 空态行 + 周表头行 + this.网格高度() + 内边距 + 列间距;
  }

  @Builder
  private 单元格(日: 日历单日) {
    Text(日.日号.toString())
      .width('100%')
      .height(应用尺寸.日历_单元格高度)
      .fontSize(应用尺寸.字号_说明)
      .fontWeight(日.是否今天 ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.取热力文字色(日))
      .textAlign(TextAlign.Center)
      .backgroundColor(日.是否当月 ? this.取热力色(日.热力强度) : Color.Transparent)
      .border({
        width: 日.是否今天 ? 应用尺寸.卡片边框 : 0,
        color: this.动作主色
      })
      .borderRadius(应用尺寸.圆角_单元格)
      .opacity(日.是否当月 ? 1 : 0.45)
  }

  build() {
    Column({ space: 应用尺寸.间距_7 }) {
      Row() {
        Column({ space: 应用尺寸.间距_2 }) {
          Text($r('app.string.month_learning'))
            .fontSize(应用尺寸.字号_卡片标题)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(this.标题)
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text($r('app.string.heat_hint'))
          .fontSize(应用尺寸.字号_说明)
          .fontColor($r('app.color.text_tertiary'))
        Text('▼')
          .fontSize(应用尺寸.字号_正文_中)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 应用尺寸.间距_8 })
          .padding({ left: 应用尺寸.间距_4, right: 应用尺寸.间距_4, top: 应用尺寸.间距_4, bottom: 应用尺寸.间距_4 })
          .rotate({ angle: this.已折叠 ? -90 : 0 })
          .animation({ duration: 300, curve: Curve.EaseOut })
      }
      .width('100%')

      if (!this.已折叠) {
        if (!this.有学习记录) {
          Text($r('app.string.month_empty_hint'))
            .fontSize(应用尺寸.字号_说明)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }

        Row() {
          ForEach(this.星期表头, (星期: Resource, index: number) => {
            Text(星期)
              .fontSize(应用尺寸.字号_说明_小)
              .fontColor($r('app.color.text_tertiary'))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
          }, (星期: Resource, index: number) => `weekday-${index}`)
        }
        .width('100%')

        Grid() {
          ForEach(this.日期列表, (日: 日历单日) => {
            GridItem() {
              this.单元格(日)
            }
          }, (日: 日历单日) => 日.key)
        }
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
        .rowsTemplate(this.行模板())
        .columnsGap(应用尺寸.日历_列间距)
        .rowsGap(应用尺寸.日历_行间距)
        .width('100%')
        .height(this.网格高度())
      }
    }
    .width('100%')
    .height(this.已折叠 ? 82 : this.卡片高度())
    .animation({ duration: 300, curve: Curve.EaseOut })
    .padding(应用尺寸.间距_14)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
    .onClick(() => {
      if (this.切换展开回调 !== null) {
        this.切换展开回调();
      }
    })
  }
}
