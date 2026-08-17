// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-HOME-SUMMARY-001
// @名称 主页摘要分页
//
// @作用
// 主页顶部摘要卡：Swiper 8 页（可左右滑动，与桌面卡片形态一致）。
//   1. 今日进度 / 2. 记忆率 / 3. 今日计数 / 4. 卡片状态
//   5. 小时分布 / 6. 难度分布 / 7. 间隔分布 / 8. 未来到期预测
// 第1页用 主页快照数据 渲染今日摘要卡；第2-8页用 图表快照 渲染简化统计。
// 图表快照 为 null（图表未加载）时只显示第1页，不显示 Swiper。
//
// @输入
// 主页快照数据: 主页快照（今日完成/记忆率等）
// 图表快照: 桌面卡片数据 | null（提取卡片数据 转换的纯基础类型统计）
//
// @输出
// 渲染 Swiper 8 页或单页今日摘要卡
//
// @副作用
// 无。
// ========================================================

import { 今日摘要卡 } from '../今日摘要卡';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 颜色键 } from '../../model/颜色主题';
import { 桌面卡片数据 } from '../../model/桌面卡片数据存储';
import { 主页快照 } from '../../model/主页模型';

@Component
export struct 主页摘要分页 {
  @Prop 主页快照数据: 主页快照;
  @Prop 图表快照: 桌面卡片数据 | null = null;
  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';
  @StorageProp(颜色键.新卡计数色) private 新卡计数色: string = '#3974D9';
  @StorageProp(颜色键.学习中计数色) private 学习中计数色: string = '#B56A22';
  @StorageProp(颜色键.复习中计数色) private 复习中计数色: string = '#7056C8';
  @State private 当前页: number = 0;

  // ========================================================
  // 页1：今日进度（复用 今日摘要卡 组件）
  // ========================================================
  @Builder
  今日进度页() {
    今日摘要卡({
      已完成数: this.主页快照数据.today.completedCount,
      待学数: this.主页快照数据.today.pendingCount,
      牌组数: this.主页快照数据.today.deckCount,
      今日答对率: this.主页快照数据.memory.state === 'today_answered'
        ? 1 - this.主页快照数据.memory.todayAgainRate : -1
    })
  }

  // ========================================================
  // 页2：记忆率
  // ========================================================
  @Builder
  记忆率页() {
    Column({ space: 应用尺寸.间距_8 }) {
      Row() {
        Text('记忆率')
          .fontSize(应用尺寸.字号_摘要标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(this.格式化时间(this.图表快照!.更新时间))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      if (this.图表快照!.fsrs已启用) {
        Row() {
          Text(`${Math.round(this.图表快照!.记忆率)}%`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.动作主色)
          Text('全库平均可提取率')
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8, bottom: 4 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Bottom)
      } else {
        Column() {
          Text('未启用 FSRS')
            .fontSize(应用尺寸.字号_正文)
            .fontColor($r('app.color.text_secondary'))
          Text('开启 FSRS 后显示全库记忆率')
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height(150)
    .padding(应用尺寸.卡片内边距)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
  }

  // ========================================================
  // 页3：今日计数
  // ========================================================
  @Builder
  今日计数页() {
    Column({ space: 应用尺寸.间距_8 }) {
      Row() {
        Text('今日学习')
          .fontSize(应用尺寸.字号_摘要标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 应用尺寸.间距_10 }) {
        this.计数格('答题', this.图表快照!.今日答题数, this.动作主色)
        this.计数格('正确', this.图表快照!.今日正确数, '#238463')
      }
      .width('100%')

      Row({ space: 应用尺寸.间距_10 }) {
        this.计数格('新学', this.图表快照!.今日新学数, this.新卡计数色)
        this.计数格('复习', this.图表快照!.今日复习数, this.复习中计数色)
        this.计数格('重学', this.图表快照!.今日重学数, this.学习中计数色)
      }
      .width('100%')
    }
    .width('100%')
    .height(150)
    .padding(应用尺寸.卡片内边距)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  计数格(标签: string, 数值: number, 颜色: string) {
    Column({ space: 2 }) {
      Text(数值.toString())
        .fontSize(应用尺寸.字号_指标)
        .fontWeight(FontWeight.Bold)
        .fontColor(颜色)
      Text(标签)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // ========================================================
  // 页4：卡片状态
  // ========================================================
  @Builder
  卡片状态页() {
    Column({ space: 应用尺寸.间距_8 }) {
      Row() {
        Text('卡片状态')
          .fontSize(应用尺寸.字号_摘要标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 应用尺寸.间距_10 }) {
        this.计数格('新卡', this.图表快照!.卡片状态.新卡, this.新卡计数色)
        this.计数格('学习', this.图表快照!.卡片状态.学习中, this.学习中计数色)
        this.计数格('重学', this.图表快照!.卡片状态.重学中, '#B34C00')
      }
      .width('100%')

      Row({ space: 应用尺寸.间距_10 }) {
        this.计数格('年轻', this.图表快照!.卡片状态.年轻, this.复习中计数色)
        this.计数格('成熟', this.图表快照!.卡片状态.成熟, '#238463')
        this.计数格('暂停', this.图表快照!.卡片状态.暂停, '#991B1B')
      }
      .width('100%')
    }
    .width('100%')
    .height(150)
    .padding(应用尺寸.卡片内边距)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
    .justifyContent(FlexAlign.Center)
  }

  // ========================================================
  // 页5：小时分布（24 柱简化柱状图）
  // ========================================================
  @Builder
  小时分布页() {
    Column({ space: 应用尺寸.间距_8 }) {
      Row() {
        Text('小时分布')
          .fontSize(应用尺寸.字号_摘要标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')

      this.柱状图(this.图表快照!.小时分布.map((项: [number, number]): number => 项[0]), this.动作主色)
    }
    .width('100%')
    .height(150)
    .padding(应用尺寸.卡片内边距)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
  }

  // ========================================================
  // 页6：难度分布
  // ========================================================
  @Builder
  难度分布页() {
    Column({ space: 应用尺寸.间距_8 }) {
      Row() {
        Text('难度分布')
          .fontSize(应用尺寸.字号_摘要标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(`平均 ${Math.round(this.图表快照!.难度分布.平均 / 10)}%`)
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      this.柱状图(this.图表快照!.难度分布.桶.map((项: [number, number]): number => 项[1]), this.复习中计数色)
    }
    .width('100%')
    .height(150)
    .padding(应用尺寸.卡片内边距)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
  }

  // ========================================================
  // 页7：间隔分布
  // ========================================================
  @Builder
  间隔分布页() {
    Column({ space: 应用尺寸.间距_8 }) {
      Row() {
        Text('间隔分布')
          .fontSize(应用尺寸.字号_摘要标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')

      this.柱状图(this.图表快照!.间隔分布.map((项: [number, number]): number => 项[1]), this.新卡计数色)
    }
    .width('100%')
    .height(150)
    .padding(应用尺寸.卡片内边距)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
  }

  // ========================================================
  // 页8：未来到期预测
  // ========================================================
  @Builder
  未来到期页() {
    Column({ space: 应用尺寸.间距_8 }) {
      Row() {
        Text('未来到期')
          .fontSize(应用尺寸.字号_摘要标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')

      this.柱状图(this.图表快照!.未来到期.map((项: [number, number]): number => 项[1]), this.动作主色)
    }
    .width('100%')
    .height(150)
    .padding(应用尺寸.卡片内边距)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
  }

  // ========================================================
  // 通用柱状图：数据数组 → 等宽柱状 Row
  // ========================================================
  @Builder
  柱状图(数据: number[], 颜色: string) {
    Row({ space: 2 }) {
      ForEach(数据, (值: number, 索引: number) => {
        Column()
          .layoutWeight(1)
          .height(this.柱高(值, 数据))
          .backgroundColor(颜色)
          .borderRadius(2)
      }, (值: number, 索引: number) => `${索引}_${值}`)
    }
    .width('100%')
    .height(70)
    .alignItems(VerticalAlign.Bottom)
  }

  // 柱高：按最大值等比缩放，最小 2vp 保证可见
  private 柱高(值: number, 数据: number[]): number {
    let 最大值: number = 1;
    for (let i: number = 0; i < 数据.length; i++) {
      if (数据[i] > 最大值) {
        最大值 = 数据[i];
      }
    }
    if (值 <= 0) {
      return 2;
    }
    return Math.max(值 / 最大值 * 70, 2);
  }

  private 格式化时间(毫秒: number): string {
    if (毫秒 <= 0) return '';
    const 日期: Date = new Date(毫秒);
    const 时: number = 日期.getHours();
    const 分: number = 日期.getMinutes();
    const 补零 = (n: number): string => n < 10 ? `0${n}` : `${n}`;
    return `更新于 ${补零(时)}:${补零(分)}`;
  }

  build() {
    if (this.图表快照 === null) {
      // 图表未加载：只显示今日进度单页
      this.今日进度页()
    } else {
      // 指示点叠加在卡片顶部（与桌面卡片一致：卡片内部顶部）
      Stack({ alignContent: Alignment.Top }) {
        Swiper() {
          this.今日进度页()
          this.记忆率页()
          this.今日计数页()
          this.卡片状态页()
          this.小时分布页()
          this.难度分布页()
          this.间隔分布页()
          this.未来到期页()
        }
        .indicator(false)
        .loop(true)
        .autoPlay(false)
        .onAnimationStart((_index: number, targetIndex: number) => {
          this.当前页 = targetIndex;
        })
        .onChange((index: number) => {
          this.当前页 = index;
        })

        // 翻页指示点：叠加在卡片顶部中央
        Row({ space: 4 }) {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
            Circle()
              .width(i === this.当前页 ? 6 : 4)
              .height(i === this.当前页 ? 6 : 4)
              .fill(i === this.当前页 ? this.动作主色 : $r('app.color.text_secondary'))
              .opacity(i === this.当前页 ? 1 : 0.4)
          }, (i: number) => `${i}`)
        }
        .width('100%')
        .height(10)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 6 })
      }
      .width('100%')
    }
  }
}
