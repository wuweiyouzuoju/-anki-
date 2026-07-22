// SPDX-License-Identifier: AGPL-3.0-or-later

import type { DeckLimits } from '../proto/messages/DeckConfigMessages';
import type { ValidationIssue } from './DeckConfigForm';

export class DeckOptionsRequestFields {
  limits: DeckLimits | null = null;
  newCardsIgnoreReviewLimit: boolean = false;
  fsrs: boolean = false;
  applyAllParentLimits: boolean = false;
  fsrsReschedule: boolean = false;
  fsrsHealthCheck: boolean = false;
}

class LimitDraft implements DeckLimits {
  review: number | null = null;
  new: number | null = null;
  reviewToday: number | null = null;
  newToday: number | null = null;
  reviewTodayActive: boolean = false;
  newTodayActive: boolean = false;
  desiredRetention: number | null = null;
}

function copyLimits(source: DeckLimits): LimitDraft {
  const target = new LimitDraft(); target.review = source.review; target.new = source.new; target.reviewToday = source.reviewToday; target.newToday = source.newToday; target.reviewTodayActive = source.reviewTodayActive; target.newTodayActive = source.newTodayActive; target.desiredRetention = source.desiredRetention; return target;
}
function limitText(value: number | null): string { return value === null ? '' : value.toString(); }
function u32(value: string): number | null { const trimmed: string = value.trim(); if (trimmed === '') return null; if (!/^\d+$/.test(trimmed)) return null; const parsed: number = Number(trimmed); return Number.isSafeInteger(parsed) && parsed <= 4294967295 ? parsed : null; }
function retention(value: string): number | null { const trimmed: string = value.trim(); if (trimmed === '') return null; const parsed: number = Number(trimmed); return Number.isFinite(parsed) && parsed >= 0.7 && parsed <= 0.99 ? parsed : null; }

/** UI-only draft for current-deck limits and request-level scheduler flags. */
@Observed
export class DeckOptionsEdit {
  reviewLimit: string = '';
  newLimit: string = '';
  reviewToday: string = '';
  newToday: string = '';
  desiredRetentionOverride: string = '';
  reviewTodayActive: boolean = false;
  newTodayActive: boolean = false;
  newCardsIgnoreReviewLimit: boolean = false;
  fsrs: boolean = false;
  applyAllParentLimits: boolean = false;
  fsrsReschedule: boolean = false;
  fsrsHealthCheck: boolean = false;
  private sourceLimits: DeckLimits | null = null;
  private appliedLimits: DeckLimits | null = null;

  private constructor(limits: DeckLimits | null, newCardsIgnoreReviewLimit: boolean, fsrs: boolean, applyAllParentLimits: boolean, fsrsHealthCheck: boolean) {
    if (limits !== null) { this.sourceLimits = copyLimits(limits); this.appliedLimits = copyLimits(limits); this.reviewLimit = limitText(limits.review); this.newLimit = limitText(limits.new); this.reviewToday = limitText(limits.reviewToday); this.newToday = limitText(limits.newToday); this.desiredRetentionOverride = limitText(limits.desiredRetention); this.reviewTodayActive = limits.reviewTodayActive; this.newTodayActive = limits.newTodayActive; }
    this.newCardsIgnoreReviewLimit = newCardsIgnoreReviewLimit; this.fsrs = fsrs; this.applyAllParentLimits = applyAllParentLimits; this.fsrsHealthCheck = fsrsHealthCheck;
  }

  static fromView(limits: DeckLimits | null, newCardsIgnoreReviewLimit: boolean, fsrs: boolean, applyAllParentLimits: boolean, fsrsHealthCheck: boolean): DeckOptionsEdit { return new DeckOptionsEdit(limits, newCardsIgnoreReviewLimit, fsrs, applyAllParentLimits, fsrsHealthCheck); }

  validate(): ValidationIssue[] {
    const issues: ValidationIssue[] = []; const keys: string[] = ['reviewLimit', 'newLimit', 'reviewToday', 'newToday']; const values: string[] = [this.reviewLimit, this.newLimit, this.reviewToday, this.newToday];
    for (let i = 0; i < keys.length; i++) if (values[i].trim() !== '' && u32(values[i]) === null) issues.push({ key: keys[i], messageKey: 'deck_limit_validation_error' });
    if (this.desiredRetentionOverride.trim() !== '' && retention(this.desiredRetentionOverride) === null) issues.push({ key: 'desiredRetentionOverride', messageKey: 'deck_retention_validation_error' }); return issues;
  }

  apply(): boolean {
    if (this.validate().length > 0) return false;
    if (this.sourceLimits === null) { this.appliedLimits = null; return true; }
    const next = new LimitDraft(); next.review = u32(this.reviewLimit); next.new = u32(this.newLimit); next.reviewToday = u32(this.reviewToday); next.newToday = u32(this.newToday); next.reviewTodayActive = this.reviewTodayActive; next.newTodayActive = this.newTodayActive; next.desiredRetention = retention(this.desiredRetentionOverride); this.appliedLimits = next; return true;
  }

  toRequestFields(): DeckOptionsRequestFields { const result = new DeckOptionsRequestFields(); result.limits = this.appliedLimits === null ? null : copyLimits(this.appliedLimits); result.newCardsIgnoreReviewLimit = this.newCardsIgnoreReviewLimit; result.fsrs = this.fsrs; result.applyAllParentLimits = this.applyAllParentLimits; result.fsrsReschedule = this.fsrsReschedule; result.fsrsHealthCheck = this.fsrsHealthCheck; return result; }
}
