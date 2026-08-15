// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-WIDGET-STATS-001
// @名称 统计桌面卡片（2×4）
//
// @作用
// 桌面服务卡片 UI：Swiper 8 页
//   1. 月历热力图 / 2. 记忆率 / 3. 今日计数 / 4. 卡片状态
//   5. 小时分布 / 6. 难度分布 / 7. 间隔分布 / 8. 未来到期预测
// 点击卡片通过 postCardAction router 拉起 App 并跳转统计页（jidecards://stats）。
//
// @约束
// - 卡片运行在独立沙箱进程，不能访问 AppStorage / 主进程内存
// - 数据通过 LocalStorageProp 从 FormExtensionAbility 的 updateForm 注入
// - 不能用 Web 组件、Grid/GridItem
// - 卡片 UI 限制：不能用 @StorageLink / @StorageProp，只能用 @LocalStorageProp / @Prop
// - @Builder 内不能用 let/const，复杂数据预处理移到 private 方法
//
// @数据流
// FormExtensionAbility.onUpdateForm → formProvider.updateForm({ statsCardData: JSON字符串 })
// → 卡片 @LocalStorageProp('statsCardData') 接字符串 → aboutToAppear/@Watch 解析到 @State 数据
// → 渲染 8 页 Swiper
//
// @根因修复
// 1. 数据传递：HarmonyOS 卡片 LocalStorage 注入按字段平铺，不支持嵌套对象。
//    FormAbility 整对象 JSON.stringify 塞到单键 'statsCardData'，卡片接字符串后解析。
// 2. @Watch 初始不触发：@Watch 只在值变化时回调，初始挂载不触发。
//    在 aboutToAppear 中手动调 数据更新() 解析初始数据。
// 3. preferences 跨进程不共享：改用 filesDir 文件系统存储（见 桌面卡片数据存储.ets）。
// ========================================================

let 存储键: string = 'statsCardData';

interface 卡片状态数据 {
  新卡: number;
  学习中: number;
  重学中: number;
  年轻: number;
  成熟: number;
  暂停: number;
  埋藏: number;
}

interface 难度分布数据 {
  桶: [number, number][];
  平均: number;
}

interface 主题色 {
  主色按钮背景: string;
  主色容器: string;
  主色文字: string;
  文字主: string;
  文字次: string;
  热力1: string;
  热力2: string;
  热力3: string;
  热力4: string;
  页面底色: string;
  卡片底色: string;
  是否深色: boolean;
}

interface 卡片数据 {
  hasData: boolean;
  月历数据: [string, number][];
  记忆率: number;
  fsrs已启用: boolean;
  今日答题数: number;
  今日正确数: number;
  今日新学数: number;
  今日复习数: number;
  今日重学数: number;
  卡片状态: 卡片状态数据;
  小时分布: [number, number][];
  难度分布: 难度分布数据;
  间隔分布: [number, number][];
  未来到期: [number, number][];
  更新时间: number;
  主题色: 主题色;
}

interface 日历单日 {
  日号: number;
  是否当月: boolean;
  是否今天: boolean;
  热力强度: number;  // 0-4
}

function 空卡片状态(): 卡片状态数据 {
  return { 新卡: 0, 学习中: 0, 重学中: 0, 年轻: 0, 成熟: 0, 暂停: 0, 埋藏: 0 };
}

function 空难度分布(): 难度分布数据 {
  return { 桶: [], 平均: 0 };
}

function 默认主题色(): 主题色 {
  return {
    主色按钮背景: '#2F5FD0',
    主色容器: '#E8EEFC',
    主色文字: '#2F5FD0',
    文字主: '#182230',
    文字次: '#667085',
    热力1: '#DCE8FF',
    热力2: '#B8CEFA',
    热力3: '#7EA3EE',
    热力4: '#2F5FD0',
    页面底色: '#F5F7FA',
    卡片底色: '#FFFFFF',
    是否深色: false
  };
}

function 空卡片数据(): 卡片数据 {
  return {
    hasData: false,
    月历数据: [],
    记忆率: 0,
    fsrs已启用: false,
    今日答题数: 0,
    今日正确数: 0,
    今日新学数: 0,
    今日复习数: 0,
    今日重学数: 0,
    卡片状态: 空卡片状态(),
    小时分布: [],
    难度分布: 空难度分布(),
    间隔分布: [],
    未来到期: [],
    更新时间: 0,
    主题色: 默认主题色()
  };
}

@Entry
@Component
struct 统计卡片 {
  // FormExtensionAbility 推送的 statsCardData 是整对象 JSON 字符串
  // 用 @Watch 监听变化后 parse 到 @State 数据
  @LocalStorageProp(存储键) @Watch('数据更新') 数据JSON: string = '';
  @State 数据: 卡片数据 = 空卡片数据();
  @State 当前页索引: number = 0;
  private 页面总数: number = 8;

  // aboutToAppear：@Watch 初始挂载不触发，需手动解析一次初始数据
  aboutToAppear(): void {
    this.数据更新();
  }

  // ========================================================
  // @名称 数据更新
  // @作用 @Watch 回调：JSON.parse 数据JSON 到 @State 数据
  // ========================================================
  数据更新(): void {
    if (this.数据JSON === '') {
      this.数据 = 空卡片数据();
      return;
    }
    try {
      const 解析: object = JSON.parse(this.数据JSON);
      const obj = 解析 as Record<string, Object>;
      // 区分两种载荷：
      // 1. FormAbility 空态：{ hasData: false }（仅含 hasData 字段）
      // 2. 主进程完整数据：桌面卡片数据接口（含 月历数据/记忆率/... 等字段，无 hasData 字段）
      const 含hasData字段: boolean = obj.hasData !== undefined;
      if (含hasData字段) {
        const 标志: boolean = obj.hasData as boolean;
        if (!标志) {
          // 空态
          this.数据 = 空卡片数据();
          return;
        }
      }
      // 完整数据：按字段逐个提取（避免 object literal 类型推断失败）
      // 用 月历数据 字段是否存在判断是主进程完整数据（而非空态 hasData:true 误传）
      const 月历: Object = obj.月历数据;
      if (月历 === undefined || 月历 === null) {
        this.数据 = 空卡片数据();
        return;
      }
      const 卡状: 卡片状态数据 = (obj.卡片状态 as 卡片状态数据) ?? 空卡片状态();
      const 难分: 难度分布数据 = (obj.难度分布 as 难度分布数据) ?? 空难度分布();
      const 主题: 主题色 = (obj.主题色 as 主题色) ?? 默认主题色();
      this.数据 = {
        hasData: true,
        月历数据: obj.月历数据 as [string, number][] ?? [],
        记忆率: obj.记忆率 as number ?? 0,
        fsrs已启用: obj.fsrs已启用 as boolean ?? false,
        今日答题数: obj.今日答题数 as number ?? 0,
        今日正确数: obj.今日正确数 as number ?? 0,
        今日新学数: obj.今日新学数 as number ?? 0,
        今日复习数: obj.今日复习数 as number ?? 0,
        今日重学数: obj.今日重学数 as number ?? 0,
        卡片状态: 卡状,
        小时分布: obj.小时分布 as [number, number][] ?? [],
        难度分布: 难分,
        间隔分布: obj.间隔分布 as [number, number][] ?? [],
        未来到期: obj.未来到期 as [number, number][] ?? [],
        更新时间: obj.更新时间 as number ?? 0,
        主题色: 主题
      };
    } catch (e) {
      this.数据 = 空卡片数据();
    }
  }

  // 热力色：从主题色载体取 4 档热力色，强度 0 透明
  private 取热力色(强度: number): string {
    const 主题: 主题色 = this.数据.主题色;
    if (强度 === 0) return 'rgba(0,0,0,0)';
    if (强度 === 1) return 主题.热力1;
    if (强度 === 2) return 主题.热力2;
    if (强度 === 3) return 主题.热力3;
    return 主题.热力4;
  }

  // 卡片背景色：跟随主题页面底色（与 App 首页背景一致）
  private 卡片背景色(): string {
    return this.数据.主题色.页面底色;
  }

  // 分区背景色：卡片底色（比页面底色略亮/略暗，形成层次）
  private 分区背景色(): string {
    return this.数据.主题色.卡片底色;
  }

  // 分割线颜色（浅色 #E4E8EF / 深色 #2C3038）
  private 分割线色(): string {
    return this.数据.主题色.是否深色 ? '#2C3038' : '#E4E8EF';
  }

  // 标题框背景色（浅灰，跟随深浅色）
  private 标题框背景色(): string {
    return this.数据.主题色.是否深色 ? '#2C3038' : '#F0F1F4';
  }

  // 解析月历数据并构建当月日历（扁平列表）
  private 构建当月日历(): 日历单日[] {
    const 当前: Date = new Date();
    const 年: number = 当前.getFullYear();
    const 月: number = 当前.getMonth();
    const 当月天数: number = new Date(年, 月 + 1, 0).getDate();
    const 首日周几: number = new Date(年, 月, 1).getDay();
    const 复习计数: Map<string, number> = new Map<string, number>();
    const 月历数组: [string, number][] = this.数据.月历数据;
    for (const 项 of 月历数组) {
      复习计数.set(项[0], 项[1]);
    }
    let 最大值: number = 0;
    复习计数.forEach((值: number) => {
      if (值 > 最大值) 最大值 = 值;
    });
    const 今日键: string = this.日期键(年, 月, 当前.getDate());
    const 单日列表: 日历单日[] = [];
    for (let i: number = 0; i < 首日周几; i++) {
      const 日: number = new Date(年, 月, 0 - (首日周几 - 1 - i)).getDate();
      单日列表.push({ 日号: 日, 是否当月: false, 是否今天: false, 热力强度: 0 });
    }
    for (let 日: number = 1; 日 <= 当月天数; 日++) {
      const 键: string = this.日期键(年, 月, 日);
      const 次数: number = 复习计数.get(键) ?? 0;
      单日列表.push({
        日号: 日,
        是否当月: true,
        是否今天: 键 === 今日键,
        热力强度: this.热力分档(次数, 最大值)
      });
    }
    while (单日列表.length < 35) {
      const 序号: number = 单日列表.length - 首日周几 - 当月天数 + 1;
      单日列表.push({ 日号: 序号, 是否当月: false, 是否今天: false, 热力强度: 0 });
    }
    return 单日列表;
  }

  private 构建当月日历分行(): 日历单日[][] {
    const 扁平: 日历单日[] = this.构建当月日历();
    const 分行: 日历单日[][] = [];
    for (let i: number = 0; i < 扁平.length; i += 7) {
      分行.push(扁平.slice(i, i + 7));
    }
    return 分行;
  }

  private 日期键(年: number, 月: number, 日: number): string {
    const 补零: (n: number) => string = (n: number): string => n < 10 ? `0${n}` : `${n}`;
    return `${年}-${补零(月 + 1)}-${补零(日)}`;
  }

  private 热力分档(次数: number, 最大值: number): number {
    if (次数 <= 0 || 最大值 <= 0) return 0;
    const 比例: number = 次数 / 最大值;
    if (比例 <= 0.25) return 1;
    if (比例 <= 0.5) return 2;
    if (比例 <= 0.75) return 3;
    return 4;
  }

  private 格式化时间(毫秒: number): string {
    if (毫秒 <= 0) return '';
    const 日期: Date = new Date(毫秒);
    const 时: number = 日期.getHours();
    const 分: number = 日期.getMinutes();
    const 补零: (n: number) => string = (n: number): string => n < 10 ? `0${n}` : `${n}`;
    return `更新于 ${补零(时)}:${补零(分)}`;
  }

  // ========================================================
  // 页1：月历热力图
  // ========================================================
  @Builder
  月历页() {
    Column({ space: 4 }) {
      Row() {
        Text('本月复习热力')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.数据.主题色.文字主)
          .layoutWeight(1)
        Text(this.格式化时间(this.数据.更新时间))
          .fontSize(9)
          .fontColor(this.数据.主题色.文字次)
      }
      .width('100%')

      if (this.数据.hasData) {
        Column({ space: 2 }) {
          Row() {
            ForEach(['日', '一', '二', '三', '四', '五', '六'], (日: string) => {
              Text(日)
                .fontSize(8)
                .fontColor(this.数据.主题色.文字次)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
            })
          }
          .width('100%')

          Column({ space: 1 }) {
            ForEach(this.构建当月日历分行(), (行: 日历单日[], 行号: number) => {
              Row({ space: 1 }) {
                ForEach(行, (日: 日历单日, 列号: number) => {
                  Stack() {
                    Text(`${日.日号}`)
                      .fontSize(8)
                      .fontColor(日.是否当月 ? (日.热力强度 >= 4 ? '#FFFFFF' : this.数据.主题色.文字主) : this.数据.主题色.文字次)
                      .fontWeight(日.是否今天 ? FontWeight.Bold : FontWeight.Normal)
                  }
                  .layoutWeight(1)
                  .height(15)
                  .backgroundColor(this.取热力色(日.热力强度))
                  .border({
                    width: 日.是否今天 ? 1 : 0,
                    color: 日.是否今天 ? this.数据.主题色.主色按钮背景 : Color.Transparent
                  })
                  .borderRadius(2)
                }, (日: 日历单日, 列号: number) => `${行号}-${列号}`)
              }
              .width('100%')
            }, (行: 日历单日[], 行号: number) => `${行号}`)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
      } else {
        Column() {
          Text('暂无数据')
            .fontSize(11)
            .fontColor(this.数据.主题色.文字次)
          Text('打开 App 后将显示统计')
            .fontSize(9)
            .fontColor(this.数据.主题色.文字次)
            .margin({ top: 3 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8, left: 10, right: 10, bottom: 8 })
  }

  // ========================================================
  // 页2：记忆率
  // ========================================================
  @Builder
  记忆率页() {
    Column({ space: 4 }) {
      Row() {
        Text('记忆率')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.数据.主题色.文字主)
          .layoutWeight(1)
        Text(this.格式化时间(this.数据.更新时间))
          .fontSize(9)
          .fontColor(this.数据.主题色.文字次)
      }
      .width('100%')

      if (this.数据.hasData && this.数据.fsrs已启用) {
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            Progress({ value: this.数据.记忆率, total: 100, type: ProgressType.Ring })
              .width(75)
              .height(75)
              .color(this.数据.主题色.主色按钮背景)
            Column() {
              Text(`${this.数据.记忆率.toFixed(0)}%`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.数据.主题色.文字主)
              Text('平均可提取率')
                .fontSize(8)
                .fontColor(this.数据.主题色.文字次)
            }
          }
          .width(75)
          .height(75)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.数据.hasData && !this.数据.fsrs已启用) {
        Column() {
          Text('未启用 FSRS')
            .fontSize(13)
            .fontColor(this.数据.主题色.文字主)
          Text('在设置→调度器中开启 FSRS')
            .fontSize(9)
            .fontColor(this.数据.主题色.文字次)
            .margin({ top: 3 })
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text('暂无数据')
            .fontSize(11)
            .fontColor(this.数据.主题色.文字次)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8, left: 10, right: 10, bottom: 8 })
  }

  // ========================================================
  // 页3：今日计数
  // ========================================================
  @Builder
  今日计数页() {
    Column({ space: 4 }) {
      Row() {
        Text('今日学习')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.数据.主题色.文字主)
          .layoutWeight(1)
        Text(this.格式化时间(this.数据.更新时间))
          .fontSize(9)
          .fontColor(this.数据.主题色.文字次)
      }
      .width('100%')

      if (this.数据.hasData) {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            this.计数格('答题', this.数据.今日答题数, this.数据.主题色.主色按钮背景)
            this.计数格('正确', this.数据.今日正确数, '#238463')
          }
          .width('100%')

          Row({ space: 6 }) {
            this.计数格('新学', this.数据.今日新学数, this.数据.主题色.主色文字)
            this.计数格('复习', this.数据.今日复习数, this.数据.主题色.主色容器)
            this.计数格('重学', this.数据.今日重学数, '#B34C00')
          }
          .width('100%')

          if (this.数据.今日答题数 > 0) {
            Text(`正确率 ${Math.round(this.数据.今日正确数 / this.数据.今日答题数 * 100)}%`)
              .fontSize(9)
              .fontColor(this.数据.主题色.文字主)
              .width('100%')
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text('暂无数据')
            .fontSize(11)
            .fontColor(this.数据.主题色.文字次)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8, left: 10, right: 10, bottom: 8 })
  }

  @Builder
  计数格(标签: string, 数值: number, 颜色: string) {
    Column({ space: 1 }) {
      Text(`${数值}`)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(颜色)
      Text(标签)
        .fontSize(8)
        .fontColor(this.数据.主题色.文字次)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // ========================================================
  // 页4：卡片状态（按状态分桶）
  // ========================================================
  @Builder
  卡片状态页() {
    Column({ space: 4 }) {
      Row() {
        Text('卡片状态')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.数据.主题色.文字主)
          .layoutWeight(1)
        Text(this.格式化时间(this.数据.更新时间))
          .fontSize(9)
          .fontColor(this.数据.主题色.文字次)
      }
      .width('100%')

      if (this.数据.hasData) {
        Column({ space: 4 }) {
          Row({ space: 4 }) {
            this.状态格('新卡', this.数据.卡片状态.新卡, '#366ECE')
            this.状态格('学习', this.数据.卡片状态.学习中, '#A05D1C')
            this.状态格('重学', this.数据.卡片状态.重学中, '#B34C00')
            this.状态格('年轻', this.数据.卡片状态.年轻, this.数据.主题色.主色容器)
          }
          .width('100%')

          Row({ space: 4 }) {
            this.状态格('成熟', this.数据.卡片状态.成熟, '#238463')
            this.状态格('暂停', this.数据.卡片状态.暂停, '#D92D20')
            this.状态格('埋藏', this.数据.卡片状态.埋藏, this.数据.主题色.文字次)
          }
          .width('100%')

          // 总计
          Text(`总计 ${this.卡片总数()} 张`)
            .fontSize(9)
            .fontColor(this.数据.主题色.文字主)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text('暂无数据')
            .fontSize(11)
            .fontColor(this.数据.主题色.文字次)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8, left: 10, right: 10, bottom: 8 })
  }

  private 卡片总数(): number {
    const s: 卡片状态数据 = this.数据.卡片状态;
    return s.新卡 + s.学习中 + s.重学中 + s.年轻 + s.成熟 + s.暂停 + s.埋藏;
  }

  @Builder
  状态格(标签: string, 数值: number, 颜色: string) {
    Column({ space: 1 }) {
      Text(`${数值}`)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(颜色)
      Text(标签)
        .fontSize(8)
        .fontColor(this.数据.主题色.文字次)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // ========================================================
  // 页5：小时分布（24 时柱状图）
  // ========================================================
  @Builder
  小时分布页() {
    Column({ space: 4 }) {
      Row() {
        Text('小时分布（全部）')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.数据.主题色.文字主)
          .layoutWeight(1)
        Text(this.格式化时间(this.数据.更新时间))
          .fontSize(9)
          .fontColor(this.数据.主题色.文字次)
      }
      .width('100%')

      if (this.数据.hasData) {
        Column() {
          this.小时柱状图()
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
      } else {
        Column() {
          Text('暂无数据')
            .fontSize(11)
            .fontColor(this.数据.主题色.文字次)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8, left: 10, right: 10, bottom: 8 })
  }

  private 小时最大值(): number {
    let 最大值: number = 1;
    const 数据: [number, number][] = this.数据.小时分布;
    for (let i: number = 0; i < 数据.length; i++) {
      if (数据[i][0] > 最大值) 最大值 = 数据[i][0];
    }
    return 最大值;
  }

  @Builder
  小时柱状图() {
    Row({ space: 1 }) {
      ForEach(this.数据.小时分布, (项: [number, number], 索引: number) => {
        Column({ space: 1 }) {
          // 柱子
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width('70%')
              .height(`${Math.max(项[0] / this.小时最大值() * 100, 项[0] > 0 ? 6 : 0)}%`)
              .backgroundColor(this.数据.主题色.主色按钮背景)
              .borderRadius(1)
          }
          .width('100%')
          .height(50)

          if (索引 % 3 === 0) {
            Text(`${索引}`)
              .fontSize(7)
              .fontColor(this.数据.主题色.文字次)
          } else {
            Text('')
              .fontSize(7)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }, (项: [number, number], 索引: number) => `${索引}`)
    }
    .width('100%')
    .height(65)
    .alignItems(VerticalAlign.Bottom)
  }

  // ========================================================
  // 页6：难度分布（SM-2 难度直方图）
  // ========================================================
  @Builder
  难度分布页() {
    Column({ space: 4 }) {
      Row() {
        Text('难度分布')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.数据.主题色.文字主)
          .layoutWeight(1)
        Text(this.格式化时间(this.数据.更新时间))
          .fontSize(9)
          .fontColor(this.数据.主题色.文字次)
      }
      .width('100%')

      if (this.数据.hasData && this.数据.难度分布.桶.length > 0) {
        Column({ space: 2 }) {
          Text(`平均难度 ${(this.数据.难度分布.平均 / 10).toFixed(1)}%`)
            .fontSize(9)
            .fontColor(this.数据.主题色.文字主)
            .width('100%')
            .textAlign(TextAlign.Center)

          this.难度柱状图()
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
      } else if (this.数据.hasData) {
        Column() {
          Text('暂无难度数据')
            .fontSize(11)
            .fontColor(this.数据.主题色.文字次)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text('暂无数据')
            .fontSize(11)
            .fontColor(this.数据.主题色.文字次)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8, left: 10, right: 10, bottom: 8 })
  }

  private 难度最大值(): number {
    let 最大值: number = 1;
    const 桶: [number, number][] = this.数据.难度分布.桶;
    for (let i: number = 0; i < 桶.length; i++) {
      if (桶[i][1] > 最大值) 最大值 = 桶[i][1];
    }
    return 最大值;
  }

  @Builder
  难度柱状图() {
    Row({ space: 1 }) {
      ForEach(this.数据.难度分布.桶, (项: [number, number], 索引: number) => {
        Column({ space: 1 }) {
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width('70%')
              .height(`${Math.max(项[1] / this.难度最大值() * 100, 项[1] > 0 ? 6 : 0)}%`)
              .backgroundColor(this.数据.主题色.主色按钮背景)
              .borderRadius(1)
          }
          .width('100%')
          .height(55)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }, (项: [number, number], 索引: number) => `${索引}`)
    }
    .width('100%')
    .height(65)
    .alignItems(VerticalAlign.Bottom)
  }

  // ========================================================
  // 页7：间隔分布（卡片间隔天数的直方图）
  // ========================================================
  @Builder
  间隔分布页() {
    Column({ space: 4 }) {
      Row() {
        Text('间隔分布')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.数据.主题色.文字主)
          .layoutWeight(1)
        Text(this.格式化时间(this.数据.更新时间))
          .fontSize(9)
          .fontColor(this.数据.主题色.文字次)
      }
      .width('100%')

      if (this.数据.hasData && this.数据.间隔分布.length > 0) {
        Column({ space: 2 }) {
          this.间隔柱状图()
          Text(`共 ${this.数据.间隔分布.length} 个间隔桶`)
            .fontSize(9)
            .fontColor(this.数据.主题色.文字次)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
      } else if (this.数据.hasData) {
        Column() {
          Text('暂无间隔数据')
            .fontSize(11)
            .fontColor(this.数据.主题色.文字次)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text('暂无数据')
            .fontSize(11)
            .fontColor(this.数据.主题色.文字次)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8, left: 10, right: 10, bottom: 8 })
  }

  private 间隔最大值(): number {
    let 最大值: number = 1;
    const 桶: [number, number][] = this.数据.间隔分布;
    for (let i: number = 0; i < 桶.length; i++) {
      if (桶[i][1] > 最大值) 最大值 = 桶[i][1];
    }
    return 最大值;
  }

  @Builder
  间隔柱状图() {
    Row({ space: 1 }) {
      ForEach(this.数据.间隔分布, (项: [number, number], 索引: number) => {
        Column({ space: 1 }) {
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width('70%')
              .height(`${Math.max(项[1] / this.间隔最大值() * 100, 项[1] > 0 ? 6 : 0)}%`)
              .backgroundColor(this.数据.主题色.主色按钮背景)
              .borderRadius(1)
          }
          .width('100%')
          .height(55)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }, (项: [number, number], 索引: number) => `${索引}`)
    }
    .width('100%')
    .height(65)
    .alignItems(VerticalAlign.Bottom)
  }

  // ========================================================
  // 页8：未来到期预测
  // ========================================================
  @Builder
  预测页() {
    Column({ space: 4 }) {
      Row() {
        Text('未来 7 天到期')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.数据.主题色.文字主)
          .layoutWeight(1)
        Text(this.格式化时间(this.数据.更新时间))
          .fontSize(9)
          .fontColor(this.数据.主题色.文字次)
      }
      .width('100%')

      if (this.数据.hasData) {
        Column() {
          this.预测柱状图()
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
      } else {
        Column() {
          Text('暂无数据')
            .fontSize(11)
            .fontColor(this.数据.主题色.文字次)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8, left: 10, right: 10, bottom: 8 })
  }

  private 预测最大值(): number {
    let 最大值: number = 1;
    const 数据: [number, number][] = this.数据.未来到期;
    for (let i: number = 0; i < 数据.length; i++) {
      if (数据[i][1] > 最大值) 最大值 = 数据[i][1];
    }
    return 最大值;
  }

  @Builder
  预测柱状图() {
    Row({ space: 3 }) {
      ForEach(this.数据.未来到期, (项: [number, number], 索引: number) => {
        Column({ space: 2 }) {
          Text(`${项[1]}`)
            .fontSize(8)
            .fontColor(this.数据.主题色.文字主)
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width('55%')
              .height(`${Math.max(项[1] / this.预测最大值() * 100, 项[1] > 0 ? 8 : 0)}%`)
              .backgroundColor(项[0] === 0 ? this.数据.主题色.主色按钮背景 : this.数据.主题色.主色容器)
              .borderRadius(2)
          }
          .width('100%')
          .height(45)

          Text(项[0] === 0 ? '今' : `+${项[0]}`)
            .fontSize(8)
            .fontColor(项[0] === 0 ? this.数据.主题色.主色按钮背景 : this.数据.主题色.文字次)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }, (项: [number, number], 索引: number) => `${索引}`)
    }
    .width('100%')
    .height(80)
    .alignItems(VerticalAlign.Bottom)
  }

  build() {
    Stack() {
      Column() {
        // 顶部翻页指示点
        Row({ space: 4 }) {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
            Circle()
              .width(i === this.当前页索引 ? 5 : 3)
              .height(i === this.当前页索引 ? 5 : 3)
              .fill(i === this.当前页索引 ? this.数据.主题色.主色按钮背景 : this.数据.主题色.文字次)
              .opacity(i === this.当前页索引 ? 1 : 0.4)
          }, (i: number) => `${i}`)
        }
        .width('100%')
        .height(10)
        .justifyContent(FlexAlign.Center)

        Swiper() {
          this.月历页()
          this.记忆率页()
          this.今日计数页()
          this.卡片状态页()
          this.小时分布页()
          this.难度分布页()
          this.间隔分布页()
          this.预测页()
        }
        .indicator(false)
        .loop(true)
        .autoPlay(false)
        .onChange((index: number) => {
          this.当前页索引 = index;
        })
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.卡片背景色())
    .onClick(() => {
      // 点击卡片拉起 App 跳统计页（jidecards://stats DeepLink）
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': {
          'uri': 'jidecards://stats'
        }
      });
    })
  }
}
