// ProtoReader/ProtoWriter 单元测试：字节级锁定 wire format 行为，
// 样例与 protobuf 官方文档及 prost 编码对齐。
import assert from 'node:assert/strict';
import test from 'node:test';

import { ProtoReader } from '../../entry/src/main/ets/proto/core/ProtoReader.ts';
import { ProtoWriter, WIRE_VARINT, WIRE_LENGTH_DELIMITED } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';
import { utf8Decode, utf8Encode } from '../../entry/src/main/ets/proto/core/utf8.ts';

function hex(bytes) {
  return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join(' ');
}

test('varint encoding matches the protobuf spec examples', () => {
  const w = new ProtoWriter();
  w.writeVarint(1, 150);
  // field1 varint: tag 0x08, 150 = 0x96 0x01（官方文档样例）
  assert.equal(hex(w.toBytes()), '08 96 01');
});

test('varint roundtrips across boundary values', () => {
  for (const value of [0, 1, 127, 128, 300, 2 ** 31, 2 ** 53 - 1]) {
    const w = new ProtoWriter();
    w.writeVarint(3, value);
    const r = new ProtoReader(w.toBytes());
    const tag = r.readTag();
    assert.equal(tag.fieldNumber, 3);
    assert.equal(tag.wireType, WIRE_VARINT);
    assert.equal(r.readVarint(), value);
    assert.equal(r.done, true);
  }
});

test('int64 negative values encode as 10-byte two-complement varints', () => {
  const w = new ProtoWriter();
  w.writeInt64(1, -1);
  const bytes = w.toBytes();
  assert.equal(bytes.length, 1 + 10);

  const r = new ProtoReader(bytes);
  r.readTag();
  assert.equal(r.readInt64(), -1);
});

test('int64 positive roundtrip for deck-id scale values', () => {
  const w = new ProtoWriter();
  w.writeInt64(1, 1752902400123);
  const r = new ProtoReader(w.toBytes());
  r.readTag();
  assert.equal(r.readInt64(), 1752902400123);
});

test('string fields use length-delimited encoding', () => {
  const w = new ProtoWriter();
  w.writeString(2, 'hi');
  // field2 wire2: tag 0x12, len 2, "hi"（官方文档样例）
  assert.equal(hex(w.toBytes()), '12 02 68 69');

  const r = new ProtoReader(w.toBytes());
  const tag = r.readTag();
  assert.equal(tag.fieldNumber, 2);
  assert.equal(tag.wireType, WIRE_LENGTH_DELIMITED);
  assert.equal(r.readString(), 'hi');
});

test('utf8 roundtrips CJK and emoji', () => {
  for (const text of ['记得卡片', '英语四级核心', '日本語テスト', 'emoji 🃏✨']) {
    assert.equal(utf8Decode(utf8Encode(text)), text);
  }
});

test('utf8 decoder replaces malformed sequences with U+FFFD', () => {
  assert.equal(utf8Decode(new Uint8Array([0xff, 0x41])), '�A');
});

test('nested messages embed with length prefix', () => {
  const inner = new ProtoWriter();
  inner.writeString(1, 'deck');
  const outer = new ProtoWriter();
  outer.writeMessage(5, inner);

  const r = new ProtoReader(outer.toBytes());
  const tag = r.readTag();
  assert.equal(tag.fieldNumber, 5);
  const embedded = new ProtoReader(r.readBytes());
  embedded.readTag();
  assert.equal(embedded.readString(), 'deck');
});

test('reader skips unknown fields of every wire type', () => {
  const w = new ProtoWriter();
  w.writeVarint(1, 7); // 已知
  w.writeVarint(99, 1); // 未知 varint
  w.writeBytes(98, new Uint8Array([1, 2, 3])); // 未知 LEN
  w.writeVarint(2, 42); // 已知

  // 手工拼一个 fixed64（field20）+ fixed32（field22）尾部
  // key = field*8 + wireType，varint 编码：161 → [0xA1,0x01]，181 → [0xB5,0x01]
  const tail = new Uint8Array([0xa1, 0x01, 1, 2, 3, 4, 5, 6, 7, 8, 0xb5, 0x01, 9, 10, 11, 12]);
  const all = new Uint8Array(w.toBytes().length + tail.length);
  all.set(w.toBytes(), 0);
  all.set(tail, w.toBytes().length);

  const r = new ProtoReader(all);
  const seen = [];
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 1 || tag.fieldNumber === 2) {
      seen.push(tag.fieldNumber);
      r.readVarint();
    } else {
      r.skipField(tag.wireType);
    }
  }
  assert.deepEqual(seen, [1, 2]);
});

test('packed int64/float encode as length-delimited payloads like prost', () => {
  const i64 = new ProtoWriter();
  i64.writePackedInt64(1, [1, 300]);
  // field1 wire2: tag 0x0a, len 3, 1=0x01, 300=0xac 0x02
  assert.equal(hex(i64.toBytes()), '0a 03 01 ac 02');

  const f32 = new ProtoWriter();
  f32.writePackedFloat(1, [1.0]);
  assert.equal(hex(f32.toBytes()), '0a 04 00 00 80 3f');

  // 空数组不产出任何字节（proto3 空 repeated 等同未设置）
  const empty = new ProtoWriter();
  empty.writePackedInt64(1, []);
  empty.writePackedFloat(2, []);
  assert.equal(empty.toBytes().length, 0);
});

test('packed readers roundtrip and handle negative int64', () => {
  const w = new ProtoWriter();
  w.writePackedInt64(1, [1752902400123, -1]);
  w.writePackedFloat(2, [0.5, 2.5]);

  const r = new ProtoReader(w.toBytes());
  r.readTag();
  assert.deepEqual(r.readPackedInt64(), [1752902400123, -1]);
  r.readTag();
  assert.deepEqual(r.readPackedFloat(), [0.5, 2.5]);
  assert.equal(r.done, true);
});

test('offset/sliceFrom capture raw field bytes for verbatim passthrough', () => {
  const w = new ProtoWriter();
  w.writeVarint(1, 7);
  w.writeVarint(9, 20); // 未建模字段
  const r = new ProtoReader(w.toBytes());

  r.readTag();
  r.readVarint();
  const start = r.offset;
  r.readTag();
  r.skipField(WIRE_VARINT);
  const raw = r.sliceFrom(start);
  assert.equal(hex(raw), '48 14');

  const out = new ProtoWriter();
  out.writeVarint(1, 7);
  out.writeRawBytes(raw);
  assert.equal(hex(out.toBytes()), hex(w.toBytes()));
});

test('reader rejects truncated input instead of reading out of bounds', () => {
  // tag 的 varint 截断
  assert.throws(() => new ProtoReader(new Uint8Array([0x80])).readTag());
  // tag 完整但 value 缺失
  assert.throws(() => {
    const r = new ProtoReader(new Uint8Array([0x08]));
    r.readTag();
    r.readVarint();
  });
  // length-delimited 声明长度超过剩余字节
  assert.throws(() => {
    const r = new ProtoReader(new Uint8Array([0x0a, 0x05, 0x68]));
    r.readTag();
    r.readBytes();
  });
});

test('reader rejects varints beyond the safe integer range', () => {
  const w = new ProtoWriter();
  w.writeVarint(1, 0);
  const bytes = w.toBytes();
  // 构造 2^60 的 varint
  bytes[1] = 0x80;
  const huge = new Uint8Array([0x08, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x10]);
  const r = new ProtoReader(huge);
  r.readTag();
  assert.throws(() => r.readVarint());
});
