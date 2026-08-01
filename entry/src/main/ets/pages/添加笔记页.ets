// SPDX-License-Identifier: AGPL-3.0-or-later

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

export interface 添加笔记牌组选项 {
  id: number;
  name: string;
}

export interface 添加笔记笔记类型选项 {
  id: number;
  name: string;
}

interface 添加笔记下拉选项 {
  value: string;
}

export interface 添加笔记页参数 {
  deckId?: string;
  deckName?: string;
  deckOptions?: 添加笔记牌组选项[];
}

@Component
export struct 添加笔记页 {
  pageDeckId: string = '';
  pageDeckName: string = '';
  pageDeckOptions: 添加笔记牌组选项[] = [];
  pathStack: NavPathStack = new NavPathStack();

  private readonly 笔记服务实例: 笔记服务 = new 笔记服务();
  private readonly 笔记类型服务实例: 笔记类型服务 = new 笔记类型服务();
  private readonly 图片遮罩服务实例: 图片遮罩服务 = new 图片遮罩服务();
  private readonly 媒体服务实例: 媒体服务 = new 媒体服务();
  private readonly 填空字段控制器: TextAreaController = new TextAreaController();

  @State private 牌组ID: number = 0;
  @State private 牌组名: string = '';
  @State private 牌组选项: 添加笔记牌组选项[] = [];
  @State private 已选笔记类型ID: number = 0;
  @State private 笔记类型选项: 添加笔记笔记类型选项[] = [];
  @State private 字段名列表: string[] = [];
  @State private 字段值列表: string[] = [];
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
  @State private 填空选区起: number = -1;
  @State private 填空选区止: number = -1;

  @State private 是否图片遮盖模式: boolean = false;
  @State private 图片遮盖_源图Uri: string = '';
  @State private 图片遮盖_遮罩列表: 遮罩描述[] = [];
  @State private 图片遮盖_标题: string = '';
  @State private 图片遮盖_额外: string = '';
  @State private 图片遮盖_显示编辑器: boolean = false;
  @State private 主题模式值: 主题模式 = 'system';
  @StorageLink('systemDarkMode') private 系统暗黑模式: boolean = false;

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下色: string = '#1E4FB8';
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';

  async aboutToAppear(): Promise<void> {
    this.牌组ID = this.pageDeckId === '' ? 0 : parseInt(this.pageDeckId);
    this.牌组名 = this.pageDeckName;
    this.牌组选项 = this.pageDeckOptions;
    try {
      this.主题模式值 = await 加载主题模式();
    } catch (错误) {
      this.主题模式值 = 'system';
    }
    await this.加载初始数据();
  }

  private 是否深色(): boolean {
    return 解析是否深色(this.主题模式值, this.系统暗黑模式);
  }

  private 取能力上下文(): common.UIAbilityContext | null {
    const 上下文: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return 上下文 === undefined ? null : 上下文;
  }

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
      if (!名称列表.some((项: NotetypeNameId): boolean => this.是图片遮盖笔记类型名(项.name))) {
        try {
          await this.图片遮罩服务实例.添加图片遮罩笔记类型();
          名称列表 = await this.笔记类型服务实例.获取笔记类型名列表();
        } catch (图片遮罩添加错误) {
          this.错误信息 = 图片遮罩添加错误 instanceof Error
            ? 图片遮罩添加错误.message : `${图片遮罩添加错误}`;
        }
      }
      const 可见名称列表: NotetypeNameId[] = 名称列表.filter(
        (项: NotetypeNameId): boolean => !this.是隐藏的笔记类型变种(项.name)
      );
      this.笔记类型选项 = 可见名称列表.map((项: NotetypeNameId): 添加笔记笔记类型选项 => ({
        id: 项.id, name: 项.name
      }));
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
      const 光标位置: number = 插入位置 + 前缀.length;
      this.填空选区起 = 光标位置;
      this.填空选区止 = 光标位置;
      this.调度光标(光标位置);
    }
  }

  private 调度光标(位置: number): void {
    setTimeout(() => {
      try {
        this.填空字段控制器.caretPosition(位置);
      } catch (错误) {
      }
    }, 0);
  }

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

  private async 提交(): Promise<void> {
    if (this.处理中 || this.牌组ID === 0 || this.已选笔记类型ID === 0) {
      return;
    }
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
      AppStorage.setOrCreate<number>('noteAddedTick', Date.now());
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
      return;
    }
    this.图片遮盖_源图Uri = uri;
    this.图片遮盖_遮罩列表 = [];
  }

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

  private async 图片遮盖_提交(): Promise<void> {
    if (this.处理中 || this.牌组ID === 0 || this.已选笔记类型ID === 0) {
      return;
    }
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
      const 字节: Uint8Array = this.读取图片字节(this.图片遮盖_源图Uri);
      const 期望文件名: string = `image-occlusion-${Date.now()}.img`;
      const 最终文件名: string = await this.媒体服务实例.添加媒体文件(期望文件名, 字节);
      const 索引: 图片遮罩字段索引 =
        await this.图片遮罩服务实例.获取图片遮罩字段(this.已选笔记类型ID);
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
      await this.笔记服务实例.添加笔记(笔记, this.牌组ID);
      AppStorage.setOrCreate<number>('noteAddedTick', Date.now());
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
        Scroll() {
          Column({ space: 应用尺寸.间距_14 }) {
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

            if (this.是否图片遮盖模式) {
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

  private 图片遮盖_标题字段索引(): number {
    for (let i: number = 0; i < this.字段名列表.length; i++) {
      if (this.是Header字段(this.字段名列表[i])) {
        return i;
      }
    }
    return -1;
  }

  private 图片遮盖_额外字段索引(): number {
    for (let i: number = 0; i < this.字段名列表.length; i++) {
      if (this.是BackExtra字段(this.字段名列表[i])) {
        return i;
      }
    }
    return -1;
  }
}
