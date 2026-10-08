import deviceInfo from '@ohos.deviceInfo';
import { SdkConstants } from '../constant/SdkConstants';
import { PreferencesUtil } from './PreferencesUtil';

export class DeviceUtils {
  static getModel(): string {
    try {
      const m = deviceInfo.productModel;
      return m && m.length > 0 ? m : 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  static getLoginDevice(): string {
    const key = 'harmony_login_device_id';
    let id = PreferencesUtil.getInstance().getString(key, '');
    if (id.length === 0) {
      id = `${Date.now()}_${Math.random().toString(16).slice(2, 18)}`;
      PreferencesUtil.getInstance().putString(key, id);
    }
    return `HarmonyOS_${DeviceUtils.getModel()}_${id}`;
  }
}
