// SPDX-License-Identifier: AGPL-3.0-or-later

export class 词法记号 {
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

export class 文本或填空节点 {
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

  获取提示(): string {
    return this.提示 !== null ? this.提示 : '...';
  }

  填空后文本(): string {
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

  包含编号(编号: number): boolean {
    for (const 当前编号 of this.编号列表) {
      if (当前编号 === 编号) {
        return true;
      }
    }
    return false;
  }
}

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

export function 切词法记号(文本: string): 词法记号[] {
  const 记号列表: 词法记号[] = [];
  let 位置 = 0;
  while (位置 < 文本.length) {
    const 开匹配 = 匹配开填空标记(文本, 位置);
    if (开匹配 !== null) {
      记号列表.push(new 开填空标记(开匹配.编号列表));
      位置 = 开匹配.结束位置;
      continue;
    }
    if (文本.startsWith('}}', 位置)) {
      记号列表.push(new 闭填空标记());
      位置 += 2;
      continue;
    }
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
        输出.push(new 文本节点('}}'));
      }
    }
  }
  return 输出;
}

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

export function 揭示填空内容(文本: string, 填空编号: number, 问而非答: boolean): string {
  const 输出: string[] = [];
  for (const 节点 of 解析带填空文本(文本)) {
    收集填空内容到数组(节点, 填空编号, 问而非答, 输出);
  }
  return 输出.join(', ');
}

export function 提取拼写填空内容(文本: string, 填空编号: number): string {
  const 输出: string[] = [];
  for (const 节点 of 解析带填空文本(文本)) {
    收集填空内容到数组(节点, 填空编号, false, 输出);
  }
  if (输出.length === 0) {
    return '';
  }
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
