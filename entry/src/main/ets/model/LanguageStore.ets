// SPDX-License-Identifier: AGPL-3.0-or-later

import { i18n } from '@kit.LocalizationKit';

export type LanguageMode = 'zh-Hans' | 'en';

export function currentLanguageMode(): LanguageMode {
  const language: string = i18n.System.getAppPreferredLanguage();
  if (language.startsWith('en')) {
    return 'en';
  }
  return 'zh-Hans';
}

export function setLanguageMode(mode: LanguageMode): void {
  i18n.System.setAppPreferredLanguage(mode);
}
