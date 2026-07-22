import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import {
  decodeDeckConfig,
  encodeDeckConfig
} from '../../entry/src/main/ets/proto/messages/DeckConfigMessages.ts';
import { ProtoWriter } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';

function completeSettings() {
  return {
    learnSteps: [1, 10], relearnSteps: [10], fsrsParams4: [0.1], easyDaysPercentages: [0.2],
    fsrsParams5: [0.3], fsrsParams6: [0.4], newPerDay: 20, reviewsPerDay: 200,
    initialEase: 2.5, easyMultiplier: 1.3, hardMultiplier: 1.2, lapseMultiplier: 0,
    intervalMultiplier: 1, maximumReviewInterval: 36500, minimumLapseInterval: 1,
    graduatingIntervalGood: 1, graduatingIntervalEasy: 4, newCardInsertOrder: 1,
    leechAction: 1, leechThreshold: 8, disableAutoplay: true, capAnswerTimeToSecs: 60,
    showTimer: true, skipQuestionWhenReplayingAnswer: true, buryNew: true, buryReviews: true,
    buryInterdayLearning: true, newMix: 2, interdayLearningMix: 1, newCardSortOrder: 4,
    reviewOrder: 7, newCardGatherPriority: 5, newPerDayMinimum: 1, questionAction: 1,
    desiredRetention: 0.9, stopTimerOnAnswer: true, historicalRetention: 0.88,
    secondsToShowQuestion: 4, secondsToShowAnswer: 5, answerAction: 2, waitForAudio: true,
    paramSearch: 'deck:English', ignoreRevlogsBeforeDate: '2025-01-01', other: new Uint8Array([1, 2]),
    preserved: []
  };
}

function assertEverySetting(actual, expected) {
  const fields = [
    'learnSteps', 'relearnSteps', 'fsrsParams4', 'easyDaysPercentages', 'fsrsParams5', 'fsrsParams6',
    'newPerDay', 'reviewsPerDay', 'initialEase', 'easyMultiplier', 'hardMultiplier', 'lapseMultiplier',
    'intervalMultiplier', 'maximumReviewInterval', 'minimumLapseInterval', 'graduatingIntervalGood',
    'graduatingIntervalEasy', 'newCardInsertOrder', 'leechAction', 'leechThreshold', 'disableAutoplay',
    'capAnswerTimeToSecs', 'showTimer', 'skipQuestionWhenReplayingAnswer', 'buryNew', 'buryReviews',
    'buryInterdayLearning', 'newMix', 'interdayLearningMix', 'newCardSortOrder', 'reviewOrder',
    'newCardGatherPriority', 'newPerDayMinimum', 'questionAction', 'desiredRetention', 'stopTimerOnAnswer',
    'historicalRetention', 'secondsToShowQuestion', 'secondsToShowAnswer', 'answerAction', 'waitForAudio',
    'paramSearch', 'ignoreRevlogsBeforeDate', 'other'
  ];
  assert.equal(fields.length, 44, 'fields 1-46 excluding reserved 7,8,39');
  for (const field of fields) {
    const current = actual[field]; const wanted = expected[field];
    if (current instanceof Uint8Array) assert.deepEqual(current, wanted, field);
    else if (Array.isArray(current)) {
      assert.equal(current.length, wanted.length, field);
      current.forEach((value, index) => assert.ok(Math.abs(value - wanted[index]) < 0.00001, `${field}[${index}]`));
    } else if (typeof current === 'number' && !Number.isInteger(wanted)) assert.ok(Math.abs(current - wanted) < 0.00001, field);
    else assert.equal(current, wanted, field);
  }
}

test('DeckConfig.Config round-trips every public field and unknown chunks', () => {
  const unknown = new ProtoWriter();
  unknown.writeVarint(200, 42);
  const deck = { id: 1, name: 'Default', mtimeSecs: 2, usn: 3, config: completeSettings() };
  deck.config.preserved.push(unknown.toBytes());
  const decoded = decodeDeckConfig(encodeDeckConfig(deck));
  assertEverySetting(decoded.config, completeSettings());
  assert.deepEqual(decoded.config.learnSteps, [1, 10]);
  assert.deepEqual(decoded.config.relearnSteps, [10]);
  assert.equal(decoded.config.maximumReviewInterval, 36500);
  assert.equal(decoded.config.reviewOrder, 7);
  assert.equal(decoded.config.stopTimerOnAnswer, true);
  assert.ok(Math.abs(decoded.config.desiredRetention - 0.9) < 0.00001);
  assert.equal(decoded.config.answerAction, 2);
  assert.equal(decoded.config.ignoreRevlogsBeforeDate, '2025-01-01');
  assert.deepEqual(decoded.config.other, new Uint8Array([1, 2]));
  assert.ok(decoded.config.preserved.some((chunk) => chunk.length > 0));
  assert.deepEqual(decodeDeckConfig(encodeDeckConfig(decoded)).config, decoded.config);
});

test('DeckConfig form rejects invalid values without partially changing settings', async () => {
  const { DeckConfigForm } = await import('../../entry/src/main/ets/model/DeckConfigForm.ets');
  const settings = completeSettings();
  const form = DeckConfigForm.fromSettings(settings);
  form.learnSteps = '1 zero';
  form.desiredRetention = '1.1';
  const before = JSON.stringify(settings);
  assert.ok(form.validate().length > 0);
  assert.equal(form.applyToSettings(settings), false);
  assert.equal(JSON.stringify(settings), before);
});

test('DeckConfig form retains invalid raw numeric and fractional enum edits for validation', async () => {
  const { DeckConfigForm } = await import('../../entry/src/main/ets/model/DeckConfigForm.ets');
  const settings = completeSettings(); const form = DeckConfigForm.fromSettings(settings);
  form.setNumber('maximumReviewInterval', 'not-a-number');
  form.setNumber('reviewOrder', '1.5');
  assert.equal(form.valueText('maximumReviewInterval'), 'not-a-number');
  assert.ok(form.validate().some((issue) => issue.key === 'maximumReviewInterval'));
  assert.ok(form.validate().some((issue) => issue.key === 'reviewOrder'));
  assert.equal(form.applyToSettings(settings), false);
});

test('DeckConfig form retains invalid float-array input until it can be corrected', async () => {
  const { DeckConfigForm } = await import('../../entry/src/main/ets/model/DeckConfigForm.ets');
  const settings = completeSettings(); const form = DeckConfigForm.fromSettings(settings);
  form.setFloatArray('fsrsParams6', '0.4 invalid 2');
  assert.equal(form.floatArrayText('fsrsParams6'), '0.4 invalid 2');
  assert.ok(form.validate().some((issue) => issue.key === 'fsrsParams6'));
  assert.equal(form.applyToSettings(settings), false);
});

test('deck options keep five common fields visible and fold the rest into advanced settings', () => {
  const panel = readFileSync(new URL('../../entry/src/main/ets/components/DeckOptionsPanel.ets', import.meta.url), 'utf8');
  const advanced = readFileSync(new URL('../../entry/src/main/ets/components/AdvancedDeckOptionsPanel.ets', import.meta.url), 'utf8');
  // 7 个分组随高级设置移入 AdvancedDeckOptionsPanel（独立全屏磨砂覆盖层）
  for (const group of ['New', 'Lapses', 'Burying', 'Audio', 'Timer', 'FSRS', 'Advanced']) {
    assert.match(advanced, new RegExp(group, 'i'));
  }
  assert.match(panel, /deck_group_advanced_hub/);
  // DeckOptionsPanel 入口触发 showAdvanced；7 个分组及 expanded 状态在 AdvancedDeckOptionsPanel
  assert.match(panel, /@State private showAdvanced: boolean = false/);
  assert.match(advanced, /@State private newExpanded: boolean = false/);
  assert.match(advanced, /@State private fsrsExpanded: boolean = false/);
  assert.doesNotMatch(panel, /commonExpanded|displayOrderExpanded/);
  assert.match(panel, /FieldHelpPanel/);
  assert.doesNotMatch(panel, /learnStepsHint/);
  assert.match(panel, /deck_learn_steps_help/);
});
