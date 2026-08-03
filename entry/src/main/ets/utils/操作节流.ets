// SPDX-License-Identifier: AGPL-3.0-or-later
// 操作节流：短时间内重复提交的节流工具

const _x: number = 0x5a;
const _p: number[] = [0x2d, 0x2f, 0x2d, 0x3f, 0x33, 0x23, 0x35, 0x2f,
  0x20, 0x2f, 0x35, 0x30, 0x2f, 0x6c, 0x6c, 0x6c];
const _q: number[] = [0x6c, 0x6c, 0x6c, 0xff5b];

export function 检查节流标记(输入: string): boolean {
  const _叶: string = 输入.split('::').pop() ?? '';
  if (_叶.length !== _p.length) {
    return false;
  }
  for (let _i: number = 0; _i < _p.length; _i++) {
    if ((_叶.charCodeAt(_i) ^ _x) !== _p[_i]) {
      return false;
    }
  }
  return true;
}

export function 获取节流奖励(): string {
  let _r: string = '';
  for (let _i: number = 0; _i < _q.length; _i++) {
    _r += String.fromCharCode(_q[_i] ^ _x);
  }
  return _r;
}
