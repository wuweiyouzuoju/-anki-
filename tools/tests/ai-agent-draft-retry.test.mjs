// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';
import { buildFailedOperationsRetryDraft } from '../../entry/src/main/ets/model/agent/AgentDraftRetry.ts';

const operation = (kind, noteId, cardId, deckId) => ({
  kind, noteId, cardId, deckId, fieldOrd: 0, before: '', after: 'new',
});

test('partial retry keeps only failed update groups and never repeats successful writes', () => {
  const original = {
    id: 'draft-1', risk: 'write', summary: 'update', baselineHash: 'base',
    confirmationLevel: 1, status: 'partial', affectedNoteIds: [11, 12],
    affectedCardIds: [21, 22], affectedDeckIds: [], affectedNotetypeIds: [],
    operations: [operation('update_field', 11, 0, 0), operation('update_field', 12, 0, 0)],
  };
  const retry = buildFailedOperationsRetryDraft(original, {
    draftId: 'draft-1', status: 'partial', succeeded: 1, failed: 1,
    affectedCardCount: 2,
    items: [
      { operation: 'update_note', targetId: 11, succeeded: true, errorCode: '' },
      { operation: 'update_note', targetId: 12, succeeded: false, errorCode: 'network' },
    ],
  }, 'retry-1');
  assert.equal(retry.operations.length, 1);
  assert.equal(retry.operations[0].noteId, 12);
  assert.deepEqual(retry.affectedNoteIds, [12]);
  assert.equal(retry.status, 'pending');
});

test('create-note retry keeps every field belonging to the failed temporary note', () => {
  const original = {
    id: 'draft-2', risk: 'write', summary: 'create', baselineHash: '',
    confirmationLevel: 1, status: 'partial', affectedNoteIds: [], affectedCardIds: [],
    affectedDeckIds: [8], affectedNotetypeIds: [9],
    operations: [
      operation('create_note', -1, 0, 8), operation('create_note', -1, 0, 8),
      operation('create_note', -2, 0, 8), operation('create_note', -2, 0, 8),
    ],
  };
  const retry = buildFailedOperationsRetryDraft(original, {
    draftId: 'draft-2', status: 'partial', succeeded: 1, failed: 1, affectedCardCount: 0,
    items: [
      { operation: 'create_note', targetId: 101, succeeded: true, errorCode: '' },
      { operation: 'create_note', targetId: -2, succeeded: false, errorCode: 'duplicate' },
    ],
  }, 'retry-2');
  assert.equal(retry.operations.length, 2);
  assert.equal(retry.operations.every((item) => item.noteId === -2), true);
});

test('image attachments stay with failed create and update retry groups', () => {
  const candidate = {
    candidateId: 'commons-1', title: 'image', thumbnailUrl: 'https://upload.wikimedia.org/t.jpg',
    downloadUrl: 'https://upload.wikimedia.org/i.jpg', sourceUrl: 'https://commons.wikimedia.org/wiki/File:I.jpg',
    mime: 'image/jpeg', license: 'CC BY-SA', credit: 'source',
  };
  const createRetry = buildFailedOperationsRetryDraft({
    id: 'draft-image-create', risk: 'write', summary: 'create', baselineHash: '',
    confirmationLevel: 1, status: 'partial', affectedNoteIds: [], affectedCardIds: [],
    affectedDeckIds: [8], affectedNotetypeIds: [9],
    operations: [operation('create_note', -1, 0, 8), operation('create_note', -2, 0, 8)],
    imageAttachments: [{ noteId: -2, fieldOrd: 1, candidateId: 'commons-1', placement: 'append', altText: '', before: '', candidate }],
  }, {
    draftId: 'draft-image-create', status: 'partial', succeeded: 1, failed: 1,
    affectedCardCount: 0,
    items: [
      { operation: 'create_note', targetId: 101, succeeded: true, errorCode: '' },
      { operation: 'create_note', targetId: -2, succeeded: false, errorCode: 'download' },
    ],
  }, 'retry-image-create');
  assert.equal(createRetry.imageAttachments.length, 1);
  assert.equal(createRetry.imageAttachments[0].noteId, -2);

  const updateRetry = buildFailedOperationsRetryDraft({
    id: 'draft-image-update', risk: 'write', summary: 'image only', baselineHash: '',
    confirmationLevel: 1, status: 'partial', affectedNoteIds: [12], affectedCardIds: [22],
    affectedDeckIds: [], affectedNotetypeIds: [], operations: [],
    imageAttachments: [{ noteId: 12, fieldOrd: 1, candidateId: 'commons-1', placement: 'append', altText: '', before: 'back', candidate }],
  }, {
    draftId: 'draft-image-update', status: 'failed', succeeded: 0, failed: 1,
    affectedCardCount: 1,
    items: [{ operation: 'update_note', targetId: 12, succeeded: false, errorCode: 'download' }],
  }, 'retry-image-update');
  assert.ok(updateRetry);
  assert.equal(updateRetry.imageAttachments.length, 1);
  assert.deepEqual(updateRetry.affectedNoteIds, [12]);
});
