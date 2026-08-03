// SPDX-License-Identifier: AGPL-3.0-or-later
//
// 移植自 Anki rslib/src/typeanswer.rs，纯函数无副作用。
// 实现 compare_answer 字符级 diff，行为与 Anki Type-in-the-Answer 一致。
// 不依赖任何 HarmonyOS Kit / @kit.* / 后端调用，可被 node test runner 直接加载。

// ========================================================
// @块ID MODEL-TYPE-ANSWER-001
// @名称 拼写比对器-常量与预处理工具
//
// @作用
// 定义 HTML/换行/声音/TTS/组合标记正则、命名实体表，以及
// 转义HTML / 是否组合标记 / 剥除答案标签 等纯工具函数。
// 对应 Anki rslib/src/typeanswer.rs 的常量与预处理函数。
//
// @输入
// 字符串。
//
// @输出
// 处理后的字符串或布尔值。
//
// @业务规则
// 剥除答案标签流程：去音视频 → 换行转空格 → 去 HTML 标签并解码实体 → trim。
// 转义HTML：& < > " ' 五字符转义为实体。
// 命名实体表覆盖常见 HTML 实体（amp/lt/gt/quot/apos/nbsp 等）。
//
// @副作用
// 无。
// ========================================================

const 换行正则 = /(\n|<br\s?\/?>|<\/?div>)+/gi;
const HTML标签正则 = /<!--.*?-->|<style.*?>.*?<\/style>|<script.*?>.*?<\/script>|<.*?>/gis;
const 声音标签正则 = /\[sound:[^\]]*\]/g;
const TTS指令正则 = /\[anki:tts[^\]]*\][\s\S]*?\[\/anki:tts\]/g;
const 组合标记正则 = /\p{M}/u;

const 命名实体表: Record<string, string> = {
  amp: '&',
  lt: '<',
  gt: '>',
  quot: '"',
  apos: "'",
  nbsp: '\u00A0',
  copy: '\u00A9',
  reg: '\u00AE',
  trade: '\u2122',
  hellip: '\u2026',
  mdash: '\u2014',
  ndash: '\u2013',
  lsquo: '\u2018',
  rsquo: '\u2019',
  ldquo: '\u201C',
  rdquo: '\u201D',
  laquo: '\u00AB',
  raquo: '\u00BB',
  deg: '\u00B0',
  plusmn: '\u00B1',
  times: '\u00D7',
  divide: '\u00F7',
  euro: '\u20AC',
  pound: '\u00A3',
  cent: '\u00A2',
  yen: '\u00A5',
  sect: '\u00A7',
  para: '\u00B6',
  middot: '\u00B7',
  bull: '\u2022',
  dagger: '\u2020',
  Dagger: '\u2021',
  permil: '\u2030',
  prime: '\u2032',
  Prime: '\u2033',
  infin: '\u221E',
  ne: '\u2260',
  le: '\u2264',
  ge: '\u2265',
};

export function 转义HTML(字符串: string): string {
  return 字符串
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function 是否组合标记(字符串: string): boolean {
  return 组合标记正则.test(字符串);
}

/** 解码 HTML 实体（数字 / 十六进制 / 命名）。 */
function 解码实体(字符串: string): string {
  if (!字符串.includes('&')) {
    return 字符串;
  }
  return 字符串
    .replace(/&#(\d+);/g, (原匹配, 十进制) => {
      try {
        return String.fromCodePoint(parseInt(十进制, 10));
      } catch {
        return 原匹配;
      }
    })
    .replace(/&#x([0-9a-fA-F]+);/g, (原匹配, 十六进制) => {
      try {
        return String.fromCodePoint(parseInt(十六进制, 16));
      } catch {
        return 原匹配;
      }
    })
    .replace(/&([a-zA-Z][a-zA-Z0-9]*);/g, (原匹配, 名称) => {
      const 实体 = 命名实体表[名称];
      return 实体 !== undefined ? 实体 : 原匹配;
    })
    .replace(/\u00A0/g, ' ');
}

/** 剥除声音与 TTS 标签。 */
function 剥除音视频标签(字符串: string): string {
  return 字符串.replace(声音标签正则, '').replace(TTS指令正则, '');
}

/** 剥除 HTML 标签并解码实体。 */
function 剥除HTML(字符串: string): string {
  return 解码实体(字符串.replace(HTML标签正则, ''));
}

export function 剥除答案标签(期望答案: string): string {
  const 无音视频 = 剥除音视频标签(期望答案);
  const 无换行 = 无音视频.replace(换行正则, ' ');
  return 剥除HTML(无换行).trim();
}

/** 生成 typeans 容器 HTML。 */
function 格式化拼写框(内容: string): string {
  return `<code id=typeans>${内容}</code>`;
}

/** 若首字符是组合标记，前置一个不间断空格避免被某些渲染器丢弃。 */
function 隔离前导组合标记(文本: string): string {
  const 首字符 = [...文本][0];
  if (首字符 !== undefined && 是否组合标记(首字符)) {
    return '\u00A0' + 文本;
  }
  return 文本;
}

/** 两个 string[] 是否逐项相等。 */
function 数组相等(左: string[], 右: string[]): boolean {
  if (左.length !== 右.length) return false;
  for (let i = 0; i < 左.length; i++) {
    if (左[i] !== 右[i]) return false;
  }
  return true;
}

// ========================================================
// @块ID MODEL-TYPE-ANSWER-002
// @名称 拼写比对器-差异片段与渲染
//
// @作用
// 定义差异片段类型（正确/错误/缺失）及其 CSS 类映射，
// 提供 渲染片段 函数把片段数组渲染为带 span class 的 HTML。
// 对应 Anki typeanswer.rs 的 typeGood/typeBad/typeMissed 渲染逻辑。
//
// @输入
// 差异片段[] / 单段文本。
//
// @输出
// HTML 字符串（span 包裹）。
//
// @业务规则
// CSS 类名固定：typeGood / typeBad / typeMissed（与 Anki 桌面端 CSS 一致，不可改写）。
// 渲染前对每段文本调用 隔离前导组合标记 + 转义HTML。
// DiffTokenKind 字面量 'Good'/'Bad'/'Missing' 保持英文，与上游语义对齐。
//
// @副作用
// 无。
// ========================================================

type 差异片段类别 = 'Good' | 'Bad' | 'Missing';

interface 差异片段 {
  类别: 差异片段类别;
  文本: string;
}

function 正确片段(文本: string): 差异片段 {
  return { 类别: 'Good', 文本 };
}

function 错误片段(文本: string): 差异片段 {
  return { 类别: 'Bad', 文本 };
}

function 缺失片段(文本: string): 差异片段 {
  return { 类别: 'Missing', 文本 };
}

function 片段CSS类(片段: 差异片段): string {
  switch (片段.类别) {
    case 'Good': return 'typeGood';
    case 'Bad': return 'typeBad';
    case 'Missing': return 'typeMissed';
  }
}

function 渲染片段(片段列表: 差异片段[]): string {
  let 累加 = '';
  for (const 片段 of 片段列表) {
    const 隔离后 = 隔离前导组合标记(片段.文本);
    const 编码后 = 转义HTML(隔离后);
    累加 += `<span class=${片段CSS类(片段)}>${编码后}</span>`;
  }
  return 累加;
}

// ========================================================
// @块ID MODEL-TYPE-ANSWER-003
// @名称 拼写比对器-序列匹配器（difflib 移植）
//
// @作用
// Python difflib SequenceMatcher（autojunk=false）的 TS 移植。
// find_longest_match 使用 b2j 倒排索引 + 动态规划，行为与 CPython difflib 一致。
// 用于求 输入 与 期望 字符序列的最长公共子序列，输出操作码序列。
//
// @输入
// a: 输入字符数组（typed）。
// b: 期望字符数组（expected）。
//
// @输出
// 操作码[]：equal/delete/insert/replace 操作序列。
//
// @业务规则
// 不启用 autojunk（与 Anki 上游一致）。
// Opcode tag 'equal'/'delete'/'insert'/'replace' 保持英文，与 Python difflib 上游一致。
//
// @副作用
// 无。
// ========================================================

interface 操作码 {
  tag: 'equal' | 'delete' | 'insert' | 'replace';
  firstStart: number;
  firstEnd: number;
  secondStart: number;
  secondEnd: number;
}

// Python difflib SequenceMatcher port (autojunk=false).
// find_longest_match 使用 b2j 倒排索引 + 动态规划，与 CPython difflib 一致。
class 序列匹配器 {
  private a: string[];
  private b: string[];
  private b倒排索引: Map<string, number[]>;

  constructor(a: string[], b: string[]) {
    this.a = a;
    this.b = b;
    this.b倒排索引 = new Map();
    for (let j = 0; j < b.length; j++) {
      const 键 = b[j];
      let 列表 = this.b倒排索引.get(键);
      if (!列表) {
        列表 = [];
        this.b倒排索引.set(键, 列表);
      }
      列表.push(j);
    }
  }

  private 寻找最长匹配(
    a下界: number, a上界: number, b下界: number, b上界: number
  ): { 最佳I: number; 最佳J: number; 最佳长度: number } {
    const a = this.a;
    let 最佳I = a下界;
    let 最佳J = b下界;
    let 最佳长度 = 0;
    let j到长度 = new Map<number, number>();
    for (let i = a下界; i < a上界; i++) {
      const ai = a[i];
      const 索引列表 = this.b倒排索引.get(ai);
      const 新j到长度 = new Map<number, number>();
      if (索引列表) {
        for (const j of 索引列表) {
          if (j < b下界) continue;
          if (j >= b上界) break;
          const k = (j到长度.get(j - 1) ?? 0) + 1;
          新j到长度.set(j, k);
          if (k > 最佳长度) {
            最佳I = i - k + 1;
            最佳J = j - k + 1;
            最佳长度 = k;
          }
        }
      }
      j到长度 = 新j到长度;
    }
    return { 最佳I, 最佳J, 最佳长度 };
  }

  private 获取匹配块(): { ai: number; bj: number; size: number }[] {
    const 块列表: { ai: number; bj: number; size: number }[] = [];
    const la = this.a.length;
    const lb = this.b.length;
    const 递归 = (a下界: number, a上界: number, b下界: number, b上界: number) => {
      const { 最佳I, 最佳J, 最佳长度 } = this.寻找最长匹配(a下界, a上界, b下界, b上界);
      if (最佳长度 > 0) {
        if (a下界 < 最佳I && b下界 < 最佳J) {
          递归(a下界, 最佳I, b下界, 最佳J);
        }
        块列表.push({ ai: 最佳I, bj: 最佳J, size: 最佳长度 });
        if (最佳I + 最佳长度 < a上界 && 最佳J + 最佳长度 < b上界) {
          递归(最佳I + 最佳长度, a上界, 最佳J + 最佳长度, b上界);
        }
      }
    };
    递归(0, la, 0, lb);
    块列表.push({ ai: la, bj: lb, size: 0 });
    return 块列表;
  }

  获取操作码(): 操作码[] {
    const 操作码列表: 操作码[] = [];
    let i = 0;
    let j = 0;
    for (const { ai, bj, size } of this.获取匹配块()) {
      let tag: 操作码['tag'] | '' = '';
      if (i < ai && j < bj) {
        tag = 'replace';
      } else if (i < ai) {
        tag = 'delete';
      } else if (j < bj) {
        tag = 'insert';
      }
      if (tag !== '') {
        操作码列表.push({ tag, firstStart: i, firstEnd: ai, secondStart: j, secondEnd: bj });
      }
      i = ai + size;
      j = bj + size;
      if (size > 0) {
        操作码列表.push({ tag: 'equal', firstStart: ai, firstEnd: ai + size, secondStart: bj, secondEnd: bj + size });
      }
    }
    return 操作码列表;
  }
}

// ========================================================
// @块ID MODEL-TYPE-ANSWER-004
// @名称 拼写比对器-差异上下文与 HTML 构建
//
// @作用
// 定义 差异上下文 接口与两种实现：
//   - 差异比对：保留组合标记（NFC 规范化）。
//   - 不合并组合标记的差异比对：剥除组合标记（NFKD 规范化），用于不区分组合标记的语言。
// 提供 构建差异片段 / 构建差异HTML 公共函数。
// 对应 Anki typeanswer.rs 的 Diff / DiffNonCombining。
//
// @输入
// 期望 / 输入 字符串。
//
// @输出
// HTML 字符串（typeans 容器）。
//
// @业务规则
// 输入 完全等于 期望 时直接渲染为单 typeGood span。
// 否则按操作码渲染：equal→Good / delete→Bad / insert→Missing / replace→Bad+Missing。
// 输出结构：<code id=typeans>{输入HTML}<br><span id=typearrow>&darr;</span><br>{期望HTML}</code>
// CSS 类名 typeGood/typeBad/typeMissed、id typeans/typearrow 均为 Anki 上游固定值，不可改写。
//
// @副作用
// 无。
// ========================================================

interface 差异上下文 {
  获取输入序列(): string[];
  获取期望序列(): string[];
  获取期望原文(): string;
  渲染期望片段(片段列表: 差异片段[]): string;
}

function 构建差异片段(上下文: 差异上下文): { 输入片段: 差异片段[]; 期望片段: 差异片段[] } {
  const 匹配器 = new 序列匹配器(上下文.获取输入序列(), 上下文.获取期望序列());
  const 输入片段: 差异片段[] = [];
  const 期望片段: 差异片段[] = [];
  for (const 操作 of 匹配器.获取操作码()) {
    const 输入切片 = 上下文.获取输入序列().slice(操作.firstStart, 操作.firstEnd).join('');
    const 期望切片 = 上下文.获取期望序列().slice(操作.secondStart, 操作.secondEnd).join('');
    switch (操作.tag) {
      case 'equal':
        输入片段.push(正确片段(输入切片));
        期望片段.push(正确片段(期望切片));
        break;
      case 'delete':
        输入片段.push(错误片段(输入切片));
        break;
      case 'insert':
        输入片段.push(缺失片段('-'.repeat([...期望切片].length)));
        期望片段.push(缺失片段(期望切片));
        break;
      case 'replace':
        输入片段.push(错误片段(输入切片));
        期望片段.push(缺失片段(期望切片));
        break;
    }
  }
  return { 输入片段, 期望片段 };
}

function 构建差异HTML(上下文: 差异上下文): string {
  if (数组相等(上下文.获取输入序列(), 上下文.获取期望序列())) {
    return 格式化拼写框(`<span class=typeGood>${转义HTML(上下文.获取期望原文())}</span>`);
  }
  const { 输入片段, 期望片段 } = 构建差异片段(上下文);
  const 输入HTML = 渲染片段(输入片段);
  const 期望HTML = 上下文.渲染期望片段(期望片段);
  return 格式化拼写框(`${输入HTML}<br><span id=typearrow>&darr;</span><br>${期望HTML}`);
}

/** 保留组合标记的差异比对（NFC 规范化）。 */
class 差异比对 implements 差异上下文 {
  private 输入: string[];
  private 期望: string[];

  constructor(期望: string, 输入: string) {
    this.输入 = [...输入.normalize('NFC')];
    this.期望 = [...期望.normalize('NFC')];
  }

  获取输入序列(): string[] {
    return this.输入;
  }

  获取期望序列(): string[] {
    return this.期望;
  }

  获取期望原文(): string {
    return this.期望.join('');
  }

  渲染期望片段(片段列表: 差异片段[]): string {
    return 渲染片段(片段列表);
  }

  转HTML(): string {
    return 构建差异HTML(this);
  }
}

/** 剥除组合标记的差异比对（NFKD 规范化），用于不区分组合标记的语言。 */
class 不合并组合标记的差异比对 implements 差异上下文 {
  private 输入: string[];
  private 期望: string[];
  private 期望切分: string[];
  private 期望原文: string;

  constructor(期望: string, 输入: string) {
    const 输入剥除后: string[] = [];
    for (const 字符 of 输入.normalize('NFKD')) {
      if (!是否组合标记(字符)) {
        输入剥除后.push(字符);
      }
    }
    const 期望剥除后: string[] = [];
    const 期望切分: string[] = [];
    for (const 字符 of 期望.normalize('NFKD')) {
      if (是否组合标记(字符)) {
        const 末位索引 = 期望切分.length - 1;
        if (末位索引 >= 0) {
          期望切分[末位索引] = 期望切分[末位索引] + 字符;
        }
      } else {
        期望剥除后.push(字符);
        期望切分.push(字符);
      }
    }
    this.输入 = 输入剥除后;
    this.期望 = 期望剥除后;
    this.期望切分 = 期望切分;
    this.期望原文 = 期望;
  }

  获取输入序列(): string[] {
    return this.输入;
  }

  获取期望序列(): string[] {
    return this.期望;
  }

  获取期望原文(): string {
    return this.期望原文;
  }

  渲染期望片段(片段列表: 差异片段[]): string {
    let 索引 = 0;
    let 累加 = '';
    for (const 片段 of 片段列表) {
      const 终点 = 索引 + [...片段.文本].length;
      const 文本 = this.期望切分.slice(索引, 终点).join('');
      索引 = 终点;
      const 编码后 = 转义HTML(文本);
      累加 += `<span class=${片段CSS类(片段)}>${编码后}</span>`;
    }
    return 累加;
  }

  转HTML(): string {
    return 构建差异HTML(this);
  }
}

// ========================================================
// @块ID MODEL-TYPE-ANSWER-005
// @名称 拼写比对器-比对答案
//
// @作用
// 比对期望答案与用户输入，返回 typeans HTML（与 Anki Type-in-the-Answer 行为一致）。
// 启用组合标记=true 走 差异比对（保留组合标记），否则走 不合并组合标记的差异比对。
//
// @输入
// 期望答案: 期望答案原始文本（含 HTML/AV 标签）。
// 用户输入: 用户输入文本。
// 启用组合标记: 是否启用组合标记敏感比对。
//
// @输出
// HTML 字符串（<code id=typeans>...</code>）。
//
// @业务规则
// 用户输入 为空时直接渲染期望答案为单 typeGood span（无差异）。
//
// @副作用
// 无。
// ========================================================

export function 比对答案(期望答案: string, 用户输入: string, 启用组合标记: boolean): string {
  const 剥除后 = 剥除答案标签(期望答案);
  if (用户输入 === '') {
    return 格式化拼写框(转义HTML(剥除后));
  }
  if (启用组合标记) {
    return new 差异比对(剥除后, 用户输入).转HTML();
  }
  return new 不合并组合标记的差异比对(剥除后, 用户输入).转HTML();
}
