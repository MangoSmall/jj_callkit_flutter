import preferences from '@ohos.data.preferences';
import { Context } from '@kit.AbilityKit';
import { SdkConstants } from '../constant/SdkConstants';

export class PreferencesUtil {
  private static instance: PreferencesUtil | null = null;
  private store: preferences.Preferences | null = null;

  static getInstance(): PreferencesUtil {
    if (PreferencesUtil.instance === null) {
      PreferencesUtil.instance = new PreferencesUtil();
    }
    return PreferencesUtil.instance;
  }

  init(context: Context): void {
    this.store = preferences.getPreferencesSync(context, { name: SdkConstants.PREFERENCES_NAME });
  }

  getString(key: string, defaultValue: string): string {
    if (this.store === null) {
      return defaultValue;
    }
    try {
      const v = this.store.getSync(key, defaultValue);
      return typeof v === 'string' ? v : defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  putString(key: string, value: string): void {
    if (this.store === null) {
      return;
    }
    try {
      void this.store.putSync(key, value);
      void this.store.flush();
    } catch (_) {
    }
  }

  getInt(key: string, defaultValue: number): number {
    if (this.store === null) {
      return defaultValue;
    }
    try {
      const v = this.store.getSync(key, defaultValue);
      return typeof v === 'number' ? v : defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  putInt(key: string, value: number): void {
    if (this.store === null) {
      return;
    }
    try {
      void this.store.putSync(key, value);
      void this.store.flush();
    } catch (_) {
    }
  }

  getBoolean(key: string, defaultValue: boolean): boolean {
    if (this.store === null) {
      return defaultValue;
    }
    try {
      const v = this.store.getSync(key, defaultValue);
      return typeof v === 'boolean' ? v : defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  putBoolean(key: string, value: boolean): void {
    if (this.store === null) {
      return;
    }
    try {
      void this.store.putSync(key, value);
      void this.store.flush();
    } catch (_) {
    }
  }

  remove(key: string): void {
    if (this.store === null) {
      return;
    }
    try {
      void this.store.deleteSync(key);
      void this.store.flush();
    } catch (_) {
    }
  }

  clear(): void {
    if (this.store === null) {
      return;
    }
    try {
      void this.store.clearSync();
      void this.store.flush();
    } catch (_) {
    }
  }
}
