// SPDX-License-Identifier: AGPL-3.0-or-later

// Anki 26.05 notes.proto messages needed by the native add-note flow.
import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

export interface EditableNote {
  id: number;
  guid: string;
  notetypeId: number;
  mtimeSecs: number;
  usn: number;
  tags: string[];
  fields: string[];
}

export interface DeckAndNotetype {
  deckId: number;
  notetypeId: number;
}

export enum NoteFieldsCheckState {
  NORMAL = 0,
  EMPTY = 1,
  DUPLICATE = 2,
  MISSING_CLOZE = 3,
  NOTETYPE_NOT_CLOZE = 4,
  FIELD_NOT_CLOZE = 5
}

export interface NoteFieldsCheckResponse {
  state: NoteFieldsCheckState;
}

export function encodeNote(note: EditableNote): Uint8Array {
  const writer = new ProtoWriter();
  if (note.id !== 0) {
    writer.writeInt64(1, note.id);
  }
  if (note.guid !== '') {
    writer.writeString(2, note.guid);
  }
  if (note.notetypeId !== 0) {
    writer.writeInt64(3, note.notetypeId);
  }
  if (note.mtimeSecs !== 0) {
    writer.writeVarint(4, note.mtimeSecs);
  }
  if (note.usn !== 0) {
    writer.writeInt64(5, note.usn);
  }
  for (const tag of note.tags) {
    if (tag !== '') {
      writer.writeString(6, tag);
    }
  }
  for (const field of note.fields) {
    writer.writeString(7, field);
  }
  return writer.toBytes();
}

export function decodeNote(bytes: Uint8Array): EditableNote {
  const reader = new ProtoReader(bytes);
  const note: EditableNote = {
    id: 0,
    guid: '',
    notetypeId: 0,
    mtimeSecs: 0,
    usn: 0,
    tags: [],
    fields: []
  };
  let tag;
  while ((tag = reader.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        note.id = reader.readInt64();
        break;
      case 2:
        note.guid = reader.readString();
        break;
      case 3:
        note.notetypeId = reader.readInt64();
        break;
      case 4:
        note.mtimeSecs = reader.readVarint();
        break;
      case 5:
        note.usn = reader.readInt64();
        break;
      case 6:
        note.tags.push(reader.readString());
        break;
      case 7:
        note.fields.push(reader.readString());
        break;
      default:
        reader.skipField(tag.wireType);
    }
  }
  return note;
}

export function encodeAddNoteRequest(note: EditableNote, deckId: number): Uint8Array {
  const writer = new ProtoWriter();
  writer.writeBytes(1, encodeNote(note));
  if (deckId !== 0) {
    writer.writeInt64(2, deckId);
  }
  return writer.toBytes();
}

export function decodeAddNoteResponse(bytes: Uint8Array): number {
  const reader = new ProtoReader(bytes);
  let noteId = 0;
  let tag;
  while ((tag = reader.readTag()) !== null) {
    if (tag.fieldNumber === 2) {
      noteId = reader.readInt64();
    } else {
      reader.skipField(tag.wireType);
    }
  }
  return noteId;
}

export function encodeDefaultsForAddingRequest(homeDeckOfCurrentReviewCard: number = 0): Uint8Array {
  const writer = new ProtoWriter();
  if (homeDeckOfCurrentReviewCard !== 0) {
    writer.writeInt64(1, homeDeckOfCurrentReviewCard);
  }
  return writer.toBytes();
}

export function decodeDeckAndNotetype(bytes: Uint8Array): DeckAndNotetype {
  const reader = new ProtoReader(bytes);
  const result: DeckAndNotetype = { deckId: 0, notetypeId: 0 };
  let tag;
  while ((tag = reader.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      result.deckId = reader.readInt64();
    } else if (tag.fieldNumber === 2) {
      result.notetypeId = reader.readInt64();
    } else {
      reader.skipField(tag.wireType);
    }
  }
  return result;
}

export function decodeNoteFieldsCheckResponse(bytes: Uint8Array): NoteFieldsCheckResponse {
  const reader = new ProtoReader(bytes);
  let state: NoteFieldsCheckState = NoteFieldsCheckState.NORMAL;
  let tag;
  while ((tag = reader.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      state = reader.readVarint() as NoteFieldsCheckState;
    } else {
      reader.skipField(tag.wireType);
    }
  }
  return { state };
}
