# HarmonyOS Flutter 桥接开发文档

> 目标：把 `@useasy/callsdk-harmony`（HAR）封装进 Flutter Plugin 的 `ohos/` 平台，与 Android / iOS 共用 Dart API。  
> 原生 API 对照见 `easyapp/callsdk-harmony/docs/CallSDK_HarmonyOS_接入文档.md`。

## 目录

```
jj_callkit/
├── lib/                 # Dart 统一 API
├── android/             # CallSDK AAR
├── ios/                 # JJCallKit xcframework
└── ohos/
    ├── index.ets
    ├── oh-package.json5           # 依赖 file:./har/callsdk
    ├── har/callsdk/               # 内置鸿蒙 CallSDK 源码 / HAR
    └── src/main/ets/components/plugin/JjCallkitPlugin.ets
```

## 通道（必须与双端一致）

| 通道 | 名称 |
|------|------|
| MethodChannel | `com.jj/callkit/methods` |
| EventChannel | `com.jj/callkit/events` |

实现模板：`android/.../JjCallkitPlugin.kt`。  
鸿蒙插件类：`getUniqueClassName() => "JjCallkitPlugin"`，`pubspec` 中 `ohos.pluginClass: JjCallkitPlugin`。

## 已知缺口

1. HAR `CallStateListener` 无 `onCallCalling` → `makeCall` 成功时补发 `callCalling`
2. `sipDisconnected`：HAR 已通过 PJSIP `reg_state` 丢失 + `setOnSipDisconnectedListener` 发出
3. 开发与联调必须用 **Flutter for OpenHarmony**，与官方 Flutter SDK 并存时用 `flutter-ohos` 别名

## 编解码注意

EventChannel / MethodChannel 的复杂结果必须用 `Map` / `Array`，**不要**用自定义 ArkTS class（codec 会变成空对象）。

## 换包

替换 `ohos/har/callsdk/`（从 `easyapp/callsdk-harmony/callsdk` rsync），跑 example 登录 / 外呼 / 挂断验收。
