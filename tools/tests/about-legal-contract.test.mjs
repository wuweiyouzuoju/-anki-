// SPDX-License-Identifier: AGPL-3.0-or-later
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

function read(relativePath) {
  return readFileSync(new URL(`../../${relativePath}`, import.meta.url), 'utf8');
}

test('About explains the Anki relationship and independent project status', () => {
  const panel = read('entry/src/main/ets/components/SettingsPanel.ets');

  for (const key of ['app_about_title', 'app_about_summary', 'app_about_anki_notice', 'app_about_license_notice']) {
    assert.match(panel, new RegExp(`app\\.string\\.${key}`));
  }
});

test('About keeps local-data backup reminder and stays free of heavy legal wording', () => {
  const panel = read('entry/src/main/ets/components/SettingsPanel.ets');

  for (const key of ['app_about_data_notice', 'app_about_copyright', 'licenses_title']) {
    assert.match(panel, new RegExp(`app\\.string\\.${key}`));
  }
  assert.doesNotMatch(panel, /Copyright ©/);
  assert.doesNotMatch(panel, /按“现状”提供/);
  assert.doesNotMatch(panel, /法律强制规定不得排除的责任除外/);
});

test('open-source entry opens a real legal surface instead of an unavailable stub', () => {
  const panel = read('entry/src/main/ets/components/SettingsPanel.ets');
  const page = read('entry/src/main/ets/pages/Index.ets');

  assert.match(panel, /onOpenLicenses/);
  assert.match(page, /LicensesPanel\(\{/);
  assert.doesNotMatch(page, /license_loading/);
  assert.doesNotMatch(panel, /非官方 AGPL-3\.0-or-later 派生项目/);
});

test('licenses panel carries AGPL wording, source placeholder and third-party notices', () => {
  const panelPath = 'entry/src/main/ets/components/LicensesPanel.ets';
  const panel = read(panelPath);

  for (const key of [
    'licenses_title', 'licenses_app_section', 'licenses_app_body',
    'licenses_source_section', 'licenses_source_body',
    'licenses_rights_section', 'licenses_rights_body',
    'licenses_third_section', 'licenses_third_anki', 'licenses_third_rust',
    'licenses_trademark_section', 'licenses_trademark_body',
    'licenses_disclaimer_section', 'licenses_disclaimer_body'
  ]) {
    assert.match(panel, new RegExp(`app\\.string\\.${key}`), `LicensesPanel must reference ${key}`);
  }

  const strings = JSON.parse(read('entry/src/main/resources/base/element/string.json')).string;
  const values = strings.map((item) => `${item.name}=${item.value}`).join('\n');
  assert.match(values, /AGPL-3\.0-or-later/);
  assert.match(values, /jidecards contributors/);
  assert.match(values, /【待填写】/);
  assert.match(values, /Ankitects Pty Ltd/);
  assert.match(values, /github\.com\/ankitects\/anki/);
  assert.match(values, /按“现状”提供/);
});
