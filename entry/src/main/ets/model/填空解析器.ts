// SPDX-License-Identifier: AGPL-3.0-or-later
// 来源: https://github.com/ankitects/anki/blob/main/rslib/src/cloze.rs
// 移植自 Ankitects Pty Ltd 的 cloze.rs，遵循 AGPL-3.0-or-later

// 移植说明：
// - Rust enum Token → TS class 层级（开填空标记/纯文本记号/闭填空标记 extends 词法记号）
// - Rust enum TextOrCloze → TS class 层级（文本节点/已提取填空节点 extends 文本或填空节点）
// - Rust generator tokenize → TS 返回 词法记号[] 数组
// - Rust Cow<str> → TS string
// - Rust HashSet<u16> → TS number[]（去重排序）
// - 不依赖 @kit.* 或 ArkUI，可被 node test runner 直接加载

// ========================================================
// @块ID MODEL-CLOZE-PARSER-001
// @名称 填空解析器-词法记号类型
//
// @作用
// 定义切词阶段产出的三种词法记号：开填空标记 / 纯文本记号 / 闭填空标记。
// 对应 Rust enum Token 的三种变体（OpenCloze/Text/CloseCloze）。
//
// @输入
// 无（类型定义）。
//
// @输出
// 三个 export class：词法记号（基类）、开填空标记、纯文本记号、闭填空标记。
//
// @业务规则
// 开填空标记携带 编号列表（去重排序后的填空编号）。
// 纯文本记号携带原始文本片段。
// 闭填空标记无负载，仅标志填空段结束。
//
// @副作用
// 无。
// ========================================================

export class 词法记号 {
  // 基类：切词法记号 输出的三种记号之一
}

export class 开填空标记 extends 词法记号 {
  readonly 编号列表: number[];
  constructor(编号列表: number[]) {
    super();
    this.编号列表 = 编号列表;
  }
}

export class 纯文本记号 extends 词法记号 {
  readonly 文本: string;
  constructor(文本: string) {
    super();
    this.文本 = 文本;
  }
}

export class 闭填空标记 extends 词法记号 {
  constructor() {
    super();
  }
}

// ========================================================
// @块ID MODEL-CLOZE-PARSER-002
// @名称 填空解析器-文本或填空节点类型
//
// @作用
// 定义解析后的树状节点：文本节点 / 已提取填空节点。
// 对应 Rust enum TextOrCloze 的两种变体。
//
// @输入
// 无（类型定义）。
//
// @输出
// 两个 export class：文本或填空节点（基类）、文本节点、已提取填空节点。
//
// @业务规则
// 已提取填空节点可嵌套，含 编号列表/子节点/提示。
// 填空后文本() 返回该填空揭示后的完整答案文本（递归合并子节点）。
// 获取提示() 返回 提示，未提供时返回 "..."。
//
// @副作用
// 无。
// ========================================================

export class 文本或填空节点 {
  // 基类：解析后的树状节点
}

export class 文本节点 extends 文本或填空节点 {
  readonly 文本: string;
  constructor(文本: string) {
    super();
    this.文本 = 文本;
  }
}

export class 已提取填空节点 extends 文本或填空节点 {
  readonly 编号列表: number[];
  readonly 子节点: 文本或填空节点[];
  提示: string | null;

  constructor(编号列表: number[], 子节点: 文本或填空节点[], 提示: string | null) {
    super();
    this.编号列表 = 编号列表;
    this.子节点 = 子节点;
    this.提示 = 提示;
  }

  /** 返回填空提示，未提供时返回 "..."。 */
  获取提示(): string {
    return this.提示 !== null ? this.提示 : '...';
  }

  /** 返回该填空揭示后的完整答案文本（递归合并子节点）。 */
  填空后文本(): string {
    // 高效路径：单 文本节点 子节点直接返回
    if (this.子节点.length === 1 && this.子节点[0] instanceof 文本节点) {
      return (this.子节点[0] as 文本节点).文本;
    }
    let 缓冲 = '';
    for (const 节点 of this.子节点) {
      if (节点 instanceof 文本节点) {
        缓冲 += 节点.文本;
      } else if (节点 instanceof 已提取填空节点) {
        缓冲 += 节点.填空后文本();
      }
    }
    return 缓冲;
  }

  /** 是否包含指定编号。 */
  包含编号(编号: number): boolean {
    for (const 当前编号 of this.编号列表) {
      if (当前编号 === 编号) {
        return true;
      }
    }
    return false;
  }
}

// ========================================================
// @块ID MODEL-CLOZE-PARSER-003
// @名称 填空解析器-切词法记号
//
// @作用
// 将文本切为 词法记号 数组（开填空标记 / 纯文本记号 / 闭填空标记）。
// 对应 Rust tokenize 函数（generator + nom parser combinators）。
//
// @输入
// 文本: 待切词的原始文本。
//
// @输出
// 词法记号[]。
//
// @业务规则
// 开填空标记语法：`{{c<digits,>::`，编号去重排序后必须非空。
// 闭填空标记语法：`}}`。
// 纯文本记号一直延伸到下一个开/闭标记位置。
//
// @副作用
// 无。
// ========================================================

/**
 * 在 位置 处尝试匹配开填空标记 `{{c<digits,>::`。
 * 匹配成功返回 {编号列表, 结束位置}；失败返回 null。
 * 对应 Rust open_cloze parser：tag("{{c") + take_while(digit|',') + tag("::")
 */
function 匹配开填空标记(文本: string, 位置: number): { 编号列表: number[]; 结束位置: number } | null {
  if (!文本.startsWith('{{c', 位置)) {
    return null;
  }
  let 游标 = 位置 + 3;
  const 起点 = 游标;
  while (游标 < 文本.length) {
    const 字符 = 文本.charAt(游标);
    if ((字符 >= '0' && 字符 <= '9') || 字符 === ',') {
      游标++;
    } else {
      break;
    }
  }
  const 编号字符串 = 文本.substring(起点, 游标);
  // 解析、去重、排序 —— 对应 Rust split(',').filter_map(parse).collect::<HashSet>().sorted()
  const 集合 = new Set<number>();
  const 分段 = 编号字符串.split(',');
  for (const 段 of 分段) {
    if (段.length === 0) {
      continue;
    }
    const 数字 = parseInt(段, 10);
    if (Number.isNaN(数字)) {
      continue;
    }
    集合.add(数字);
  }
  if (集合.size === 0) {
    return null;
  }
  const 编号列表 = Array.from(集合).sort((a, b) => a - b);
  if (!文本.startsWith('::', 游标)) {
    return null;
  }
  游标 += 2;
  return { 编号列表, 结束位置: 游标 };
}

/**
 * 切词法记号：将文本切为 开填空标记 / 纯文本记号 / 闭填空标记 数组。
 * Rust 用 generator + nom parser combinators，TS 改为单次扫描返回数组。
 */
export function 切词法记号(文本: string): 词法记号[] {
  const 记号列表: 词法记号[] = [];
  let 位置 = 0;
  while (位置 < 文本.length) {
    // 尝试在当前位置匹配开填空标记
    const 开匹配 = 匹配开填空标记(文本, 位置);
    if (开匹配 !== null) {
      记号列表.push(new 开填空标记(开匹配.编号列表));
      位置 = 开匹配.结束位置;
      continue;
    }
    // 尝试在当前位置匹配闭填空标记
    if (文本.startsWith('}}', 位置)) {
      记号列表.push(new 闭填空标记());
      位置 += 2;
      continue;
    }
    // 普通文本：找到下一个开/闭标记的位置。
    // Rust 的 normal_text 从 idx=0 开始检查（这里相当于 位置），
    // 但上面已确认 位置 处不匹配开/闭，所以从 位置+1 开始搜索。
    let 终点 = 文本.length;
    for (let i = 位置 + 1; i < 文本.length; i++) {
      if (文本.startsWith('}}', i) || 匹配开填空标记(文本, i) !== null) {
        终点 = i;
        break;
      }
    }
    记号列表.push(new 纯文本记号(文本.substring(位置, 终点)));
    位置 = 终点;
  }
  return 记号列表;
}

// ========================================================
// @块ID MODEL-CLOZE-PARSER-004
// @名称 填空解析器-解析带填空文本
//
// @作用
// 将文本解析为 文本或填空节点 树状结构（支持嵌套，最多 10 层）。
// 对应 Rust parse_text_with_clozes。
//
// @输入
// 文本: 原始文本（含 {{c1::...}} 等标记）。
//
// @输出
// 文本或填空节点[]（顶层节点列表）。
//
// @业务规则
// 开填空标记 入栈（最多 10 层）；纯文本记号 在栈非空时挂到栈顶填空的子节点，
// 并按首个 "::" 切出 提示；闭填空标记 弹栈并挂到外层或顶层。
// 栈空时遇到 闭填空标记 视为普通文本 "}}"。
//
// @副作用
// 无。
// ========================================================

export function 解析带填空文本(文本: string): 文本或填空节点[] {
  const 待闭合填空栈: 已提取填空节点[] = [];
  const 输出: 文本或填空节点[] = [];
  const 记号列表 = 切词法记号(文本);
  for (const 记号 of 记号列表) {
    if (记号 instanceof 开填空标记) {
      if (待闭合填空栈.length < 10) {
        待闭合填空栈.push(new 已提取填空节点(记号.编号列表, [], null));
      }
    } else if (记号 instanceof 纯文本记号) {
      let 文本片段 = 记号.文本;
      if (待闭合填空栈.length > 0) {
        const 当前填空 = 待闭合填空栈[待闭合填空栈.length - 1];
        // 提取 提示 —— 对应 Rust 的 split_once("::")
        const 提示索引 = 文本片段.indexOf('::');
        if (提示索引 >= 0) {
          当前填空.提示 = 文本片段.substring(提示索引 + 2);
          文本片段 = 文本片段.substring(0, 提示索引);
        }
        当前填空.子节点.push(new 文本节点(文本片段));
      } else {
        输出.push(new 文本节点(文本片段));
      }
    } else if (记号 instanceof 闭填空标记) {
      const 弹出的填空 = 待闭合填空栈.pop();
      if (弹出的填空 !== undefined) {
        let 目标列表: 文本或填空节点[];
        if (待闭合填空栈.length > 0) {
          const 外层填空 = 待闭合填空栈[待闭合填空栈.length - 1];
          目标列表 = 外层填空 !== undefined ? 外层填空.子节点 : 输出;
        } else {
          目标列表 = 输出;
        }
        目标列表.push(弹出的填空);
      } else {
        // 闭合标记出现在任何填空之外
        输出.push(new 文本节点('}}'));
      }
    }
  }
  return 输出;
}

// ========================================================
// @块ID MODEL-CLOZE-PARSER-005
// @名称 填空解析器-收集填空内容到数组
//
// @作用
// 递归收集激活填空的内容到 输出 数组。
// 仅处理 已提取填空节点；若 cloze 包含 填空编号，push 提示(问) 或 填空后文本(答)，
// 然后递归子节点。对应 Rust reveal_cloze_text_in_nodes。
//
// @输入
// 节点: 当前节点。
// 填空编号: 当前激活的填空编号。
// 问而非答: true 取提示（问），false 取填空后文本（答）。
// 输出: 累积输出数组（按引用修改）。
//
// @输出
// 无返回值，结果写入 输出。
//
// @副作用
// 修改传入的 输出 数组（push）。
// ========================================================

export function 收集填空内容到数组(
  节点: 文本或填空节点,
  填空编号: number,
  问而非答: boolean,
  输出: string[]
): void {
  if (节点 instanceof 已提取填空节点) {
    const 当前填空 = 节点;
    if (当前填空.包含编号(填空编号)) {
      if (问而非答) {
        输出.push(当前填空.获取提示());
      } else {
        输出.push(当前填空.填空后文本());
      }
    }
    for (const 子节点 of 当前填空.子节点) {
      收集填空内容到数组(子节点, 填空编号, 问而非答, 输出);
    }
  }
}

// ========================================================
// @块ID MODEL-CLOZE-PARSER-006
// @名称 填空解析器-揭示填空内容
//
// @作用
// 揭示文本中所有匹配 填空编号 的 cloze 内容，以 ", " 连接。
// 与 提取拼写填空内容 的区别：不塌缩重复内容。
// 对应 Rust reveal_cloze_text_only。
//
// @输入
// 文本: 原始文本。
// 填空编号: 当前激活的填空编号。
// 问而非答: true 取问，false 取答。
//
// @输出
// 拼接后的字符串（", " 分隔）。
//
// @副作用
// 无。
// ========================================================

export function 揭示填空内容(文本: string, 填空编号: number, 问而非答: boolean): string {
  const 输出: string[] = [];
  for (const 节点 of 解析带填空文本(文本)) {
    收集填空内容到数组(节点, 填空编号, 问而非答, 输出);
  }
  return 输出.join(', ');
}

// ========================================================
// @块ID MODEL-CLOZE-PARSER-007
// @名称 填空解析器-提取拼写填空内容
//
// @作用
// 提取当前 填空编号 的 cloze 内容用于拼写校验。
// 多匹配塌缩：若所有输出相同则返回单条，否则 join ', '。
// 对应 Rust extract_cloze_for_typing。
//
// @输入
// 文本: 原始文本。
// 填空编号: 当前激活的填空编号。
//
// @输出
// 拼写校验用的答案文本（可能已塌缩）。
//
// @业务规则
// 无匹配返回空串；全相同返回首条；否则 ", " 连接。
//
// @副作用
// 无。
// ========================================================

export function 提取拼写填空内容(文本: string, 填空编号: number): string {
  const 输出: string[] = [];
  for (const 节点 of 解析带填空文本(文本)) {
    收集填空内容到数组(节点, 填空编号, false, 输出);
  }
  if (输出.length === 0) {
    return '';
  }
  // 所有匹配文本一致时塌缩为单条
  const 首条 = 输出[0];
  if (首条 !== undefined) {
    let 全部相同 = true;
    for (let i = 1; i < 输出.length; i++) {
      if (输出[i] !== 首条) {
        全部相同 = false;
        break;
      }
    }
    if (全部相同) {
      return 首条;
    }
  }
  return 输出.join(', ');
}

// ========================================================
// @块ID MODEL-CLOZE-PARSER-008
// @名称 填空解析器-文本中的填空编号
//
// @作用
// 返回文本中所有 cloze ordinal（去重排序，不含 0）。
// 对应 Rust cloze_numbers_in_string（Rust 返回 HashSet，TS 改为排序数组）。
//
// @输入
// 文本: 原始文本。
//
// @输出
// number[]（升序，去重，不含 0）。
//
// @副作用
// 无。
// ========================================================

function 累加填空编号到集合(节点列表: 文本或填空节点[], 集合: Set<number>): void {
  for (const 节点 of 节点列表) {
    if (节点 instanceof 已提取填空节点) {
      for (const 编号 of 节点.编号列表) {
        if (编号 !== 0) {
          集合.add(编号);
        }
      }
      累加填空编号到集合(节点.子节点, 集合);
    }
  }
}

export function 文本中的填空编号(文本: string): number[] {
  const 集合 = new Set<number>();
  累加填空编号到集合(解析带填空文本(文本), 集合);
  return Array.from(集合).sort((a, b) => a - b);
}
