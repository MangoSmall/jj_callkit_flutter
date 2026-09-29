# 升级

插件版本和原生 SDK 版本分开。换原生包时：

1. 替换 `android/repo/com/useasy/callsdk/<version>/` 下的 `callsdk-*.aar` 与 `.pom`，并更新 `android/build.gradle` 中的 `api("com.useasy:callsdk:x.y.z")`。AAR 内已含 `pjsua2-classes.jar`，不要再单独放一份同名 jar。
2. 替换 `ios/Frameworks/JJCallKit.xcframework`。如果新包没有 `Modules/module.modulemap`，要补上，否则 Swift `import JJCallKit` 会失败。
3. 跑 `example` 的登录、外呼、挂断、外显号码。
4. 更新 README 里的版本对应表和本文件。

0.1.0 内置的是 callsdk 1.3.7 和 JJCallKit 1.1.1。Android 侧 `getCurrentAudioRoute()` / `audioRouteChanged` 走原生音频路由（听筒 / 扬声器 / 蓝牙）；iOS 仍主要按扬声器开关近似。

从原生 Demo 迁到 Flutter 时，删除宿主里的 AAR / Framework 依赖，改调 `JJCallKit`。不要保留原来的 `CallSDK.init` 或 `VoIPManager.login`。
