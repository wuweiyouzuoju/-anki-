import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '..', '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('Anki 26.05 exposes the Notes and Notetypes service indexes used by add note', () => {
  const ids = read('entry/src/main/ets/backend/ServiceIds.ts');
  assert.match(ids, /BACKEND_NOTETYPES:\s*23/);
  assert.match(ids, /BACKEND_NOTES:\s*25/);
  assert.match(ids, /export const NOTES_METHOD\s*=\s*\{/);
  assert.match(ids, /NEW_NOTE:\s*0/);
  assert.match(ids, /ADD_NOTE:\s*1/);
  assert.match(ids, /DEFAULTS_FOR_ADDING:\s*3/);
  assert.match(ids, /NOTE_FIELDS_CHECK:\s*11/);
  assert.match(ids, /export const NOTETYPES_METHOD\s*=\s*\{/);
  assert.match(ids, /GET_NOTETYPE:\s*6/);
  assert.match(ids, /GET_NOTETYPE_NAMES:\s*8/);
});

test('notes and notetypes codecs cover Anki add-note request and dynamic field metadata', () => {
  const notes = read('entry/src/main/ets/proto/messages/NoteMessages.ts');
  const notetypes = read('entry/src/main/ets/proto/messages/NotetypeMessages.ts');
  for (const symbol of [
    'EditableNote', 'encodeNote', 'decodeNote', 'encodeAddNoteRequest', 'decodeAddNoteResponse',
    'encodeDefaultsForAddingRequest', 'decodeDeckAndNotetype', 'decodeNoteFieldsCheckResponse'
  ]) {
    assert.match(notes, new RegExp(`export (?:function|interface|enum) ${symbol}`));
  }
  assert.match(notes, /MISSING_CLOZE/);
  assert.match(notes, /NOTETYPE_NOT_CLOZE/);
  assert.match(notes, /FIELD_NOT_CLOZE/);
  for (const symbol of [
    'NotetypeView', 'NotetypeNameId', 'encodeNotetypeId', 'decodeNotetype', 'decodeNotetypeNames'
  ]) {
    assert.match(notetypes, new RegExp(`export (?:function|interface) ${symbol}`));
  }
  assert.match(notetypes, /fieldNames/);
  assert.match(notetypes, /ord/);
});

test('add-note protobuf codecs use Anki fields and retain Note field order', async () => {
  const notes = await import('../../entry/src/main/ets/proto/messages/NoteMessages.ts');
  const notetypes = await import('../../entry/src/main/ets/proto/messages/NotetypeMessages.ts');
  const { ProtoReader } = await import('../../entry/src/main/ets/proto/core/ProtoReader.ts');
  const { ProtoWriter } = await import('../../entry/src/main/ets/proto/core/ProtoWriter.ts');
  const note = {
    id: 12, guid: 'guid', notetypeId: 34, mtimeSecs: 56, usn: -1,
    tags: ['language', 'verbs'], fields: ['go', 'went']
  };
  assert.deepEqual(notes.decodeNote(notes.encodeNote(note)), note);
  const addRequest = new ProtoReader(notes.encodeAddNoteRequest(note, 78));
  assert.equal(addRequest.readTag().fieldNumber, 1);
  assert.deepEqual(notes.decodeNote(addRequest.readBytes()), note);
  assert.equal(addRequest.readTag().fieldNumber, 2);
  assert.equal(addRequest.readInt64(), 78);
  const defaults = new ProtoReader(notes.encodeDefaultsForAddingRequest(90));
  assert.equal(defaults.readTag().fieldNumber, 1);
  assert.equal(defaults.readInt64(), 90);
  const check = new ProtoWriter();
  check.writeVarint(1, notes.NoteFieldsCheckState.MISSING_CLOZE);
  assert.equal(notes.decodeNoteFieldsCheckResponse(check.toBytes()).state, notes.NoteFieldsCheckState.MISSING_CLOZE);

  const firstOrd = new ProtoWriter();
  firstOrd.writeVarint(1, 1);
  const firstField = new ProtoWriter();
  firstField.writeMessage(1, firstOrd);
  firstField.writeString(2, 'Back');
  const secondOrd = new ProtoWriter();
  secondOrd.writeVarint(1, 0);
  const secondField = new ProtoWriter();
  secondField.writeMessage(1, secondOrd);
  secondField.writeString(2, 'Front');
  const notetype = new ProtoWriter();
  notetype.writeInt64(1, 34);
  notetype.writeString(2, 'Basic');
  notetype.writeMessage(8, firstField);
  notetype.writeMessage(8, secondField);
  assert.deepEqual(notetypes.decodeNotetype(notetype.toBytes()).fieldNames, ['Front', 'Back']);
});

test('every public add-note codec has a callable runtime implementation', async () => {
  const notes = await import('../../entry/src/main/ets/proto/messages/NoteMessages.ts');
  const notetypes = await import('../../entry/src/main/ets/proto/messages/NotetypeMessages.ts');
  const { ProtoWriter } = await import('../../entry/src/main/ets/proto/core/ProtoWriter.ts');
  const note = { id: 0, guid: '', notetypeId: 1, mtimeSecs: 0, usn: 0, tags: [], fields: ['', ''] };
  assert.ok(notes.encodeNote(note) instanceof Uint8Array);
  assert.equal(notes.decodeNote(notes.encodeNote(note)).notetypeId, 1);
  assert.ok(notes.encodeAddNoteRequest(note, 2) instanceof Uint8Array);
  const addResponse = new ProtoWriter();
  addResponse.writeInt64(2, 3);
  assert.equal(notes.decodeAddNoteResponse(addResponse.toBytes()), 3);
  assert.ok(notes.encodeDefaultsForAddingRequest() instanceof Uint8Array);
  const defaults = new ProtoWriter();
  defaults.writeInt64(1, 4);
  defaults.writeInt64(2, 5);
  assert.deepEqual(notes.decodeDeckAndNotetype(defaults.toBytes()), { deckId: 4, notetypeId: 5 });
  const normal = new ProtoWriter();
  assert.equal(notes.decodeNoteFieldsCheckResponse(normal.toBytes()).state, notes.NoteFieldsCheckState.NORMAL);

  assert.ok(notetypes.encodeNotetypeId(1) instanceof Uint8Array);
  assert.deepEqual(notetypes.decodeNotetype(new Uint8Array(0)).fieldNames, []);
  const names = new ProtoWriter();
  const name = new ProtoWriter();
  name.writeInt64(1, 6);
  name.writeString(2, 'Basic');
  names.writeMessage(1, name);
  assert.deepEqual(notetypes.decodeNotetypeNames(names.toBytes()), [{ id: 6, name: 'Basic' }]);
});

test('add note services validate field state before creating the note in the selected deck', () => {
  const noteService = read('entry/src/main/ets/backend/NoteService.ts');
  const notetypeService = read('entry/src/main/ets/backend/NotetypeService.ts');
  for (const method of ['defaultsForAdding', 'newNote', 'addNote']) {
    assert.match(noteService, new RegExp(`async ${method}`));
  }
  assert.match(noteService, /NOTES_METHOD\.NOTE_FIELDS_CHECK/);
  assert.match(noteService, /NOTES_METHOD\.ADD_NOTE/);
  assert.match(noteService, /deckId/);
  assert.match(noteService, /EMPTY|DUPLICATE|MISSING_CLOZE|NOTETYPE_NOT_CLOZE|FIELD_NOT_CLOZE/);
  assert.match(notetypeService, /async getNotetypeNames/);
  assert.match(notetypeService, /async getNotetype/);
  assert.match(notetypeService, /NOTETYPES_METHOD\.GET_NOTETYPE_NAMES/);
  assert.match(notetypeService, /NOTETYPES_METHOD\.GET_NOTETYPE/);
});

test('add note panel is presentation-only and preserves drafts until a successful save', () => {
  const panel = read('entry/src/main/ets/components/AddNotePanel.ets');
  assert.doesNotMatch(panel, /BackendSession|NoteService|NotetypeService|\.run\(/);
  assert.match(panel, /@Prop fieldNames: string\[\]/);
  assert.match(panel, /ForEach\(this\.fieldNames/);
  assert.match(panel, /@State private fieldValues: string\[\]/);
  assert.match(panel, /add_note_advanced/);
  assert.match(panel, /tags/);
  assert.match(panel, /duplicate/);
  assert.match(panel, /onSave: \(fields: string\[\], tags: string\[\], notetypeId: number\)/);
  assert.match(panel, /onSaved/);
  assert.match(panel, /this\.fieldValues = this\.fieldNames\.map/);
});
