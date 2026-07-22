// SPDX-License-Identifier: AGPL-3.0-or-later

import { BackendSession } from './BackendSession';
import { NOTES_METHOD, SERVICE } from './ServiceIds';
import type { DeckAndNotetype, EditableNote } from '../proto/messages/NoteMessages';
import {
  decodeAddNoteResponse,
  decodeDeckAndNotetype,
  decodeNote,
  decodeNoteFieldsCheckResponse,
  encodeAddNoteRequest,
  encodeDefaultsForAddingRequest,
  encodeNote
} from '../proto/messages/NoteMessages';
import { encodeNotetypeId } from '../proto/messages/NotetypeMessages';
import { NoteFieldsCheckState } from '../proto/messages/NoteMessages';

export type NoteFieldValidationKey =
  'add_note_empty_error' |
  'add_note_duplicate_error' |
  'add_note_invalid_cloze_error';

/** Error with a resource key, so presentation code—not the backend boundary—localizes it. */
export class NoteFieldValidationError extends Error {
  readonly messageKey: NoteFieldValidationKey;

  constructor(messageKey: NoteFieldValidationKey) {
    super(messageKey);
    this.messageKey = messageKey;
  }
}

function validationKeyFor(state: NoteFieldsCheckState): NoteFieldValidationKey | null {
  switch (state) {
    case NoteFieldsCheckState.EMPTY:
      return 'add_note_empty_error';
    case NoteFieldsCheckState.DUPLICATE:
      return 'add_note_duplicate_error';
    case NoteFieldsCheckState.MISSING_CLOZE:
    case NoteFieldsCheckState.NOTETYPE_NOT_CLOZE:
    case NoteFieldsCheckState.FIELD_NOT_CLOZE:
      return 'add_note_invalid_cloze_error';
    default:
      return null;
  }
}

/** Anki 26.05 note creation boundary; it never owns UI draft state. */
export class NoteService {
  private readonly session: BackendSession = BackendSession.getInstance();

  async defaultsForAdding(): Promise<DeckAndNotetype> {
    const response = await this.session.run(
      SERVICE.BACKEND_NOTES,
      NOTES_METHOD.DEFAULTS_FOR_ADDING,
      encodeDefaultsForAddingRequest());
    return decodeDeckAndNotetype(response);
  }

  async newNote(notetypeId: number): Promise<EditableNote> {
    const response = await this.session.run(
      SERVICE.BACKEND_NOTES, NOTES_METHOD.NEW_NOTE, encodeNotetypeId(notetypeId));
    return decodeNote(response);
  }

  async addNote(note: EditableNote, deckId: number): Promise<number> {
    const checkResponse = await this.session.run(
      SERVICE.BACKEND_NOTES, NOTES_METHOD.NOTE_FIELDS_CHECK, encodeNoteForCheck(note));
    const validationKey = validationKeyFor(decodeNoteFieldsCheckResponse(checkResponse).state);
    if (validationKey !== null) {
      throw new NoteFieldValidationError(validationKey);
    }
    const response = await this.session.run(
      SERVICE.BACKEND_NOTES, NOTES_METHOD.ADD_NOTE, encodeAddNoteRequest(note, deckId));
    return decodeAddNoteResponse(response);
  }
}

function encodeNoteForCheck(note: EditableNote): Uint8Array {
  return encodeNote(note);
}
