// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';

@Component
export struct 今日摘要卡 {
  @Prop 已完成数: number = 0;
  @Prop 待学数: number = 0;
  @Prop 牌组数: number = 0;
  @Prop 今日回忆率: number = -1;
  @Prop 已折叠: boolean = false;
  切换展开回调: (() => void) | null = null;

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';
  @StorageProp(颜色键.新卡计数色) private 新卡计数色: string = '#3974D9';
  @StorageProp(颜色键.学习中计数色) private 学习中计数色: string = '#B56A22';
  @StorageProp(颜色键.复习中计数色) private 复习中计数色: string = '#7056C8';

  private 进度值(): number {
    const 总数: number = this.已完成数 + this.待学数;
    if (总数 <= 0) {
      return 0;
    }
    return this.已完成数 / 总数 * 100;
  }

  private 是否空态(): boolean {
    return this.牌组数 === 0;
  }

  private 空态提示(): Resource {
    return $r('app.string.today_empty_no_decks_hint');
  }

  build() {
    Column({ space: this.已折叠 ? 应用尺寸.间距_8 : 应用尺寸.间距_13 }) {
      Row() {
        Column({ space: 应用尺寸.间距_3 }) {
          Text($r('app.string.today_progress'))
            .fontSize(应用尺寸.字号_摘要标题)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.today_summary_detail', this.已完成数, this.待学数))
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Blank()
        Text($r('app.string.deck_count_summary', this.牌组数))
          .fontSize(应用尺寸.字号_正文_中)
          .fontColor($r('app.color.text_secondary'))
        Text('▼')
          .fontSize(应用尺寸.字号_正文_中)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 应用尺寸.间距_8 })
          .padding({ left: 应用尺寸.间距_4, right: 应用尺寸.间距_4, top: 应用尺寸.间距_4, bottom: 应用尺寸.间距_4 })
          .rotate({ angle: this.已折叠 ? -90 : 0 })
          .animation({ duration: 300, curve: Curve.EaseOut })
      }
      .width('100%')

      if (this.是否空态()) {
        if (this.已折叠) {
          Text(this.空态提示())
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else {
          Blank()
          Text(this.空态提示())
            .fontSize(应用尺寸.字号_正文)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .width('100%')
          Blank()
        }
      } else {
        Progress({ value: this.进度值(), total: 100, type: ProgressType.Linear })
          .height(应用尺寸.进度条高度)
          .color(this.动作主色)
          .backgroundColor(this.主色容器色)
          .borderRadius(应用尺寸.圆角_进度条)

        if (!this.已折叠) {
          Row({ space: 应用尺寸.间距_10 }) {
            Column({ space: 应用尺寸.间距_3 }) {
              Text(this.已完成数.toString())
                .fontSize(应用尺寸.字号_指标)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.新卡计数色)
              Text($r('app.string.completed_today'))
                .fontSize(应用尺寸.字号_正文_小)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: 应用尺寸.间距_3 }) {
              Text(this.待学数.toString())
                .fontSize(应用尺寸.字号_指标)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.学习中计数色)
              Text($r('app.string.pending_today'))
                .fontSize(应用尺寸.字号_正文_小)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: 应用尺寸.间距_3 }) {
              Text(this.今日回忆率 >= 0 ? `${Math.round(this.今日回忆率 * 100)}%` : '-')
                .fontSize(应用尺寸.字号_指标)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.复习中计数色)
              Text($r('app.string.today_recall_rate'))
                .fontSize(应用尺寸.字号_正文_小)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
        }
      }
    }
    .width('100%')
    .height(this.已折叠 ? 82 : 应用尺寸.卡片高度)
    .animation({ duration: 300, curve: Curve.EaseOut })
    .padding(应用尺寸.卡片内边距)
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
