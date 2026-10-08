# jj_callkit_flutter

Flutter VoIP 插件**开发仓库**。iOS / Android SDK 同事一起维护，把两端原生 SDK 桥到同一套 Dart API。

| 项 | 版本 |
|----|------|
| 插件 | 0.2.0 |
| Android SDK | callsdk 1.3.9（arm64-v8a） |
| iOS SDK | JJCallKit 1.1.1 |
| HarmonyOS SDK | @useasy/callsdk-harmony 1.0.0 |
| Flutter（Android/iOS） | 官方 Flutter 3.16+ |
| Flutter（鸿蒙） | Flutter for OpenHarmony（见 `~/sdk/flutter_ohos`） |
| iOS | 12.4+ |
| Android minSdk | 23 |
| HarmonyOS | compatibleSdk ≥ 6.0.2(22)，arm64 真机 |

通道名两端必须一致：

| 通道 | 名称 |
|------|------|
| MethodChannel | `com.jj/callkit/methods` |
| EventChannel | `com.jj/callkit/events` |

## 目录分工

```
jj_callkit_flutter/
├── lib/                 # Dart 统一 API（两端共用，改协议先改这里）
├── android/             # Android 桥接 + CallSDK（Android 同事主改）
│   ├── repo/            # 本地 Maven：com.useasy:callsdk:x.y.z
│   └── src/.../JjCallkitPlugin.kt
├── ios/                 # iOS 桥接 + xcframework（iOS 同事主改）
│   ├── Frameworks/      # JJCallKit.xcframework
│   └── Classes/JjCallkitPlugin.swift
├── ohos/                # 鸿蒙桥接 + CallSDK HAR（ohos 同事主改）
│   ├── har/callsdk/     # @useasy/callsdk-harmony
│   └── src/.../JjCallkitPlugin.ets
├── example/             # 真机联调示例（含 example/ohos）
├── doc/                 # 插件对外使用说明
├── docs/                # 桥接开发文档、原生 API 对照
└── dist/FlutterCallSDK/ # 对外交付包（接入文档 + 插件快照 + Demo）
```

- **Android**：改 `android/`，对照 [`docs/Android_Flutter桥接开发文档.md`](docs/Android_Flutter桥接开发文档.md) 与 [`docs/CallSDK_Android_API.md`](docs/CallSDK_Android_API.md)。
- **iOS**：改 `ios/`，对照 [`docs/iOS_Flutter桥接开发文档.md`](docs/iOS_Flutter桥接开发文档.md) 与 [`docs/JJCallKit_iOS_API.md`](docs/JJCallKit_iOS_API.md)。
- **HarmonyOS**：改 `ohos/`，对照 [`docs/HarmonyOS_Flutter桥接开发文档.md`](docs/HarmonyOS_Flutter桥接开发文档.md)；联调使用 `flutter-ohos`。
- **协议 / 事件 / 错误码**：优先看 [`docs/Flutter插件实施计划.md`](docs/Flutter插件实施计划.md) 和 `lib/`，三端 MethodChannel 参数与 EventChannel payload 必须对齐。
- **对外交付**：见 [`dist/FlutterCallSDK/`](dist/FlutterCallSDK/)，主文档为 [`JJCallKit_Flutter_接入文档.md`](dist/FlutterCallSDK/JJCallKit_Flutter_接入文档.md)。客户包 README 只保留目录与快速开始；发版同步命令如下（在仓库根执行）：

```bash
rsync -a --delete \
  --exclude '.git' --exclude 'docs' --exclude 'example' --exclude 'test' --exclude 'dist' \
  --exclude '.dart_tool' --exclude 'build' --exclude '**/Pods' --exclude '**/.symlinks' \
  --exclude '**/.cxx' --exclude '**/.hvigor' --exclude '**/oh_modules' --exclude '**/node_modules' \
  ./ dist/FlutterCallSDK/jj_callkit/

# 覆盖后把 jj_callkit/README.md 恢复为客户精简版（勿用本仓库开发 README）

rsync -a --delete \
  --exclude '.dart_tool' --exclude 'build' --exclude '**/Pods' --exclude '**/.symlinks' \
  --exclude '**/.cxx' --exclude '**/.hvigor' --exclude '**/oh_modules' --exclude '**/node_modules' \
  example/ dist/FlutterCallSDK/jj_callkit-demo/

# 同步后务必：
# 1) jj_callkit-demo/pubspec.yaml → path: ../jj_callkit（example 是 path: ../，不能原样拷）
# 2) 恢复 jj_callkit/README.md 为客户精简版
# 3) 更新 FlutterCallSDK/ 根 README 与接入文档版本号
```


## 本地开发

```bash
cd example
flutter pub get
flutter run   # 建议 arm64 真机；Android 当前包无 x86
```

换原生 SDK 包时：

- Android：替换 `android/repo/com/useasy/callsdk/<version>/` 下的 aar/pom，并改 `android/build.gradle` 里的版本号
- iOS：替换 `ios/Frameworks/JJCallKit.xcframework`，必要时改 `ios/jj_callkit.podspec`
- HarmonyOS：rsync `easyapp/callsdk-harmony/callsdk/` → `ohos/har/callsdk/`

## 文档索引

桥接开发（同事协作）：

- [Android Flutter 桥接](docs/Android_Flutter桥接开发文档.md)
- [iOS Flutter 桥接](docs/iOS_Flutter桥接开发文档.md)
- [HarmonyOS Flutter 桥接](docs/HarmonyOS_Flutter桥接开发文档.md)
- [CallSDK Android API](docs/CallSDK_Android_API.md)
- [JJCallKit iOS API](docs/JJCallKit_iOS_API.md)
- [插件实施计划](docs/Flutter插件实施计划.md)

插件使用（验收 / 对外说明）：

- [Android 集成](doc/integration_android.md)
- [iOS 集成](doc/integration_ios.md)
- [HarmonyOS 集成](doc/integration_ohos.md)
- [API](doc/api_reference.md)
- [事件](doc/events.md)
- [错误码](doc/error_codes.md)
- [升级](doc/migration.md)

## 业务侧怎么用（验收参考）

业务工程只依赖本插件，不要再手动集成 AAR / xcframework，也不要自己建第二套 CallKit。

```yaml
dependencies:
  jj_callkit:
    path: ../jj_callkit_flutter   # 按实际相对路径调整
  permission_handler: ^11.4.0
```

拨号前申请麦克风。`init` 要等 SIP 注册成功才返回。

```dart
await JJCallKit.init(CallConfig(
  username: '6000@useasy',
  password: 'your_password',
  environment: CallEnvironment.production,
));

JJCallKit.events.listen((event) {
  switch (event) {
    case ServerCallEvent(:final call):
      // 打开通话页。SDK 已自动接听，不要再 makeCall
    case CallAnsweredEvent():
    case CallReleasedEvent():
    case KickedEvent():
    default:
      break;
  }
});
```

Android 权限由插件 Manifest 合并；运行时麦克风仍要 Dart 侧申请。iOS 麦克风与 Background Modes Audio 写在宿主 `Info.plist`。
