// SPDX-License-Identifier: AGPL-3.0-or-later

// Anki 26.05 DeckConfig protocol. Every public Config field is modeled here;
// `preserved` holds future unknown fields verbatim so updates remain lossless.
import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter, WIRE_LENGTH_DELIMITED } from '../core/ProtoWriter';

export function encodeDeckConfigId(dcid: number): Uint8Array {
  const w = new ProtoWriter();
  if (dcid !== 0) w.writeInt64(1, dcid);
  return w.toBytes();
}

export interface DeckConfigSettings {
  learnSteps: number[]; relearnSteps: number[]; fsrsParams4: number[]; easyDaysPercentages: number[];
  fsrsParams5: number[]; fsrsParams6: number[]; newPerDay: number; reviewsPerDay: number;
  initialEase: number; easyMultiplier: number; hardMultiplier: number; lapseMultiplier: number;
  intervalMultiplier: number; maximumReviewInterval: number; minimumLapseInterval: number;
  graduatingIntervalGood: number; graduatingIntervalEasy: number; newCardInsertOrder: number;
  leechAction: number; leechThreshold: number; disableAutoplay: boolean; capAnswerTimeToSecs: number;
  showTimer: boolean; skipQuestionWhenReplayingAnswer: boolean; buryNew: boolean; buryReviews: boolean;
  buryInterdayLearning: boolean; newMix: number; interdayLearningMix: number; newCardSortOrder: number;
  reviewOrder: number; newCardGatherPriority: number; newPerDayMinimum: number; questionAction: number;
  desiredRetention: number; stopTimerOnAnswer: boolean; historicalRetention: number;
  secondsToShowQuestion: number; secondsToShowAnswer: number; answerAction: number; waitForAudio: boolean;
  paramSearch: string; ignoreRevlogsBeforeDate: string; other: Uint8Array; preserved: Uint8Array[];
}

export interface DeckConfig { id: number; name: string; mtimeSecs: number; usn: number; config: DeckConfigSettings | null; }

export function emptyDeckConfigSettings(): DeckConfigSettings {
  return {
    learnSteps: [], relearnSteps: [], fsrsParams4: [], easyDaysPercentages: [], fsrsParams5: [], fsrsParams6: [],
    newPerDay: 0, reviewsPerDay: 0, initialEase: 0, easyMultiplier: 0, hardMultiplier: 0, lapseMultiplier: 0,
    intervalMultiplier: 0, maximumReviewInterval: 0, minimumLapseInterval: 0, graduatingIntervalGood: 0,
    graduatingIntervalEasy: 0, newCardInsertOrder: 0, leechAction: 0, leechThreshold: 0, disableAutoplay: false,
    capAnswerTimeToSecs: 0, showTimer: false, skipQuestionWhenReplayingAnswer: false, buryNew: false,
    buryReviews: false, buryInterdayLearning: false, newMix: 0, interdayLearningMix: 0, newCardSortOrder: 0,
    reviewOrder: 0, newCardGatherPriority: 0, newPerDayMinimum: 0, questionAction: 0, desiredRetention: 0,
    stopTimerOnAnswer: false, historicalRetention: 0, secondsToShowQuestion: 0, secondsToShowAnswer: 0,
    answerAction: 0, waitForAudio: false, paramSearch: '', ignoreRevlogsBeforeDate: '', other: new Uint8Array(), preserved: []
  };
}

function floats(w: ProtoWriter, field: number, value: number[]): void { if (value.length > 0) w.writePackedFloat(field, value); }
function uint(w: ProtoWriter, field: number, value: number): void { if (value !== 0) w.writeVarint(field, value); }
function float(w: ProtoWriter, field: number, value: number): void { if (value !== 0) w.writeFloat(field, value); }
function bool(w: ProtoWriter, field: number, value: boolean): void { if (value) w.writeBool(field, true); }
function text(w: ProtoWriter, field: number, value: string): void { if (value !== '') w.writeString(field, value); }
function readFloats(r: ProtoReader, wireType: number, target: number[]): void {
  if (wireType === WIRE_LENGTH_DELIMITED) target.push(...r.readPackedFloat()); else target.push(r.readFloat());
}

function encodeSettings(input: DeckConfigSettings): ProtoWriter {
  const v: DeckConfigSettings = { ...emptyDeckConfigSettings(), ...input };
  const w = new ProtoWriter();
  floats(w, 1, v.learnSteps); floats(w, 2, v.relearnSteps); floats(w, 3, v.fsrsParams4); floats(w, 4, v.easyDaysPercentages);
  floats(w, 5, v.fsrsParams5); floats(w, 6, v.fsrsParams6); uint(w, 9, v.newPerDay); uint(w, 10, v.reviewsPerDay);
  float(w, 11, v.initialEase); float(w, 12, v.easyMultiplier); float(w, 13, v.hardMultiplier); float(w, 14, v.lapseMultiplier);
  float(w, 15, v.intervalMultiplier); uint(w, 16, v.maximumReviewInterval); uint(w, 17, v.minimumLapseInterval);
  uint(w, 18, v.graduatingIntervalGood); uint(w, 19, v.graduatingIntervalEasy); uint(w, 20, v.newCardInsertOrder);
  uint(w, 21, v.leechAction); uint(w, 22, v.leechThreshold); bool(w, 23, v.disableAutoplay); uint(w, 24, v.capAnswerTimeToSecs);
  bool(w, 25, v.showTimer); bool(w, 26, v.skipQuestionWhenReplayingAnswer); bool(w, 27, v.buryNew); bool(w, 28, v.buryReviews);
  bool(w, 29, v.buryInterdayLearning); uint(w, 30, v.newMix); uint(w, 31, v.interdayLearningMix); uint(w, 32, v.newCardSortOrder);
  uint(w, 33, v.reviewOrder); uint(w, 34, v.newCardGatherPriority); uint(w, 35, v.newPerDayMinimum); uint(w, 36, v.questionAction);
  float(w, 37, v.desiredRetention); bool(w, 38, v.stopTimerOnAnswer); float(w, 40, v.historicalRetention);
  float(w, 41, v.secondsToShowQuestion); float(w, 42, v.secondsToShowAnswer); uint(w, 43, v.answerAction); bool(w, 44, v.waitForAudio);
  text(w, 45, v.paramSearch); text(w, 46, v.ignoreRevlogsBeforeDate); if (v.other.length > 0) w.writeBytes(255, v.other);
  for (const raw of v.preserved) w.writeRawBytes(raw);
  return w;
}

function decodeSettings(bytes: Uint8Array): DeckConfigSettings {
  const r = new ProtoReader(bytes); const out = emptyDeckConfigSettings();
  while (true) {
    const start = r.offset;
    const tag = r.readTag();
    if (tag === null) break;
    switch (tag.fieldNumber) {
      case 1: readFloats(r, tag.wireType, out.learnSteps); break; case 2: readFloats(r, tag.wireType, out.relearnSteps); break;
      case 3: readFloats(r, tag.wireType, out.fsrsParams4); break; case 4: readFloats(r, tag.wireType, out.easyDaysPercentages); break;
      case 5: readFloats(r, tag.wireType, out.fsrsParams5); break; case 6: readFloats(r, tag.wireType, out.fsrsParams6); break;
      case 9: out.newPerDay = r.readVarint(); break; case 10: out.reviewsPerDay = r.readVarint(); break;
      case 11: out.initialEase = r.readFloat(); break; case 12: out.easyMultiplier = r.readFloat(); break;
      case 13: out.hardMultiplier = r.readFloat(); break; case 14: out.lapseMultiplier = r.readFloat(); break;
      case 15: out.intervalMultiplier = r.readFloat(); break; case 16: out.maximumReviewInterval = r.readVarint(); break;
      case 17: out.minimumLapseInterval = r.readVarint(); break; case 18: out.graduatingIntervalGood = r.readVarint(); break;
      case 19: out.graduatingIntervalEasy = r.readVarint(); break; case 20: out.newCardInsertOrder = r.readVarint(); break;
      case 21: out.leechAction = r.readVarint(); break; case 22: out.leechThreshold = r.readVarint(); break;
      case 23: out.disableAutoplay = r.readBool(); break; case 24: out.capAnswerTimeToSecs = r.readVarint(); break;
      case 25: out.showTimer = r.readBool(); break; case 26: out.skipQuestionWhenReplayingAnswer = r.readBool(); break;
      case 27: out.buryNew = r.readBool(); break; case 28: out.buryReviews = r.readBool(); break;
      case 29: out.buryInterdayLearning = r.readBool(); break; case 30: out.newMix = r.readVarint(); break;
      case 31: out.interdayLearningMix = r.readVarint(); break; case 32: out.newCardSortOrder = r.readVarint(); break;
      case 33: out.reviewOrder = r.readVarint(); break; case 34: out.newCardGatherPriority = r.readVarint(); break;
      case 35: out.newPerDayMinimum = r.readVarint(); break; case 36: out.questionAction = r.readVarint(); break;
      case 37: out.desiredRetention = r.readFloat(); break; case 38: out.stopTimerOnAnswer = r.readBool(); break;
      case 40: out.historicalRetention = r.readFloat(); break; case 41: out.secondsToShowQuestion = r.readFloat(); break;
      case 42: out.secondsToShowAnswer = r.readFloat(); break; case 43: out.answerAction = r.readVarint(); break;
      case 44: out.waitForAudio = r.readBool(); break; case 45: out.paramSearch = r.readString(); break;
      case 46: out.ignoreRevlogsBeforeDate = r.readString(); break; case 255: out.other = r.readBytes(); break;
      default: r.skipField(tag.wireType); out.preserved.push(r.sliceFrom(start)); break;
    }
  }
  return out;
}

export function encodeDeckConfig(value: DeckConfig): Uint8Array {
  const w = new ProtoWriter(); if (value.id !== 0) w.writeInt64(1, value.id); if (value.name !== '') w.writeString(2, value.name);
  if (value.mtimeSecs !== 0) w.writeInt64(3, value.mtimeSecs); if (value.usn !== 0) w.writeVarint(4, value.usn);
  if (value.config !== null) w.writeMessage(5, encodeSettings(value.config)); return w.toBytes();
}
export function decodeDeckConfig(bytes: Uint8Array): DeckConfig {
  const r = new ProtoReader(bytes); const out: DeckConfig = { id: 0, name: '', mtimeSecs: 0, usn: 0, config: null }; let tag;
  while ((tag = r.readTag()) !== null) { switch (tag.fieldNumber) { case 1: out.id = r.readInt64(); break; case 2: out.name = r.readString(); break; case 3: out.mtimeSecs = r.readInt64(); break; case 4: out.usn = r.readInt32(); break; case 5: out.config = decodeSettings(r.readBytes()); break; default: r.skipField(tag.wireType); } }
  return out;
}

export interface DeckLimits { review: number | null; new: number | null; reviewToday: number | null; newToday: number | null; reviewTodayActive: boolean; newTodayActive: boolean; desiredRetention: number | null; }
export function encodeLimits(v: DeckLimits): ProtoWriter { const w = new ProtoWriter(); if (v.review !== null) uint(w, 1, v.review); if (v.new !== null) uint(w, 2, v.new); if (v.reviewToday !== null) uint(w, 3, v.reviewToday); if (v.newToday !== null) uint(w, 4, v.newToday); bool(w, 5, v.reviewTodayActive); bool(w, 6, v.newTodayActive); if (v.desiredRetention !== null) float(w, 7, v.desiredRetention); return w; }
export function decodeLimits(bytes: Uint8Array): DeckLimits { const r = new ProtoReader(bytes); const out: DeckLimits = { review: null, new: null, reviewToday: null, newToday: null, reviewTodayActive: false, newTodayActive: false, desiredRetention: null }; let tag; while ((tag = r.readTag()) !== null) { switch (tag.fieldNumber) { case 1: out.review = r.readVarint(); break; case 2: out.new = r.readVarint(); break; case 3: out.reviewToday = r.readVarint(); break; case 4: out.newToday = r.readVarint(); break; case 5: out.reviewTodayActive = r.readBool(); break; case 6: out.newTodayActive = r.readBool(); break; case 7: out.desiredRetention = r.readFloat(); break; default: r.skipField(tag.wireType); } } return out; }

export interface DeckConfigWithUseCount { config: DeckConfig; useCount: number; }
export interface CurrentDeckInfo { name: string; configId: number; parentConfigIds: number[]; limits: DeckLimits | null; }
function decodeConfigWithExtra(bytes: Uint8Array): DeckConfigWithUseCount { const r = new ProtoReader(bytes); const out: DeckConfigWithUseCount = { config: { id: 0, name: '', mtimeSecs: 0, usn: 0, config: null }, useCount: 0 }; let tag; while ((tag = r.readTag()) !== null) { if (tag.fieldNumber === 1) out.config = decodeDeckConfig(r.readBytes()); else if (tag.fieldNumber === 2) out.useCount = r.readVarint(); else r.skipField(tag.wireType); } return out; }
function decodeCurrentDeck(bytes: Uint8Array): CurrentDeckInfo { const r = new ProtoReader(bytes); const out: CurrentDeckInfo = { name: '', configId: 0, parentConfigIds: [], limits: null }; let tag; while ((tag = r.readTag()) !== null) { switch (tag.fieldNumber) { case 1: out.name = r.readString(); break; case 2: out.configId = r.readInt64(); break; case 3: if (tag.wireType === WIRE_LENGTH_DELIMITED) out.parentConfigIds.push(...r.readPackedInt64()); else out.parentConfigIds.push(r.readInt64()); break; case 4: out.limits = decodeLimits(r.readBytes()); break; default: r.skipField(tag.wireType); } } return out; }
export interface DeckConfigsForUpdateView { allConfigs: DeckConfigWithUseCount[]; currentDeck: CurrentDeckInfo | null; defaults: DeckConfig | null; schemaModified: boolean; cardStateCustomizer: string; newCardsIgnoreReviewLimit: boolean; fsrs: boolean; applyAllParentLimits: boolean; fsrsHealthCheck: boolean; }
export function decodeDeckConfigsForUpdate(bytes: Uint8Array): DeckConfigsForUpdateView { const r = new ProtoReader(bytes); const out: DeckConfigsForUpdateView = { allConfigs: [], currentDeck: null, defaults: null, schemaModified: false, cardStateCustomizer: '', newCardsIgnoreReviewLimit: false, fsrs: false, applyAllParentLimits: false, fsrsHealthCheck: false }; let tag; while ((tag = r.readTag()) !== null) { switch (tag.fieldNumber) { case 1: out.allConfigs.push(decodeConfigWithExtra(r.readBytes())); break; case 2: out.currentDeck = decodeCurrentDeck(r.readBytes()); break; case 3: out.defaults = decodeDeckConfig(r.readBytes()); break; case 4: out.schemaModified = r.readBool(); break; case 6: out.cardStateCustomizer = r.readString(); break; case 7: out.newCardsIgnoreReviewLimit = r.readBool(); break; case 8: out.fsrs = r.readBool(); break; case 9: out.applyAllParentLimits = r.readBool(); break; case 11: out.fsrsHealthCheck = r.readBool(); break; default: r.skipField(tag.wireType); } } return out; }
export const UPDATE_DECK_CONFIGS_MODE_NORMAL = 0; export const UPDATE_DECK_CONFIGS_MODE_APPLY_TO_CHILDREN = 1; export const UPDATE_DECK_CONFIGS_MODE_COMPUTE_ALL_PARAMS = 2;
export interface UpdateDeckConfigsInput { targetDeckId: number; configs: DeckConfig[]; removedConfigIds: number[]; mode: number; cardStateCustomizer: string; limits: DeckLimits | null; newCardsIgnoreReviewLimit: boolean; fsrs: boolean; applyAllParentLimits: boolean; fsrsReschedule: boolean; fsrsHealthCheck: boolean; }
export function encodeUpdateDeckConfigsRequest(req: UpdateDeckConfigsInput): Uint8Array { const w = new ProtoWriter(); if (req.targetDeckId !== 0) w.writeInt64(1, req.targetDeckId); for (const config of req.configs) w.writeBytes(2, encodeDeckConfig(config)); w.writePackedInt64(3, req.removedConfigIds); uint(w, 4, req.mode); text(w, 5, req.cardStateCustomizer); if (req.limits !== null) w.writeMessage(6, encodeLimits(req.limits)); bool(w, 7, req.newCardsIgnoreReviewLimit); bool(w, 8, req.fsrs); bool(w, 9, req.applyAllParentLimits); bool(w, 10, req.fsrsReschedule); bool(w, 11, req.fsrsHealthCheck); return w.toBytes(); }
export function decodeUpdateDeckConfigsRequest(bytes: Uint8Array): UpdateDeckConfigsInput { const r = new ProtoReader(bytes); const out: UpdateDeckConfigsInput = { targetDeckId: 0, configs: [], removedConfigIds: [], mode: 0, cardStateCustomizer: '', limits: null, newCardsIgnoreReviewLimit: false, fsrs: false, applyAllParentLimits: false, fsrsReschedule: false, fsrsHealthCheck: false }; let tag; while ((tag = r.readTag()) !== null) { switch (tag.fieldNumber) { case 1: out.targetDeckId = r.readInt64(); break; case 2: out.configs.push(decodeDeckConfig(r.readBytes())); break; case 3: if (tag.wireType === WIRE_LENGTH_DELIMITED) out.removedConfigIds.push(...r.readPackedInt64()); else out.removedConfigIds.push(r.readInt64()); break; case 4: out.mode = r.readVarint(); break; case 5: out.cardStateCustomizer = r.readString(); break; case 6: out.limits = decodeLimits(r.readBytes()); break; case 7: out.newCardsIgnoreReviewLimit = r.readBool(); break; case 8: out.fsrs = r.readBool(); break; case 9: out.applyAllParentLimits = r.readBool(); break; case 10: out.fsrsReschedule = r.readBool(); break; case 11: out.fsrsHealthCheck = r.readBool(); break; default: r.skipField(tag.wireType); } } return out; }
