# jj_callkit

Flutter VoIP 插件。一套 Dart API，内置 Android / iOS / HarmonyOS 原生 SDK。

| 项 | 版本 |
|----|------|
| 插件 | 0.2.0 |
| Android | callsdk 1.3.9（arm64-v8a） |
| iOS | JJCallKit 1.1.1 |
| HarmonyOS | @useasy/callsdk-harmony 1.0.0 |

接入请读交付包根目录《JJCallKit_Flutter_接入文档.md》。业务工程只需 path 依赖本目录，不要再单独集成 AAR / xcframework / HAR。

```yaml
dependencies:
  jj_callkit:
    path: ../jj_callkit
```

鸿蒙宿主需使用 **Flutter for OpenHarmony**，详见 `doc/integration_ohos.md`。
