import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { decodeUpdateDeckConfigsRequest, encodeUpdateDeckConfigsRequest } from '../../entry/src/main/ets/proto/messages/DeckConfigMessages.ts';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');

test('current deck limits and scheduler flags round-trip as editable request data', async () => {
  const { DeckOptionsEdit } = await import('../../entry/src/main/ets/model/DeckOptionsEdit.ets');
  const edit = DeckOptionsEdit.fromView({ review: 100, new: null, reviewToday: 20, newToday: 10, reviewTodayActive: true, newTodayActive: false, desiredRetention: null }, false, false, false, false);
  edit.reviewLimit = '120'; edit.newLimit = '30'; edit.reviewToday = '25'; edit.newToday = '';
  edit.reviewTodayActive = false; edit.newTodayActive = true; edit.desiredRetentionOverride = '0.85';
  edit.newCardsIgnoreReviewLimit = true; edit.fsrs = true; edit.applyAllParentLimits = true;
  edit.fsrsReschedule = true; edit.fsrsHealthCheck = true;
  assert.deepEqual(edit.validate(), []);
  assert.equal(edit.apply(), true);
  const bytes = encodeUpdateDeckConfigsRequest({ targetDeckId: 1, configs: [], removedConfigIds: [], mode: 0, cardStateCustomizer: '', ...edit.toRequestFields() });
  const decoded = decodeUpdateDeckConfigsRequest(bytes);
  assert.equal(decoded.limits.review, 120); assert.equal(decoded.limits.new, 30); assert.equal(decoded.limits.reviewToday, 25); assert.equal(decoded.limits.newToday, null); assert.equal(decoded.limits.reviewTodayActive, false); assert.equal(decoded.limits.newTodayActive, true); assert.ok(Math.abs(decoded.limits.desiredRetention - 0.85) < 0.00001);
  assert.equal(decoded.newCardsIgnoreReviewLimit, true);
  assert.equal(decoded.fsrs, true);
  assert.equal(decoded.applyAllParentLimits, true);
  assert.equal(decoded.fsrsReschedule, true);
  assert.equal(decoded.fsrsHealthCheck, true);
});

test('invalid deck limits are atomic and identify their own fields', async () => {
  const { DeckOptionsEdit } = await import('../../entry/src/main/ets/model/DeckOptionsEdit.ets');
  const edit = DeckOptionsEdit.fromView({ review: 10, new: null, reviewToday: null, newToday: null, reviewTodayActive: false, newTodayActive: false, desiredRetention: null }, false, false, false, false);
  edit.reviewLimit = '-1'; edit.newToday = '1.2'; edit.desiredRetentionOverride = '1.2';
  const before = JSON.stringify(edit.toRequestFields());
  const issues = edit.validate();
  assert.deepEqual(issues.map((issue) => issue.key).sort(), ['desiredRetentionOverride', 'newToday', 'reviewLimit']);
  assert.equal(edit.apply(), false);
  assert.equal(JSON.stringify(edit.toRequestFields()), before);
});

test('DeckConfig form enforces Anki 26.05 field bounds and FSRS array shapes atomically', async () => {
  const { DeckConfigForm } = await import('../../entry/src/main/ets/model/DeckConfigForm.ets');
  const { emptyDeckConfigSettings } = await import('../../entry/src/main/ets/proto/messages/DeckConfigMessages.ts');
  const settings = emptyDeckConfigSettings();
  const form = DeckConfigForm.fromSettings(settings);
  form.newPerDay = '10000'; form.setNumber('initialEase', '1.3'); form.setNumber('historicalRetention', '0.98');
  form.setFloatArray('easyDaysPercentages', '1 1 1'); form.setFloatArray('fsrsParams6', Array.from({ length: 20 }, () => '1').join(' '));
  const before = JSON.stringify(settings);
  const keys = form.validate().map((issue) => issue.key);
  for (const key of ['newPerDay', 'initialEase', 'historicalRetention', 'easyDaysPercentages', 'fsrsParams6']) assert.ok(keys.includes(key), key);
  assert.equal(form.applyToSettings(settings), false);
  assert.equal(JSON.stringify(settings), before);
});

test('deck option controls bind editable limits and render adjacent field errors', () => {
  const panel = read('entry/src/main/ets/components/DeckOptionsPanel.ets');
  const advanced = read('entry/src/main/ets/components/AdvancedDeckOptionsPanel.ets');
  // 牌组选项流已迁移：保存入口在 Index.ets（options.toRequestFields()），开关控件在 AdvancedDeckOptionsPanel.ets
  const host = read('entry/src/main/ets/pages/Index.ets');
  for (const key of ['reviewLimit', 'newLimit', 'reviewToday', 'newToday', 'desiredRetentionOverride', 'newCardsIgnoreReviewLimit', 'fsrs', 'applyAllParentLimits', 'fsrsReschedule', 'fsrsHealthCheck']) assert.match(`${panel}\n${advanced}\n${host}`, new RegExp(key));
  assert.match(panel, /private fieldError\(key: string\)/);
  assert.match(panel, /this\.fieldError\(this\.fieldKey\(label\)\)/);
  assert.match(host, /options\.toRequestFields\(\)/);
});
