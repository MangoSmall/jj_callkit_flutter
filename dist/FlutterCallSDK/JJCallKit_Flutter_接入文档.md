# JJCallKit Flutter 接入文档

> 当前交付版本：**0.1.3**  
> 内置原生 SDK：Android **callsdk 1.3.9**、iOS **JJCallKit 1.1.1**  
> Dart 入口：`package:jj_callkit/jj_callkit.dart` → `JJCallKit`

---

## 1. 概述

JJCallKit 是一套 Flutter VoIP 插件，用**同一套 Dart API** 同时对接 Android CallSDK 与 iOS JJCallKit。业务工程只需依赖本插件，**不要**再单独集成 `callsdk-*.aar` 或 `JJCallKit.xcframework`，也不要自己再建一套 CallKit / MethodChannel。

### 核心特性

- 支持音频通话（SIP）
- 两种通话场景：**主动外呼**、**服务端发起通话**
- 外显号码 / 号码组配置
- 通话状态事件（振铃 / 接听 / 挂断 / 失败）
- 通话控制（静音、扬声器、DTMF）
- 被踢下线通知

### 通话场景说明

| 场景 | 说明 | 触发方式 |
|------|------|----------|
| **主动外呼** | 调用 `JJCallKit.makeCall()` | 业务主动调用 |
| **服务端发起通话** | 服务端调度，SDK 自动接听 SIP | 收到 `ServerCallEvent` 后打开通话页即可，**不要再 makeCall** |

### 架构概览

```
┌──────────────────────────────────────────────────────────┐
│                     JJCallKit（Dart）                     │
│                                                          │
│  init / logout / release     → 生命周期                   │
│  makeCall / hangup / DTMF    → 通话控制                   │
│  mute / speaker / audioRoute → 音频                      │
│  外显号码 / 号码组            → 业务配置                   │
│  JJCallKit.events            → SIP / 通话 / 被踢 / 路由   │
└───────────────────────┬──────────────────────────────────┘
                        │ MethodChannel / EventChannel
          ┌─────────────┴─────────────┐
          ▼                           ▼
   Android callsdk 1.3.9        iOS JJCallKit 1.1.1
```

### 交付包目录

```
FlutterCallSDK/
├── JJCallKit_Flutter_接入文档.md   ← 本文档
├── jj_callkit/                     ← Flutter 插件（含两端原生 SDK）
└── jj_callkit-demo/                ← 示例工程（可直接运行）
```

---

## 2. 环境要求

| 项 | 要求 |
|----|------|
| Flutter | 3.16+（Demo 使用 Dart `^3.10.3`） |
| Android minSdk | 23；建议 **arm64-v8a 真机**（当前 so 不含 x86） |
| iOS | 12.4+；锁屏 / CallKit 绿条需**真机** |
| 权限 | 麦克风（两端）；Android 12+ 蓝牙耳机需 `BLUETOOTH_CONNECT` |

---

## 3. 依赖引入

将交付包中的 `jj_callkit/` 放到业务工程旁（或 monorepo 内），在业务 `pubspec.yaml` 中：

```yaml
dependencies:
  jj_callkit:
    path: ../jj_callkit   # 按实际相对路径调整
```

然后：

```bash
flutter pub get
```

> **注意**：不要把 `callsdk-*.aar` 再拷进宿主 `android/libs`，也不要在 iOS 工程里再拖一份 `JJCallKit.xcframework`。原生包已内置在插件里。

---

## 4. 平台配置

### 4.1 Android

插件已合并下列权限（业务 Manifest 一般无需再抄）：

- `INTERNET` / `ACCESS_NETWORK_STATE`
- `RECORD_AUDIO` / `MODIFY_AUDIO_SETTINGS`
- `BLUETOOTH` / `BLUETOOTH_ADMIN` / `BLUETOOTH_CONNECT`

**运行时仍需申请** `RECORD_AUDIO`（以及 Android 12+ 使用蓝牙时的 `BLUETOOTH_CONNECT`）。无麦克风时 `makeCall` 返回 `-301`。

混淆规则已在插件 `consumer-rules.pro`，会随插件合并，请勿删除对 `com.useasy.callsdk` 的 keep。

当前内置 so 仅 **arm64-v8a**。x86 模拟器会加载不到 `libpjsua2.so`，验收请用 arm64 真机。

> 通话进程若在后台被系统杀掉，需宿主自行做前台服务 / 保活。本版本插件不内置通知栏保活。

### 4.2 iOS

宿主 `ios/Runner/Info.plist` 必须配置：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>用于语音通话</string>
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

Xcode → Signing & Capabilities → Background Modes → 勾选 **Audio**。未配置时，锁屏可能有通话条但无声音。

**不要**在业务 App 里再 `import CallKit` 后创建 `CXProvider`。Framework 已接入系统通话，第二套会抢通话会话。

若使用 `permission_handler`，在 Podfile `post_install` 打开麦克风宏（Demo 已有示例）：

```ruby
config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
  '$(inherited)',
  'PERMISSION_MICROPHONE=1',
]
```

插件 pod 为 static，内含动态 Framework。若真机启动报找不到 `JJCallKit`，检查 `[CP] Embed Pods Frameworks` 是否已 embed 该 Framework（可先在 Demo 上 `pod install` 对照）。

---

## 5. 快速集成

### 5.1 监听事件（建议在 App 启动后尽早订阅）

```dart
import 'package:jj_callkit/jj_callkit.dart';

late final StreamSubscription<CallEvent> _sub;

void startListening() {
  _sub = JJCallKit.events.listen((event) {
    switch (event) {
      case SipConnectedEvent():
        // 登录 / SIP 就绪（init 的 Future 也会在此时完成）
        break;
      case SipConnectFailedEvent(:final errorCode, :final errorMsg):
        // 登录或 SIP 注册失败
        break;
      case SipDisconnectedEvent():
        // 曾注册成功后 SIP 掉线，回到登录页并提示重新登录
        break;
      case KickedEvent():
        // 账号在其他端登录，回到登录页
        break;
      case ServerCallEvent(:final call):
        // 服务端来电：只打开通话页，不要 makeCall
        break;
      case CallAlertingEvent(:final call):
        // 对方振铃
        break;
      case CallAnsweredEvent(:final call):
        // 已接通
        break;
      case CallReleasedEvent(:final hangupType):
        // 正常挂断：0 主叫挂断，1 被叫挂断
        break;
      case CallFailedEvent(:final errorCode, :final errorMsg):
        // 通话中失败
        break;
      case AudioRouteChangedEvent(:final route):
        // 听筒 / 扬声器 / 蓝牙
        break;
      default:
        break;
    }
  });
}

// 页面销毁时 cancel 订阅；不要在页面 dispose 里调用 release()
```

### 5.2 初始化并登录

```dart
await JJCallKit.init(CallConfig(
  username: account,
  password: password,           // 与 passwordPk 二选一
  // passwordPk: passwordPk,    // 与 password 二选一；都传时原生优先用 passwordPk
  environment: CallEnvironment.production, // 或 CallEnvironment.debug
  logConfig: const LogConfig(
    enableLog: true,
    logLevel: 1,                // 0 错误 / 1 一般 / 2 全量
    consoleLogEnabled: true,
  ),
));
// Future 在 SIP 注册成功后才结束，结束前不要拨号
```

### 5.3 主动外呼

```dart
// 拨号前申请麦克风权限（可用 permission_handler）
try {
  final info = await JJCallKit.makeCall(
    phoneNumber,
    userData: {'orderId': 'xxx'}, // 可选；UTF-8 编码后须 < 255 字节，否则 -312
  );
  // 返回只表示呼叫已发出；振铃 / 接通 / 挂断看 events
} on JJCallException catch (e) {
  final tip = e.message.isNotEmpty
      ? e.message
      : JJCallKit.errorDescription(e.code);
  // 例如 -301 无麦克风、-310 黑名单、-311 风控
}
```

### 5.4 通话控制

```dart
await JJCallKit.setMute(true);
await JJCallKit.setSpeaker(true);
await JJCallKit.sendDTMF('1');   // 0-9 * #
await JJCallKit.hangupCall();

final muted = await JJCallKit.isMuted();
final speaker = await JJCallKit.isSpeakerOn();
final route = await JJCallKit.getCurrentAudioRoute(); // receiver / speaker / bluetooth
```

> Android（callsdk 1.3.9）可准确返回听筒 / 扬声器 / 蓝牙。iOS 目前主要按扬声器开关近似，不保证 `bluetooth`。

### 5.5 外显号码

```dart
final agent = await JJCallKit.getAgentConfig();
final numbers = await JJCallKit.getDisplayNumberList();
final groups = await JJCallKit.getNumberGroupList(page: 1, pageSize: 20);
// iOS 忽略分页，一次返回全量

await JJCallKit.updateDisplayNumber('021xxxxxxxx');
// Android 可传 id 或 name；iOS 只支持号码组 id（只传 name 会 -4002）
await JJCallKit.updateNumberGroup(id: groupId);
```

### 5.6 登出与销毁

```dart
await JJCallKit.logout();   // 登出，插件本身仍在
await JJCallKit.release();  // 销毁原生 SDK；下次必须重新 init
// 不要把 release() 放在通话页 dispose 里
```

---

## 6. API 一览

### 6.1 生命周期

| 方法 | 说明 |
|------|------|
| `init(CallConfig)` | 初始化并登录；SIP 注册成功后 Future 结束 |
| `logout()` | 登出 |
| `release()` | 销毁原生 SDK |
| `canMakeCall()` | 当前能否外呼 |
| `getLoginInfo()` | `agentId` / `agentNumber` / `mobile` / `accountId`（不含 token） |
| `errorDescription(code)` | 错误码文案 |

### 6.2 通话

| 方法 | 说明 |
|------|------|
| `makeCall(phone, {userData})` | 外呼；接通看事件 |
| `hangupCall()` | 挂断当前通话 |
| `sendDTMF(digit)` | `0-9`、`*`、`#` |
| `getCurrentCallInfo()` | 无通话时为 `null` |

### 6.3 音频

| 方法 | 说明 |
|------|------|
| `setMute` / `isMuted` | 静音 |
| `setSpeaker` / `isSpeakerOn` | 扬声器 |
| `getCurrentAudioRoute()` | `receiver` / `speaker` / `bluetooth` |

### 6.4 外显号码

| 方法 | 说明 |
|------|------|
| `getAgentConfig()` | 策略与当前选中号码 / 号码组 |
| `getDisplayNumberList()` | 外显号码列表 |
| `getNumberGroupList(page, pageSize)` | 号码组 |
| `updateDisplayNumber(selectNumber)` | 指定外显号码 |
| `updateNumberGroup({id, name})` | 指定号码组 |

---

## 7. 事件说明

```dart
JJCallKit.events.listen((event) { ... });
```

可多处监听；页面销毁时 `cancel` 订阅。

| 事件 | 何时 |
|------|------|
| `SipConnectedEvent` | SIP 注册成功（同时 `init` 完成） |
| `SipConnectFailedEvent` | 登录或 SIP 注册失败 |
| `SipDisconnectedEvent` | SIP 断开（曾注册成功后掉线；两端均有） |
| `KickedEvent` | 账号在其他端登录 |
| `CallCallingEvent` | 正在呼叫（SIP INVITE 已发出；可忽略） |
| `CallAlertingEvent` | 对方振铃 |
| `CallAnsweredEvent` | 已接通 |
| `CallReleasedEvent` | 正常挂断；`hangupType` 0 主叫、1 被叫 |
| `CallFailedEvent` | 通话中失败，带 `errorCode` |
| `DtmfReceivedEvent` | 收到 DTMF（当前主要来自 Android） |
| `ServerCallEvent` | 服务端来电，每个 callId 只推一次 |
| `AudioRouteChangedEvent` | 音频路由变化 |

**主动外呼成功路径**：`calling` → `alerting` → `answered` → `released`  
**主动外呼失败**：`makeCall` 抛 `JJCallException`，一般不会再发一条 `CallFailedEvent`  
**服务端来电**：先 `ServerCallEvent`（`direction == server`），后续振铃 / 接通仍走对应事件

---

## 8. 错误码

`JJCallException.code` 与 Android / iOS 原生一致。优先展示原生带回的 `message`，否则用 `JJCallKit.errorDescription(code)`。

| 码 | 含义 |
|----|------|
| -1 | SDK 初始化失败 |
| -2 | SDK 未初始化 |
| -105 / -106 | 账号或密码为空 |
| -201 / -202 | 登录失败 |
| -207 | SIP 注册失败 |
| -301 | 没有麦克风权限 |
| -302 | 未登录不能呼叫 |
| -303 | 号码为空 |
| -310 | 黑名单 |
| -311 | 风控，呼叫次数达到上限 |
| -312 | userData 超过 255 字节 |
| -4002 | 外显号码配置失败（iOS 只传号码组名称时也会是此码） |
| -9999 | 未知错误 |

分段约定：

- `-1 ~ -99` 初始化
- `-100 ~ -199` 参数
- `-200 ~ -299` 登录 / SIP
- `-300 ~ -399` 通话
- `-400 ~ -499` 网络
- `-2000 ~ -2099` HTTP
- `-2100 ~ -2199` WebSocket
- `-4000 ~ -4099` 外显号码

---

## 9. 运行 Demo

```bash
cd FlutterCallSDK/jj_callkit-demo
flutter pub get
flutter run   # 建议 arm64 真机
```

Demo 覆盖：登录、外呼、挂断、静音、扬声器、DTMF、被踢、SIP 断开、外显号码设置页。

---

## 10. 常见问题

1. **Android 模拟器闪退 / 找不到 so**  
   当前包仅 arm64-v8a，请用 arm64 真机验收。

2. **makeCall 返回 -301**  
   未授予麦克风权限，拨号前动态申请。

3. **iOS 锁屏有通话条但无声音**  
   检查 Info.plist 的 `UIBackgroundModes` → `audio`，以及 Xcode Background Modes。

4. **服务端来电重复打开页面**  
   只在 `ServerCallEvent` 打开页面；SDK 已自动接听，不要再 `makeCall`。iOS 侧同 callId 会去重。

5. **业务里还集成了 AAR / xcframework**  
   请移除。双份原生栈会导致冲突或体积翻倍。

6. **页面 dispose 里调用了 release()**  
   会导致下次进通话页必须重新 init。`release` 仅在账号退出 / App 彻底不用通话能力时调用。

---

## 11. 版本更新日志

| 版本 | 说明 |
|------|------|
| **0.1.3** | Demo 补齐 `SipDisconnectedEvent`；Android detach 清理全局监听；去掉过时 1.3.8 AAR |
| **0.1.2** | Android 内置 callsdk 升级至 **1.3.9**（补齐 `CallCallingEvent` / `SipDisconnectedEvent`，对齐 iOS） |
| **0.1.1** | Android 内置 callsdk 升级至 **1.3.8**（限 PCMA/PCMU + TCP INVITE 兜底，修复部分 Wi‑Fi/NAT 下外呼失败） |
| **0.1.0** | 首版：统一 Dart API；内置 callsdk 1.3.7 + JJCallKit 1.1.1；登录 / 外呼 / 媒体控制 / 外显号码 / 事件流 |

原生 Android 详细变更见 Android 交付包《CallSDK_Android_接入文档》版本日志（1.3.9 / 1.3.8 / 1.3.7 等）。

---

## 12. 与原生 SDK 的关系

| 能力 | Flutter `JJCallKit` | Android CallSDK | iOS JJCallKit |
|------|---------------------|-----------------|---------------|
| 业务依赖方式 | 只依赖本插件 | `callsdk-*.aar` | `JJCallKit.xcframework` |
| 登录 / 外呼 / 挂断 | ✅ | ✅ | ✅ |
| 静音 / 扬声器 / DTMF | ✅ | ✅ | ✅ |
| 外显号码 | ✅ | ✅ | ✅（号码组建议传 id） |
| 服务端来电 | `ServerCallEvent` | `OnServerCallListener` | 对应原生回调 |
| 被踢 | `KickedEvent` | `setOnKickedListener` | 对应原生回调 |
| 音频路由枚举 | ✅（iOS 近似） | ✅ 1.3.5+ | 主要听筒/扬声器 |

业务侧以本文档与 Demo 为准；原生独立交付包仍可用于纯 Android / 纯 iOS 工程。
