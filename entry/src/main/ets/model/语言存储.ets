// SPDX-License-Identifier: AGPL-3.0-or-later

import { i18n } from '@kit.LocalizationKit';

export type 语言模式 = 'zh-Hans' | 'en';

export function 当前语言模式(): 语言模式 {
  const 语言: string = i18n.System.getAppPreferredLanguage();
  if (语言.startsWith('en')) {
    return 'en';
  }
  return 'zh-Hans';
}

export function 设置语言模式(模式: 语言模式): void {
  i18n.System.setAppPreferredLanguage(模式);
}
