import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { SdkLogger } from './SdkLogger';

const MIC_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';

export class MicPermissionUtil {
  static async ensureMicGranted(): Promise<boolean> {
    const ctx = AppStorage.get<common.UIAbilityContext>('uiAbilityContext');
    if (ctx === undefined) {
      // 宿主未注入 uiAbilityContext 时不能跳过授权（否则无弹窗直接拨号失败）
      SdkLogger.warn('MicPermissionUtil', 'uiAbilityContext missing, deny mic');
      return false;
    }
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const result = await atManager.requestPermissionsFromUser(ctx, [MIC_PERMISSION]);
      if (result.authResults.length === 0) {
        return false;
      }
      return result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (_) {
      return false;
    }
  }
}
