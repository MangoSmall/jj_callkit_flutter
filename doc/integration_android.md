# Android 集成

业务 `pubspec.yaml` 只加 `jj_callkit`。不要把 `callsdk-*.aar` 再拷进宿主 `libs`。

插件会合并这些权限：

- `INTERNET`
- `ACCESS_NETWORK_STATE`
- `RECORD_AUDIO`
- `MODIFY_AUDIO_SETTINGS`
- `BLUETOOTH` / `BLUETOOTH_ADMIN` / `BLUETOOTH_CONNECT`

`RECORD_AUDIO` 和 Android 12+ 的 `BLUETOOTH_CONNECT` 仍要运行时申请。拨号前用 `permission_handler` 申请麦克风。没有权限时 `makeCall` 返回 `-301`。

混淆规则已经放在插件的 `consumer-rules.pro`，会随插件合并。不要删 `com.useasy.callsdk` 的 keep。

当前内置包只有 `arm64-v8a`。模拟器如果是 x86，加载不到 `libpjsua2.so`。验收用 arm64 真机。

如果通话进程在后台被系统杀掉，需要宿主自己做前台服务。插件这一版不内置通知栏保活。

依赖：

```yaml
dependencies:
  jj_callkit:
    path: ../jj_callkit
```

不要把插件发成只含 Dart、不含原生 SDK 的空包（Android 需带上 `android/repo` 内的 callsdk）。
