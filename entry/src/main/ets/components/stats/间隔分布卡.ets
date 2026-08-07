// SPDX-License-Identifier: AGPL-3.0-or-later

// 间隔分布卡：渲染 GraphsView.intervals（SM-2）或 stability（FSRS）为水平条形图。
// 是否FSRS=true 时展示 stability，否则展示 intervals。

import type { Intervals } from '../../proto/messages/StatsMessages';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 颜色键 } from '../../model/颜色主题';

interface 分布项 {
  标签: string;
  数量: number;
  键: number;
}

@Component
export struct 间隔分布卡 {
  @Prop 间隔数据: Intervals | null = null;
  @Prop FSRS稳定度: Intervals | null = null;
  @Prop 是否FSRS: boolean = false;
  @StorageProp(颜色键.动作主色) private 主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 容器色: string = '#E8EEFC';

  private 取数据(): Intervals | null {
    if (this.是否FSRS && this.FSRS稳定度 !== null) {
      return this.FSRS稳定度;
    }
    return this.间隔数据;
  }

  private 取条目(数据: Intervals): 分布项[] {
    if (数据.intervals === null) {
      return [];
    }
    const 项列表: 分布项[] = [];
    数据.intervals.forEach((值: number, 键: number) => {
      const 标签: string = this.是否FSRS ? `${键}` : `${键}天`;
      const 项: 分布项 = { 标签: 标签, 数量: 值, 键: 键 };
      项列表.push(项);
    });
    项列表.sort((a: 分布项, b: 分布项) => a.键 - b.键);
    return 项列表.slice(0, 20);
  }

  private 取最大值(条目: 分布项[]): number {
    let 最大: number = 0;
    for (let i = 0; i < 条目.length; i++) {
      if (条目[i].数量 > 最大) {
        最大 = 条目[i].数量;
      }
    }
    return 最大 === 0 ? 1 : 最大;
  }

  @Builder
  private 分布行(项: 分布项, 比例: number) {
    Row({ space: 应用尺寸.间距_8 }) {
      Text(项.标签)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
        .width(50)
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(应用尺寸.进度条高度)
          .backgroundColor(this.容器色)
          .borderRadius(应用尺寸.圆角_进度条)
        Column()
          .width(`${比例 * 100}%`)
          .height(应用尺寸.进度条高度)
          .backgroundColor(this.主色)
          .borderRadius(应用尺寸.圆角_进度条)
      }
      .layoutWeight(1)
      .height(应用尺寸.进度条高度)
      Text(`${项.数量}`)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_primary'))
        .width(40)
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  private 数据为空(): boolean {
    const 数据: Intervals | null = this.取数据();
    if (数据 === null) return true;
    return this.取条目(数据).length === 0;
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
        this.渲染间隔(this.取条目(this.取数据() as Intervals), this.取最大值(this.取条目(this.取数据() as Intervals)))
      }
    }
    .width('100%')
  }

  @Builder
  private 渲染间隔(条目: 分布项[], 最大值: number) {
    Column({ space: 应用尺寸.间距_3 }) {
      ForEach(条目, (项: 分布项) => {
        this.分布行(项, 项.数量 / 最大值)
      }, (项: 分布项) => `${项.键}`)
    }
    .width('100%')
  }
}
