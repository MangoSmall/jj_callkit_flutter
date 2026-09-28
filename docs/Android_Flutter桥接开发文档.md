# Android Flutter 桥接开发文档

> 目标：把 `callsdk-1.3.7.aar`（`com.useasy.callsdk.CallSDK`）封装进 Flutter Plugin，让 Dart 侧用同一套 API 完成登录、外呼、通话控制和外显号码配置。  
> API 对照见同目录 `CallSDK_Android_API.md`。  
> iOS 侧对照见 `iOS_Flutter桥接开发文档.md`。

---

## 1. 角色与产物

| 角色 | 要做的事 |
|------|----------|
| **插件开发者（本文）** | 在 Plugin 的 `android/` 里引入 AAR，用 MethodChannel / EventChannel 把 `CallSDK` 桥到 Dart |
| **业务开发者** | 只依赖 `jj_callkit` 插件，在 Flutter 里调 `JJCallKit`，不直接碰 AAR |

产物：

```
jj_callkit/
├── lib/                          # Dart 统一 API（两端共用）
├── android/
│   ├── libs/callsdk-1.3.7.aar
│   ├── build.gradle
│   ├── consumer-rules.pro
│   └── src/main/
│       ├── AndroidManifest.xml
│       └── kotlin/.../JjCallKitPlugin.kt
└── example/                      # 真机验证用
```

通道名两端必须一致：

| 通道 | 名称 |
|------|------|
| MethodChannel | `com.jj/callkit/methods` |
| EventChannel | `com.jj/callkit/events` |

---

## 2. 桥接原理

Flutter 不能直接调用 Kotlin。Android 侧只做三件事：

1. **收命令**：Dart `invokeMethod` → `onMethodCall` → 调 `CallSDK.xxx`
2. **回结果**：异步 Listener / Callback 里调用 `result.success` 或 `result.error`（每个 MethodCall 只能回一次）
3. **推事件**：`CallStateListener`、`OnServerCallListener`、被踢、音频路由 → `EventSink.success(map)`

```
Dart JJCallKit.makeCall()
        │  MethodChannel "makeCall"
        ▼
JjCallKitPlugin.onMethodCall
        │  CallSDK.makeCall(phone, userData, MakeCallCallback)
        ▼
onSuccess(callInfo) ── result.success(map)
onFailed(code, msg) ─ result.error(...)

CallSDK 后续状态
        │  CallStateListener（主线程）
        ▼
eventSink.success({ type, payload })
        │  EventChannel
        ▼
Dart JJCallKit.events
```

`CallSDK` 的回调都在主线程，可以直接 `eventSink.success`。`eventSink` 为 null（Dart 还没 `listen`）时丢掉事件即可，不要缓存后在子线程补发。

---

## 3. 开发步骤

### 步骤 1：创建 Plugin

```bash
cd JJSDK/Flutter
flutter create --template=plugin --platforms=android,ios --org com.jj jj_callkit
```

语言选 Kotlin。之后只改 `android/`，Dart 层两端共用。

### 步骤 2：放入 AAR 并声明依赖

把交付包里的 `Android/sdk/callsdk-1.3.7.aar` 拷到：

```
jj_callkit/android/libs/callsdk-1.3.7.aar
```

`android/build.gradle`：

```gradle
android {
    namespace 'com.jj.jj_callkit'
    compileSdk 34

    defaultConfig {
        minSdk 21
        consumerProguardFiles 'consumer-rules.pro'
    }
}

repositories {
    flatDir { dirs 'libs' }
}

dependencies {
    implementation(name: 'callsdk-1.3.7', ext: 'aar')
    implementation 'com.squareup.okhttp3:okhttp:4.9.3'
}
```

`android/consumer-rules.pro`（随插件合并进宿主混淆规则）：

```proguard
-keep class com.useasy.callsdk.** { *; }
-keep interface com.useasy.callsdk.** { *; }
```

### 步骤 3：声明权限

`android/src/main/AndroidManifest.xml`。插件 Manifest 会合并进宿主 App。

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
</manifest>
```

`RECORD_AUDIO`、`BLUETOOTH_CONNECT` 仍需运行时申请。插件不弹系统框，由 Dart 在 `makeCall` 前用 `permission_handler` 申请。Native 拨号前可再查一次，没有权限时 `result.error("-301", "通话权限被拒绝", null)`。

### 步骤 4：实现 Plugin 入口

`JjCallKitPlugin` 同时实现 `FlutterPlugin`、`MethodCallHandler`、`EventChannel.StreamHandler`。

```kotlin
class JjCallKitPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var appContext: Context? = null

    // 每个进行中的 MethodCall 只能持有一个 Result，回完置空
    private var pendingInit: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        val messenger = binding.binaryMessenger

        methodChannel = MethodChannel(messenger, "com.jj/callkit/methods")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(messenger, "com.jj/callkit/events")
        eventChannel.setStreamHandler(this)

        // 被踢与 SDK 生命周期无关，尽早挂上
        CallSDK.setOnKickedListener {
            emit("kicked", emptyMap())
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        CallSDK.removeCallStateListener(callStateListener)
        CallSDK.setOnServerCallListener(null)
        CallSDK.setAudioRouteChangeListener(null)
        // 不要在这里 CallSDK.release()，Engine 重建不等于用户退出登录
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
```

在 `android/src/main/kotlin/.../JjCallKitPlugin.kt` 同文件底部用 Java 静态注册（`flutter create` 已生成）：

```kotlin
companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) { /* v1 embedding，可省略 */ }
}
```

`pubspec.yaml` 的 `flutter.plugin.platforms.android` 要指向这个类，`flutter create` 默认已写好。

### 步骤 5：实现 init（登录）

Dart `init` 对应 Android **一次** `CallSDK.init`。`onInitSuccess` 表示初始化、登录、SIP 注册都完成，此时再 `result.success(null)`，与 iOS「等到 SIP 连接成功再 complete」对齐。

```kotlin
private fun handleInit(call: MethodCall, result: MethodChannel.Result) {
    if (pendingInit != null) {
        result.error("-1", "init 正在进行", null)
        return
    }
    val ctx = appContext
    if (ctx == null) {
        result.error("-1", "context 为空", null)
        return
    }

    val username = call.argument<String>("username").orEmpty()
    val password = call.argument<String>("password")
    val passwordPk = call.argument<String>("passwordPk")
    val environment = call.argument<String>("environment") ?: "production"
    val log = call.argument<Map<String, Any?>>("logConfig")

    val config = SDKConfig(
        username = username,
        password = password,
        passwordPk = passwordPk,
        baseUrl = if (environment == "debug") Environment.DEBUG else Environment.PRODUCTION,
        logConfig = LogConfig(
            enableLog = log?.get("enableLog") as? Boolean ?: false,
            logLevel = (log?.get("logLevel") as? Int) ?: Log.INFO,
            logFilePath = log?.get("logFilePath") as? String,
            fileLoggingEnabled = log?.get("fileLoggingEnabled") as? Boolean ?: false,
            consoleLogEnabled = log?.get("consoleLogEnabled") as? Boolean ?: false
        )
    )

    pendingInit = result
    registerPersistentListeners()

    CallSDK.init(ctx, config, object : InitListener {
        override fun onInitSuccess() {
            emit("sipConnected", emptyMap())
            pendingInit?.success(null)
            pendingInit = null
        }

        override fun onInitFailed(errorCode: Int, errorMsg: String?) {
            emit("sipConnectFailed", mapOf(
                "errorCode" to errorCode,
                "errorMsg" to (errorMsg ?: "")
            ))
            pendingInit?.error(errorCode.toString(), errorMsg, null)
            pendingInit = null
        }
    })
}
```

`registerPersistentListeners()` 在 init 前调用一次，内部做：

- `CallSDK.addCallStateListener(callStateListener)`（先 remove 再 add，避免重复注册）
- `CallSDK.setOnServerCallListener { emit("serverCall", callInfoMap(it)) }`
- `CallSDK.setAudioRouteChangeListener { emit("audioRouteChanged", mapOf("route" to route.name.lowercase())) }`

`release()` 之后这些监听会被 SDK 清掉，下次 `init` 必须重新注册。

### 步骤 6：把通话状态转成统一事件

Listener 只负责组 Map，不操作 UI。

```kotlin
private val callStateListener = object : CallStateListener {
    override fun onCallAlerting(callInfo: CallInfo) {
        emit("callAlerting", callInfoMap(callInfo))
    }
    override fun onCallAnswered(callInfo: CallInfo) {
        emit("callAnswered", callInfoMap(callInfo))
    }
    override fun onCallReleased(callInfo: CallInfo, hangupType: Int) {
        emit("callReleased", callInfoMap(callInfo) + mapOf("hangupType" to hangupType))
    }
    override fun onCallFailed(callInfo: CallInfo, errorCode: Int, errorMsg: String) {
        emit("callFailed", callInfoMap(callInfo) + mapOf(
            "errorCode" to errorCode,
            "errorMsg" to errorMsg
        ))
    }
    override fun onDtmfReceived(callInfo: CallInfo, dtmf: String) {
        emit("dtmfReceived", callInfoMap(callInfo) + mapOf("dtmf" to dtmf))
    }
}

private fun callInfoMap(info: CallInfo): Map<String, Any?> = mapOf(
    "callId" to info.callId,
    "phoneNumber" to info.phoneNumber,
    "direction" to info.direction.name.lowercase(), // app / server
    "state" to info.state.name.lowercase(),         // calling / alerting / ...
    "startTime" to info.startTime
)

private fun emit(type: String, payload: Map<String, Any?>) {
    val sink = eventSink ?: return
    sink.success(mapOf("type" to type, "payload" to payload))
}
```

`direction`、`state`、`route` 一律小写字符串，与 iOS 插件输出一致。

### 步骤 7：实现 makeCall / hangup / 控制类方法

`makeCall` 的 `onSuccess` 只表示呼叫已发出，用 MethodChannel 回 `CallInfo`。振铃、接通、挂断继续走 EventChannel，不要塞进这次 `result`。

```kotlin
private fun handleMakeCall(call: MethodCall, result: MethodChannel.Result) {
    val phone = call.argument<String>("phoneNumber").orEmpty()
    val userData = call.argument<Map<String, Any?>>("userData")
    val json = userData?.let { JSONObject(it) }

    val callback = object : MakeCallCallback {
        override fun onSuccess(callInfo: CallInfo) {
            result.success(callInfoMap(callInfo))
        }
        override fun onFailed(errorCode: Int, errorMsg: String) {
            result.error(errorCode.toString(), errorMsg, null)
        }
    }

    if (json != null) CallSDK.makeCall(phone, json, callback)
    else CallSDK.makeCall(phone, callback)
}
```

同步方法直接回：

| Dart method | Android 调用 | result |
|-------------|--------------|--------|
| `hangupCall` | `CallSDK.hangupCall()` | `null` |
| `setMute` | `CallSDK.openMute(enabled)` | `null` |
| `isMuted` | `CallSDK.isMuteOn()` | `Boolean` |
| `setSpeaker` | `CallSDK.openLoudSpeaker(enabled)` | `null` |
| `isSpeakerOn` | `CallSDK.isLoudSpeakerOn()` | `Boolean` |
| `getCurrentAudioRoute` | `CallSDK.getCurrentAudioRoute().name.lowercase()` | `String` |
| `sendDTMF` | `CallSDK.sendDTMF(digit)` | `null` |
| `getCurrentCallInfo` | `CallSDK.getCurrentCallInfo()?.let { callInfoMap(it) }` | `Map?` |
| `logout` | `CallSDK.logout()` | `null` |
| `release` | 先摘监听，再 `CallSDK.release()` | `null` |

`onMethodCall` 用 `when (call.method)` 分发。未识别的 method 调 `result.notImplemented()`。

### 步骤 8：外显号码（全部异步）

这类接口都是 Listener，模式与 `makeCall` 相同：成功 `result.success`，失败 `result.error("-4002", errorMsg, null)`。

| Dart method | Android |
|-------------|---------|
| `getAgentConfig` | `CallSDK.getAgentConfig` |
| `getDisplayNumberList` | `CallSDK.queryDisplayNumberList` |
| `getNumberGroupList` | `CallSDK.queryNumberGroupList(page, pageSize, listener)` |
| `updateDisplayNumber` | `CallSDK.updateAgentSelectNumber(selectNumber, listener)` |
| `updateNumberGroup` | 有 `id` 走 `updateAgentNumberGroupById`，有 `name` 走 `updateAgentNumberGroupByName` |

`AgentConfig`、`DisplayNumber`、`NumberGroup` 在回 Dart 前转成 `Map`，字段名用文档里的 camelCase：`callerStrategy`、`selectNumber`、`numberGroup`、`id`、`number`、`groupName`。

`getLoginInfo` 把 `LoginInfo` 里业务需要的字段（至少 `agentId`）抽成 Map。Demo 里 agentId 来自 `loginInfo?.agent?._id`，以 AAR 实际字段为准，不要把整个 Java Bean 原样丢给 Flutter。

### 步骤 9：错误回传约定

`MethodChannel.Result.error` 的 code 用错误码字符串，和 iOS 一致：

```kotlin
result.error("-302", "未登录无法呼叫", null)
```

Dart 解析 `PlatformException.code` 成 `int`。能拿到 `CallSDK` 错误文案时放 `message`，不要自己编一套码。

### 步骤 10：example 真机验证

```bash
cd jj_callkit/example
flutter run
```

验证顺序：

1. 授予麦克风权限
2. `init` 成功，收到 `sipConnected`
3. `makeCall` 返回 `callId`，随后收到 `callAlerting` → `callAnswered`
4. `setMute` / `setSpeaker` / `sendDTMF`
5. `hangupCall` 后收到 `callReleased`
6. 服务端发起通话时收到 `serverCall`，且 `direction == server`
7. 同账号另端登录，收到 `kicked`
8. `logout`、`release` 后再 `init` 仍能拨号

模拟器没有真实音频路由，扬声器/蓝牙以真机为准。

---

## 4. MethodChannel 协议（Android 必须实现）

请求参数都是 `Map`，空参数传 `null`。

| method | arguments | success 返回 |
|--------|-----------|----------------|
| `init` | `username`, `password?`, `passwordPk?`, `environment`(`production`/`debug`), `logConfig?` | `null` |
| `logout` | — | `null` |
| `release` | — | `null` |
| `makeCall` | `phoneNumber`, `userData?`（Map，序列化后 < 256 字节） | `CallInfo` Map |
| `hangupCall` | — | `null` |
| `setMute` | `enabled: bool` | `null` |
| `isMuted` | — | `bool` |
| `setSpeaker` | `enabled: bool` | `null` |
| `isSpeakerOn` | — | `bool` |
| `getCurrentAudioRoute` | — | `receiver` / `speaker` / `bluetooth` |
| `sendDTMF` | `digit` | `null` |
| `getCurrentCallInfo` | — | `CallInfo` Map 或 `null` |
| `getAgentConfig` | — | 座席配置 Map |
| `getDisplayNumberList` | — | `List<Map>` |
| `getNumberGroupList` | `page`, `pageSize` | `{ list, pageInfo }` |
| `updateDisplayNumber` | `selectNumber` | `null` |
| `updateNumberGroup` | `id?` 或 `name?` | `null` |
| `getLoginInfo` | — | Map 或 `null` |

`logConfig`：`enableLog`, `logLevel`, `consoleLogEnabled`, `fileLoggingEnabled`, `logFilePath`。

### EventChannel 事件

每条：

```json
{ "type": "callAnswered", "payload": { "callId": "...", "phoneNumber": "...", "direction": "app", "state": "answered", "startTime": 0 } }
```

| type | 来源 | payload 额外字段 |
|------|------|------------------|
| `sipConnected` | `onInitSuccess` | — |
| `sipConnectFailed` | `onInitFailed` | `errorCode`, `errorMsg` |
| `kicked` | `setOnKickedListener` | — |
| `callAlerting` | `onCallAlerting` | CallInfo |
| `callAnswered` | `onCallAnswered` | CallInfo |
| `callReleased` | `onCallReleased` | CallInfo + `hangupType` |
| `callFailed` | `onCallFailed` | CallInfo + `errorCode`, `errorMsg` |
| `dtmfReceived` | `onDtmfReceived` | CallInfo + `dtmf` |
| `serverCall` | `OnServerCallListener` | CallInfo，`direction` 为 `server` |
| `audioRouteChanged` | `AudioRouteChangeListener` | `route` |

---

## 5. 实现时要注意的点

1. **Result 只能调用一次。** `pendingInit` 在 success/error 后立刻置空。超时、重复 `init` 不要再碰旧 Result。
2. **不要在 `onDetachedFromEngine` 里 `release()`。** Flutter 热重载会拆 Engine，拆掉不等于登出。登出只走 Dart 的 `logout` / `release`。
3. **监听器成对。** `addCallStateListener` 与 `removeCallStateListener` 使用同一个对象实例。`release()` 之后下次 `init` 要重新 add。
4. **服务端来电只推事件，不在 Native 弹页面。** 打开通话页是 Flutter 的事。
5. **userData 超限。** 超过约 255 字节时 SDK 走 `MakeCallCallback.onFailed(-312)`，原样 `result.error`。
6. **未初始化调用。** SDK 1.3.5 起未初始化调用会安全返回。插件仍应在未 init 时对 `makeCall` 回 `-2`，避免 Dart 以为成功。
7. **前台保活由 SDK/Demo 的前台 Service 负责。** 插件第一期不重写通知栏；若接通后切后台被系统杀掉，再按 Demo 的 `CallService` 补到插件里。

---

## 6. 业务方使用方式

业务工程只加插件依赖，不拷贝 AAR。

`pubspec.yaml`：

```yaml
dependencies:
  jj_callkit:
    path: ../jj_callkit
  permission_handler: ^11.0.0
```

宿主 `android/app/src/main/AndroidManifest.xml` 一般不用再写权限（插件已合并）。Android 6+ 仍要在 Dart 里申请麦克风：

```dart
final status = await Permission.microphone.request();
if (!status.isGranted) return;
```

最小通话页：

```dart
await JJCallKit.init(CallConfig(
  username: '6000@useasy',
  password: 'your_password',
  environment: CallEnvironment.production,
));

final sub = JJCallKit.events.listen((event) {
  switch (event) {
    case CallAlertingEvent(:final call):
      // 振铃
    case CallAnsweredEvent(:final call):
      // 开始计时
    case CallReleasedEvent(:final call):
      // 关闭通话页
    case CallFailedEvent(:final errorCode, :final errorMsg):
      // 提示 errorMsg
    case ServerCallEvent(:final call):
      // 打开通话页，不要再 makeCall
    case KickedEvent():
      // 回到登录页
    default:
      break;
  }
});

final call = await JJCallKit.makeCall('13800138000', userData: {
  'orderId': '12345',
});

await JJCallKit.setMute(true);
await JJCallKit.sendDTMF('1');
await JJCallKit.hangupCall();

await sub.cancel();
await JJCallKit.logout();
```

服务端来电：收到 `ServerCallEvent` 后只展示 UI。SDK 已经自动接听 SIP，**不要再调 `makeCall`**。

页面销毁时只 `cancel` 事件订阅，不要 `JJCallKit.release()`。`release()` 放在用户退出账号或进程级清理。

完整错误码见 `CallSDK_Android_API.md` 第 6 节。Dart 捕获：

```dart
try {
  await JJCallKit.makeCall(phone);
} on JJCallException catch (e) {
  // e.code == -310 黑名单，-311 风控，-301 无麦克风权限
}
```
