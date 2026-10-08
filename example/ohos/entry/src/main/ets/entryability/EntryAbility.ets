import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { AbilityConstant, Want } from '@kit.AbilityKit';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

export default class EntryAbility extends FlutterAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam);
    // CallSDK MicPermissionUtil / 业务侧可能从 AppStorage 取 UIAbilityContext
    AppStorage.setOrCreate('uiAbilityContext', this.context);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
  }
}
