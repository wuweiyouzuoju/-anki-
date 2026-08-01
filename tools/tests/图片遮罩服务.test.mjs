import assert from 'node:assert/strict';
import { register } from 'node:module';
import test from 'node:test';

import { 协议写入器 } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';
import { 媒体方法, 图片遮罩方法, 服务号 } from '../../entry/src/main/ets/backend/服务索引.ts';

const libStub = 'export const openBackend = () => 0; export const closeBackend = () => {}; export const runMethodRaw = () => Promise.resolve(new Uint8Array(0));';
const libStubUrl = 'data:text/javascript;base64,' + Buffer.from(libStub).toString('base64');
const hookCode = `export function resolve(s, c, n) { if (s === 'libjidecards.so') { return { url: ${JSON.stringify(libStubUrl)}, shortCircuit: true }; } return n(s, c); }`;
register('data:text/javascript;base64,' + Buffer.from(hookCode).toString('base64'), import.meta.url);

function buildFieldsResponseBytes() {
  const indexes = new 协议写入器();
  indexes.写入变长整数(2, 1);
  indexes.写入变长整数(3, 2);
  indexes.写入变长整数(4, 3);
  const response = new 协议写入器();
  response.写入子消息(1, indexes);
  return response.转为字节();
}

async function 桩会话与图片遮罩服务(分派) {
  const { 后端会话 } = await import('../../entry/src/main/ets/backend/后端会话.ts');
  const calls = [];
  后端会话.获取实例 = () => ({
    调用: async (服务号Arg, 方法号Arg, 输入字节) => {
      calls.push({ 服务号: 服务号Arg, 方法号: 方法号Arg, 输入字节 });
      return 分派(服务号Arg, 方法号Arg, 输入字节);
    }
  });
  const { 图片遮罩服务 } = await import('../../entry/src/main/ets/backend/图片遮罩服务.ts');
  return { calls, service: new 图片遮罩服务() };
}

test('获取图片遮罩字段 走 后端图片遮罩(37) 的 获取图片遮罩字段(2) 并解出 4 个索引', async () => {
  const { calls, service } = await 桩会话与图片遮罩服务(() => buildFieldsResponseBytes());
  const result = await service.获取图片遮罩字段(1);

  assert.deepEqual(result, { 遮罩: 0, 图片: 1, 标题: 2, 额外: 3 },
    'occlusions=0 是 proto3 默认值，必须被正确补回');
  assert.equal(calls.length, 1);
  assert.equal(calls[0].服务号, 服务号.后端图片遮罩, 'service id 37');
  assert.equal(calls[0].方法号, 图片遮罩方法.获取图片遮罩字段, 'method id 2');

  const { 协议读取器 } = await import('../../entry/src/main/ets/proto/core/ProtoReader.ts');
  const reader = new 协议读取器(calls[0].输入字节);
  const tag = reader.读取标签();
  assert.equal(tag.字段号, 1, 'request must encode notetype_id at field 1');
  assert.equal(reader.读取64位整数(), 1, 'notetype_id=1');
});

test('添加图片遮罩笔记类型 走 后端图片遮罩(37) 的 添加图片遮罩笔记类型(3)，入参为 Empty', async () => {
  const { calls, service } = await 桩会话与图片遮罩服务(() => new Uint8Array(0));
  await service.添加图片遮罩笔记类型();

  assert.equal(calls.length, 1);
  assert.equal(calls[0].服务号, 服务号.后端图片遮罩, 'service id 37');
  assert.equal(calls[0].方法号, 图片遮罩方法.添加图片遮罩笔记类型, 'method id 3');
  assert.equal(calls[0].输入字节.length, 0, 'generic.Empty must be empty bytes');
});

test('媒体服务.添加媒体文件 走 后端媒体(41) 的 添加媒体文件(1) 并返回最终文件名', async () => {
  const { 后端会话 } = await import('../../entry/src/main/ets/backend/后端会话.ts');
  const calls = [];
  后端会话.获取实例 = () => ({
    调用: async (服务号Arg, 方法号Arg, 输入字节) => {
      calls.push({ 服务号: 服务号Arg, 方法号: 方法号Arg, 输入字节 });
      const w = new 协议写入器();
      w.写入字符串(1, 'photo-1.png');
      return w.转为字节();
    }
  });
  const { 媒体服务 } = await import('../../entry/src/main/ets/backend/媒体服务.ts');
  const service = new 媒体服务();
  const 最终文件名 = await service.添加媒体文件('photo.png', new Uint8Array([1, 2, 3]));

  assert.equal(最终文件名, 'photo-1.png', 'generic.String.val returned as final filename');
  assert.equal(calls[0].服务号, 服务号.后端媒体, 'service id 41');
  assert.equal(calls[0].方法号, 媒体方法.添加媒体文件, 'method id 1');
});
