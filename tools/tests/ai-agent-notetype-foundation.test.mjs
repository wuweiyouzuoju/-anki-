// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { register } from 'node:module';
import test from 'node:test';

import {
  decodeClozeFieldOrds,
  decodeNotetype,
  NOTE_TYPE_KIND_CLOZE,
  NOTE_TYPE_KIND_NORMAL,
} from '../../entry/src/main/ets/proto/messages/NotetypeMessages.ts';
import { 协议写入器 } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';
import { 笔记类型方法, 服务号 } from '../../entry/src/main/ets/backend/服务索引.ts';

const libStub = 'export const openBackend = () => 0; export const closeBackend = () => {}; export const runMethodRaw = () => Promise.resolve(new Uint8Array(0));';
const libStubUrl = 'data:text/javascript;base64,' + Buffer.from(libStub).toString('base64');
const networkStub = 'export const http = {};';
const networkStubUrl = 'data:text/javascript;base64,' + Buffer.from(networkStub).toString('base64');
const hookCode = `export function resolve(s, c, n) {
  if (s === 'libjidecards.so') return { url: ${JSON.stringify(libStubUrl)}, shortCircuit: true };
  if (s === '@kit.NetworkKit') return { url: ${JSON.stringify(networkStubUrl)}, shortCircuit: true };
  return n(s, c);
}`;
register('data:text/javascript;base64,' + Buffer.from(hookCode).toString('base64'), import.meta.url);

function read(path) {
  return readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
}

function buildNotetype(name, kind) {
  const message = new 协议写入器();
  message.写入64位整数(1, 42);
  message.写入字符串(2, name);
  if (kind !== null) {
    const config = new 协议写入器();
    config.写入变长整数(1, kind);
    message.写入子消息(7, config);
  }
  return message.转为字节();
}

test('decodes cloze kind from config regardless of imported note-type name', () => {
  const view = decodeNotetype(buildNotetype('机器学习·挖空', NOTE_TYPE_KIND_CLOZE));
  assert.equal(view.name, '机器学习·挖空');
  assert.equal(view.kind, NOTE_TYPE_KIND_CLOZE);
});

test('defaults an absent note-type kind to normal', () => {
  const view = decodeNotetype(buildNotetype('Imported custom type', null));
  assert.equal(view.kind, NOTE_TYPE_KIND_NORMAL);
});

test('decodes packed and unpacked cloze field ords as sorted unique values', () => {
  const response = new 协议写入器();
  response.写入打包64位整数(1, [3, 1, 3]);
  response.写入变长整数(1, 2);
  assert.deepEqual(decodeClozeFieldOrds(response.转为字节()), [1, 2, 3]);
});

test('note-type capability service reads cloze ords only for cloze types', async () => {
  assert.equal(笔记类型方法.获取填空字段序号, 18);
  const { 后端会话 } = await import('../../entry/src/main/ets/backend/后端会话.ts');
  const calls = [];
  let requestedKind = NOTE_TYPE_KIND_NORMAL;
  后端会话.获取实例 = () => ({
    调用: async (serviceId, methodId, inputBytes) => {
      calls.push({ serviceId, methodId, inputBytes });
      if (methodId === 笔记类型方法.获取笔记类型) {
        return buildNotetype('Imported capability type', requestedKind);
      }
      const response = new 协议写入器();
      response.写入打包64位整数(1, [2, 0]);
      return response.转为字节();
    },
  });
  const { 笔记类型服务 } = await import('../../entry/src/main/ets/backend/笔记类型服务.ts');

  const normal = await new 笔记类型服务().获取笔记类型能力(42);
  assert.equal(normal.kind, NOTE_TYPE_KIND_NORMAL);
  assert.deepEqual(normal.clozeFieldOrds, []);
  assert.deepEqual(calls.map((call) => call.methodId), [笔记类型方法.获取笔记类型]);

  calls.length = 0;
  requestedKind = NOTE_TYPE_KIND_CLOZE;
  const cloze = await new 笔记类型服务().获取笔记类型能力(42);
  assert.equal(cloze.kind, NOTE_TYPE_KIND_CLOZE);
  assert.deepEqual(cloze.clozeFieldOrds, [0, 2]);
  assert.deepEqual(calls.map((call) => call.methodId), [
    笔记类型方法.获取笔记类型,
    笔记类型方法.获取填空字段序号,
  ]);
  assert.ok(calls.every((call) => call.serviceId === 服务号.后端笔记类型));
});

test('AI card page loads structural capabilities instead of guessing cloze from names', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.doesNotMatch(page, /填空笔记类型名集合/);
  assert.doesNotMatch(page, /是否填空笔记类型\s*\(/);
  assert.match(page, /获取笔记类型能力\s*\(/);
  assert.match(page, /clozeFieldOrds/);
});

test('AI prompt restricts cloze markup to backend-declared field ords', async () => {
  const { 构建系统提示 } = await import('../../entry/src/main/ets/backend/AI制卡服务.ets');
  const prompt = 构建系统提示({
    apiKey: 'secret',
    baseUrl: 'https://example.com',
    model: 'example-model',
    笔记类型名: '机器学习·挖空',
    字段名列表: ['Question', 'Text', 'Source'],
    noteTypeKind: NOTE_TYPE_KIND_CLOZE,
    clozeFieldOrds: [1],
    用户输入: 'make cards',
  });
  assert.match(prompt, /第 2 个字段（Text）/);
  assert.match(prompt, /只允许/);
  assert.doesNotMatch(prompt, /第一个字段（题干）/);
});

test('AI prompt rejects a cloze type with no backend-declared cloze fields', async () => {
  const { AI制卡错误, 构建系统提示 } = await import('../../entry/src/main/ets/backend/AI制卡服务.ets');
  assert.throws(() => 构建系统提示({
    apiKey: 'secret',
    baseUrl: 'https://example.com',
    model: 'example-model',
    笔记类型名: 'Broken cloze',
    字段名列表: ['Text'],
    noteTypeKind: NOTE_TYPE_KIND_CLOZE,
    clozeFieldOrds: [],
    用户输入: 'make cards',
  }), (error) => error instanceof AI制卡错误 && error.kind === 'unsupported_notetype');
});
