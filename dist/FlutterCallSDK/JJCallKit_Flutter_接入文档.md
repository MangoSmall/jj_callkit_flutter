# JJCallKit Flutter 接入文档

> 版本 **0.1.3** · Android callsdk **1.3.9** · iOS JJCallKit **1.1.1**  
> Dart 入口：`package:jj_callkit/jj_callkit.dart` → `JJCallKit`

---

## 1. 概述

JJCallKit 是 Flutter VoIP 插件，Android / iOS 共用同一套 Dart API。业务工程只依赖本插件即可，**不要**再单独集成 `callsdk-*.aar` 或 `JJCallKit.xcframework`，也不要自己再建 CallKit / MethodChannel。

能力概览：

- SIP 音频通话
- 主动外呼、服务端发起通话
- 外显号码 / 号码组
- 静音、扬声器、DTMF
- 振铃 / 接通 / 挂断 / 失败、被踢、SIP 断线等事件

交付包：

```
FlutterCallSDK/
├── JJCallKit_Flutter_接入文档.md
├── jj_callkit/              # 插件（含两端原生 SDK）
└── jj_callkit-demo/         # 示例工程
```

建议先跑通 Demo，再按本文接入业务工程。

---

## 2. 接入前准备

| 项 | 说明 |
|----|------|
| 通话账号 | 由业务侧发放的 SIP / 座席账号 |
| 密码 | 明文 `password`，或 RSA 加密后的 `passwordPk`（二选一） |
| 环境 | 测试用 `CallEnvironment.debug`，正式用 `CallEnvironment.production` |
| 真机 | Android 需 arm64；iOS 锁屏 / CallKit 绿条需真机 |
| 麦克风 | 登录或拨号前申请运行时权限 |

账号与环境以你们业务后台配置为准，本文不涉及开户流程。

---

## 3. 环境要求

| 项 | 要求 |
|----|------|
| Flutter | 3.38+（Dart ≥ 3.10.3） |
| Android | minSdk 23；**arm64-v8a 真机**（当前 so 不含 x86） |
| iOS | 12.4+；锁屏 / CallKit 需真机 |
| 权限 | 麦克风；Android 12+ 使用蓝牙耳机时还需 `BLUETOOTH_CONNECT` |

---

## 4. 依赖引入

把交付包中的 `jj_callkit/` 放到业务工程旁，在 `pubspec.yaml` 中：

```yaml
dependencies:
  jj_callkit:
    path: ../jj_callkit   # 按实际路径调整
```

```bash
flutter pub get
```

不要把 `callsdk-*.aar` 再拷进宿主 `android/libs`，也不要在 iOS 工程里再拖一份 `JJCallKit.xcframework`。

---

## 5. 平台配置

### 5.1 Android

插件已声明：`INTERNET`、`ACCESS_NETWORK_STATE`、`RECORD_AUDIO`、`MODIFY_AUDIO_SETTINGS`、`BLUETOOTH`、`BLUETOOTH_ADMIN`、`BLUETOOTH_CONNECT`。业务 Manifest 一般不用再抄。

运行时仍需申请 `RECORD_AUDIO`（Android 12+ 用蓝牙时再申请 `BLUETOOTH_CONNECT`）。无麦克风时 `makeCall` 抛 `JJCallException`，`code == -301`。

混淆规则在插件 `consumer-rules.pro`，会随插件合并；不要删掉对 `com.useasy.callsdk` 的 keep。

当前 so 仅 **arm64-v8a**，x86 模拟器会找不到 `libpjsua2.so`。

通话进后台若被系统杀掉，需宿主自行做前台服务 / 保活；本插件不内置通知栏保活。

### 5.2 iOS

`ios/Runner/Info.plist`：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>用于语音通话</string>
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

Xcode → Signing & Capabilities → Background Modes → 勾选 **Audio**。未配置时锁屏可能有通话条但无声音。

不要在业务 App 里再 `import CallKit` 并创建 `CXProvider`。Framework 已接入系统通话，第二套会抢会话。

若使用 `permission_handler`，在 Podfile `post_install` 打开麦克风宏（Demo 已有示例）：

```ruby
config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
  '$(inherited)',
  'PERMISSION_MICROPHONE=1',
]
```

插件 pod 为 static，内含动态 Framework。真机启动若报找不到 `JJCallKit`，检查 `[CP] Embed Pods Frameworks` 是否已 embed（可对照 Demo 执行 `pod install`）。

---

## 6. 接入步骤

推荐顺序与 Demo 一致：

1. App 启动后尽早订阅 `JJCallKit.events`（全局，不要挂在通话页）
2. 申请麦克风权限
3. `JJCallKit.init` 登录，等 Future 完成后再拨号
4. 外呼走 `makeCall`；服务端来电只处理 `ServerCallEvent`
5. 通话中用 mute / speaker / DTMF / hangup
6. 账号退出时 `logout`；彻底不用通话能力时再 `release`

### 6.1 生命周期

```
订阅 events
    ↓
init（登录 + SIP 注册）──失败──→ JJCallException / SipConnectFailedEvent
    ↓ 成功
可外呼 / 可收服务端来电
    ↓
通话中（events 推状态）
    ↓
logout（登出，插件仍在）或 release（销毁，下次必须重新 init）
```

注意：

- `init` 的 Future 在 SIP 注册成功后才结束，结束前不要 `makeCall`
- 页面 `dispose` 里只 `cancel` 事件订阅，**不要**调 `release`
- `SipDisconnectedEvent` / `KickedEvent` 建议关通话页并回到登录

### 6.2 监听事件

```dart
import 'dart:async';

import 'package:jj_callkit/jj_callkit.dart';

late final StreamSubscription<CallEvent> _sub;

void startListening() {
  _sub = JJCallKit.events.listen((event) {
    switch (event) {
      case SipConnectedEvent():
        // SIP 就绪；init 的 Future 也会在此时完成
        break;
      case SipConnectFailedEvent(:final errorCode, :final errorMsg):
        break;
      case SipDisconnectedEvent():
        // 曾注册成功后掉线，回登录页
        break;
      case KickedEvent():
        // 其他端登录，回登录页
        break;
      case ServerCallEvent(:final call):
        // 只打开通话页，不要 makeCall
        break;
      case CallAlertingEvent(:final call):
        break;
      case CallAnsweredEvent(:final call):
        break;
      case CallReleasedEvent(:final hangupType):
        // 0 主叫挂断，1 被叫挂断
        break;
      case CallFailedEvent(:final errorCode, :final errorMsg):
        break;
      case AudioRouteChangedEvent(:final route):
        break;
      default:
        break;
    }
  });
}
```

可多处监听；页面销毁时 `cancel`。服务端来电、被踢、SIP 断线建议在 App 根部统一处理，避免漏接。

### 6.3 初始化并登录

`CallConfig`：

| 字段 | 说明 |
|------|------|
| `username` | 账号，必填 |
| `password` | 明文密码；与 `passwordPk` 二选一 |
| `passwordPk` | RSA 加密密码；都传时原生优先用它 |
| `environment` | `production` / `debug` |
| `logConfig` | 可选，见下表 |

`LogConfig`：

| 字段 | 说明 |
|------|------|
| `enableLog` | 是否开日志 |
| `logLevel` | `0` 错误 / `1` 一般 / `2` 全量 |
| `consoleLogEnabled` | 控制台输出 |
| `fileLoggingEnabled` | 写文件 |
| `logFilePath` | 日志路径；不传则走原生默认 |

```dart
try {
  await JJCallKit.init(CallConfig(
    username: account,
    password: password,
    environment: CallEnvironment.production,
    logConfig: const LogConfig(
      enableLog: true,
      logLevel: 1,
      consoleLogEnabled: true,
    ),
  ));
} on JJCallException catch (e) {
  // 同时会收到 SipConnectFailedEvent
  final tip = e.message.isNotEmpty
      ? e.message
      : JJCallKit.errorDescription(e.code);
}
```

登录成功后可用 `JJCallKit.getLoginInfo()` 取 `agentId` / `agentNumber` / `mobile` / `accountId`（不含 token）。拨号前可用 `canMakeCall()` 判断是否可外呼。

### 6.4 主动外呼

拨号前先申请麦克风权限（可用 `permission_handler`）。

```dart
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
  // 常见：-301 无麦克风、-310 黑名单、-311 风控
}
```

### 6.5 通话控制

```dart
await JJCallKit.setMute(true);
await JJCallKit.setSpeaker(true);
await JJCallKit.sendDTMF('1');   // 0-9 * #
await JJCallKit.hangupCall();

final muted = await JJCallKit.isMuted();
final speaker = await JJCallKit.isSpeakerOn();
final AudioRoute route = await JJCallKit.getCurrentAudioRoute();
// AudioRoute.receiver / .speaker / .bluetooth
```

Android 可区分听筒 / 扬声器 / 蓝牙。iOS 目前主要按扬声器开关近似，不保证能报出 `AudioRoute.bluetooth`。

### 6.6 登出与销毁

```dart
await JJCallKit.logout();   // 登出，插件还在
await JJCallKit.release();  // 销毁原生 SDK；下次必须重新 init
```

---

## 7. 通话流程

### 7.1 主动外呼

```
业务拨号
  → makeCall（成功仅表示已发出）
  → CallCallingEvent（可忽略）
  → CallAlertingEvent（对方振铃）
  → CallAnsweredEvent（接通）
  → CallReleasedEvent（挂断）
```

`makeCall` 本身失败会抛 `JJCallException`，一般不会再跟一条 `CallFailedEvent`。  
通话过程中失败走 `CallFailedEvent`。

### 7.2 服务端发起通话

```
服务端调度
  → ServerCallEvent（SDK 已自动接听 SIP）
  → 业务只负责打开通话页（不要再 makeCall）
  → 后续仍可能收到 alerting / answered / released 等事件
```

`ServerCallEvent` 里 `call.direction == CallDirection.server`。同一 `callId` 只推一次；打开通话页时注意防重入（Demo 用 `_callOpen` 标志）。

---

## 8. 外显号码

登录成功后可查询 / 切换外显：

```dart
final agent = await JJCallKit.getAgentConfig();
final numbers = await JJCallKit.getDisplayNumberList();
final groups = await JJCallKit.getNumberGroupList(page: 1, pageSize: 20);
// NumberGroupListResult：列表 groups.list，分页 groups.pageInfo
// iOS 忽略分页，一次返回全量

await JJCallKit.updateDisplayNumber('021xxxxxxxx');
// Android 可传 id 或 name；iOS 只支持号码组 id（只传 name 会 -4002）
await JJCallKit.updateNumberGroup(id: groupId);
```

`AgentConfig.callerStrategy` 可判断当前策略；是否走号码组可用 `agent.usesNumberGroup`。

---

## 9. API 一览

### 生命周期

| 方法 | 说明 |
|------|------|
| `init(CallConfig)` | 初始化并登录；SIP 注册成功后 Future 结束 |
| `logout()` | 登出 |
| `release()` | 销毁原生 SDK |
| `canMakeCall()` | 当前能否外呼 |
| `getLoginInfo()` | 登录信息（不含 token） |
| `errorDescription(code)` | 错误码文案 |

### 通话

| 方法 | 说明 |
|------|------|
| `makeCall(phone, {userData})` | 外呼；接通看事件 |
| `hangupCall()` | 挂断 |
| `sendDTMF(digit)` | `0-9`、`*`、`#` |
| `getCurrentCallInfo()` | 无通话时为 `null` |

### 音频

| 方法 | 说明 |
|------|------|
| `setMute` / `isMuted` | 静音 |
| `setSpeaker` / `isSpeakerOn` | 扬声器 |
| `getCurrentAudioRoute()` | 返回 `AudioRoute` |

### 外显号码

| 方法 | 说明 |
|------|------|
| `getAgentConfig()` | 策略与当前选中号码 / 号码组 |
| `getDisplayNumberList()` | 外显号码列表 |
| `getNumberGroupList(page, pageSize)` | `NumberGroupListResult` |
| `updateDisplayNumber(selectNumber)` | 指定外显号码 |
| `updateNumberGroup({id, name})` | 指定号码组 |

---

## 10. 事件说明

| 事件 | 说明 |
|------|------|
| `SipConnectedEvent` | SIP 注册成功（同时 `init` 完成） |
| `SipConnectFailedEvent` | 登录或 SIP 注册失败 |
| `SipDisconnectedEvent` | 曾注册成功后 SIP 掉线 |
| `KickedEvent` | 账号在其他端登录 |
| `CallCallingEvent` | 正在呼叫（可忽略） |
| `CallAlertingEvent` | 对方振铃 |
| `CallAnsweredEvent` | 已接通 |
| `CallReleasedEvent` | 正常挂断；`hangupType` 0 主叫、1 被叫 |
| `CallFailedEvent` | 通话中失败，带 `errorCode` |
| `DtmfReceivedEvent` | 收到 DTMF（目前主要 Android） |
| `ServerCallEvent` | 服务端来电，同一 callId 只推一次 |
| `AudioRouteChangedEvent` | 音频路由变化 |

---

## 11. 错误码

优先展示原生带回的 `message`，否则用 `JJCallKit.errorDescription(code)`。

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
| -4002 | 外显号码配置失败（iOS 只传号码组名称时也是这个码） |
| -9999 | 未知错误 |

分段：`-1~-99` 初始化，`-100~-199` 参数，`-200~-299` 登录 / SIP，`-300~-399` 通话，`-400~-499` 网络，`-2000~-2099` HTTP，`-2100~-2199` WebSocket，`-4000~-4099` 外显号码。

---

## 12. 上线前检查清单

- [ ] `pubspec` 只依赖 `jj_callkit`，宿主未再引入 AAR / xcframework
- [ ] Android 在 arm64 真机验证；未依赖 x86 模拟器验收
- [ ] Android 运行时已申请麦克风（及需要时的蓝牙权限）
- [ ] iOS 已配置 `NSMicrophoneUsageDescription` 与 Background Modes → Audio
- [ ] 未在业务侧自行创建 `CXProvider`
- [ ] `JJCallKit.events` 在 App 启动后全局订阅，能处理服务端来电 / 被踢 / SIP 断线
- [ ] `init` 成功后再拨号；`release` 未放在页面 `dispose`
- [ ] 服务端来电只打开页面，未再次 `makeCall`
- [ ] 正式环境使用 `CallEnvironment.production`；上线前关闭或降低冗余日志
- [ ] 后台保活策略已按业务需要自行接入（插件不内置）

---

## 13. 运行 Demo

```bash
cd FlutterCallSDK/jj_callkit-demo
flutter pub get
flutter run   # 建议 arm64 真机
```

Demo 覆盖：登录、外呼、挂断、静音、扬声器、DTMF、被踢、SIP 断开、外显号码设置。事件监听写在 App 根部，可直接对照业务接入。

---

## 14. 常见问题

**Android 模拟器闪退 / 找不到 so**  
当前只有 arm64-v8a，请用 arm64 真机。

**makeCall 抛 `JJCallException`，code 为 -301**  
没给麦克风权限，拨号前动态申请。

**iOS 锁屏有通话条但没声音**  
检查 Info.plist 的 `UIBackgroundModes` → `audio`，以及 Xcode Background Modes。

**服务端来电页面打开多次**  
只在 `ServerCallEvent` 打开页面，不要再 `makeCall`。业务侧自行做防重入；iOS 对同一 callId 会去重。

**业务里还集成了 AAR / xcframework**  
去掉。两套原生栈会冲突，体积也翻倍。

**在页面 dispose 里调了 release()**  
下次进通话页还得重新 init。`release` 只在账号退出或整 App 不再用通话时调用。

**init 一直不返回**  
Future 会等到 SIP 注册成功。失败会抛异常并收到 `SipConnectFailedEvent`；请检查账号、密码、网络与 `environment`。

---

## 15. 版本

| 版本 | 说明 |
|------|------|
| **0.1.3** | 统一 Dart API；内置 Android callsdk 1.3.9、iOS JJCallKit 1.1.1；登录 / 外呼 / 服务端来电 / 媒体控制 / 外显号码 / 事件流 |
