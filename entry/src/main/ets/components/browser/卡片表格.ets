// SPDX-License-Identifier-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-BROWSER-TABLE-001
// @名称 卡片表格
//
// @作用
// 浏览页结果列表组件。从 浏览页.结果列表区() 提取为独立组件：
// 扁平列表展示卡片/笔记行（对标 Anki 桌面端 Browser 列表），
// 点击行触发 onRowClick，长按行进入多选模式并显示复选框，
// 空结果显示统一空态。滚动到底触发懒加载。
//
// @输入
// 行列表：浏览行数据[]（来自 SearchMessages.BrowserRow）
// 结果总数：搜索结果总数（可能 > 行列表长度，因懒加载；为 0 显示空态）
// 已加载行数：当前已加载的行数（用于判断是否还有更多）
// onRowClick：非多选模式下点击行回调
// onLongPress：长按行进入多选模式时回调
// onLoadMore：滚动到底部时触发，宿主应加载下一批行
//
// @输出
// 渲染扁平列表 / 空态
//
// @业务规则
// - 结果总数 === 0 时显示 统一空态（标题 browser_empty）
// - 非多选模式：点击行 → onRowClick(id)
// - 多选模式：长按行进入并选中该行；点击行切换选中（不触发 onRowClick）；
//   顶部显示「已选 N 项」（browser_select_count，%d 替换），✕ 退出多选
// - 选中ID集合用 Set<number>；切换时整体重新赋值以触发 @State 刷新
// - 滚动到底部且 已加载行数 < 结果总数 时触发 onLoadMore
//
// @副作用
// 无。
// ========================================================

import { 应用尺寸 } from '../../utils/应用尺寸';
import { 统一空态 } from '../common/统一空态';
import type { BrowserCell } from '../../proto/messages/SearchMessages';

/** 单行展示数据：卡片/笔记 ID + 后端返回的单元格 */
export interface 浏览行数据 {
  id: number;
  cells: BrowserCell[];
}

@Component
export struct 卡片表格 {
  @Prop 行列表: 浏览行数据[] = [];
  @Prop 结果总数: number = 0;
  @Prop 已加载行数: number = 0;
  onRowClick: (id: number) => void = (): void => {};
  onLongPress: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};

  @State private 多选模式: boolean = false;
  @State private 选中ID集合: Set<number> = new Set<number>();
  @State private 加载中: boolean = false;

  /** 取行第一列文本作为主文案（Question 列，空则回退 #id）。 */
  private 取行主文案(行: 浏览行数据): string {
    if (行.cells.length === 0) {
      return `#${行.id}`;
    }
    return 行.cells[0].text || `#${行.id}`;
  }

  /** 取行第二列文本作为副文案（Deck 列，可能不存在）。 */
  private 取行副文案(行: 浏览行数据): string {
    if (行.cells.length < 2) {
      return '';
    }
    return 行.cells[1].text || '';
  }

  /** 多选模式下取选中计数文案（browser_select_count，替换 %d）。 */
  private 取选中计数文案(): string {
    const 模板: string = this.getUIContext().getHostContext()!.resourceManager
      .getStringSync($r('app.string.browser_select_count').id);
    return 模板.replace('%d', `${this.选中ID集合.size}`);
  }

  /** 点击行：多选模式下切换选中，否则触发 onRowClick。 */
  private 处理行点击(id: number): void {
    if (this.多选模式) {
      this.设置选中(id, !this.选中ID集合.has(id));
    } else {
      this.onRowClick(id);
    }
  }

  /** 长按行：进入多选模式并选中当前行，通知宿主。 */
  private 处理长按(id: number): void {
    if (this.多选模式) {
      return;
    }
    this.多选模式 = true;
    this.选中ID集合 = new Set<number>([id]);
    this.onLongPress();
  }

  /** 设置某行选中状态（整体重新赋值以触发 @State 刷新）。 */
  private 设置选中(id: number, 选中: boolean): void {
    const 新集合: Set<number> = new Set<number>(this.选中ID集合);
    if (选中) {
      新集合.add(id);
    } else {
      新集合.delete(id);
    }
    this.选中ID集合 = 新集合;
  }

  /** 退出多选模式，清空选中。 */
  private 退出多选(): void {
    this.多选模式 = false;
    this.选中ID集合 = new Set<number>();
  }

  @Builder
  private 选中计数条() {
    Row({ space: 应用尺寸.间距_8 }) {
      Text(this.取选中计数文案())
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Text('✕')
        .fontSize(应用尺寸.字号_标题)
        .fontColor($r('app.color.text_secondary'))
        .padding({
          left: 应用尺寸.间距_8,
          right: 应用尺寸.间距_8,
          top: 应用尺寸.间距_4,
          bottom: 应用尺寸.间距_4
        })
        .onClick((): void => this.退出多选())
    }
    .width('100%')
    .padding({
      left: 应用尺寸.间距_16,
      right: 应用尺寸.间距_16,
      top: 应用尺寸.间距_12,
      bottom: 应用尺寸.间距_12
    })
    .backgroundColor($r('app.color.surface_card'))
  }

  build() {
    Column() {
      if (this.结果总数 === 0) {
        统一空态({
          标题: $r('app.string.browser_empty')
        })
      } else {
        if (this.多选模式) {
          this.选中计数条()
        }

        List({ space: 1 }) {
          ForEach(this.行列表, (行: 浏览行数据, index: number) => {
            ListItem() {
              Row({ space: 应用尺寸.间距_8 }) {
                if (this.多选模式) {
                  Checkbox()
                    .select(this.选中ID集合.has(行.id))
                    .selectedColor($r('app.color.action_primary'))
                    .width(20)
                    .height(20)
                    .onChange((value: boolean): void => {
                      this.设置选中(行.id, value);
                    })
                }

                Column({ space: 应用尺寸.间距_2 }) {
                  Text(this.取行主文案(行))
                    .fontSize(应用尺寸.字号_正文)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')

                  if (this.取行副文案(行) !== '') {
                    Text(this.取行副文案(行))
                      .fontSize(应用尺寸.字号_正文_小)
                      .fontColor($r('app.color.text_secondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding({
                left: 应用尺寸.间距_16,
                right: 应用尺寸.间距_16,
                top: 应用尺寸.间距_12,
                bottom: 应用尺寸.间距_12
              })
              .backgroundColor($r('app.color.surface_page'))
              .onClick((): void => this.处理行点击(行.id))
              .gesture(
                LongPressGesture()
                  .onAction((): void => this.处理长按(行.id))
              )
            }
          }, (行: 浏览行数据): string => `${行.id}`)
        }
        .width('100%')
        .layoutWeight(1)
        .divider({
          strokeWidth: 0.5,
          color: $r('app.color.divider'),
          startMargin: 应用尺寸.间距_16,
          endMargin: 应用尺寸.间距_16
        })
        .onReachEnd((): void => {
          if (!this.加载中 && this.已加载行数 < this.结果总数) {
            this.加载中 = true;
            this.onLoadMore();
            setTimeout((): void => { this.加载中 = false; }, 1000);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
