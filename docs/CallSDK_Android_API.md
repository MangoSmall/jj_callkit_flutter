# CallSDK Android API 参考

> 来源：`CallSDK_Android_HarmonyOS_20260802/Android/接入文档/CallSDK_Android_接入文档.md`  
> SDK 版本：**1.3.8**（`callsdk-1.3.8.aar`）  
> 包名：`com.useasy.callsdk`  
> 用途：供 Flutter 插件 Android 端 MethodChannel / EventChannel 对接参考

---

## 1. 概述

CallSDK 是一款 Android 通话 SDK，基于 SIP 协议提供音频通话能力。

### 1.1 通话场景

| 场景 | 说明 | 触发方式 |
|------|------|----------|
| **主动外呼** | 开发者调用 `makeCall()` 发起通话 | 开发者主动调用 |
| **服务端发起通话** | 服务端调度通话任务，SDK 自动接听 SIP | SDK 自动处理，通过 `OnServerCallListener` 通知开发者 |

### 1.2 架构与回调

```
┌──────────────────────────────────────────────────────────┐
│                       CallSDK                             │
│                                                          │
│  ① InitListener              → 初始化结果                 │
│  ② OnServerCallListener      → 服务端通话通知             │
│  ③ CallStateListener         → 通话状态变化               │
│  ④ MakeCallCallback          → 外呼发起结果               │
│  ⑤ setOnKickedListener       → 被踢下线通知               │
│  ⑥ AudioRouteChangeListener  → 音频路由变化（v1.3.5+）    │
└──────────────────────────────────────────────────────────┘
```

**重要约定：所有回调均在主线程触发**，可直接更新 UI；Flutter 侧可通过 EventChannel 转发至 Dart 层。

---

## 2. 配置模型

### 2.1 SDKConfig

| 字段 | 类型 | 说明 |
|------|------|------|
| `username` | `String` | 座席账号，格式 `user@account` |
| `password` | `String?` | 明文密码（与 `passwordPk` 二选一） |
| `passwordPk` | `String?` | RSA 加密密码（与 `password` 二选一） |
| `baseUrl` | `Environment` | 服务器环境，如 `Environment.DEBUG` / `Environment.PRODUCTION` |
| `logConfig` | `LogConfig` | 日志配置 |

### 2.2 LogConfig

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `enableLog` | `Boolean` | `false` | 日志总开关 |
| `logLevel` | `Int` | — | 日志级别（如 `Log.INFO`、`Log.DEBUG`） |
| `consoleLogEnabled` | `Boolean` | `false` | 控制台输出 |
| `fileLoggingEnabled` | `Boolean` | `false` | 写文件 |
| `logFilePath` | `String?` | `null` | 日志目录；`null` 时使用 `filesDir/logs` |

### 2.3 Environment

预置环境常量，用于 `SDKConfig.baseUrl`：

| 常量 | 说明 |
|------|------|
| `Environment.DEBUG` | 调试环境 |
| `Environment.PRODUCTION` | 生产环境 |

---

## 3. API 参考

### 3.1 初始化 & 生命周期

| 方法 | 签名 | 说明 |
|------|------|------|
| `init` | `CallSDK.init(context, config, initListener)` | 初始化 SDK（含登录） |
| `logout` | `CallSDK.logout()` | 注销登录，释放通话和连接资源 |
| `release` | `CallSDK.release()` | 销毁 SDK 实例，释放所有资源（含监听器），调用后需重新 `init()` |
| `getLoginInfo` | `CallSDK.getLoginInfo(): LoginInfo?` | 获取登录信息 |
| `getConfig` | `CallSDK.getConfig(): SDKConfig` | 获取当前 SDK 配置 |
| `disconnectFromCCP` | `CallSDK.disconnectFromCCP()` | 仅断开 SIP 栈（高级接口，一般不用） |

### 3.2 监听器

| 方法 | 签名 | 说明 |
|------|------|------|
| `setOnServerCallListener` | `CallSDK.setOnServerCallListener(listener)` | 设置服务端通话监听器（全局唯一，传 `null` 移除） |
| `setOnKickedListener` | `CallSDK.setOnKickedListener(listener)` | 设置被踢下线监听器（全局唯一，传 `null` 移除） |
| `addCallStateListener` | `CallSDK.addCallStateListener(listener)` | 添加通话状态监听器（支持多个） |
| `removeCallStateListener` | `CallSDK.removeCallStateListener(listener)` | 移除通话状态监听器 |
| `setAudioRouteChangeListener` | `CallSDK.setAudioRouteChangeListener(listener)` | 设置音频路由变化监听器（v1.3.5+，传 `null` 移除） |

### 3.3 通话

| 方法 | 签名 | 说明 |
|------|------|------|
| `makeCall` | `CallSDK.makeCall(phoneNumber, callback)` | 发起通话 |
| `makeCall` | `CallSDK.makeCall(phoneNumber, userData, callback)` | 发起通话（携带自定义参数，`JSONObject`，< 256 字节） |
| `hangupCall` | `CallSDK.hangupCall()` | 挂断当前通话 |
| `sendDTMF` | `CallSDK.sendDTMF(dtmfNumber)` | 发送 DTMF 信号（`*`、`#`、`0-9`） |
| `getCurrentCallInfo` | `CallSDK.getCurrentCallInfo(): CallInfo?` | 获取当前通话信息 |
| `getCurrentCallId` | `CallSDK.getCurrentCallId(): String?` | 获取当前通话 ID |

### 3.4 通话控制

| 方法 | 签名 | 说明 |
|------|------|------|
| `openLoudSpeaker` | `CallSDK.openLoudSpeaker(open: Boolean)` | 打开/关闭扬声器 |
| `isLoudSpeakerOn` | `CallSDK.isLoudSpeakerOn(): Boolean` | 获取扬声器状态 |
| `openMute` | `CallSDK.openMute(open: Boolean)` | 开启/关闭静音 |
| `isMuteOn` | `CallSDK.isMuteOn(): Boolean` | 获取静音状态 |
| `getCurrentAudioRoute` | `CallSDK.getCurrentAudioRoute(): AudioRoute` | 获取当前音频路由（v1.3.5+） |

### 3.5 外显号码配置

| 方法 | 签名 | 说明 |
|------|------|------|
| `queryNumberGroupList` | `CallSDK.queryNumberGroupList(page, pageSize, listener)` | 查询外显号码组列表 |
| `queryDisplayNumberList` | `CallSDK.queryDisplayNumberList(listener)` | 查询外显号码列表 |
| `updateAgentNumberGroupById` | `CallSDK.updateAgentNumberGroupById(numberGroupId, listener)` | 设置座席外显号码组（通过 ID） |
| `updateAgentNumberGroupByName` | `CallSDK.updateAgentNumberGroupByName(numberGroupName, listener)` | 设置座席外显号码组（通过名称） |
| `updateAgentSelectNumber` | `CallSDK.updateAgentSelectNumber(selectNumber, listener)` | 设置座席自定义外显号码 |
| `getAgentConfig` | `CallSDK.getAgentConfig(listener)` | 查询座席配置 |

---

## 4. 监听器接口

### 4.1 InitListener — 初始化监听器

```kotlin
interface InitListener {
    fun onInitSuccess() {}
    fun onInitFailed(errorCode: Int, errorMsg: String?) {}
}
```

### 4.2 OnServerCallListener — 服务端通话监听器

```kotlin
fun interface OnServerCallListener {
    fun onServerCall(callInfo: CallInfo)
}
```

服务端发起通话时 SDK 自动接听 SIP，开发者应在回调中打开通话界面。

### 4.3 MakeCallCallback — 发起通话回调

```kotlin
interface MakeCallCallback {
    fun onSuccess(callInfo: CallInfo)
    fun onFailed(errorCode: Int, errorMsg: String)
}
```

外呼发起结果与通话状态分离：`onSuccess` 表示呼叫已发出，后续状态通过 `CallStateListener` 接收。

### 4.4 CallStateListener — 通话状态监听器

```kotlin
interface CallStateListener {
    fun onCallAlerting(callInfo: CallInfo) {}
    fun onCallAnswered(callInfo: CallInfo) {}
    fun onCallReleased(callInfo: CallInfo, hangupType: Int) {}
    fun onCallFailed(callInfo: CallInfo, errorCode: Int, errorMsg: String) {}
    fun onDtmfReceived(callInfo: CallInfo, dtmf: String) {}
}
```

> 所有方法提供默认空实现，开发者只需 override 关心的回调。  
> `addCallStateListener` / `removeCallStateListener` 必须成对调用。

### 4.5 AudioRouteChangeListener — 音频路由监听器（v1.3.5+）

```kotlin
interface AudioRouteChangeListener {
    fun onAudioRouteChanged(route: AudioRoute)
}
```

### 4.6 外显号码相关监听器

```kotlin
interface NumberGroupListListener {
    fun onSuccess(response: NumberGroupListResponse?)
    fun onFailed(errorMsg: String?)
}

interface DisplayNumberListListener {
    fun onSuccess(numbers: List<DisplayNumber>?)
    fun onFailed(errorMsg: String?)
}

interface AgentConfigListener {
    fun onSuccess(config: AgentConfig?)
    fun onFailed(errorMsg: String?)
}
```

### 4.7 被踢下线监听器

```kotlin
// 独立于 init，全局生效
CallSDK.setOnKickedListener {
    // 账号被踢下线
}
```

---

## 5. 数据模型

### 5.1 CallInfo — 通话信息

| 字段 | 类型 | 说明 |
|------|------|------|
| `callId` | `String?` | 通话 ID |
| `phoneNumber` | `String?` | 电话号码 |
| `direction` | `CallDirection` | 通话方向 |
| `state` | `CallState` | 当前通话状态 |
| `startTime` | `Long` | 通话开始时间（毫秒时间戳） |

### 5.2 CallDirection — 通话方向

| 值 | 说明 |
|----|------|
| `APP` | APP 端发起（开发者主动调用 `makeCall()`） |
| `SERVER` | 服务端发起，SDK 自动接听 |

### 5.3 CallState — 通话状态

| 值 | 说明 |
|----|------|
| `CALLING` | 呼叫发起中 |
| `ALERTING` | 对方振铃中 |
| `ANSWERED` | 通话中（对方已接听） |
| `RELEASED` | 通话已结束 |
| `FAILED` | 通话失败 |

**状态流转：**

```
主动外呼 / 服务端发起：
  CALLING → ALERTING → ANSWERED → RELEASED
                    └→ FAILED
```

### 5.4 AudioRoute — 音频路由（v1.3.5+）

| 值 | 说明 |
|----|------|
| `RECEIVER` | 听筒 |
| `SPEAKER` | 扬声器 |
| `BLUETOOTH` | 蓝牙 SCO |

### 5.5 AgentConfig — 座席配置

`getAgentConfig` / 更新外显接口返回，其中 `agentCallConfig` 主要字段：

| 字段 | 说明 |
|------|------|
| `callerStrategy` | 外显策略，如 `enterprise`（外显号码）/ `enterpriseGroup`（外显号码组） |
| `selectNumber` | 当前外显号码 |
| `numberGroup` | 当前号码组 ID |

### 5.6 DisplayNumber — 外显号码

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String?` | 号码 ID |
| `number` | `String?` | 外显号码 |

### 5.7 NumberGroup — 外显号码组

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String?` | 号码组 ID |
| `groupName` | `String?` | 号码组名称 |

### 5.8 NumberGroupListResponse — 号码组列表响应

| 字段 | 类型 | 说明 |
|------|------|------|
| `list` | `List<NumberGroup>?` | 号码组列表 |
| `pageInfo` | — | 分页信息（如有） |

### 5.9 LoginInfo — 登录信息

通过 `CallSDK.getLoginInfo()` 获取，包含座席账号、agent 等信息（Demo 中通过 `loginInfo?.agent?._id` 获取 agentId）。

---

## 6. 错误码

### 6.1 错误码分类

| 错误码范围 | 分类 | 说明 |
|----------|------|------|
| **0** | 成功 | 操作成功 |
| **-1 ~ -99** | 初始化错误 | SDK 初始化相关错误 |
| **-100 ~ -199** | 参数验证错误 | 输入参数验证失败 |
| **-200 ~ -299** | 登录流程错误 | 登录、认证、SIP 注册相关错误 |
| **-300 ~ -399** | 通话相关错误 | 呼叫、通话控制相关错误 |
| **-400 ~ -499** | 网络错误 | 网络连接、超时相关错误 |
| **-2000 ~ -2099** | HTTP 请求错误 | HTTP 接口调用错误 |
| **-2100 ~ -2199** | WebSocket 错误 | WebSocket 连接相关错误 |
| **-4000 ~ -4099** | 外显号码错误 | 外显号码配置相关错误 |
| **-9999** | 未知错误 | 未定义的错误 |

### 6.2 通用错误

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -9999 | `UNKNOWN_ERROR` | 未知错误（网络异常、解析失败等兜底错误） |

### 6.3 初始化错误（-1 ~ -99）

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -1 | `SDK_INIT_FAILED` | SDK 初始化失败 |
| -2 | `SDK_NOT_INITIALIZED` | SDK 未初始化 |
| -3 | `PJSIP_CREATE_FAILED` | PJSIP 创建失败 |
| -4 | `PJSIP_INIT_FAILED` | PJSIP 初始化失败 |
| -5 | `TRANSPORT_CREATE_FAILED` | 传输层创建失败（UDP/TCP） |
| -6 | `PJSIP_START_FAILED` | PJSIP 启动失败 |

### 6.4 参数验证错误（-100 ~ -199）

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -100 | `INVALID_ACCOUNT` | 账号无效 |
| -101 | `INVALID_PASSWORD` | 密码无效 |
| -104 | `ACCOUNT_FORMAT_ERROR` | 账号格式错误 |
| -105 | `ACCOUNT_EMPTY` | 账号为空 |
| -106 | `PASSWORD_EMPTY` | 密码为空 |
| -107 | `SERVER_URL_EMPTY` | 服务器 URL 为空 |
| -108 | `TOKEN_EMPTY` | Token 为空 |

### 6.5 登录流程错误（-200 ~ -299）

通过 `InitListener.onInitFailed(errorCode, errorMsg)` 回调返回。

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -200 | `LOGIN_REQUEST_FAILED` | 登录请求失败 |
| -201 | `LOGIN_AUTH_FAILED` | 登录认证失败 |
| -202 | `LOGIN_FAILED_WRONG_CREDENTIALS` | 登录失败，账号或密码错误 |
| -203 | `SOCKET_CONNECT_FAILED` | Socket 连接失败 |
| -205 | `SIP_CONFIG_FAILED` | 获取 SIP 配置失败 |
| -206 | `SIP_CONFIG_INCOMPLETE` | SIP 配置信息不完整 |
| -207 | `SIP_REGISTER_FAILED` | SIP 注册失败（通用） |
| -209 | `SIP_REGISTER_REJECTED` | SIP 注册被拒绝 (403) |
| -210 | `LOGIN_FAILED_ACCOUNT_FROZEN` | 账号已被冻结 |
| -211 | `AGENT_DISABLED` | 坐席已停用 |
| -212 | `ACCOUNT_NOT_FOUND` | 账户未找到 |
| -213 | `AGENT_NOT_FOUND` | 坐席未找到 |
| -215 | `SIP_REGISTER_NOT_FOUND` | SIP 注册未找到 (404) |
| -216 | `SIP_REGISTER_SERVER_ERROR` | SIP 注册服务器错误 (5xx) |
| -217 | `GET_PUBLIC_KEY_FAILED` | 获取公钥失败 |

### 6.6 通话相关错误（-300 ~ -399）

通过 `MakeCallCallback.onFailed()` 或 `CallStateListener.onCallFailed()` 回调返回。

| 错误码 | 常量名 | 原因 | 触发阶段 |
|--------|--------|------|----------|
| -300 | `CALL_FAILED` | 呼叫失败（通用） | 通话中（SIP 层） |
| -301 | `CALL_PERMISSION_DENIED` | 通话权限被拒绝 | 拨号前 |
| -302 | `CALL_NOT_LOGGED_IN` | 未登录无法呼叫 | 拨号前 |
| -303 | `CALL_NUMBER_EMPTY` | 呼叫号码为空 | 拨号前 |
| -304 | `CALL_REJECTED` | 呼叫被拒绝 (403) | 通话中（SIP 层） |
| -305 | `CALL_NUMBER_NOT_FOUND` | 号码不存在 (404) | 通话中（SIP 层） |
| -306 | `CALL_USER_BUSY` | 用户忙线 (486) | 通话中（SIP 层） |
| -307 | `CALL_REQUEST_TERMINATED` | 对方拒接或手机软件拦截 (487) | 通话中（SIP 层） |
| -308 | `CALL_TIMEOUT` | 呼叫超时 (408) | 通话中（SIP 层） |
| -309 | `CALL_TEMPORARILY_UNAVAILABLE` | 暂时不可用 (480) | 通话中（SIP 层） |
| -310 | `CALL_FAILED_BLACKLIST` | 号码在黑名单中 | 拨号前（黑名单校验） |
| -311 | `CALL_FAILED_RISK_LIMIT` | 呼叫次数已达上限（风控拦截） | 拨号前（风控查询） |
| -312 | `CALL_FAILED_USERDATA_TOO_LARGE` | userData 超过 255 字节限制 | 拨号前（参数校验） |
| -313 | `CALL_NOT_ACCEPTABLE` | 媒体协商失败 (488) | 通话中（SIP 层） |
| -314 | `CALL_REGISTRATION_DROPPED` | SIP 注册掉线 (477) | 通话中（SIP 层） |
| -315 | `CALL_NOT_EXIST` | 通话不存在 (481) | 通话中（SIP 层） |
| -316 | `CALL_ADDRESS_INCOMPLETE` | 号码不完整 (484) | 通话中（SIP 层） |
| -317 | `CALL_DECLINED` | 对方拒绝接听 (603) | 通话中（SIP 层） |
| -318 | `CALL_BUSY_EVERYWHERE` | 全局忙线 (600) | 通话中（SIP 层） |
| -319 | `CALL_SERVER_ERROR` | 服务器内部错误 (500) | 通话中（SIP 层） |
| -320 | `CALL_BAD_GATEWAY` | 网关错误 (502) | 通话中（SIP 层） |
| -321 | `CALL_SERVICE_UNAVAILABLE` | 服务不可用 (503) | 通话中（SIP 层） |
| -322 | `CALL_SERVER_TIMEOUT` | 服务器超时 (504) | 通话中（SIP 层） |
| -323 | `CALL_NETWORK_LOST` | 通话中网络中断 | 通话中（网络监听） |

**触发阶段说明：**

- **拨号前**：在 `makeCall()` 调用后、SIP 拨号前触发，通过 `MakeCallCallback.onFailed()` 返回
- **通话中**：SIP 拨号后触发，通过 `CallStateListener.onCallFailed()` 返回

### 6.7 网络错误（-400 ~ -499）

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -401 | `NETWORK_TIMEOUT` | 网络超时 |

### 6.8 HTTP 请求错误（-2000 ~ -2099）

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -2001 | `HTTP_INVALID_URL` | 无效 URL |
| -2007 | `HTTP_ERROR` | HTTP 错误 (4xx, 5xx，通用) |
| -2008 | `HTTP_EMPTY_RESPONSE` | 空响应数据 |
| -2009 | `HTTP_JSON_PARSE_FAILED` | JSON 解析失败 |

### 6.9 WebSocket 错误（-2100 ~ -2199）

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -2100 | `WS_INVALID_URL` | 无效的 WebSocket URL |
| -2101 | `WS_CONNECT_FAILED` | WebSocket 连接失败 |

### 6.10 外显号码错误（-4000 ~ -4099）

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -4001 | `DISPLAY_NUMBER_AGENT_ID_EMPTY` | 坐席 ID 为空 |
| -4002 | `DISPLAY_NUMBER_CONFIG_FAILED` | 获取外显号码配置失败 |

---

## 7. Android 接入要点

### 7.1 必要权限

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

> `RECORD_AUDIO` 需动态申请，无权限拨打会失败。

### 7.2 依赖引入

```groovy
android {
    repositories {
        flatDir { dirs 'libs' }
    }
}

dependencies {
    implementation(name: 'callsdk-1.3.8', ext: 'aar')
    implementation 'com.squareup.okhttp3:okhttp:4.9.3'  // 若项目未引入
}
```

### 7.3 混淆配置

```proguard
-keep class com.useasy.callsdk.** { *; }
-keep interface com.useasy.callsdk.** { *; }
```

### 7.4 注意事项

1. **权限处理**：Android 6.0+ 需动态申请录音权限，建议在拨号前检查并申请
2. **监听器生命周期**：`addCallStateListener` / `removeCallStateListener` 成对调用
3. **服务端通话**：`OnServerCallListener` 应在初始化成功后尽早设置
4. **前台服务**：通话开始时会创建前台通知保活（Demo 参考 `CallService`）
5. **网络监听**：v1.3.2+ 通话中监听网络状态，3 秒未恢复网络则自动挂断
6. **默认音频路由**：v1.3.7 默认音频路由改为听筒

---

## 8. 1.2.x → 1.3.0 迁移要点

| 旧 API | 新 API | 说明 |
|--------|--------|------|
| `CallSDK.makeCall(phone, CallStateListener)` | `makeCall(phone, MakeCallCallback)` + `addCallStateListener()` | 外呼发起结果和通话状态分离 |
| `CallSDK.setServerCallListener(ServerCallStateListener)` | `CallSDK.setOnServerCallListener(OnServerCallListener)` | 简化为单一回调 |
| `InitListener.onKicked()` | `CallSDK.setOnKickedListener { }` | 独立为全局监听 |
| `CallStateListener` 回调参数 `callId: String?` | 回调参数 `callInfo: CallInfo` | 统一通话信息模型 |
| `onCallProceeding` / `onConnected` / `onDisconnected` / `onIncomingCall` | 已移除 | 内部状态，不再暴露 |

---

## 9. Flutter 插件对接建议

| 类型 | 建议通道 | 对应 Native API |
|------|----------|-----------------|
| 初始化 / 拨号 / 挂断 / 控制 | MethodChannel | `init`、`makeCall`、`hangupCall`、`openMute` 等 |
| 通话状态 / 服务端来电 / 被踢 / 音频路由 | EventChannel | `CallStateListener`、`OnServerCallListener`、`setOnKickedListener`、`AudioRouteChangeListener` |
| 外显号码查询 | MethodChannel + callback | `queryNumberGroupList`、`queryDisplayNumberList` 等 |

**枚举映射建议：**

- `CallDirection` → `app` / `server`
- `CallState` → `calling` / `alerting` / `answered` / `released` / `failed`
- `AudioRoute` → `receiver` / `speaker` / `bluetooth`
