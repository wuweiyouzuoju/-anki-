// SPDX-License-Identifier: AGPL-3.0-or-later

import { display } from '@kit.ArkUI';
import {
  加载工具栏位置,
  保存工具栏位置,
  学习工具栏标识,
  工具栏位置
} from '../model/学习布局存储';
import { 应用尺寸 } from '../utils/应用尺寸';
import {
  RATING_AGAIN,
  RATING_EASY,
  RATING_GOOD,
  RATING_HARD
} from '../proto/messages/SchedulerMessages';
import {
  边缘留白,
  顶部预留,
  底部预留,
  工具栏宽度,
  工具栏高度,
  工具栏标识,
  吸附侧
} from '../utils/工具栏尺寸';
import {
  学习阶段,
  吸附结果,
  夹紧X方向,
  夹紧Y方向,
  吸附到侧边,
  推断吸附侧
} from '../utils/吸附计算器';
import { 颜色键 } from '../model/颜色主题';

const 显示答案标签: number = 100;
const 埋藏标签: number = 101;
const 暂停标签: number = 102;

@Component
export struct 学习浮动工具栏 {
  @Prop 工具栏类型: 学习工具栏标识 = 'main';
  @Prop 当前阶段: 学习阶段 = 'question';
  @Prop 评分按钮文案: string[] = [];
  @Prop 兜底文案: string[] = [];
  @Prop 是否深色: boolean = false;

  显示答案回调: () => void = (): void => {};
  埋藏回调: () => void = (): void => {};
  暂停回调: () => void = (): void => {};
  评分回调: (评分: number) => void = (评分: number): void => {};

  @State private 位置X: number = 0;
  @State private 位置Y: number = 0;
  @State private 位置已加载: boolean = false;
  @State private 是否吸附: boolean = true;
  @State private 当前吸附侧: 吸附侧 = 'right';

  private 屏幕宽vp: number = 0;
  private 屏幕高vp: number = 0;
  private 拖动起点手指X: number = 0;
  private 拖动起点手指Y: number = 0;
  private 拖动起点位置X: number = 0;
  private 拖动起点位置Y: number = 0;

  private 屏幕变化回调: ((id: number) => void) | null = null;

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.动作主色按下) private 动作主色按下: string = '#1E4FB8';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下: string = '#1E4FB8';
  @StorageProp(颜色键.主色容器) private 主色容器: string = '#E8EEFC';
  @StorageProp(颜色键.主色边框) private 主色边框: string = '#B8CEFA';
  @State private 按下的评分: number = -1;

  async aboutToAppear(): Promise<void> {
    this.读取屏幕尺寸();
    await this.加载初始位置();
    this.注册屏幕变化监听();
  }

  aboutToDisappear(): void {
    this.注销屏幕变化监听();
  }

  private 读取屏幕尺寸(): void {
    try {
      const 显示器: display.Display = display.getDefaultDisplaySync();
      this.屏幕宽vp = px2vp(显示器.width);
      this.屏幕高vp = px2vp(显示器.height);
    } catch (error) {
      this.屏幕宽vp = 360;
      this.屏幕高vp = 720;
    }
  }

  private 注册屏幕变化监听(): void {
    if (this.屏幕变化回调 !== null) {
      return;
    }
    const 屏幕变化回调函数: (id: number) => void = (_id: number): void => {
      const 旧宽: number = this.屏幕宽vp;
      const 旧高: number = this.屏幕高vp;
      this.读取屏幕尺寸();
      if (this.屏幕宽vp === 旧宽 && this.屏幕高vp === 旧高) {
        return;
      }
      const 最终宽: number = 工具栏宽度(this.工具栏类型, this.是否吸附);
      const 最终高: number = 工具栏高度(this.工具栏类型, this.是否吸附, this.当前阶段);
      if (this.当前吸附侧 === 'left') {
        this.位置X = 边缘留白;
        this.位置Y = 夹紧Y方向(this.位置Y, this.屏幕高vp, this.工具栏类型, this.是否吸附, this.当前阶段);
      } else if (this.当前吸附侧 === 'right') {
        this.位置X = Math.max(边缘留白, this.屏幕宽vp - 最终宽 - 边缘留白);
        this.位置Y = 夹紧Y方向(this.位置Y, this.屏幕高vp, this.工具栏类型, this.是否吸附, this.当前阶段);
      } else if (this.当前吸附侧 === 'top') {
        this.位置X = 夹紧X方向(this.位置X, this.屏幕宽vp, this.工具栏类型, this.是否吸附);
        this.位置Y = 顶部预留;
      } else {
        this.位置X = 夹紧X方向(this.位置X, this.屏幕宽vp, this.工具栏类型, this.是否吸附);
        this.位置Y = Math.max(顶部预留, this.屏幕高vp - 最终高 - 底部预留);
      }
    };
    try {
      display.on('change', 屏幕变化回调函数);
      this.屏幕变化回调 = 屏幕变化回调函数;
    } catch (error) {
      this.屏幕变化回调 = null;
    }
  }

  private 注销屏幕变化监听(): void {
    if (this.屏幕变化回调 === null) {
      return;
    }
    try {
      display.off('change', this.屏幕变化回调);
    } catch (error) {
    }
    this.屏幕变化回调 = null;
  }

  private async 加载初始位置(): Promise<void> {
    const 已保存位置: 工具栏位置 | null = await 加载工具栏位置(this.工具栏类型);
    if (已保存位置 !== null) {
      const 推断结果 = 推断吸附侧(
        已保存位置.x, 已保存位置.y,
        this.屏幕宽vp, this.屏幕高vp,
        this.工具栏类型, this.当前阶段
      );
      this.是否吸附 = 推断结果.是否吸附;
      this.当前吸附侧 = 推断结果.吸附侧;
      this.位置X = 夹紧X方向(已保存位置.x, this.屏幕宽vp, this.工具栏类型, this.是否吸附);
      this.位置Y = 夹紧Y方向(已保存位置.y, this.屏幕高vp, this.工具栏类型, this.是否吸附, this.当前阶段);
    } else {
      const 默认位置值: 工具栏位置 = this.默认位置();
      this.位置X = 默认位置值.x;
      this.位置Y = 默认位置值.y;
      this.当前吸附侧 = this.工具栏类型 === 'main' ? 'right' : 'left';
      this.是否吸附 = true;
    }
    this.位置已加载 = true;
  }

  private 默认位置(): 工具栏位置 {
    const 宽: number = 工具栏宽度(this.工具栏类型, true);
    const 高: number = 工具栏高度(this.工具栏类型, true, this.当前阶段);
    if (this.工具栏类型 === 'main') {
      const 位置: 工具栏位置 = {
        x: 夹紧X方向(this.屏幕宽vp - 宽 - 边缘留白, this.屏幕宽vp, this.工具栏类型, true),
        y: 夹紧Y方向((this.屏幕高vp - 高) / 2, this.屏幕高vp, this.工具栏类型, true, this.当前阶段)
      };
      return 位置;
    }
    const 位置: 工具栏位置 = {
      x: 夹紧X方向(边缘留白, this.屏幕宽vp, this.工具栏类型, true),
      y: 夹紧Y方向((this.屏幕高vp - 高) / 2, this.屏幕高vp, this.工具栏类型, true, this.当前阶段)
    };
    return 位置;
  }

  private 持久化位置(): void {
    保存工具栏位置(this.工具栏类型, this.位置X, this.位置Y);
  }

  private 拖动开始(event: GestureEvent): void {
    this.拖动起点手指X = event.fingerList[0].localX;
    this.拖动起点手指Y = event.fingerList[0].localY;
    this.拖动起点位置X = this.位置X;
    this.拖动起点位置Y = this.位置Y;
  }

  private 拖动更新(event: GestureEvent): void {
    const 手指X_vp: number = event.fingerList[0].localX;
    const 手指Y_vp: number = event.fingerList[0].localY;
    const 增量X: number = 手指X_vp - this.拖动起点手指X;
    const 增量Y: number = 手指Y_vp - this.拖动起点手指Y;
    this.位置X = 夹紧X方向(this.拖动起点位置X + 增量X, this.屏幕宽vp, this.工具栏类型, this.是否吸附);
    this.位置Y = 夹紧Y方向(this.拖动起点位置Y + 增量Y, this.屏幕高vp, this.工具栏类型, this.是否吸附, this.当前阶段);
  }

  private 拖动结束(): void {
    const 吸附结果值: 吸附结果 = 吸附到侧边(
      this.位置X, this.位置Y,
      this.屏幕宽vp, this.屏幕高vp,
      this.工具栏类型, this.当前阶段
    );
    this.位置X = 吸附结果值.x;
    this.位置Y = 吸附结果值.y;
    this.当前吸附侧 = 吸附结果值.吸附侧;
    this.是否吸附 = 吸附结果值.是否吸附;
    this.持久化位置();
  }

  private 取评分按钮文案(索引: number): string {
    if (索引 < this.评分按钮文案.length && this.评分按钮文案[索引].length > 0) {
      return this.评分按钮文案[索引];
    }
    if (索引 < this.兜底文案.length) {
      return this.兜底文案[索引];
    }
    return '';
  }

  private 浮卡底色(): string {
    return this.是否深色 ? '#1E293B' : '#FFFFFF';
  }

  private 阴影样式(): ShadowStyle {
    return ShadowStyle.OUTER_DEFAULT_MD;
  }

  @Builder
  private 横版显示答案按钮() {
    Button($r('app.string.study_show_answer'))
      .width('100%')
      .height(应用尺寸.行动按钮高度)
      .fontSize(应用尺寸.字号_标题)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .backgroundColor(this.按下的评分 === 显示答案标签 ? this.主色按钮按下 : this.主色按钮背景)
      .borderRadius(应用尺寸.圆角_面板)
      .animation({ duration: 80, curve: Curve.EaseOut })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) { this.按下的评分 = 显示答案标签; }
        else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下的评分 = -1; }
      })
      .onClick(() => {
        this.显示答案回调();
      })
  }

  @Builder
  private 横版评分按钮(评分: number, 文字色: ResourceColor) {
    Button(this.取评分按钮文案(评分))
      .layoutWeight(1)
      .height(应用尺寸.行动按钮高度)
      .fontSize(应用尺寸.字号_按钮)
      .fontColor(文字色)
      .backgroundColor(this.按下的评分 === 评分 ? this.主色容器 : $r('app.color.surface_card'))
      .border({ width: 应用尺寸.卡片边框, color: 评分 === RATING_GOOD && this.按下的评分 === 评分 ? this.动作主色 : $r('app.color.border_subtle') })
      .borderRadius(应用尺寸.圆角_面板)
      .animation({ duration: 80, curve: Curve.EaseOut })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) { this.按下的评分 = 评分; }
        else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下的评分 = -1; }
      })
      .onClick(() => {
        this.评分回调(评分);
      })
  }

  @Builder
  private 横版评分按钮行() {
    Row({ space: 应用尺寸.间距_8 }) {
      this.横版评分按钮(RATING_AGAIN, $r('app.color.error_text'))
      this.横版评分按钮(RATING_HARD, $r('app.color.text_primary'))
      this.横版评分按钮(RATING_GOOD, this.动作主色)
      this.横版评分按钮(RATING_EASY, $r('app.color.text_primary'))
    }
    .width('100%')
  }

  @Builder
  private 横版辅助按钮() {
    Row({ space: 应用尺寸.间距_8 }) {
      Button($r('app.string.study_bury'))
        .layoutWeight(1)
        .height(应用尺寸.按钮高度)
        .fontSize(应用尺寸.字号_正文_中)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(this.按下的评分 === 埋藏标签 ? this.主色容器 : $r('app.color.surface_card'))
        .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
        .borderRadius(应用尺寸.圆角_面板)
        .animation({ duration: 80, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent): void => {
          if (event.type === TouchType.Down) { this.按下的评分 = 埋藏标签; }
          else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下的评分 = -1; }
        })
        .onClick(() => {
          this.埋藏回调();
        })
      Button($r('app.string.study_suspend'))
        .layoutWeight(1)
        .height(应用尺寸.按钮高度)
        .fontSize(应用尺寸.字号_正文_中)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(this.按下的评分 === 暂停标签 ? this.主色容器 : $r('app.color.surface_card'))
        .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
        .borderRadius(应用尺寸.圆角_面板)
        .animation({ duration: 80, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent): void => {
          if (event.type === TouchType.Down) { this.按下的评分 = 暂停标签; }
          else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下的评分 = -1; }
        })
        .onClick(() => {
          this.暂停回调();
        })
    }
    .width('100%')
  }

  @Builder
  private 竖版显示答案按钮() {
    Button({ type: ButtonType.Normal }) {
      Text($r('app.string.study_show_answer'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .fontSize(应用尺寸.字号_按钮)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 4, right: 4 })
    .backgroundColor(this.按下的评分 === 显示答案标签 ? this.主色按钮按下 : this.主色按钮背景)
    .borderRadius(应用尺寸.圆角_面板)
    .animation({ duration: 80, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) { this.按下的评分 = 显示答案标签; }
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下的评分 = -1; }
    })
    .onClick(() => {
      this.显示答案回调();
    })
  }

  @Builder
  private 竖版评分按钮(评分: number, 文字色: ResourceColor) {
    Button({ type: ButtonType.Normal }) {
      Text(this.取评分按钮文案(评分))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .fontSize(应用尺寸.字号_按钮)
        .fontColor(文字色)
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(this.按下的评分 === 评分 ? this.主色容器 : $r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: 评分 === RATING_GOOD && this.按下的评分 === 评分 ? this.动作主色 : $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_面板)
    .animation({ duration: 80, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) { this.按下的评分 = 评分; }
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下的评分 = -1; }
    })
    .onClick(() => {
      this.评分回调(评分);
    })
  }

  @Builder
  private 竖版评分按钮列() {
    Column({ space: 应用尺寸.间距_8 }) {
      this.竖版评分按钮(RATING_AGAIN, $r('app.color.error_text'))
      this.竖版评分按钮(RATING_HARD, $r('app.color.text_primary'))
      this.竖版评分按钮(RATING_GOOD, this.动作主色)
      this.竖版评分按钮(RATING_EASY, $r('app.color.text_primary'))
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private 竖版辅助按钮() {
    Column({ space: 应用尺寸.间距_8 }) {
      Button({ type: ButtonType.Normal }) {
        Text($r('app.string.study_bury'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(this.按下的评分 === 埋藏标签 ? this.主色容器 : $r('app.color.surface_card'))
      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
      .borderRadius(应用尺寸.圆角_面板)
      .animation({ duration: 80, curve: Curve.EaseOut })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) { this.按下的评分 = 埋藏标签; }
        else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下的评分 = -1; }
      })
      .onClick(() => {
        this.埋藏回调();
      })
      Button({ type: ButtonType.Normal }) {
        Text($r('app.string.study_suspend'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(this.按下的评分 === 暂停标签 ? this.主色容器 : $r('app.color.surface_card'))
      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
      .borderRadius(应用尺寸.圆角_面板)
      .animation({ duration: 80, curve: Curve.EaseOut })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) { this.按下的评分 = 暂停标签; }
        else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下的评分 = -1; }
      })
      .onClick(() => {
        this.暂停回调();
      })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    if (!this.位置已加载) {
      Stack() {
      }
      .width(0)
      .height(0)
    } else {
      Stack() {
        if (this.是否吸附) {
          Column() {
            if (this.工具栏类型 === 'main') {
              if (this.当前阶段 === 'question') {
                this.竖版显示答案按钮()
              } else if (this.当前阶段 === 'answer') {
                this.竖版评分按钮列()
              }
            } else {
              if (this.当前阶段 === 'question' || this.当前阶段 === 'answer') {
                this.竖版辅助按钮()
              }
            }
          }
          .width('100%')
          .height('100%')
          .padding(应用尺寸.间距_8)
          .backgroundColor(this.浮卡底色())
          .borderRadius(应用尺寸.圆角_面板)
          .border({ width: 应用尺寸.卡片边框, color: this.主色边框 })
          .shadow(this.阴影样式())
        } else {
          Column({ space: 应用尺寸.间距_8 }) {
            if (this.工具栏类型 === 'main') {
              if (this.当前阶段 === 'question') {
                this.横版显示答案按钮()
              } else if (this.当前阶段 === 'answer') {
                this.横版评分按钮行()
              }
            } else {
              if (this.当前阶段 === 'question' || this.当前阶段 === 'answer') {
                this.横版辅助按钮()
              }
            }
          }
          .width('100%')
          .height('100%')
          .padding(应用尺寸.间距_8)
          .backgroundColor(this.浮卡底色())
          .borderRadius(应用尺寸.圆角_面板)
          .border({ width: 应用尺寸.卡片边框, color: this.主色边框 })
          .shadow(this.阴影样式())
        }
      }
      .width(工具栏宽度(this.工具栏类型, this.是否吸附))
      .height(工具栏高度(this.工具栏类型, this.是否吸附, this.当前阶段))
      .position({ x: this.位置X, y: this.位置Y })
      .gesture(
        PanGesture()
          .onActionStart((event: GestureEvent): void => {
            this.拖动开始(event);
          })
          .onActionUpdate((event: GestureEvent): void => {
            this.拖动更新(event);
          })
          .onActionEnd((): void => {
            this.拖动结束();
          })
      )
    }
  }
}
