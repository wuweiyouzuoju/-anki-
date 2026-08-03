// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-PAGE-BROWSER-001
// @名称 浏览页
//
// @作用
// 卡片/笔记浏览器（对标 Anki Browser）。手机端单栏布局：
// 顶部条（返回 + 标题 + Cards/Notes 切换）+ 搜索框 + 结果列表。
// 阶段 1 MVP：可搜索 + 查看只读列表。
// 阶段 2 起在列表行点击后用 bindsheet 弹出详情编辑区。
//
// @输入
// pageDeckId：可选牌组 ID（空=全库浏览）
// pathStack：Navigation 页面栈，用于返回主页
//
// @输出
// 渲染浏览页 NavDestination
//
// @业务规则
// 进入页面即拉取全部卡片（空搜索串）。搜索串由后端构建（前端不拼字符串），
// 保证与 Anki 桌面端搜索语法一致。行数据按需懒加载（浏览器行按ID）。
//
// @Invariants
// - 搜索串必须经 搜索服务.构建搜索串 构建，不前端拼接
// - 浏览模式切换后自动重新搜索
// - 行缓存与 结果ID列表 按索引对齐
//
// @Extension Points
// - T4 搜索框组件将替换内联 TextInput
// - T5 卡片表格组件将替换内联 List
// - T7 详情编辑区将以 bindsheet 形式接入
//
// @副作用
// 通过 搜索服务 调用后端 RPC，读取 Anki collection。
// ========================================================

import { common } from '@kit.AbilityKit';
import { 后端会话 } from '../backend/后端会话';
import { 搜索服务 } from '../backend/搜索服务';
import type {
  BrowserColumn,
  BrowserRow,
  SearchRequest,
  SortOrder
} from '../proto/messages/SearchMessages';
import {
  makeParsableTextNode
} from '../proto/messages/SearchMessages';
import { 应用尺寸 } from '../utils/应用尺寸';
import { CustomTransition } from '../utils/自定义转场';
import { 统一加载态 } from '../components/common/统一加载态';
import { 统一错误态 } from '../components/common/统一错误态';
import { 搜索框 } from '../components/browser/搜索框';
import { 卡片表格, 浏览行数据 } from '../components/browser/卡片表格';
import { 颜色键 } from '../model/颜色主题';

/** 浏览页阶段状态机：loading=加载中，list=列表展示，error=出错 */
type 浏览阶段 = 'loading' | 'list' | 'error';

/** 浏览模式：cards=卡片列表，notes=笔记列表 */
type 浏览模式 = 'cards' | 'notes';

/** 浏览页入栈参数 */
export interface 浏览页参数 {
  /** 可选：限定牌组 ID（空=全库浏览） */
  deckId?: string;
}

@Component
export struct 浏览页 {
  /** Navigation 入栈参数：牌组 ID（空=全库） */
  pageDeckId: string = '';
  /** 页面栈：返回主页时 pop */
  pathStack: NavPathStack = new NavPathStack();
  private readonly 搜索服务实例: 搜索服务 = new 搜索服务();

  @State private 阶段: 浏览阶段 = 'loading';
  @State private 错误详情: string = '';
  @State private 搜索文本: string = '';
  @State private 浏览模式值: 浏览模式 = 'cards';
  @State private 结果ID列表: number[] = [];
  @State private 行列表: 浏览行数据[] = [];
  @State private 列定义: BrowserColumn[] = [];
  /** NavDestination 透明度（由 customNavContentTransition 回调控制，实现淡入淡出转场）。 */
  @State private 转场透明度: number = 1;

  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';
  @StorageProp(颜色键.页面底色微染) private 页面底色微染值: string = '#F5F7FA';

  async aboutToAppear(): Promise<void> {
    // 注册自定义转场回调：首页 Navigation.customNavContentTransition 通过此 name 查找回调，
    // 在 animateTo 内调用起点/终点回调修改 转场透明度，实现淡入淡出（替代系统默认左右平移）。
    // key 用 'BrowserPage'（NavPathStack pushPath 时传的 name，与 from.name / to.name 一致）。
    CustomTransition.getInstance().注册NavParam('BrowserPage',
      (isPush: boolean, isExit: boolean): void => {
        this.转场透明度 = isExit ? 1 : 0;
      },
      (isPush: boolean, isExit: boolean): void => {
        this.转场透明度 = isExit ? 0 : 1;
      }
    );
    await this.执行搜索();
  }

  aboutToDisappear(): void {
    CustomTransition.getInstance().注销NavParam('BrowserPage');
  }

  private 取能力上下文(): common.UIAbilityContext | null {
    const context: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return context === undefined ? null : context;
  }

  // ========================================================
  // @块ID UI-PAGE-BROWSER-002
  // @名称 执行搜索
  //
  // @作用
  // 根据当前搜索文本和浏览模式，调后端搜索卡片/笔记 ID，并预加载前 50 行数据。
  //
  // @输入
  // 搜索文本 + 浏览模式值
  //
  // @输出
  // 更新 阶段 / 结果ID列表 / 行列表 / 列定义
  //
  // @业务规则
  // 搜索串由后端构建搜索串生成（前端不拼字符串）。
  // 首次搜索时拉取列定义（全部浏览器列），后续复用。
  // 行数据按需懒加载，MVP 预加载前 50 行避免首屏空白。
  //
  // @副作用
  // 调后端 构建搜索串 / 搜索卡片 / 搜索笔记 / 全部浏览器列 / 浏览器行按ID
  // ========================================================
  private async 执行搜索(): Promise<void> {
    this.阶段 = 'loading';
    try {
      const context: common.UIAbilityContext | null = this.取能力上下文();
      if (context === null) {
        this.阶段 = 'error';
        this.错误详情 = this.getUIContext().getHostContext()!.resourceManager
          .getStringSync($r('app.string.ability_context_unavailable').id);
        return;
      }
      await 后端会话.获取实例().确保已打开(context.filesDir);

      // 首次搜索时拉取列定义并设置激活列（后端 browser_row_for_id 要求 active_browser_columns 已设置）
      if (this.列定义.length === 0) {
        const cols = await this.搜索服务实例.全部浏览器列();
        this.列定义 = cols.columns;
        // 手机端默认只激活 Question + Deck + Due 三列（cells 顺序按激活列顺序）
        // 列 key 来自 Anki 后端 strum camelCase 序列化（browser_table.rs）：Question→"question" 等
        // 未设置则 browser_row_for_id 报 "Active browser columns not set."
        const 默认列键: string[] = ['question', 'deck', 'cardDue'];
        await this.搜索服务实例.设置激活浏览器列(默认列键);
        console.info(`BrowserPage: 列定义=${cols.columns.length} 列，激活列=${默认列键.join(',')}`);
      }

      // 构建搜索串（后端构建，前端不拼字符串）
      const searchNode = makeParsableTextNode(this.搜索文本);
      const searchStr = await this.搜索服务实例.构建搜索串(searchNode);
      console.info(`BrowserPage: 搜索文本="${this.搜索文本}" 搜索串="${searchStr}"`);

      // 按模式搜索卡片或笔记
      const order: SortOrder = { kind: 'none' };
      const request: SearchRequest = { search: searchStr, order };
      const ids = this.浏览模式值 === 'cards'
        ? await this.搜索服务实例.搜索卡片(request)
        : await this.搜索服务实例.搜索笔记(request);
      console.info(`BrowserPage: 模式=${this.浏览模式值} 搜索返回 ${ids.length} 个 ID`);

      this.结果ID列表 = ids;
      this.行列表 = [];

      // 预加载前 200 行（避免首屏空白；后端 browser_row_for_id 是单 ID 查询，无批量接口）
      await this.预加载行(ids.slice(0, 200));
      console.info(`BrowserPage: 预加载完成 行列表=${this.行列表.length} 行`);

      this.阶段 = 'list';
    } catch (error) {
      this.阶段 = 'error';
      this.错误详情 = error instanceof Error ? error.message : `${error}`;
    }
  }

  /**
   * 加载更多行：取下一批未加载的 ID，预加载后追加到 行列表。
   * 由 卡片表格.onReachEnd 触发；批次大小 100，并发 10。
   */
  private async 加载更多(): Promise<void> {
    const 已加载数: number = this.行列表.length;
    if (已加载数 >= this.结果ID列表.length) {
      return;
    }
    const 下一批: number[] = this.结果ID列表.slice(已加载数, 已加载数 + 100);
    console.info(`BrowserPage: 加载更多 已加载=${已加载数} 本批=${下一批.length} 总=${this.结果ID列表.length}`);
    await this.预加载行(下一批);
    console.info(`BrowserPage: 加载更多完成 行列表=${this.行列表.length} 行`);
  }

  /** 预加载行数据：并行拉取（每批 20 个），累积后一次性赋值触发 UI 刷新。 */
  private async 预加载行(ids: number[]): Promise<void> {
    const 批次大小: number = 20;
    let 成功数: number = 0;
    let 失败数: number = 0;
    const 累积新增: 浏览行数据[] = [];
    for (let i = 0; i < ids.length; i += 批次大小) {
      const 批次: number[] = ids.slice(i, i + 批次大小);
      const 行们: (BrowserRow | null)[] = await Promise.all(
        批次.map((id: number): Promise<BrowserRow | null> => {
          return this.搜索服务实例.浏览器行按ID(id)
            .then((row: BrowserRow): BrowserRow => {
              成功数++;
              return row;
            })
            .catch((err: ESObject): BrowserRow | null => {
              失败数++;
              console.info(`BrowserPage: 浏览器行按ID(${id}) 失败: ${err}`);
              return null;
            });
        })
      );
      批次.forEach((id: number, idx: number): void => {
        const row: BrowserRow | null = 行们[idx];
        if (row !== null) {
          累积新增.push({ id, cells: row.cells });
        }
      });
    }
    // 累积所有批次后一次性赋值，避免循环内多次 concat 导致 @State 更新丢失
    if (累积新增.length > 0) {
      this.行列表 = this.行列表.concat(累积新增);
    }
    console.info(`BrowserPage: 预加载统计 成功=${成功数} 失败=${失败数}`);
  }

  /** 切换浏览模式（cards/notes），切换后自动重新搜索。 */
  private 切换模式(模式: 浏览模式): void {
    if (this.浏览模式值 === 模式) {
      return;
    }
    this.浏览模式值 = 模式;
    this.执行搜索();
  }

  /** 提交搜索（搜索框 onSubmit 触发）。 */
  private 提交搜索(文本: string): void {
    this.搜索文本 = 文本;
    this.执行搜索();
  }

  /** 行点击：阶段 1 仅占位，阶段 2 将打开 bindsheet 详情编辑区。 */
  private 行点击(行ID: number): void {
    // T7 详情编辑区将在此接入
  }

  /** 返回主页。 */
  private 返回(): void {
    this.pathStack.pop();
  }

  @Builder
  private 顶部条() {
    Row({ space: 应用尺寸.间距_8 }) {
      // 返回按钮
      Button($r('app.string.study_back'))
        .height(应用尺寸.按钮高度)
        .padding({ left: 应用尺寸.间距_12, right: 应用尺寸.间距_12 })
        .fontSize(应用尺寸.字号_按钮)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_card'))
        .onClick((): void => this.返回())

      // 标题
      Text($r('app.string.browser_title'))
        .fontSize(应用尺寸.字号_面板标题)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .padding({ left: 应用尺寸.间距_8, right: 应用尺寸.间距_16 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      Column() {
        this.顶部条()

        // 搜索框组件（TextInput + Cards/Notes 模式切换）
        搜索框({
          搜索文本: this.搜索文本,
          浏览模式值: this.浏览模式值,
          主色按钮背景色: this.主色按钮背景色,
          onSearch: (文本: string): void => { this.提交搜索(文本); },
          onModeChange: (模式: string): void => { this.切换模式(模式 as 浏览模式); }
        })
          .padding({ left: 应用尺寸.间距_16, right: 应用尺寸.间距_16, top: 应用尺寸.间距_8,
            bottom: 应用尺寸.间距_8 })

        if (this.阶段 === 'loading') {
          统一加载态({
            文案: $r('app.string.browser_loading')
          })
        }
        if (this.阶段 === 'error') {
          统一错误态({
            文案: this.错误详情 !== '' ? this.错误详情 : $r('app.string.browser_search_error'),
            onRetry: (): void => { this.执行搜索(); }
          })
        }
        if (this.阶段 === 'list') {
          // 卡片表格组件（扁平列表 + 多选 + 空态 + 懒加载）
          卡片表格({
            行列表: this.行列表,
            结果总数: this.结果ID列表.length,
            已加载行数: this.行列表.length,
            onRowClick: (行ID: number): void => { this.行点击(行ID); },
            onLongPress: (): void => {},
            onLoadMore: (): void => { this.加载更多(); }
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.页面底色微染值)
    }
    .hideTitleBar(true)
    .opacity(this.转场透明度)
  }
}
