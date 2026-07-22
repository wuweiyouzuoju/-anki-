import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';
import { DECK_CONFIG_METHOD, SERVICE } from '../../entry/src/main/ets/backend/ServiceIds.ts';

function read(path) { return readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8'); }
const PANEL = 'entry/src/main/ets/components/DeckOptionsPanel.ets';
const PANE = 'entry/src/main/ets/components/DeckDetailPane.ets';

test('deck config methods match Anki 26.05 backend service', () => {
  assert.equal(SERVICE.BACKEND_DECK_CONFIG, 11);
  assert.equal(DECK_CONFIG_METHOD.GET_DECK_CONFIGS_FOR_UPDATE, 6);
  assert.equal(DECK_CONFIG_METHOD.UPDATE_DECK_CONFIGS, 7);
});

test('deck options remain presentation-only and organize complete settings progressively', () => {
  assert.equal(existsSync(new URL(`../../${PANEL}`, import.meta.url)), true);
  const panel = read(PANEL);
  const advanced = read('entry/src/main/ets/components/AdvancedDeckOptionsPanel.ets');
  assert.match(panel, /DeckConfigForm/);
  assert.match(panel, /FieldHelpPanel/);
  assert.match(panel, /AdvancedDeckOptionsPanel/);
  // 高级设置改为独立全屏磨砂覆盖层：常用 4 项（newPerDay/reviewsPerDay/learnSteps/reviewOrder）在 DeckOptionsPanel
  // 入口按钮触发 showAdvanced；7 个分组及目标记忆保持率全部移入 AdvancedDeckOptionsPanel
  assert.match(panel, /@State private showAdvanced: boolean = false/);
  for (const group of ['newExpanded', 'lapsesExpanded', 'buryingExpanded', 'audioExpanded', 'timerExpanded', 'fsrsExpanded', 'advancedExpanded']) assert.match(advanced, new RegExp(group));
  for (const group of ['@State private newExpanded', '@State private fsrsExpanded', '@State private advancedExpanded']) assert.match(advanced, new RegExp(group));
  assert.match(panel, /Button\(\$r\('app\.string\.field_help_button'\)\)/);
  assert.doesNotMatch(panel, /Button\(\$r\('app\.string\.deck_options_title'\)\)/);
  assert.doesNotMatch(panel, /learnStepsHint/);
  assert.doesNotMatch(panel, /BackendSession|DeckConfigService|libjidecards\.so/);
});

test('advanced options use semantic localized selects, unique labels, and field help', () => {
  const panel = read(PANEL);
  const advanced = read('entry/src/main/ets/components/AdvancedDeckOptionsPanel.ets');
  const base = JSON.parse(read('entry/src/main/resources/base/element/string.json')).string;
  const english = JSON.parse(read('entry/src/main/resources/en_US/element/string.json')).string;
  const baseNames = new Set(base.map((entry) => entry.name));
  const englishNames = new Set(english.map((entry) => entry.name));
  // reviewOrder 走小浮层（bindPopup），其余 enum 字段走 Select 形式的 enumSelector，统一在 AdvancedDeckOptionsPanel 中
  const flyoutKeys = ['reviewOrder'];
  const selectKeys = ['newCardInsertOrder', 'newCardGatherPriority', 'newCardSortOrder', 'newMix', 'interdayLearningMix', 'leechAction', 'questionAction', 'answerAction'];
  for (const key of flyoutKeys) {
    assert.match(panel, new RegExp(`this\\.reviewOrderSelector\\([^\\n]*${key}`), `${key} uses flyout selector`);
    assert.match(panel, new RegExp(`deck_${key}_label`), `${key} label resource used`);
  }
  for (const key of selectKeys) {
    assert.match(advanced, new RegExp(`this\\.enumSelector\\([^\\n]*${key}`), `${key} uses Select`);
    assert.doesNotMatch(advanced, new RegExp(`this\\.labeledInput\\([^\\n]*${key}`), `${key} is never a numeric text input`);
  }
  const editable = ['newPerDay', 'reviewsPerDay', 'learnSteps', 'relearnSteps', 'newPerDayMinimum', 'graduatingIntervalGood', 'graduatingIntervalEasy', 'newCardInsertOrder', 'newCardGatherPriority', 'newCardSortOrder', 'newMix', 'interdayLearningMix', 'minimumLapseInterval', 'leechThreshold', 'leechAction', 'reviewOrder', 'buryNew', 'buryReviews', 'buryInterdayLearning', 'disableAutoplay', 'skipQuestionWhenReplayingAnswer', 'waitForAudio', 'capAnswerTimeToSecs', 'showTimer', 'stopTimerOnAnswer', 'secondsToShowQuestion', 'secondsToShowAnswer', 'questionAction', 'answerAction', 'desiredRetention', 'fsrsParams4', 'easyDaysPercentages', 'fsrsParams5', 'fsrsParams6', 'historicalRetention', 'paramSearch', 'initialEase', 'easyMultiplier', 'hardMultiplier', 'lapseMultiplier', 'intervalMultiplier', 'maximumReviewInterval', 'ignoreRevlogsBeforeDate'];
  // 常用 4 项（newPerDay/reviewsPerDay/learnSteps/reviewOrder）在 DeckOptionsPanel；其余在 AdvancedDeckOptionsPanel
  const combined = `${panel}\n${advanced}`;
  for (const key of editable) {
    const label = `deck_${key}_label`;
    const help = `deck_${key}_help`;
    assert.ok(baseNames.has(label), `Chinese label for ${key}`);
    assert.ok(englishNames.has(label), `English label for ${key}`);
    assert.ok(baseNames.has(help), `Chinese help for ${key}`);
    assert.ok(englishNames.has(help), `English help for ${key}`);
    assert.match(combined, new RegExp(`app\\.string\\.${label}`), `${key} uses unique label`);
    assert.match(combined, new RegExp(`app\\.string\\.${help}`), `${key} exposes help`);
  }
});

test('every editable Anki DeckConfig field has a form or panel binding', () => {
  const panel = read(PANEL); const advanced = read('entry/src/main/ets/components/AdvancedDeckOptionsPanel.ets'); const form = read('entry/src/main/ets/model/DeckConfigForm.ets');
  const editable = ['learnSteps', 'relearnSteps', 'fsrsParams4', 'easyDaysPercentages', 'fsrsParams5', 'fsrsParams6', 'newPerDay', 'reviewsPerDay', 'initialEase', 'easyMultiplier', 'hardMultiplier', 'lapseMultiplier', 'intervalMultiplier', 'maximumReviewInterval', 'minimumLapseInterval', 'graduatingIntervalGood', 'graduatingIntervalEasy', 'newCardInsertOrder', 'newCardGatherPriority', 'newCardSortOrder', 'newMix', 'reviewOrder', 'interdayLearningMix', 'leechAction', 'leechThreshold', 'disableAutoplay', 'capAnswerTimeToSecs', 'showTimer', 'stopTimerOnAnswer', 'secondsToShowQuestion', 'secondsToShowAnswer', 'questionAction', 'answerAction', 'waitForAudio', 'skipQuestionWhenReplayingAnswer', 'buryNew', 'buryReviews', 'buryInterdayLearning', 'desiredRetention', 'historicalRetention', 'paramSearch', 'ignoreRevlogsBeforeDate'];
  for (const key of editable) assert.match(`${panel}\n${advanced}\n${form}`, new RegExp(key), key);
  assert.match(form, /other.*preserved/, 'opaque Anki bytes remain preserved, not edited as text');
});

test('home page converts through DeckConfigForm before submitting preserved config', () => {
  // B12 重构：牌组选项流程从 DeckDetailPane 上移到 Index.ets 根 Stack（全局磨砂覆盖）
  const pane = read('entry/src/main/ets/pages/Index.ets');
  assert.match(pane, /DeckConfigForm\.fromSettings\(config\.config\)/);
  assert.match(pane, /private async saveDeckOptions\(form: DeckConfigForm, options: DeckOptionsEdit\)/);
  assert.match(pane, /form\.validate\(\)/);
  assert.match(pane, /options\.validate\(\)/);
  assert.match(pane, /form\.applyToSettings\(config\.config\)/);
  assert.match(pane, /options\.apply\(\)/);
  assert.match(pane, /configs: \[config\]/);
  assert.match(pane, /options\.toRequestFields\(\)/);
  assert.match(pane, /limits: edited\.limits/);
  assert.match(pane, /newCardsIgnoreReviewLimit: edited\.newCardsIgnoreReviewLimit/);
  assert.match(pane, /fsrsHealthCheck: edited\.fsrsHealthCheck/);
  assert.match(pane, /this\.deckConfigService\.updateDeckConfigs\(request\)/);
});
