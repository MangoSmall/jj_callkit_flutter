# jj_callkit

Flutter VoIP SDK。一套 Dart API 同时对接 Android CallSDK 与 iOS JJCallKit。

| 项 | 版本 |
|----|------|
| 插件 | 0.1.1 |
| Android 原生 | callsdk 1.3.8（arm64-v8a） |
| iOS 原生 | JJCallKit 1.1.1 |
| Flutter | 3.16+ |
| Android minSdk | 23 |
| iOS | 12.4+ |

## 快速开始

```yaml
dependencies:
  jj_callkit:
    path: ../jj_callkit   # 或 git / 私有源
```

```dart
import 'package:jj_callkit/jj_callkit.dart';

await JJCallKit.init(CallConfig(
  username: account,
  password: password,
  environment: CallEnvironment.production,
));

JJCallKit.events.listen((event) { /* 通话 / 被踢 / SIP */ });

await JJCallKit.makeCall('13800138000');
```

完整说明见交付包根目录 **《JJCallKit_Flutter_接入文档.md》**。本目录下 `doc/` 为分册（Android / iOS 集成、API、事件、错误码）。

## 重要约定

- 业务工程**只依赖本插件**，不要再集成 `callsdk-*.aar` 或 `JJCallKit.xcframework`。
- 服务端来电只处理 `ServerCallEvent` 并打开页面，**不要再 `makeCall`**。
- Android 验收请用 **arm64 真机**；iOS 锁屏通话请用真机。
