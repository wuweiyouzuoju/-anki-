// SPDX-License-Identifier: AGPL-3.0-or-later

// 添加笔记页：独立全屏建卡页（Task 9）。
// 由 首页.ets 通过 Navigation pathStack 以 NavDestination 形式入栈（与 学习页 同机制），
// 取代原 添加笔记面板 弹层。Cloze 笔记类型下提供 c1-c5 快捷挖空按钮与保存前预校验。
// Task 10：笔记类型加载失败时 try/catch 捕获，错误信息在 错误信息 显示，不静默 rejection。
// T3：Image Occlusion 笔记类型下切换为图片遮盖建卡专属布局（选图 → 编辑遮罩 → Header/Back Extra → Tags），
// 首次进入时若无 ImageOcclusion 笔记类型则自动调后端添加并重新拉取列表。

import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { 后端会话 } from '../backend/后端会话';
import { 笔记服务, 笔记字段校验错误 } from '../backend/笔记服务';
import { 笔记类型服务 } from '../backend/笔记类型服务';
import { 图片遮罩服务 } from '../backend/图片遮罩服务';
import type { 图片遮罩字段索引 } from '../backend/图片遮罩服务';
import { 媒体服务 } from '../backend/媒体服务';
import { 文本中的填空编号 } from '../model/填空解析器';
import { 生成Occlusions字符串 } from '../model/图片遮罩模型';
import type { 遮罩描述 } from '../model/图片遮罩模型';
import { 加载主题模式 } from '../model/主题存储';
import { 解析是否深色, 主题模式 } from '../model/主题设置';
import { 字段帮助面板 } from '../components/字段帮助面板';
import { 图片遮罩编辑器 } from '../components/图片遮罩编辑器';
import { 从图库选取图片 } from '../utils/文件导入助手';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';
import type { EditableNote } from '../proto/messages/NoteMessages';
import type { NotetypeNameId, NotetypeView } from '../proto/messages/NotetypeMessages';

/** 建卡目标牌组候选（通过 Navigation param 传入） */
export interface 添加笔记牌组选项 {
  id: number;
  name: string;
}

/** 笔记类型下拉候选 */
export interface 添加笔记笔记类型选项 {
  id: number;
  name: string;
}

/** Select 组件所需选项结构 */
interface 添加笔记下拉选项 {
  value: string;
}

/** Navigation 入栈参数（与 学习页参数 同风格） */
export interface 添加笔记页参数 {
  deckId?: string;
  deckName?: string;
  deckOptions?: 添加笔记牌组选项[];
}

@Component
export struct 添加笔记页 {
  /** Navigation 入栈参数 */
  pageDeckId: string = '';
  pageDeckName: string = '';
  pageDeckOptions: 添加笔记牌组选项[] = [];
  /** 页面栈：保存成功 / 取消时 pop 返回牌组详情 */
  pathStack: NavPathStack = new NavPathStack();

  private readonly 笔记服务实例: 笔记服务 = new 笔记服务();
  private readonly 笔记类型服务实例: 笔记类型服务 = new 笔记类型服务();
  private readonly 图片遮罩服务实例: 图片遮罩服务 = new 图片遮罩服务();
  private readonly 媒体服务实例: 媒体服务 = new 媒体服务();
  // Cloze Text 字段专用 controller：用于点击 c1-c5 后定位光标。
  // 仅 cloze 笔记类型的 Text 字段绑定此 controller，其它字段不绑定。
  private readonly 填空字段控制器: TextAreaController = new TextAreaController();

  @State private 牌组ID: number = 0;
  @State private 牌组名: string = '';
  @State private 牌组选项: 添加笔记牌组选项[] = [];
  @State private 已选笔记类型ID: number = 0;
  @State private 笔记类型选项: 添加笔记笔记类型选项[] = [];
  @State private 字段名列表: string[] = [];
  @State private 字段值列表: string[] = [];
  // 笔记类型名称用于判断是否为 Cloze（Anki 默认 Cloze 笔记类型名为 "Cloze"）
  @State private 笔记类型名: string = '';
  @State private 笔记类型帮助: Resource = $r('app.string.add_note_notetype_help');
  @State private 标签: string = '';
  @State private 高级已展开: boolean = false;
  @State private 错误信息: string = '';
  @State private 处理中: boolean = false;
  @State private 保存按下: boolean = false;
  @State private 显示帮助: boolean = false;
  @State private 帮助标题: Resource = $r('app.string.add_note_deck');
  @State private 帮助正文: Resource = $r('app.string.add_note_deck_help');
  // Cloze Text 字段最近一次选区/光标位置（onSelect 更新）。
  // 起===止 视为光标位置；起=-1 表示从未触发 onSelect，回退到文末插入。
  @State private 填空选区起: number = -1;
  @State private 填空选区止: number = -1;

  // ========================================================
  // @块ID UI-PAGE-ADDNOTE-IMG-OCC-STATE
  // @名称 图片遮盖建卡状态
  //
  // @作用
  // Image Occlusion 笔记类型下的建卡状态：是否进入专属布局、选图 URI、
  // 遮罩列表、Header/Back Extra 文本、是否显示遮罩编辑器全屏弹层。
  // 仅当 是否图片遮盖模式 === true 时这些字段才被读写。
  //
  // @输入
  // 加载笔记类型 进入 'Image Occlusion' 时置位；选图/编辑遮罩/输入文本时由 UI 写入。
  //
  // @输出
  // 驱动 build() 中的条件渲染与 图片遮盖_提交() 的字段填充。
  //
  // @业务规则
  // 切换出 ImageOcclusion 模式时所有字段重置为初值，避免脏数据残留。
  //
  // @副作用
  // 无（纯状态字段）。
  // ========================================================
  @State private 是否图片遮盖模式: boolean = false;
  @State private 图片遮盖_源图Uri: string = '';
  @State private 图片遮盖_遮罩列表: 遮罩描述[] = [];
  @State private 图片遮盖_标题: string = '';
  @State private 图片遮盖_额外: string = '';
  @State private 图片遮盖_显示编辑器: boolean = false;
  // 当前实际是否深色模式（与 首页/学习页 同语义：主题模式 + 系统暗黑模式合成）
  @State private 主题模式值: 主题模式 = 'system';
  @StorageLink('systemDarkMode') private 系统暗黑模式: boolean = false;

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  // 2.1.4.1 对比度：按钮背景专用档（配 #FFFFFF 文字 ≥ 4.5:1）
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下色: string = '#1E4FB8';
  // ⓘ 圆形按钮背景色（淡蓝容器色，配 动作主色 深蓝字符）
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';

  async aboutToAppear(): Promise<void> {
    this.牌组ID = this.pageDeckId === '' ? 0 : parseInt(this.pageDeckId);
    this.牌组名 = this.pageDeckName;
    this.牌组选项 = this.pageDeckOptions;
    // 加载主题模式用于图片遮罩编辑器的深色判断；失败回退默认 'system'，不阻塞建卡流程。
    try {
      this.主题模式值 = await 加载主题模式();
    } catch (错误) {
      this.主题模式值 = 'system';
    }
    await this.加载初始数据();
  }

  /** 暗色模式判断：主题模式值=system 时跟随系统，否则按显式选择。与 学习页.ets 同语义。 */
  private 是否深色(): boolean {
    return 解析是否深色(this.主题模式值, this.系统暗黑模式);
  }

  private 取能力上下文(): common.UIAbilityContext | null {
    const 上下文: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return 上下文 === undefined ? null : 上下文;
  }

  /** 读取本地化文案，context 不可用时回退空串。 */
  private 取本地化文案(资源: Resource): string {
    const 上下文: common.UIAbilityContext | null = this.取能力上下文();
    if (上下文 === null) {
      return '';
    }
    try {
      return 上下文.resourceManager.getStringSync(资源.id);
    } catch (错误) {
      return '';
    }
  }

  // ========================================================
  // @块ID UI-PAGE-ADDNOTE-001
  // @名称 加载初始数据
  //
  // @作用
  // 打开本地 collection，拉取默认笔记类型与笔记类型名列表，进入首个笔记类型字段加载。
  //
  // @输入
  // 无（从 取能力上下文 取 filesDir，调后端服务）
  //
  // @输出
  // 成功 → 填充 笔记类型选项 并调 加载笔记类型；失败 → 在 错误信息 显示加载失败文案
  //
  // @业务规则
  // context 不可用时直接报错，不进入后端调用。
  // 笔记类型名列表映射为下拉候选结构（id + name）。
  // T3.2：若列表中无 'Image Occlusion'，调一次 图片遮罩服务.添加图片遮罩笔记类型() 后重新拉取列表；
  //   该调用失败时记录到 错误信息，但不阻断主流程（用户仍能选其他类型）。
  // 2026-07-28：3 个 Basic 变种（附翻转卡片 / 可选附翻转卡片 / 输入答案）暂不做 UI 适配，
  //   从下拉列表隐藏；默认值若被过滤掉则 fallback 到可见列表首个 id。
  //
  // @副作用
  // 调后端 确保已打开 / 获取添加默认值 / 获取笔记类型名列表；读写 处理中 状态
  // ========================================================
  private async 加载初始数据(): Promise<void> {
    this.处理中 = true;
    this.错误信息 = '';
    const 上下文: common.UIAbilityContext | null = this.取能力上下文();
    if (上下文 === null) {
      this.错误信息 = this.取本地化文案($r('app.string.add_note_notetype_load_failed'));
      this.处理中 = false;
      return;
    }
    try {
      await 后端会话.获取实例().确保已打开(上下文.filesDir);
      const 默认值 = await this.笔记服务实例.获取添加默认值();
      let 名称列表: NotetypeNameId[] = await this.笔记类型服务实例.获取笔记类型名列表();
      // T3.2：Anki 26.05 默认 collection 不预置 ImageOcclusion，需主动调一次 add。
      // 调用失败不阻断主流程（用户仍能选其他类型）；只在 错误信息 留一条提示。
      // 注意：后端返回的笔记类型名是本地化的（中文环境下为「图片遮盖」），用 是图片遮盖笔记类型名 识别。
      if (!名称列表.some((项: NotetypeNameId): boolean => this.是图片遮盖笔记类型名(项.name))) {
        try {
          await this.图片遮罩服务实例.添加图片遮罩笔记类型();
          名称列表 = await this.笔记类型服务实例.获取笔记类型名列表();
        } catch (图片遮罩添加错误) {
          // 不抛出，主流程继续用现有 名称列表（无 Image Occlusion 选项）。
          // 仅在 错误信息 中追加提示，方便用户感知后端问题。
          this.错误信息 = 图片遮罩添加错误 instanceof Error
            ? 图片遮罩添加错误.message : `${图片遮罩添加错误}`;
        }
      }
      // 用户决策 2026-07-28：3 个 Basic 变种（附翻转卡片 / 可选附翻转卡片 / 输入答案）
      // 暂不做 UI 适配，从下拉列表隐藏，后续考虑。相关帮助文案/名集合保留不删，便于后续启用。
      const 可见名称列表: NotetypeNameId[] = 名称列表.filter(
        (项: NotetypeNameId): boolean => !this.是隐藏的笔记类型变种(项.name)
      );
      this.笔记类型选项 = 可见名称列表.map((项: NotetypeNameId): 添加笔记笔记类型选项 => ({
        id: 项.id, name: 项.name
      }));
      // 默认值若被过滤掉（如上次用过变种类型），fallback 到可见列表首个 id。
      const 默认ID可见: boolean = 可见名称列表.some(
        (项: NotetypeNameId): boolean => 项.id === 默认值.notetypeId
      );
      const 加载ID: number = 默认ID可见 || 可见名称列表.length === 0
        ? 默认值.notetypeId
        : 可见名称列表[0].id;
      await this.加载笔记类型(加载ID);
    } catch (错误) {
      this.已选笔记类型ID = 0;
      this.字段名列表 = [];
      this.字段值列表 = [];
      this.错误信息 = this.取本地化文案($r('app.string.add_note_notetype_load_failed'));
    } finally {
      this.处理中 = false;
    }
  }

  // ========================================================
  // @块ID UI-PAGE-ADDNOTE-002
  // @名称 加载笔记类型
  //
  // @作用
  // 按 notetypeId 拉取笔记类型视图，填充字段名/字段值/帮助文案；失败时清空字段并在 错误信息 提示。
  //
  // @输入
  // notetypeId: 笔记类型 ID
  //
  // @输出
  // 成功 → 更新 已选笔记类型ID / 笔记类型名 / 笔记类型帮助 / 字段名列表 / 字段值列表；
  //        字段值列表全部初始化为空串，填空选区重置为 -1。
  // 失败 → 清空上述字段并显示加载失败文案。
  //
  // @业务规则
  // Task 10：失败时 try/catch 捕获并在 错误信息 提示，不静默 rejection。
  //
  // @副作用
  // 调后端 获取笔记类型；读写 处理中 状态
  // ========================================================
  private async 加载笔记类型(notetypeId: number): Promise<void> {
    this.处理中 = true;
    try {
      const 视图: NotetypeView = await this.笔记类型服务实例.获取笔记类型(notetypeId);
      this.已选笔记类型ID = notetypeId;
      this.笔记类型名 = 视图.name;
      this.笔记类型帮助 = this.笔记类型帮助文案(视图.name);
      this.字段名列表 = 视图.fieldNames;
      this.字段值列表 = 视图.fieldNames.map((_名: string): string => '');
      this.填空选区起 = -1;
      this.填空选区止 = -1;
      // T3.3-T3.4：进入 / 退出 ImageOcclusion 模式标志与状态变量重置。
      // 进入时设为 true，build() 切换为图片遮盖专属布局；切换出时清空遮盖状态，避免脏数据残留。
      // 注意：后端笔记类型名是本地化的（中文环境下为「图片遮盖」），用 是图片遮盖笔记类型名 识别。
      if (this.是图片遮盖笔记类型名(视图.name)) {
        this.是否图片遮盖模式 = true;
        this.图片遮盖_源图Uri = '';
        this.图片遮盖_遮罩列表 = [];
        this.图片遮盖_标题 = '';
        this.图片遮盖_额外 = '';
        this.图片遮盖_显示编辑器 = false;
      } else {
        this.是否图片遮盖模式 = false;
        this.图片遮盖_源图Uri = '';
        this.图片遮盖_遮罩列表 = [];
        this.图片遮盖_标题 = '';
        this.图片遮盖_额外 = '';
        this.图片遮盖_显示编辑器 = false;
      }
      this.错误信息 = '';
    } catch (错误) {
      this.已选笔记类型ID = 0;
      this.字段名列表 = [];
      this.字段值列表 = [];
      this.笔记类型名 = '';
      this.笔记类型帮助 = $r('app.string.add_note_notetype_help');
      this.是否图片遮盖模式 = false;
      this.图片遮盖_源图Uri = '';
      this.图片遮盖_遮罩列表 = [];
      this.图片遮盖_标题 = '';
      this.图片遮盖_额外 = '';
      this.图片遮盖_显示编辑器 = false;
      this.错误信息 = this.取本地化文案($r('app.string.add_note_notetype_load_failed'));
    } finally {
      this.处理中 = false;
    }
  }

  // ========================================================
  // @块ID UI-PAGE-ADDNOTE-LOCALE-MATCH
  // @名称 笔记类型与字段名本地化识别
  //
  // @作用
  // Anki 后端创建 stock notetype 时使用 tr.*() 翻译笔记类型名与字段名，
  // 中文环境下后端返回的是「图片遮盖」「填空题」「问答题」等中文名，不是英文 'Image Occlusion' / 'Cloze' / 'Basic'。
  // 前端如果只按英文名比较，会导致：
  //   - 是否图片遮盖模式 永远 false → 用户看到 4 个 TextArea 而非选图 UI
  //   - 笔记类型帮助文案 switch 永远走 default → 用户看到「一套词」
  //   - 是填空笔记类型 永远 false → c1-c5 按钮不出现
  // 本组助手覆盖 en / zh-CN / zh-TW 三种已知译名，按字段结构识别而非按单一字符串。
  //
  // @输入
  // 笔记类型名或字段名（来自 NotetypeView.name / NotetypeView.fieldNames）
  //
  // @输出
  // boolean：是否匹配
  //
  // @业务规则
  // 译名来源 anki/ftl/core-repo/core/{en,zh-CN,zh-TW}/notetypes.ftl。
  // 新增语言支持时往对应数组追加译名即可，不需改调用点。
  //
  // @副作用
  // 无（纯函数）。
  // ========================================================
  private static readonly 图片遮盖笔记类型名集合: string[] = ['Image Occlusion', '图片遮盖', '影像遮擋'];
  private static readonly 填空笔记类型名集合: string[] = ['Cloze', '填空题'];
  private static readonly Basic笔记类型名集合: string[] = ['Basic', '问答题'];
  private static readonly Basic反转笔记类型名集合: string[] = ['Basic (and reversed card)', '问答题（附翻转卡片）'];
  private static readonly Basic可选反转笔记类型名集合: string[] = ['Basic (optional reversed card)', '问答题（可选附翻转卡片）'];
  private static readonly Basic输入答案笔记类型名集合: string[] = ['Basic (type in the answer)', '问答题（输入答案）'];
  private static readonly Header字段名集合: string[] = ['Header', '标题'];
  private static readonly BackExtra字段名集合: string[] = ['Back Extra', '背面额外'];
  private static readonly TextField名集合: string[] = ['Text', '文字'];

  private 是图片遮盖笔记类型名(名: string): boolean {
    return 添加笔记页.图片遮盖笔记类型名集合.indexOf(名) >= 0;
  }

  private 是填空笔记类型名(名: string): boolean {
    return 添加笔记页.填空笔记类型名集合.indexOf(名) >= 0;
  }

  /** 是否为当前 UI 暂不适配的 Basic 变种（附翻转卡片 / 可选附翻转卡片 / 输入答案），需从下拉列表隐藏。 */
  private 是隐藏的笔记类型变种(名: string): boolean {
    return 添加笔记页.Basic反转笔记类型名集合.indexOf(名) >= 0
      || 添加笔记页.Basic可选反转笔记类型名集合.indexOf(名) >= 0
      || 添加笔记页.Basic输入答案笔记类型名集合.indexOf(名) >= 0;
  }

  private 是Header字段(名: string): boolean {
    return 添加笔记页.Header字段名集合.indexOf(名) >= 0;
  }

  private 是BackExtra字段(名: string): boolean {
    return 添加笔记页.BackExtra字段名集合.indexOf(名) >= 0;
  }

  private 是Text字段(名: string): boolean {
    return 添加笔记页.TextField名集合.indexOf(名) >= 0;
  }

  /** 按当前笔记类型名称返回对应的专门帮助文案；未知类型回退到通用 add_note_notetype_help。 */
  private 笔记类型帮助文案(名: string): Resource {
    if (添加笔记页.Basic笔记类型名集合.indexOf(名) >= 0) {
      return $r('app.string.add_note_notetype_basic_help');
    }
    if (添加笔记页.Basic反转笔记类型名集合.indexOf(名) >= 0) {
      return $r('app.string.add_note_notetype_basic_reversed_help');
    }
    if (添加笔记页.Basic可选反转笔记类型名集合.indexOf(名) >= 0) {
      return $r('app.string.add_note_notetype_basic_optional_reversed_help');
    }
    if (添加笔记页.Basic输入答案笔记类型名集合.indexOf(名) >= 0) {
      return $r('app.string.add_note_notetype_basic_type_answer_help');
    }
    if (添加笔记页.填空笔记类型名集合.indexOf(名) >= 0) {
      return $r('app.string.add_note_notetype_cloze_help');
    }
    if (添加笔记页.图片遮盖笔记类型名集合.indexOf(名) >= 0) {
      return $r('app.string.add_note_notetype_image_occlusion_help');
    }
    return $r('app.string.add_note_notetype_help');
  }

  private 是填空笔记类型(): boolean {
    return this.是填空笔记类型名(this.笔记类型名);
  }

  /** Cloze 挖空作用于 "Text" 字段（Anki Cloze 笔记类型首字段）；找不到则回退首字段。 */
  private 填空字段索引(): number {
    const 索引: number = this.字段名列表.findIndex((名: string): boolean => this.是Text字段(名));
    return 索引 >= 0 ? 索引 : 0;
  }

  private 填空编号列表(): number[] {
    return [1, 2, 3, 4, 5];
  }

  private 更新字段(索引: number, 值: string): void {
    const 下一个 = this.字段值列表.slice();
    下一个[索引] = 值;
    this.字段值列表 = 下一个;
  }

  // ========================================================
  // @块ID UI-PAGE-ADDNOTE-003
  // @名称 解析标签
  //
  // @作用
  // 将 标签 文本按空白拆分并去重，返回有效标签数组。
  //
  // @输入
  // 无（读取 标签 字段）
  //
  // @输出
  // 去重后的标签数组（顺序保留首次出现顺序）
  //
  // @业务规则
  // 空白分隔（含多空格）；空串跳过；已出现的标签不重复加入。
  //
  // @副作用
  // 无
  // ========================================================
  private 解析标签(): string[] {
    const 已见: string[] = [];
    for (const 标签 of this.标签.split(/\s+/)) {
      const 已修剪 = 标签.trim();
      if (已修剪 !== '' && 已见.indexOf(已修剪) < 0) {
        已见.push(已修剪);
      }
    }
    return 已见;
  }

  /**
   * 点击 c{n} 按钮：选中文本则包裹为 {{c{n}::选中文本}}；无选中则在光标位置插入 {{c{n}::}}，
   * 光标移到 :: 之后便于直接输入内容。
   */
  private 应用填空(编号: number): void {
    if (this.处理中) {
      return;
    }
    const 索引: number = this.填空字段索引();
    if (索引 < 0 || 索引 >= this.字段值列表.length) {
      return;
    }
    const 值: string = this.字段值列表[索引];
    const 起: number = this.填空选区起;
    const 止: number = this.填空选区止;
    if (止 > 起 && 起 >= 0 && 止 <= 值.length) {
      const 已选文本: string = 值.substring(起, 止);
      const 标记 = `{{c${编号}::${已选文本}}}`;
      const 新值 = 值.substring(0, 起) + 标记 + 值.substring(止);
      this.更新字段(索引, 新值);
      const 光标位置: number = 起 + 标记.length;
      this.填空选区起 = 光标位置;
      this.填空选区止 = 光标位置;
      this.调度光标(光标位置);
    } else {
      const 插入位置: number = (起 >= 0 && 起 <= 值.length) ? 起 : 值.length;
      const 前缀 = `{{c${编号}::`;
      const 标记 = `${前缀}}}`;
      const 新值 = 值.substring(0, 插入位置) + 标记 + 值.substring(插入位置);
      this.更新字段(索引, 新值);
      // 光标定位到 :: 之后（前缀末尾），便于直接输入答案
      const 光标位置: number = 插入位置 + 前缀.length;
      this.填空选区起 = 光标位置;
      this.填空选区止 = 光标位置;
      this.调度光标(光标位置);
    }
  }

  // TextArea 绑定的 text 由 @State 驱动，更新后下一帧才重渲染，故光标定位延后到下一个事件循环。
  private 调度光标(位置: number): void {
    setTimeout(() => {
      try {
        this.填空字段控制器.caretPosition(位置);
      } catch (错误) {
        // 光标定位失败不影响功能，用户可手动点选
      }
    }, 0);
  }

  // ========================================================
  // @块ID UI-PAGE-ADDNOTE-004
  // @名称 提交前校验填空
  //
  // @作用
  // Cloze 笔记类型保存前预校验：Text 字段必须含至少一个 {{cN::}} 标记，避免后端 MISSING_CLOZE。
  //
  // @输入
  // 无（读取 笔记类型名 / 字段名列表 / 字段值列表）
  //
  // @输出
  // 非 Cloze 类型 → true（跳过校验）；
  // Cloze 类型且 Text 字段含 {{cN::}} 标记 → true；否则 → false。
  //
  // @业务规则
  // 非 Cloze 笔记类型无需校验；Cloze 字段索引找不到时也跳过（兜底首字段也无标记则后端报错）。
  //
  // @副作用
  // 无
  // ========================================================
  private 提交前校验填空(): boolean {
    if (!this.是填空笔记类型()) {
      return true;
    }
    const 索引: number = this.填空字段索引();
    if (索引 < 0 || 索引 >= this.字段值列表.length) {
      return true;
    }
    return 文本中的填空编号(this.字段值列表[索引]).length > 0;
  }

  // ========================================================
  // @块ID UI-PAGE-ADDNOTE-005
  // @名称 提交
  //
  // @作用
  // 校验通过后新建笔记并写入指定牌组；成功 pop 返回牌组详情，失败在 错误信息 显示友好提示。
  //
  // @输入
  // 无（使用 已选笔记类型ID / 字段值列表 / 标签 / 牌组ID）
  //
  // @输出
  // 成功 → pop 页面栈返回牌组详情；
  // 失败 → 在 错误信息 显示对应友好文案（空字段 / 重复 / 缺填空标记 / 其他错误）
  //
  // @业务规则
  // 防重入：处理中 / 牌组ID=0 / 已选笔记类型ID=0 时直接返回。
  // 提交前先调 提交前校验填空，校验失败显示缺填空标记文案。
  // 笔记字段校验错误 按 messageKey 区分：add_note_empty_error / add_note_duplicate_error 单独处理，
  // 其余（MISSING_CLOZE / NOTETYPE_NOT_CLOZE / FIELD_NOT_CLOZE）友好化为同一提示。
  //
  // @副作用
  // 调后端 新建笔记 / 添加笔记；读写 处理中 状态；成功后 pop 页面栈
  // ========================================================
  private async 提交(): Promise<void> {
    if (this.处理中 || this.牌组ID === 0 || this.已选笔记类型ID === 0) {
      return;
    }
    // T3.6：ImageOcclusion 模式走专属提交流程，不复用 Cloze 校验与字段直接填充逻辑。
    if (this.是否图片遮盖模式) {
      await this.图片遮盖_提交();
      return;
    }
    if (!this.提交前校验填空()) {
      this.错误信息 = this.取本地化文案($r('app.string.add_note_cloze_missing'));
      return;
    }
    this.错误信息 = '';
    this.处理中 = true;
    try {
      const 笔记: EditableNote = await this.笔记服务实例.新建笔记(this.已选笔记类型ID);
      笔记.fields = this.字段值列表.slice();
      笔记.tags = this.解析标签();
      await this.笔记服务实例.添加笔记(笔记, this.牌组ID);
      // 笔记添加成功：写 AppStorage 标志位通知首页/牌组详情面板立即刷新统计计数。
      // 不依赖 NavPathStack.onPop 回调（不同设备/API 版本偶发不触发），用 @StorageLink + @Watch 兜底。
      AppStorage.setOrCreate<number>('noteAddedTick', Date.now());
      this.pathStack.pop();
    } catch (错误) {
      if (错误 instanceof 笔记字段校验错误) {
        if (错误.messageKey === 'add_note_empty_error') {
          this.错误信息 = this.取本地化文案($r('app.string.add_note_empty_error'));
        } else if (错误.messageKey === 'add_note_duplicate_error') {
          this.错误信息 = this.取本地化文案($r('app.string.add_note_duplicate_error'));
        } else {
          // MISSING_CLOZE / NOTETYPE_NOT_CLOZE / FIELD_NOT_CLOZE 友好化为同一提示
          this.错误信息 = this.取本地化文案($r('app.string.add_note_cloze_missing'));
        }
      } else {
        this.错误信息 = 错误 instanceof Error ? 错误.message : `${错误}`;
      }
    } finally {
      this.处理中 = false;
    }
  }

  // ========================================================
  // @块ID UI-PAGE-ADDNOTE-IMG-OCC-PICK
  // @名称 选取图片遮盖源图
  //
  // @作用
  // ImageOcclusion 模式下"选择图片 / 更换图片"按钮的点击处理：
  //   调 从图库选取图片（与牌组定制面板同款 PhotoViewPicker），
  //   用户取消或失败时静默返回；成功时把 URI 写入 图片遮盖_源图Uri 并重置遮罩列表。
  //
  // @输入
  // 无（从 取能力上下文 取 context 传给选择器）
  //
  // @输出
  // 成功 → 更新 图片遮盖_源图Uri / 图片遮盖_遮罩列表；
  // 失败 / 取消 → 静默返回，不打错误提示。
  //
  // @业务规则
  // 选图后必须清空遮罩列表——遮罩基于原图坐标，换图后旧遮罩无意义。
  //
  // @副作用
  // 调起系统图库选择 UI。
  // ========================================================
  private async 选取图片遮盖源图(): Promise<void> {
    if (this.处理中) {
      return;
    }
    const 上下文: common.UIAbilityContext | null = this.取能力上下文();
    if (上下文 === null) {
      return;
    }
    const uri: string | null = await 从图库选取图片(上下文);
    if (uri === null || uri === '') {
      // 用户取消或选图失败：静默返回（cancel 是正常流程，与牌组定制面板一致）
      return;
    }
    this.图片遮盖_源图Uri = uri;
    this.图片遮盖_遮罩列表 = [];
  }

  // ========================================================
  // @块ID UI-PAGE-ADDNOTE-IMG-OCC-READ-BYTES
  // @名称 读取图片字节
  //
  // @作用
  // 把 PhotoViewPicker 返回的 URI 流式读为 Uint8Array，供 媒体服务.添加媒体文件 写入 collection.media。
  //
  // @输入
  // URI: PhotoViewPicker / 沙箱路径皆可（fs.openSync 直接消费 picker URI 的临时 provider 权限）
  //
  // @输出
  // Uint8Array：图片全部字节
  //
  // @业务规则
  // 不使用 fs.copyFileSync 中转落盘——copyFileSync 无法安全消费 Harmony picker 返回的临时权限，
  //   必须用 openSync + readSync 流式读（参考 数据迁移服务.按描述符复制文件）。
  // 缓冲区 64KB；读到 0 字节即结束。块拼接到一个大 Uint8Array 返回。
  //
  // @副作用
  // 打开 / 关闭文件描述符。
  // ========================================================
  private 读取图片字节(URI: string): Uint8Array {
    const 文件: fs.File = fs.openSync(URI, fs.OpenMode.READ_ONLY);
    try {
      const 缓冲大小: number = 64 * 1024;
      const 块列表: Uint8Array[] = [];
      let 总长度: number = 0;
      while (true) {
        const 缓冲: ArrayBuffer = new ArrayBuffer(缓冲大小);
        const 读取大小: number = fs.readSync(文件.fd, 缓冲, { length: 缓冲大小 });
        if (读取大小 <= 0) {
          break;
        }
        const 块: Uint8Array = new Uint8Array(缓冲.slice(0, 读取大小));
        块列表.push(块);
        总长度 += 读取大小;
        if (读取大小 < 缓冲大小) {
          break;
        }
      }
      const 结果: Uint8Array = new Uint8Array(总长度);
      let 偏移: number = 0;
      for (const 块 of 块列表) {
        结果.set(块, 偏移);
        偏移 += 块.length;
      }
      return 结果;
    } finally {
      fs.closeSync(文件);
    }
  }

  // ========================================================
  // @块ID UI-PAGE-ADDNOTE-IMG-OCC-SUBMIT
  // @名称 图片遮盖提交
  //
  // @作用
  // ImageOcclusion 模式下的提交流程：
  //   1. 校验已选图、至少 1 个遮罩
  //   2. 读 URI 字节 → 媒体服务.添加媒体文件 写入 collection.media 得最终文件名
  //   3. 图片遮罩服务.获取图片遮罩字段 取字段索引
  //   4. 笔记服务.新建笔记 创建笔记对象，按索引填 Occlusions / Image / Header / Back Extra
  //   5. 笔记服务.添加笔记 提交
  //   6. pop 返回牌组详情（与既有 Basic / Cloze 流程一致）
  //
  // @输入
  // 无（读 图片遮盖_源图Uri / 图片遮盖_遮罩列表 / 图片遮盖_标题 / 图片遮盖_额外 / 已选笔记类型ID / 牌组ID）
  //
  // @输出
  // 成功 → pop 页面栈；失败 → 在 错误信息 显示友好提示
  //
  // @业务规则
  // 防重入：处理中 / 牌组ID=0 / 已选笔记类型ID=0 时直接返回（与 提交 同守卫）。
  // 字段值数组按 字段名列表 长度初始化为空串，再按 4 个索引填值。
  // 文件名基于时间戳生成，扩展名 .img（后端会按 collection.media 已存在文件去重返回最终名）。
  //
  // @副作用
  // 调后端 添加媒体文件 / 获取图片遮罩字段 / 新建笔记 / 添加笔记；读写 处理中 状态；成功后 pop 页面栈。
  // ========================================================
  private async 图片遮盖_提交(): Promise<void> {
    if (this.处理中 || this.牌组ID === 0 || this.已选笔记类型ID === 0) {
      return;
    }
    // T3.7：未选图 / 未画至少 1 个遮罩时禁用保存按钮，此处做兜底校验。
    if (this.图片遮盖_源图Uri === '') {
      this.错误信息 = this.取本地化文案($r('app.string.add_note_image_occlusion_no_image'));
      return;
    }
    if (this.图片遮盖_遮罩列表.length === 0) {
      this.错误信息 = this.取本地化文案($r('app.string.add_note_image_occlusion_need_mask'));
      return;
    }
    this.错误信息 = '';
    this.处理中 = true;
    try {
      // 1-2. 读 URI 字节并写入 collection.media
      const 字节: Uint8Array = this.读取图片字节(this.图片遮盖_源图Uri);
      const 期望文件名: string = `image-occlusion-${Date.now()}.img`;
      const 最终文件名: string = await this.媒体服务实例.添加媒体文件(期望文件名, 字节);
      // 3. 取 ImageOcclusion 字段索引
      const 索引: 图片遮罩字段索引 =
        await this.图片遮罩服务实例.获取图片遮罩字段(this.已选笔记类型ID);
      // 4. 创建笔记对象，按索引填字段
      const 笔记: EditableNote = await this.笔记服务实例.新建笔记(this.已选笔记类型ID);
      const 字段数: number = this.字段名列表.length;
      const 字段值: string[] = new Array<string>(字段数).fill('');
      if (索引.遮罩 < 字段数) {
        字段值[索引.遮罩] = 生成Occlusions字符串(this.图片遮盖_遮罩列表);
      }
      if (索引.图片 < 字段数) {
        字段值[索引.图片] = `<img src="${最终文件名}">`;
      }
      if (索引.标题 < 字段数) {
        字段值[索引.标题] = this.图片遮盖_标题;
      }
      if (索引.额外 < 字段数) {
        字段值[索引.额外] = this.图片遮盖_额外;
      }
      笔记.fields = 字段值;
      笔记.tags = this.解析标签();
      // 5. 提交
      await this.笔记服务实例.添加笔记(笔记, this.牌组ID);
      // 笔记添加成功：写 AppStorage 标志位通知首页/牌组详情面板立即刷新统计计数。
      // 不依赖 NavPathStack.onPop 回调（不同设备/API 版本偶发不触发），用 @StorageLink + @Watch 兜底。
      AppStorage.setOrCreate<number>('noteAddedTick', Date.now());
      // 6. pop 返回牌组详情
      this.pathStack.pop();
    } catch (错误) {
      if (错误 instanceof 笔记字段校验错误) {
        if (错误.messageKey === 'add_note_empty_error') {
          this.错误信息 = this.取本地化文案($r('app.string.add_note_empty_error'));
        } else if (错误.messageKey === 'add_note_duplicate_error') {
          this.错误信息 = this.取本地化文案($r('app.string.add_note_duplicate_error'));
        } else {
          this.错误信息 = this.取本地化文案($r('app.string.add_note_cloze_missing'));
        }
      } else {
        this.错误信息 = 错误 instanceof Error ? 错误.message : `${错误}`;
      }
    } finally {
      this.处理中 = false;
    }
  }

  private 打开帮助(标题: Resource, 正文: Resource): void {
    this.帮助标题 = 标题;
    this.帮助正文 = 正文;
    this.显示帮助 = true;
  }

  private 已选笔记类型索引(): number {
    const 索引 = this.笔记类型选项.findIndex(
      (笔记类型: 添加笔记笔记类型选项): boolean => 笔记类型.id === this.已选笔记类型ID);
    return 索引 < 0 ? 0 : 索引;
  }

  private 已选笔记类型名(): string {
    for (const 笔记类型 of this.笔记类型选项) {
      if (笔记类型.id === this.已选笔记类型ID) {
        return 笔记类型.name;
      }
    }
    return '';
  }

  private 笔记类型下拉选项(): 添加笔记下拉选项[] {
    const 选项列表: 添加笔记下拉选项[] = [];
    for (const 笔记类型 of this.笔记类型选项) {
      选项列表.push({ value: 笔记类型.name });
    }
    return 选项列表;
  }

  @Builder
  private 带帮助的标签(标签文案: Resource, 取帮助: () => Resource) {
    Row() {
      Text(标签文案)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
      // 注：帮助文案用回调 取帮助: () => Resource 而非直接传 Resource。
      // 直接传 Resource 时 @Builder 在调用时求值快照，后续 @State 笔记类型帮助 变化不会更新到弹层；
      // 回调在点击时执行，读取的是 this.笔记类型帮助 的最新值，确保切换笔记类型后 i 弹出对应说明。
      Button($r('app.string.field_help_button'))
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontColor(this.动作主色)
        .enabled(!this.处理中)
        .onClick((): void => {
          this.打开帮助(标签文案, 取帮助());
        })
    }
    .width('100%')
  }

  // 标签字段块：ImageOcclusion 模式与其他笔记类型共用，统一放在「高级设置」折叠区里。
  // 抽 @Builder 消除两个分支的 Tags 代码重复（BUG-004 修复）。
  @Builder
  private 标签字段块() {
    Column({ space: 应用尺寸.间距_5 }) {
      this.带帮助的标签($r('app.string.add_note_tags'), (): Resource => $r('app.string.add_note_tags_help'))
      TextInput({ placeholder: $r('app.string.add_note_tags_placeholder'), text: this.标签 })
        .width('100%')
        .height(应用尺寸.按钮高度)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .backgroundColor($r('app.color.surface_card'))
        .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
        .borderRadius(应用尺寸.圆角_面板)
        .padding({ left: 应用尺寸.间距_10, right: 应用尺寸.间距_10 })
        .enabled(!this.处理中)
        .onChange((值: string): void => {
          this.标签 = 值;
        })
      Text($r('app.string.add_note_duplicate_rejected'))
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
    }
    .width('100%')
  }

  // 高级设置按钮 + 折叠区：ImageOcclusion 模式与其他笔记类型共用。
  // 抽 @Builder 消除两个分支的高级设置代码重复（BUG-004 修复）。
  @Builder
  private 高级设置折叠区() {
    Button(this.高级已展开 ? $r('app.string.add_note_advanced_hide') : $r('app.string.add_note_advanced'))
      .width('100%')
      .fontSize(应用尺寸.字号_正文_小)
      .fontColor(this.动作主色)
      .backgroundColor($r('app.color.surface_page'))
      .borderRadius(应用尺寸.圆角_面板)
      .enabled(!this.处理中)
      .onClick((): void => {
        this.高级已展开 = !this.高级已展开;
      })

    if (this.高级已展开) {
      this.标签字段块()
    }
  }

  @Builder
  private 顶部条() {
    // Stack 叠层：底层 Text(牌组名) 居中铺满，上层 Row(返回按钮 + Blank) 让返回按钮在左。
    // 这样牌组名在视觉上真正居中，而不是被返回按钮挤到右边。
    Stack({ alignContent: Alignment.Center }) {
      Text(this.牌组名)
        .fontSize(应用尺寸.字号_标题)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .padding({ left: 应用尺寸.间距_12, right: 应用尺寸.间距_12 })

      Row() {
        Button($r('app.string.study_back'))
          .height(应用尺寸.按钮高度)
          .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
          .constraintSize({ minWidth: 0 })
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_胶囊)
          .enabled(!this.处理中)
          .onClick(() => {
            if (!this.处理中) {
              this.pathStack.pop();
            }
          })
        Blank()
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(应用尺寸.工具栏高度)
    .padding({
      left: 应用尺寸.页面内边距_水平,
      right: 应用尺寸.页面内边距_水平
    })
    .backgroundColor($r('app.color.surface_page'))
  }

  @Builder
  private 填空按钮行() {
    Row({ space: 应用尺寸.间距_8 }) {
      ForEach(this.填空编号列表(), (编号: number) => {
        Button(`c${编号}`)
          .height(36)
          .padding({ left: 应用尺寸.间距_12, right: 应用尺寸.间距_12 })
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.action_on_primary'))
          .backgroundColor(this.主色按钮背景色)
          .borderRadius(应用尺寸.圆角_面板)
          .enabled(!this.处理中)
          .onClick((): void => {
            this.应用填空(编号);
          })
      }, (编号: number): string => `cloze-btn-${编号}`)
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Stack() {
      Column() {
        this.顶部条()
        // 中间字段区可滚动，错误信息与按钮固定在底部
        Scroll() {
          Column({ space: 应用尺寸.间距_14 }) {
            // 2026-07-28：对齐舒尔特05 settingSelectRow 形态——标签在左、Select 在右，
            // 帮助按钮 ⓘ 紧贴 Select 右侧；Select 不再 100% 宽，改为内容自适应。
            // onClick 直接读 this.笔记类型帮助（与原 带帮助的标签 回调等价：点击时取最新值）。
            Row() {
              Text($r('app.string.add_note_notetype'))
                .fontSize(应用尺寸.字号_按钮)
                .fontColor($r('app.color.text_secondary'))
                .layoutWeight(1)
              Select(this.笔记类型下拉选项())
                .selected(this.已选笔记类型索引())
                .value(this.已选笔记类型名())
                .controlSize(ControlSize.SMALL)
                .enabled(!this.处理中 && this.笔记类型选项.length > 0)
                .onSelect((索引: number): void => {
                  this.加载笔记类型(this.笔记类型选项[索引].id);
                })
              Button($r('app.string.field_help_button'))
                .type(ButtonType.Normal)
                .backgroundColor(Color.Transparent)
                .fontColor(this.动作主色)
                .enabled(!this.处理中)
                .onClick((): void => {
                  this.打开帮助($r('app.string.add_note_notetype'), this.笔记类型帮助);
                })
            }
            .width('100%')

            // T3.3-T3.4：ImageOcclusion 模式渲染图片遮盖专属布局（选图 / 预览 / Header/Back Extra / Tags）；
            // 其他笔记类型保留原通用 4 字段 TextArea + 高级设置折叠。
            if (this.是否图片遮盖模式) {
              // ① 选图按钮（已选图后文案切为"更换图片"）
              Button(this.图片遮盖_源图Uri === ''
                ? $r('app.string.add_note_image_occlusion_pick_image')
                : $r('app.string.add_note_image_occlusion_change_image'))
                .width('100%')
                .height(应用尺寸.按钮高度)
                .fontSize(应用尺寸.字号_按钮)
                .fontColor($r('app.color.action_on_primary'))
                .backgroundColor(this.主色按钮背景色)
                .borderRadius(应用尺寸.圆角_胶囊)
                .enabled(!this.处理中)
                .onClick((): void => {
                  this.选取图片遮盖源图();
                })

              // ② 图片预览 + 编辑遮罩入口
              if (this.图片遮盖_源图Uri !== '') {
                Image(this.图片遮盖_源图Uri)
                  .width('100%')
                  .objectFit(ImageFit.Contain)
                  .borderRadius(应用尺寸.圆角_面板)
                  .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })

                Button($r('app.string.add_note_image_occlusion_edit_masks'))
                  .width('100%')
                  .height(应用尺寸.按钮高度)
                  .fontSize(应用尺寸.字号_按钮)
                  .fontColor(this.动作主色)
                  .backgroundColor($r('app.color.surface_page'))
                  .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
                  .borderRadius(应用尺寸.圆角_胶囊)
                  .enabled(!this.处理中)
                  .onClick((): void => {
                    this.图片遮盖_显示编辑器 = true;
                  })
              }

              // ③ Header / Back Extra 输入（用 字段名列表 中查到的字段名做 placeholder 变量）
              if (this.图片遮盖_标题字段索引() >= 0) {
                Column({ space: 应用尺寸.间距_5 }) {
                  Text(this.字段名列表[this.图片遮盖_标题字段索引()])
                    .fontSize(应用尺寸.字号_正文_小)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                  TextArea({
                    placeholder: this.字段名列表[this.图片遮盖_标题字段索引()],
                    text: this.图片遮盖_标题
                  })
                    .width('100%')
                    .height(56)
                    .fontSize(应用尺寸.字号_正文)
                    .fontColor($r('app.color.text_primary'))
                    .placeholderColor($r('app.color.text_tertiary'))
                    .backgroundColor($r('app.color.surface_card'))
                    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
                    .borderRadius(应用尺寸.圆角_面板)
                    .padding(应用尺寸.间距_10)
                    .enabled(!this.处理中)
                    .onChange((值: string): void => {
                      this.图片遮盖_标题 = 值;
                    })
                }
                .width('100%')
              }
              if (this.图片遮盖_额外字段索引() >= 0) {
                Column({ space: 应用尺寸.间距_5 }) {
                  Text(this.字段名列表[this.图片遮盖_额外字段索引()])
                    .fontSize(应用尺寸.字号_正文_小)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                  TextArea({
                    placeholder: this.字段名列表[this.图片遮盖_额外字段索引()],
                    text: this.图片遮盖_额外
                  })
                    .width('100%')
                    .height(56)
                    .fontSize(应用尺寸.字号_正文)
                    .fontColor($r('app.color.text_primary'))
                    .placeholderColor($r('app.color.text_tertiary'))
                    .backgroundColor($r('app.color.surface_card'))
                    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
                    .borderRadius(应用尺寸.圆角_面板)
                    .padding(应用尺寸.间距_10)
                    .enabled(!this.处理中)
                    .onChange((值: string): void => {
                      this.图片遮盖_额外 = 值;
                    })
                }
                .width('100%')
              }

              // ④ Tags 折叠在「高级设置」里，与其他笔记类型保持一致（BUG-004 修复）
              this.高级设置折叠区()
            } else {
              ForEach(this.字段名列表, (字段名: string, 索引: number) => {
                Column({ space: 应用尺寸.间距_5 }) {
                  Text(字段名)
                    .fontSize(应用尺寸.字号_正文_小)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                  if (this.是填空笔记类型() && 索引 === this.填空字段索引()) {
                    TextArea({
                      placeholder: $r('app.string.add_note_cloze_placeholder'),
                      text: this.字段值列表[索引],
                      controller: this.填空字段控制器
                    })
                      .width('100%')
                      .height(56)
                      .fontSize(应用尺寸.字号_正文)
                      .fontColor($r('app.color.text_primary'))
                      .placeholderColor($r('app.color.text_tertiary'))
                      .backgroundColor($r('app.color.surface_card'))
                      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
                      .borderRadius(应用尺寸.圆角_面板)
                      .padding(应用尺寸.间距_10)
                      .enabled(!this.处理中)
                      .onChange((值: string): void => {
                        this.更新字段(索引, 值);
                      })
                      .onTextSelectionChange((选区起: number, 选区止: number): void => {
                        this.填空选区起 = 选区起;
                        this.填空选区止 = 选区止;
                      })
                    // 2026-07-28：c1-c5 按钮行移到 Text 输入框下方、Back Extra 输入框上方
                    // （原位置在 Text(字段名) 上方，与文字输入框分离，用户不便操作）
                    this.填空按钮行()
                  } else {
                    TextArea({
                      placeholder: 字段名,
                      text: this.字段值列表[索引]
                    })
                      .width('100%')
                      .height(56)
                      .fontSize(应用尺寸.字号_正文)
                      .fontColor($r('app.color.text_primary'))
                      .placeholderColor($r('app.color.text_tertiary'))
                      .backgroundColor($r('app.color.surface_card'))
                      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
                      .borderRadius(应用尺寸.圆角_面板)
                      .padding(应用尺寸.间距_10)
                      .enabled(!this.处理中)
                      .onChange((值: string): void => {
                        this.更新字段(索引, 值);
                      })
                  }
                }
                .width('100%')
              }, (字段名: string, 索引: number): string => `${索引}-${字段名}`)

              this.高级设置折叠区()
            }
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.TopStart)
        .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距, top: 应用尺寸.间距_8 })

        // 错误信息固定在按钮上方，避免软键盘或字段多时被裁剪
        if (this.错误信息 !== '') {
          Text(this.错误信息)
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.error_text'))
            .width('100%')
            .maxLines(3)
            .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
        }

        Row({ space: 应用尺寸.间距_10 }) {
          Button($r('app.string.add_note_cancel'))
            .height(应用尺寸.按钮高度)
            .layoutWeight(1)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_page'))
            .borderRadius(应用尺寸.圆角_胶囊)
            .enabled(!this.处理中)
            .onClick((): void => {
              if (!this.处理中) {
                this.pathStack.pop();
              }
            })
          Button(this.处理中 ? $r('app.string.add_note_saving') : $r('app.string.add_note_save'))
            .height(应用尺寸.按钮高度)
            .layoutWeight(1)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.保存按下 ? this.主色按钮按下色 : this.主色按钮背景色)
            .borderRadius(应用尺寸.圆角_胶囊)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .enabled(this.保存按钮可用())
            .onTouch((事件: TouchEvent): void => {
              if (事件.type === TouchType.Down) {
                this.保存按下 = true;
              } else if (事件.type === TouchType.Up || 事件.type === TouchType.Cancel) {
                this.保存按下 = false;
              }
            })
            .onClick((): void => {
              this.提交();
            })
        }
        .width('100%')
        .padding({
          left: 应用尺寸.卡片内边距,
          right: 应用尺寸.卡片内边距,
          top: 应用尺寸.间距_8,
          bottom: 应用尺寸.间距_8
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.surface_page'))

      if (this.显示帮助) {
        字段帮助面板({
          标题: this.帮助标题,
          正文: this.帮助正文,
          onClose: (): void => {
            this.显示帮助 = false;
          }
        })
      }

      // T3 遮罩编辑器全屏弹层：覆盖在主内容之上，由 图片遮盖_显示编辑器 控制。
      // 用 Stack + if 实现（与 字段帮助面板 同机制）；编辑器内部自带 c1-c5 按钮 / 撤销 / 清空 / 确定 / 取消。
      if (this.图片遮盖_显示编辑器) {
        Column() {
          图片遮罩编辑器({
            源图Uri: this.图片遮盖_源图Uri,
            是否深色: this.是否深色(),
            onConfirm: (遮罩列表: 遮罩描述[]): void => {
              this.图片遮盖_遮罩列表 = 遮罩列表;
              this.图片遮盖_显示编辑器 = false;
            },
            onCancel: (): void => {
              this.图片遮盖_显示编辑器 = false;
            }
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.surface_page'))
        .padding({
          left: 应用尺寸.页面内边距_水平,
          right: 应用尺寸.页面内边距_水平,
          top: 应用尺寸.间距_8,
          bottom: 应用尺寸.间距_8
        })
      }
    }
    .width('100%')
    .height('100%')
    }
    .hideTitleBar(true)
  }

  /** T3.7：保存按钮可用条件——ImageOcclusion 模式要求已选图 + 至少 1 个遮罩；其他模式与原逻辑一致。 */
  private 保存按钮可用(): boolean {
    if (this.处理中) {
      return false;
    }
    if (this.字段名列表.length === 0) {
      return false;
    }
    if (this.是否图片遮盖模式) {
      return this.图片遮盖_源图Uri !== '' && this.图片遮盖_遮罩列表.length > 0;
    }
    return true;
  }

  /** ImageOcclusion 模式 Header 字段在 字段名列表 中的索引；找不到返回 -1。 */
  // 注意：字段名也是本地化的（中文环境下为「标题」），用 是Header字段 识别。
  private 图片遮盖_标题字段索引(): number {
    for (let i: number = 0; i < this.字段名列表.length; i++) {
      if (this.是Header字段(this.字段名列表[i])) {
        return i;
      }
    }
    return -1;
  }

  /** ImageOcclusion 模式 Back Extra 字段在 字段名列表 中的索引；找不到返回 -1。 */
  // 注意：字段名也是本地化的（中文环境下为「背面额外」），用 是BackExtra字段 识别。
  private 图片遮盖_额外字段索引(): number {
    for (let i: number = 0; i < this.字段名列表.length; i++) {
      if (this.是BackExtra字段(this.字段名列表[i])) {
        return i;
      }
    }
    return -1;
  }
}
