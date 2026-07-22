export type ThemeMode = 'system' | 'light' | 'dark';

export const DEFAULT_THEME_MODE: ThemeMode = 'system';

export function normalizeThemeMode(value: string): ThemeMode {
  if (value === 'light') {
    return 'light';
  }
  if (value === 'dark') {
    return 'dark';
  }
  return 'system';
}

export function resolveIsDark(mode: ThemeMode, systemDark: boolean): boolean {
  if (mode === 'dark') {
    return true;
  }
  if (mode === 'light') {
    return false;
  }
  return systemDark;
}
