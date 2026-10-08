# HarmonyOS 集成

业务 `pubspec.yaml` 只加 `jj_callkit`（path 依赖交付包中的插件目录）。插件 ohos 端已内置 `@useasy/callsdk-harmony` HAR。

## 环境

| 项 | 要求 |
|----|------|
| IDE | DevEco Studio 5.x+ |
| Flutter | **Flutter for OpenHarmony**（不是 Homebrew / 官网官方 Flutter） |
| API | compatibleSdkVersion ≥ 6.0.2(22) |
| 设备 | **arm64 真机**（模拟器无法完整验证通话音频） |

本仓库开发机可用：

```bash
source ~/sdk/flutter_ohos/use-ohos-env.sh
# 或直接
flutter-ohos doctor -v
```

## 宿主必做

1. 工程需含 `ohos/` 目录（`flutter-ohos create --platforms ohos .`）。
2. `ohos/entry/src/main/module.json5` 声明麦克风、网络权限，Ability 增加 `backgroundModes: ["voip"]`（对照 `example/ohos`）。
3. **麦克风**：鸿蒙不要用 `permission_handler`（无 ohos 实现）。在 `EntryAbility` 里注入  
   `AppStorage.setOrCreate('uiAbilityContext', this.context)`，拨号时由 CallSDK 原生弹系统授权。  
   Android / iOS 仍可在 Dart 侧用 `permission_handler`。
4. **账号缓存**：与插件无关。鸿蒙暂勿依赖官方 `shared_preferences`；可用内存、自研存储或已适配鸿蒙的 preferences。
5. **不要**再单独集成一份 callsdk HAR；插件 `ohos/har/callsdk` 已内置。

## 平台差异（相对 Android / iOS）

| 项 | 说明 |
|----|------|
| `CallCallingEvent` | 鸿蒙原生无 `onCallCalling`；插件在 `makeCall` 成功时补发 |
| `SipDisconnectedEvent` | 鸿蒙 CallSDK 暂无对应监听，本端暂不发出 |
| 音频路由 | 听筒 / 扬声器 / 蓝牙（与 HAR 能力一致） |

## 跑 Demo

```bash
source ~/sdk/flutter_ohos/use-ohos-env.sh
cd example
flutter pub get
flutter run -d <ohos-device-id>
```

首次需在 DevEco 中为 `example/ohos` 配置调试签名。
