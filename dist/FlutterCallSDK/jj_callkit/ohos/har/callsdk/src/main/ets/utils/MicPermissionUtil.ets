import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

const MIC_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';

export class MicPermissionUtil {
  static async ensureMicGranted(): Promise<boolean> {
    const ctx = AppStorage.get<common.UIAbilityContext>('uiAbilityContext');
    if (ctx === undefined) {
      return true;
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
