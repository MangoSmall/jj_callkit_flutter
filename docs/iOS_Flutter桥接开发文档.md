# iOS Flutter 桥接开发文档

> 目标：把 `JJCallKit.framework`（入口 `VoIPManager`）封装进 Flutter Plugin，让 Dart 侧与 Android 使用同一套 `JJCallKit` API。  
> API 对照见同目录 `JJCallKit_iOS_API.md`。  
> Android 侧对照见 `Android_Flutter桥接开发文档.md`。

---

## 1. 角色与产物

| 角色 | 要做的事 |
|------|----------|
| **插件开发者（本文）** | 在 Plugin 的 `ios/` 里嵌入 xcframework，把 `VoIPManager` 的方法和 `NSNotification` 桥到 Dart |
| **业务开发者** | 只依赖 `jj_callkit`，在 Flutter 里调 `JJCallKit`，不自己拖 Framework、不建第二套 CallKit |

产物：

```
jj_callkit/
├── lib/                              # Dart 统一 API（与 Android 共用）
├── ios/
│   ├── Classes/
│   │   ├── JjCallKitPlugin.swift
│   │   └── JjCallKitPlugin.h         # 若用 ObjC 注册
│   ├── Frameworks/JJCallKit.xcframework
│   └── jj_callkit.podspec
└── example/ios/                      # 真机验证；模拟器不能验 CallKit 绿条
```

通道名与 Android 相同：

| 通道 | 名称 |
|------|------|
| MethodChannel | `com.jj/callkit/methods` |
| EventChannel | `com.jj/callkit/events` |

---

## 2. 桥接原理

iOS SDK 没有 Android 那套 Listener，状态走 `NotificationCenter`。插件做三件事：

1. **收命令**：Dart → `handle(_:result:)` → `VoIPManager.sharedManager()`
2. **回结果**：Block 回调里 `result(nil)` 或 `FlutterError`
3. **推事件**：把 SIP / Socket 通知收成与 Android 相同的 `{ type, payload }`，经 EventChannel 推给 Dart

和 Android 的关键差异在 **登录完成时机**：

| | Android | iOS |
|--|---------|-----|
| 初始化 | `CallSDK.init` 一步完成 | 先 `initial()`，再 `loginWithAccount` |
| `init` Future 何时成功 | `onInitSuccess`（已含 SIP 注册） | `login` 的 success **不够**，必须再等到 `kSIPConnectedNotification` |
| 通话状态 | `CallStateListener` | `kSIPCall*Notification` |
| 服务端来电 | `OnServerCallListener` 一次 | `kSocketCallStatusNotification`，同一通可能多条，要去重 |
| 被踢 | `setOnKickedListener` | `kSIPKickedOutNotification` |
| 登出 Future | `logout()` 同步返回 | 用 `logoutWithCompletion:`，completion 在主线程 |

```
Dart JJCallKit.init()
        │
        ▼
initial() == 0 ?
        │ 否 → result(FlutterError -1)
        ▼
loginWithAccount(...)
        │ failure → result(FlutterError)
        │ success → 先不要 result，只记下 pending
        ▼
kSIPConnectedNotification → result(nil) + emit sipConnected
kSIPConnectFailedNotification → result(FlutterError) + emit sipConnectFailed
```

---

## 3. 开发步骤

### 步骤 1：Plugin 的 iOS 骨架

与 Android 共用同一次 `flutter create`（见 Android 文档步骤 1）。iOS 实现语言用 Swift。

`ios/Classes/JjCallKitPlugin.swift` 实现 `FlutterPlugin`。

### 步骤 2：放入 xcframework

使用带真机 arm64 + 模拟器 arm64/x86_64 的 `JJCallKit.xcframework`，放到：

```
jj_callkit/ios/Frameworks/JJCallKit.xcframework
```

`ios/jj_callkit.podspec`：

```ruby
Pod::Spec.new do |s|
  s.name             = 'jj_callkit'
  s.version          = '0.0.1'
  s.summary          = 'JJCallKit Flutter plugin'
  s.homepage         = 'https://example.com'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'JJ' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.4'
  s.swift_version    = '5.0'
  s.static_framework = true

  s.vendored_frameworks = 'Frameworks/JJCallKit.xcframework'
  s.frameworks = 'CoreAudio', 'AudioToolbox', 'AVFoundation', 'CallKit'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-framework JJCallKit',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'PJ_IS_LITTLE_ENDIAN=1 PJ_IS_BIG_ENDIAN=0',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => ''
  }
end
```

Swift 里直接 `import JJCallKit`。若 module 没暴露头文件，在插件 target 的 Bridging Header 写：

```objc
#import <JJCallKit/VoIPManager.h>
```

并在 podspec 增加：

```ruby
s.public_header_files = 'Classes/**/*.h'
```

**不要**在插件或宿主里再创建 `CXProvider`。Framework 已经接了 CallKit，第二套会抢通话。

### 步骤 3：注册通道并开始听通知

```swift
public class JjCallKitPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var pendingInit: FlutterResult?
    private let manager = VoIPManager.sharedManager()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = JjCallKitPlugin()
        let methods = FlutterMethodChannel(
            name: "com.jj/callkit/methods",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methods)

        let events = FlutterEventChannel(
            name: "com.jj/callkit/events",
            binaryMessenger: registrar.messenger()
        )
        events.setStreamHandler(instance)
        instance.startObserving()
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
```

`detachFromEngineForRegistrar` 里只 `removeObserver`，**不要** `cleanupSDK()`。热重载会拆 Engine。

通知回调可能不在主线程。凡是 `result` 和 `eventSink` 都切主线程：

```swift
private func emit(_ type: String, _ payload: [String: Any] = [:]) {
    DispatchQueue.main.async { [weak self] in
        self?.eventSink?(["type": type, "payload": payload])
    }
}

private func finish(_ result: FlutterResult?, _ value: Any?) {
    DispatchQueue.main.async { result?(value) }
}
```

### 步骤 4：实现 init（两步 + 等 SIP）

```swift
private func handleInit(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard pendingInit == nil else {
        result(FlutterError(code: "-1", message: "init 正在进行", details: nil))
        return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    let account = args["username"] as? String ?? ""
    let password = args["password"] as? String ?? ""
    let passwordPk = args["passwordPk"] as? String
    let environment = (args["environment"] as? String) == "debug"
        ? VoIPEnvironment.development
        : VoIPEnvironment.production

    applyLogConfig(args["logConfig"] as? [String: Any])

    let code = manager.initial()
    guard code == VoIPStatusCode.success.rawValue || code == 0 else {
        result(FlutterError(code: "\(code)", message: VoIPManager.errorDescription(forCode: code), details: nil))
        return
    }

    pendingInit = result
    manager.login(
        withAccount: account,
        password: password,
        environment: environment,
        passwordPk: passwordPk,
        success: { _ in
            // 请求已发出。SIP 是否注册成功看通知，这里不要 result。
        },
        failure: { [weak self] code, message in
            self?.failInit(code: code, message: message)
        }
    )
}

private func failInit(code: Int, message: String?) {
    emit("sipConnectFailed", ["errorCode": code, "errorMsg": message ?? ""])
    let pending = pendingInit
    pendingInit = nil
    finish(pending, FlutterError(code: "\(code)", message: message, details: nil))
}
```

在 `startObserving()` 里监听连接通知：

```swift
NotificationCenter.default.addObserver(
    forName: NSNotification.Name(kSIPConnectedNotification),
    object: nil, queue: .main
) { [weak self] _ in
    guard let self = self else { return }
    self.emit("sipConnected")
    let pending = self.pendingInit
    self.pendingInit = nil
    pending?(nil)   // 已经在主队列
}
```

`kSIPConnectFailedNotification` 走 `failInit`。若 `pendingInit` 已是 nil（登录失败已经回过），不要再 `result` 第二次。

日志在 `initial()` 之前设置：

```swift
VoIPManager.setLogLevel(2)          // 0 错误 / 1 一般 / 2 全量
VoIPManager.setFileLoggingEnabled(true)
VoIPManager.setLogFilePath(nil)     // Documents/VoIPLogs/voip.log
```

`environment` 字符串与 Android 对齐：`production` → `VoIPEnvironmentProduction`，`debug` → `VoIPEnvironmentDevelopment`。

### 步骤 5：把 SIP 通知映射成统一通话事件

呼叫相关通知都带 `kSIPCallIdKey`、`kSIPRemoteNumberKey`、`kSIPCallRoleKey`、`kSIPCallIdStringKey`。

| 通知 | 发出的 type | 说明 |
|------|-------------|------|
| `kSIPCallCallingNotification` | `callCalling` | 可选。Dart 若只关心振铃可忽略 |
| `kSIPCallConnectingNotification` | `callAlerting` | 对齐 Android `onCallAlerting` |
| `kSIPCallConfirmNotification` | `callAnswered` | 对齐 `onCallAnswered`。接通后可调 `refreshAudioDevice()` |
| `kSIPCallDisconnectNotification` | `callReleased` 或 `callFailed` | 见下方 |
| `kSIPKickedOutNotification` | `kicked` | 对齐被踢 |
| `kSIPDisconnectedNotification` | `sipDisconnected` | 补充事件，Dart 可不处理 |

payload 与 Android 的 CallInfo 对齐。业务通话 ID 优先用 `kSIPCallIdStringKey`，没有再用 `kSIPCallIdKey`：

```swift
private func callPayload(_ info: [AnyHashable: Any], state: String) -> [String: Any] {
    let role = info[kSIPCallRoleKey] as? Int ?? 0
    return [
        "callId": (info[kSIPCallIdStringKey] as? String) ?? "\(info[kSIPCallIdKey] ?? "")",
        "phoneNumber": info[kSIPRemoteNumberKey] as? String ?? "",
        "direction": role == 1 ? "server" : "app",
        "state": state,
        "startTime": info[kSIPTimestampKey] as? Int ?? 0
    ]
}
```

挂断通知分流：

- userInfo 里有 `kSIPVoIPStatusCodeKey`，且 code 在 `-300 ... -399`（不是正常挂断）→ `callFailed`，带 `errorCode`、`errorMsg`（`kSIPReasonDescriptionKey`）
- 否则 → `callReleased`，带 `hangupType`（`kSIPHangupTypeKey`，0 主叫挂断，1 被叫挂断）和 `reason`

正常用户挂断也会走 `kSIPCallDisconnectNotification`，不要一律当成失败。

### 步骤 6：服务端来电

监听 `kSocketCallStatusNotification`，转成 `serverCall`。同一 `callId` 只在**第一次需要打开页面**时发送，后续状态改发 `callAlerting` / `callAnswered`，避免 Flutter 重复 push 页面。

```swift
private var seenServerCallIds = Set<String>()

private func handleSocket(_ info: [AnyHashable: Any]) {
    let callType = info[kSocketCallTypeKey] as? String ?? ""
    guard callType == "callin" || callType == "callout" else { return }

    let callId = info[kSocketCallIdKey] as? String ?? ""
    let state = info[kSocketCallStateKey] as? Int ?? 0
    let payload: [String: Any] = [
        "callId": callId,
        "phoneNumber": info[kSocketCustomerNumberKey] as? String ?? "",
        "direction": callType == "callin" ? "server" : "app",
        "state": socketStateName(state),
        "disNumber": info[kSocketDisNumberKey] as? String ?? "",
        "callState": state,
        "callStateName": info[kSocketCallStateNameKey] as? String ?? ""
    ]

    if callType == "callin", !seenServerCallIds.contains(callId) {
        seenServerCallIds.insert(callId)
        emit("serverCall", payload)
    }
    // state 与 Android CallState 的对应以服务端约定为准，建议：
    // 2 → callCalling，3 → callAlerting，接通态 → callAnswered
}
```

挂断或 `logout` 时清空 `seenServerCallIds`。

`autoAnswerIncomingCall` 保持默认 `YES`，与 Android「SDK 自动接听 SIP」一致。Dart 收到 `serverCall` 只打开 UI。

### 步骤 7：通话控制与登出

| Dart method | iOS 调用 | 回传 |
|-------------|---------|------|
| `makeCall` | `makeCall:userData:success:failure:` | success 回 `{ callId, phoneNumber, direction: "app", state: "calling" }` |
| `hangupCall` | `hangupCall()` | `nil` |
| `setMute` | `openMute(enabled)` | `nil` |
| `isMuted` | `isMuted()` | `Bool` |
| `setSpeaker` | `openLoudSpeaker(enabled)` | `nil` |
| `isSpeakerOn` | `isLoudSpeakerOn()` | `Bool` |
| `sendDTMF` | `sendDTMF(digit)` | `nil` |
| `canMakeCall` | `canMakeCall()` | `Bool` |
| `logout` | `logoutWithCompletion:` | completion 里 `result(nil)` |
| `release` | 摘观察者 + `cleanupSDK()` | `nil`。下次 init 会重新 `initial()` |

`makeCall` 前可先 `canMakeCall()`，为 false 时直接 `FlutterError(code: "-302", ...)`。麦克风被拒时 SDK 回 `-301`，原样上传。

`userData` 是 `[String: Any]`，编码后须小于 255 字节，超限 SDK 回 `-312`。

`getCurrentAudioRoute`：iOS 没有 Android 的 `AudioRoute` 枚举。用 `isLoudSpeakerOn()` 映射：`true → "speaker"`，`false → "receiver"`。蓝牙路由第一期可以不承诺 `bluetooth`，文档向业务说明 iOS 暂只有扬声器/听筒。接通后调用 `refreshAudioDevice()`。

### 步骤 8：外显号码

全部是 success/failure Block，在主线程 `result`。

| Dart method | iOS |
|-------------|-----|
| `getAgentConfig` | `getCallerStrategyWithSuccess`。把返回字典里的 `callerStrategy`、`selectNumber`、`numberGroup` 等原样放进 Map |
| `getDisplayNumberList` | `getDisplayNumberListWithSuccess`。元素字段：`id`、`status`、`number`、`province`、`city` |
| `getNumberGroupList` | `getDisplayNumberGroupListWithSuccess`。iOS 无分页参数，忽略 Dart 传来的 `page` / `pageSize`，返回 `{ "list": [...] }` |
| `updateDisplayNumber` | `updateAgentDisplayNumber(withSelectNumber: numberGroup: nil, ...)` |
| `updateNumberGroup` | 同上，`selectNumber: nil`，`numberGroup` 传 id。Dart 若只给 `name`，iOS 接口要的是组 ID，插件回 `-4002` 并说明 iOS 需传 `id` |

失败统一：

```swift
result(FlutterError(code: "\(code)", message: message, details: nil))
```

### 步骤 9：宿主工程必须改的配置

这些写在 **Framework 自己的 Info.plist 里无效**，必须出现在跑起来的 App 上。

插件 `example/ios/Runner/Info.plist`，以及以后每个接入方的 `ios/Runner/Info.plist`：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>用于语音通话</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

Xcode：Signing & Capabilities → Background Modes → **Audio, AirPlay, and Picture in Picture**。

Flutter 插件不能替宿主可靠地写入用途说明文案，在插件 README 里把这两项列为必做。未配 `audio` 时，锁屏可能有通话条但没有声音。

### 步骤 10：真机验证

模拟器会报 `CXErrorCodeRequestTransactionErrorUnentitled`（`requesttransaction error 1`）。SDK 会退回 SIP 直拨，**没有系统绿条**。锁屏、CallKit 只在真机上看。

```bash
cd jj_callkit/example
flutter run -d <真机UDID>
```

验证顺序与 Android 相同：权限 → init 且等到 `sipConnected` 才算登录成功 → 外呼 → 振铃/接通/挂断 → 静音/免提/DTMF → 服务端来电只弹一次 → 被踢 → logout 后再 init。

另外看两点：

- 接通后锁屏有系统通话条，能听、能挂断
- 挂断后 `AVAudioSession` 释放，不占用听筒

---

## 4. 与 Android 对齐的事件

iOS 插件发出的 `type` 必须用这套名字，否则 Dart 解析会分叉。

| type | iOS 来源 |
|------|----------|
| `sipConnected` | `kSIPConnectedNotification`（同时 complete `init`） |
| `sipConnectFailed` | `login` failure 或 `kSIPConnectFailedNotification` |
| `kicked` | `kSIPKickedOutNotification` |
| `callAlerting` | `kSIPCallConnectingNotification` |
| `callAnswered` | `kSIPCallConfirmNotification` |
| `callReleased` | `kSIPCallDisconnectNotification`（无通话错误码） |
| `callFailed` | `makeCall` failure 不走这里；通话中失败走挂断通知且带 `-3xx` |
| `serverCall` | `kSocketCallStatusNotification` 且 `callin`，每个 callId 一次 |
| `sipDisconnected` | `kSIPDisconnectedNotification` |

`makeCall` 的 failure 用 MethodChannel `FlutterError`，不要再发一条 `callFailed`，避免 Dart 处理两次。Android 的 `MakeCallCallback.onFailed` 同样只走 `result.error`。

---

## 5. 实现时要注意的点

1. **`login` success 不是 init 成功。** 只持有 `pendingInit`，等 `kSIPConnectedNotification`。
2. **`result` 只能一次，且在主线程。** 失败通知和 failure Block 可能都来，用 `pendingInit = nil` 挡第二次。
3. **不要第二套 CallKit。** 插件、example、业务 App 都不要 `import CallKit` 后再 `CXProvider`。
4. **观察者不要挂在会释放的 ViewController 上。** 挂在 Plugin 单例上，`logout` / `release` 时移除。
5. **服务端来电去重。** Socket 会连推多条状态。
6. **方向字段。** 外呼固定 `app`。Socket `callin` 映射 `server`，与 Android `CallDirection.SERVER` 一致。
7. **重新初始化。** `cleanupSDK()` 之后必须再 `initial()`。`initial()` 本身防重复，没 cleanup 时多次 `initial()` 会直接返回成功。
8. **音频会话。** Framework 管 `AVAudioSession`。插件不要再 `setCategory`，否则和 CallKit 抢。

---

## 6. 业务方使用方式

业务工程只依赖插件。iOS 工程额外确认 Info.plist（步骤 9），不要自己链 `JJCallKit.xcframework`。

`pubspec.yaml`：

```yaml
dependencies:
  jj_callkit:
    path: ../jj_callkit
  permission_handler: ^11.0.0
```

```dart
await Permission.microphone.request();

await JJCallKit.init(CallConfig(
  username: '6000@useasy',
  password: 'your_password',
  environment: CallEnvironment.production,
));

JJCallKit.events.listen((event) {
  switch (event) {
    case ServerCallEvent(:final call):
      // 打开通话页。iOS 已自动接听，不要 makeCall
    case CallAnsweredEvent():
      // 计时。锁屏绿条由系统 CallKit 显示，Flutter 页面可继续自绘
    case CallReleasedEvent():
      // 关页面
    case KickedEvent():
      // 回登录
    default:
      break;
  }
});

await JJCallKit.makeCall('13800138000', userData: {'orderId': '12345'});
await JJCallKit.setSpeaker(true);
await JJCallKit.hangupCall();
await JJCallKit.logout();
```

iOS 特有、业务需要知道的行为：

- 登录 `await init` 的耗时包含 SIP 注册，不要在 `init` 返回前拨号
- 模拟器可以走 SIP，但没有锁屏通话条；验收用真机
- 设置外显号码组时传 **组 ID**，不要只传名称
- `release()` 会拆掉 SDK，下次必须重新 `init`。页面 `dispose` 里不要调用

错误码与 Android 同一套负数，说明见 `JJCallKit_iOS_API.md` 第 6 节。例如 `-301` 麦克风、-302 未登录、-310 黑名单、-311 风控、-312 userData 过大。
