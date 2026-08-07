// SPDX-License-Identifier: AGPL-3.0-or-later

// 预测卡：渲染 GraphsView.futureDue 为可水平拖动的垂直柱状图。
// 30 根柱子固定宽度（36vp），超出屏幕宽度，支持拖动 + snap 对齐到最近柱子居中。
// 当前对齐柱子全不透明，其他柱子半透明（0.5），突出当前焦点。
// 显示积压=true 时也展示负键（积压天数），用灰色区分。
// 底部信息行对齐 Anki 桌面端 Future Due 表格：总计 / 平均 / 日均 / 明日到期。

import type { FutureDue } from '../../proto/messages/StatsMessages';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 颜色键 } from '../../model/颜色主题';

interface 预测项 {
  天数: number;
  数量: number;
}

@Component
export struct 预测卡 {
  @Prop @Watch('更新缓存') 预测数据: FutureDue | null = null;
  @Prop @Watch('更新缓存') 显示积压: boolean = false;
  @StorageProp(颜色键.动作主色) private 主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 容器色: string = '#E8EEFC';
  @State 偏移X: number = 0;
  @State 当前索引: number = 0;
  @State 起始偏移: number = 0;
  @State 容器宽度: number = 0;
  private readonly 图表高度: number = 120;
  private readonly 柱子区高度: number = 108;
  private readonly 数字标签高度: number = 12;
  private readonly 显示天数: number = 30;
  private readonly 柱子宽度: number = 36; // vp，含间距，足够容纳 3 位数字
  private 条目缓存: 预测项[] = [];

  aboutToAppear() {
    this.条目缓存 = this.取条目();
  }

  更新缓存() {
    this.条目缓存 = this.取条目();
    this.当前索引 = 0;
    this.偏移X = this.取对齐偏移(0);
  }

  private 取条目(): 预测项[] {
    if (this.预测数据 === null || this.预测数据.futureDue === null) {
      return [];
    }
    const 项列表: 预测项[] = [];
    this.预测数据.futureDue.forEach((值: number, 键: number) => {
      if (键 >= 0 || this.显示积压) {
        const 项: 预测项 = { 天数: 键, 数量: 值 };
        项列表.push(项);
      }
    });
    项列表.sort((a: 预测项, b: 预测项) => a.天数 - b.天数);
    return 项列表.slice(0, 30);
  }

  private 取最大值(条目: 预测项[]): number {
    let 最大: number = 0;
    for (let i = 0; i < 条目.length; i++) {
      if (条目[i].数量 > 最大) {
        最大 = 条目[i].数量;
      }
    }
    return 最大 === 0 ? 1 : 最大;
  }

  // 总计：仅统计显示范围内的卡片数（含积压则算入负键，否则只算 >= 0）。
  private 取总计(): number {
    if (this.预测数据 === null || this.预测数据.futureDue === null) {
      return 0;
    }
    let 总计: number = 0;
    this.预测数据.futureDue.forEach((值: number, 键: number) => {
      if (键 >= 0 || this.显示积压) {
        总计 += 值;
      }
    });
    return 总计;
  }

  // 平均：与 Anki 桌面端算法一致——Total / 显示天数（含空天），反映「未来 N 天日均」。
  private 取平均(): number {
    return this.取总计() / this.显示天数;
  }

  // 明日到期：取 future_due[1]，无该键则 0。
  private 取明日到期(): number {
    if (this.预测数据 === null || this.预测数据.futureDue === null) {
      return 0;
    }
    const 值 = this.预测数据.futureDue.get(1);
    return 值 === undefined ? 0 : 值;
  }

  private 数据为空(): boolean {
    if (this.预测数据 === null) return true;
    return this.条目缓存.length === 0;
  }

  // snap 对齐偏移：让第 N 根柱子居中于容器
  private 取对齐偏移(索引: number): number {
    if (this.容器宽度 === 0) return 0;
    return (this.容器宽度 - this.柱子宽度) / 2 - 索引 * this.柱子宽度;
  }

  // 从当前偏移反推最近柱子索引
  private 取最近索引(偏移: number): number {
    if (this.条目缓存.length === 0 || this.容器宽度 === 0) return 0;
    const 索引 = Math.round((this.容器宽度 / 2 - this.柱子宽度 / 2 - 偏移) / this.柱子宽度);
    return Math.max(0, Math.min(索引, this.条目缓存.length - 1));
  }

  build() {
    Column() {
      if (this.数据为空()) {
        Text($r('app.string.stats_empty_section'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 应用尺寸.间距_16, bottom: 应用尺寸.间距_16 })
      } else {
        this.渲染预测(this.条目缓存, this.取最大值(this.条目缓存), this.预测数据 as FutureDue)
      }
    }
    .width('100%')
  }

  @Builder
  private 渲染预测(条目: 预测项[], 最大值: number, d: FutureDue) {
    Column({ space: 应用尺寸.间距_8 }) {
      // 可拖动柱状图：固定柱子宽度，超出屏幕宽度，拖动 snap 对齐到最近柱子居中
      // Stack alignment=Start 让 Row 从左边缘开始，translate 偏移才与取对齐偏移公式一致
      Stack({ alignContent: Alignment.Start }) {
        Row() {
          ForEach(条目, (项: 预测项, 索引: number) => {
            Column() {
              // 数字标签：始终显示该日具体数量
              Text(项.数量 > 0 ? `${项.数量}` : '')
                .fontSize(9)
                .fontColor($r('app.color.text_secondary'))
                .height(this.数字标签高度)
                .width('100%')
                .textAlign(TextAlign.Center)
              // 柱子区
              Stack({ alignContent: Alignment.Bottom }) {
                Column()
                  .width('100%')
                  .height(应用尺寸.进度条高度)
                  .backgroundColor(this.容器色)
                  .borderRadius(应用尺寸.圆角_进度条)
                Column()
                  .width('100%')
                  .height((项.数量 / 最大值) * this.柱子区高度)
                  .backgroundColor(项.天数 < 0 ? '#999999' : this.主色)
                  .borderRadius(应用尺寸.圆角_进度条)
              }
              .width('100%')
              .height(this.柱子区高度)
            }
            .width(this.柱子宽度)
            .height(this.图表高度)
            .justifyContent(FlexAlign.End)
          }, (项: 预测项) => `${项.天数}`)
        }
        .width(条目.length * this.柱子宽度)
        .height(this.图表高度)
        .translate({ x: this.偏移X })
      }
      .width('100%')
      .height(this.图表高度)
      .clip(true)
      .onAreaChange((oldValue: Area, newValue: Area) => {
        const w = newValue.width as number
        if (w > 0 && this.容器宽度 !== w) {
          this.容器宽度 = w
          // 容器尺寸变化时重新对齐到当前索引
          this.偏移X = this.取对齐偏移(this.当前索引)
        }
      })
      .gesture(
        PanGesture()
          .onActionStart(() => {
            this.起始偏移 = this.偏移X
          })
          .onActionUpdate((event: GestureEvent) => {
            this.偏移X = this.起始偏移 + event.offsetX
          })
          .onActionEnd(() => {
            const 索引 = this.取最近索引(this.偏移X)
            animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
              this.偏移X = this.取对齐偏移(索引)
              this.当前索引 = 索引
            })
          })
      )

      // 摘要信息行：对齐 Anki 桌面 Future Due 表格 4 项数值（窄屏自动换行）
      Flex({ wrap: FlexWrap.Wrap }) {
        Text($r('app.string.stats_forecast_total', this.取总计()))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .margin({ right: 应用尺寸.间距_8, bottom: 应用尺寸.间距_4 })
        Text($r('app.string.stats_forecast_average', this.取平均().toFixed(1)))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .margin({ right: 应用尺寸.间距_8, bottom: 应用尺寸.间距_4 })
        Text($r('app.string.stats_forecast_due_tomorrow', this.取明日到期()))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .margin({ right: 应用尺寸.间距_8, bottom: 应用尺寸.间距_4 })
        Text($r('app.string.stats_forecast_daily_load', d.dailyLoad))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      // 积压提示
      if (d.haveBacklog) {
        Text($r('app.string.stats_forecast_has_backlog'))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }
    }
    .width('100%')
  }
}
