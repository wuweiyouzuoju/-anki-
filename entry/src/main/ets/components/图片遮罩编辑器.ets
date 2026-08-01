// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 遮罩描述, 编号颜色 } from '../model/图片遮罩模型';

@Component
export struct 图片遮罩编辑器 {
  @Prop 源图Uri: string = '';
  @Prop 是否深色: boolean = false;
  onConfirm: (遮罩列表: 遮罩描述[]) => void = (_l: 遮罩描述[]): void => {};
  onCancel: () => void = (): void => {};

  @State 遮罩列表: 遮罩描述[] = [];
  @State 当前选中编号: number = 1;
  @State 图片宽高比: number = 1.5;
  @State 画布宽: number = 0;
  @State 画布高: number = 0;
  @State 画布就绪: boolean = false;

  @State 拖动模式: number = 0;
  @State 创建起点归一化X: number = 0;
  @State 创建起点归一化Y: number = 0;
  @State 创建中矩形: 遮罩描述 | null = null;
  @State 移动中索引: number = -1;
  @State 移动偏移归一化X: number = 0;
  @State 移动偏移归一化Y: number = 0;

  private 上下文: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private readonly 最小拖动距离: number = 0.005;

  private 编号候选列表(): number[] {
    return [1, 2, 3, 4, 5];
  }

  private 归一化X(vp: number): number {
    if (this.画布宽 <= 0) {
      return 0;
    }
    return vp / this.画布宽;
  }

  private 归一化Y(vp: number): number {
    if (this.画布高 <= 0) {
      return 0;
    }
    return vp / this.画布高;
  }

  private 命中遮罩(归一化X: number, 归一化Y: number): number {
    for (let i: number = this.遮罩列表.length - 1; i >= 0; i--) {
      const m: 遮罩描述 = this.遮罩列表[i];
      if (归一化X >= m.左 && 归一化X <= m.左 + m.宽
        && 归一化Y >= m.顶 && 归一化Y <= m.顶 + m.高) {
        return i;
      }
    }
    return -1;
  }

  private 拖动开始(event: GestureEvent): void {
    if (this.画布宽 <= 0 || this.画布高 <= 0) {
      return;
    }
    const x: number = this.归一化X(event.fingerList[0].localX);
    const y: number = this.归一化Y(event.fingerList[0].localY);

    const 命中索引: number = this.命中遮罩(x, y);
    if (命中索引 >= 0) {
      this.拖动模式 = 2;
      this.移动中索引 = 命中索引;
      const m: 遮罩描述 = this.遮罩列表[命中索引];
      this.移动偏移归一化X = x - m.左;
      this.移动偏移归一化Y = y - m.顶;
      this.当前选中编号 = m.编号;
      return;
    }

    this.拖动模式 = 1;
    this.创建起点归一化X = x;
    this.创建起点归一化Y = y;
    this.创建中矩形 = {
      形状: 'rect',
      左: x,
      顶: y,
      宽: 0,
      高: 0,
      编号: this.当前选中编号
    };
  }

  private 拖动更新(event: GestureEvent): void {
    if (this.拖动模式 === 0) {
      return;
    }
    const x: number = Math.max(0, Math.min(1, this.归一化X(event.fingerList[0].localX)));
    const y: number = Math.max(0, Math.min(1, this.归一化Y(event.fingerList[0].localY)));

    if (this.拖动模式 === 1 && this.创建中矩形 !== null) {
      this.创建中矩形 = {
        形状: 'rect',
        左: Math.min(this.创建起点归一化X, x),
        顶: Math.min(this.创建起点归一化Y, y),
        宽: Math.abs(x - this.创建起点归一化X),
        高: Math.abs(y - this.创建起点归一化Y),
        编号: this.当前选中编号
      };
      this.重绘();
      return;
    }

    if (this.拖动模式 === 2 && this.移动中索引 >= 0) {
      const m: 遮罩描述 = this.遮罩列表[this.移动中索引];
      const 新左: number = Math.max(0, Math.min(1 - m.宽, x - this.移动偏移归一化X));
      const 新顶: number = Math.max(0, Math.min(1 - m.高, y - this.移动偏移归一化Y));
      const 新列表: 遮罩描述[] = [];
      for (let i: number = 0; i < this.遮罩列表.length; i++) {
        if (i === this.移动中索引) {
          新列表.push({
            形状: 'rect',
            左: 新左,
            顶: 新顶,
            宽: m.宽,
            高: m.高,
            编号: m.编号
          });
        } else {
          新列表.push(this.遮罩列表[i]);
        }
      }
      this.遮罩列表 = 新列表;
      this.重绘();
    }
  }

  private 拖动结束(): void {
    if (this.拖动模式 === 1 && this.创建中矩形 !== null) {
      if (this.创建中矩形.宽 >= this.最小拖动距离 && this.创建中矩形.高 >= this.最小拖动距离) {
        const 新列表: 遮罩描述[] = [];
        for (let i: number = 0; i < this.遮罩列表.length; i++) {
          新列表.push(this.遮罩列表[i]);
        }
        新列表.push(this.创建中矩形);
        this.遮罩列表 = 新列表;
      }
      this.创建中矩形 = null;
    }
    this.拖动模式 = 0;
    this.移动中索引 = -1;
    this.重绘();
  }

  private 重绘(): void {
    if (!this.画布就绪) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.上下文;
    ctx.clearRect(0, 0, this.画布宽, this.画布高);
    for (let i: number = 0; i < this.遮罩列表.length; i++) {
      this.绘制遮罩(this.遮罩列表[i], false);
    }
    if (this.创建中矩形 !== null) {
      this.绘制遮罩(this.创建中矩形, true);
    }
  }

  private 绘制遮罩(遮罩: 遮罩描述, 创建中: boolean): void {
    const ctx: CanvasRenderingContext2D = this.上下文;
    const 像素左: number = 遮罩.左 * this.画布宽;
    const 像素顶: number = 遮罩.顶 * this.画布高;
    const 像素宽: number = 遮罩.宽 * this.画布宽;
    const 像素高: number = 遮罩.高 * this.画布高;
    const 颜色: string = 编号颜色(遮罩.编号);

    ctx.fillStyle = 颜色 + (创建中 ? '88' : '55');
    ctx.fillRect(像素左, 像素顶, 像素宽, 像素高);

    ctx.strokeStyle = 颜色;
    ctx.lineWidth = 2;
    ctx.strokeRect(像素左, 像素顶, 像素宽, 像素高);
  }

  private 撤销最后一个(): void {
    if (this.遮罩列表.length === 0) {
      return;
    }
    const 新列表: 遮罩描述[] = [];
    for (let i: number = 0; i < this.遮罩列表.length - 1; i++) {
      新列表.push(this.遮罩列表[i]);
    }
    this.遮罩列表 = 新列表;
    this.重绘();
  }

  private 清空全部(): void {
    this.遮罩列表 = [];
    this.创建中矩形 = null;
    this.拖动模式 = 0;
    this.移动中索引 = -1;
    this.重绘();
  }

  build() {
    Column({ space: 应用尺寸.间距_12 }) {
      Row({ space: 应用尺寸.间距_8 }) {
        ForEach(this.编号候选列表(), (编号: number) => {
          Button(`c${编号}`)
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor('#FFFFFF')
            .backgroundColor(编号颜色(编号))
            .border({
              width: this.当前选中编号 === 编号 ? 3 : 0,
              color: '#FFFFFF'
            })
            .borderRadius(应用尺寸.圆角_胶囊)
            .onClick((): void => {
              this.当前选中编号 = 编号;
            })
        }, (编号: number): string => `ordinal-btn-${编号}`)

        Button($r('app.string.image_occlusion_undo'))
          .type(ButtonType.Normal)
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_胶囊)
          .enabled(this.遮罩列表.length > 0)
          .onClick((): void => { this.撤销最后一个(); })

        Button($r('app.string.image_occlusion_clear'))
          .type(ButtonType.Normal)
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.error_text'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_胶囊)
          .enabled(this.遮罩列表.length > 0)
          .onClick((): void => { this.清空全部(); })
      }
      .width('100%')

      Text($r('app.string.image_occlusion_hint'))
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Stack() {
        Image(this.源图Uri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .onComplete((e: ImageLoadResult) => {
            if (e.width > 0 && e.height > 0) {
              this.图片宽高比 = e.width / e.height;
            }
          })

        Canvas(this.上下文)
          .width('100%')
          .height('100%')
          .onReady((): void => {
            this.画布就绪 = true;
            this.重绘();
          })
          .onAreaChange((_旧: Area, 新区域: Area) => {
            const 宽: number = typeof 新区域.width === 'number'
              ? 新区域.width : parseInt(新区域.width as string, 10);
            const 高: number = typeof 新区域.height === 'number'
              ? 新区域.height : parseInt(新区域.height as string, 10);
            if (!Number.isNaN(宽) && !Number.isNaN(高) && (宽 !== this.画布宽 || 高 !== this.画布高)) {
              this.画布宽 = 宽;
              this.画布高 = 高;
              this.重绘();
            }
          })
          .gesture(
            PanGesture()
              .onActionStart((event: GestureEvent): void => { this.拖动开始(event); })
              .onActionUpdate((event: GestureEvent): void => { this.拖动更新(event); })
              .onActionEnd((): void => { this.拖动结束(); })
          )
      }
      .layoutWeight(1)
      .aspectRatio(this.图片宽高比)
      .backgroundColor(this.是否深色 ? '#000000' : '#F5F5F5')
      .borderRadius(应用尺寸.圆角_面板)
      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })

      Row({ space: 应用尺寸.间距_8 }) {
        Button($r('app.string.image_occlusion_cancel'))
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_胶囊)
          .onClick((): void => { this.onCancel(); })

        Button($r('app.string.image_occlusion_confirm'))
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor('#FFFFFF')
          .backgroundColor(编号颜色(this.当前选中编号))
          .borderRadius(应用尺寸.圆角_胶囊)
          .enabled(this.遮罩列表.length > 0)
          .onClick((): void => { this.onConfirm(this.遮罩列表); })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(应用尺寸.卡片内边距)
  }
}
