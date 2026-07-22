// Minimal read-only Notetype decoding for Anki 26.05 dynamic add-note fields.
import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

export interface NotetypeNameId {
  id: number;
  name: string;
}

export interface NotetypeField {
  ord: number;
  name: string;
}

export interface NotetypeView {
  id: number;
  name: string;
  fields: NotetypeField[];
  fieldNames: string[];
}

export function encodeNotetypeId(id: number): Uint8Array {
  const writer = new ProtoWriter();
  if (id !== 0) {
    writer.writeInt64(1, id);
  }
  return writer.toBytes();
}

function decodeUInt32(bytes: Uint8Array): number {
  const reader = new ProtoReader(bytes);
  let value = 0;
  let tag;
  while ((tag = reader.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      value = reader.readVarint();
    } else {
      reader.skipField(tag.wireType);
    }
  }
  return value;
}

function decodeNotetypeField(bytes: Uint8Array): NotetypeField {
  const reader = new ProtoReader(bytes);
  const field: NotetypeField = { ord: 0, name: '' };
  let tag;
  while ((tag = reader.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      field.ord = decodeUInt32(reader.readBytes());
    } else if (tag.fieldNumber === 2) {
      field.name = reader.readString();
    } else {
      // Field config and any future fields are read-only for this flow.
      reader.skipField(tag.wireType);
    }
  }
  return field;
}

export function decodeNotetype(bytes: Uint8Array): NotetypeView {
  const reader = new ProtoReader(bytes);
  const result: NotetypeView = { id: 0, name: '', fields: [], fieldNames: [] };
  let tag;
  while ((tag = reader.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      result.id = reader.readInt64();
    } else if (tag.fieldNumber === 2) {
      result.name = reader.readString();
    } else if (tag.fieldNumber === 8) {
      result.fields.push(decodeNotetypeField(reader.readBytes()));
    } else {
      // This UI never writes Notetype protobufs, so preserve its source bytes in Anki.
      reader.skipField(tag.wireType);
    }
  }
  result.fields.sort((left: NotetypeField, right: NotetypeField): number => left.ord - right.ord);
  result.fieldNames = result.fields.map((field: NotetypeField): string => field.name);
  return result;
}

function decodeNotetypeNameId(bytes: Uint8Array): NotetypeNameId {
  const reader = new ProtoReader(bytes);
  const result: NotetypeNameId = { id: 0, name: '' };
  let tag;
  while ((tag = reader.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      result.id = reader.readInt64();
    } else if (tag.fieldNumber === 2) {
      result.name = reader.readString();
    } else {
      reader.skipField(tag.wireType);
    }
  }
  return result;
}

export function decodeNotetypeNames(bytes: Uint8Array): NotetypeNameId[] {
  const reader = new ProtoReader(bytes);
  const entries: NotetypeNameId[] = [];
  let tag;
  while ((tag = reader.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      entries.push(decodeNotetypeNameId(reader.readBytes()));
    } else {
      reader.skipField(tag.wireType);
    }
  }
  return entries;
}
