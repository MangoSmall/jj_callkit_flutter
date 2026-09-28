# JJCallKit iOS API 参考

> 来源：`JJSDK/JJPhoneDemo/README.md` + `JJCallKit.framework/Headers/VoIPManager.h`  
> Framework：**JJCallKit.framework**（基于 PJSIP）  
> 入口类：`VoIPManager`  
> 用途：供 Flutter 插件 iOS 端 MethodChannel / EventChannel 对接参考

---

## 1. 概述

JJCallKit 是一款 iOS VoIP 通话 SDK，基于 SIP 协议提供音频通话能力，已接入 Apple CallKit。

### 1.1 集成方式

| 方式 | 说明 |
|------|------|
| **自带 UI** | Demo 提供完整通话界面（拨号、通话中、通话记录等），可直接集成 |
| **自定义 UI** | 仅使用底层 `VoIPManager` 能力，自行实现界面 |

### 1.2 通话场景

| 场景 | 说明 | 触发方式 |
|------|------|----------|
| **主动外呼** | 开发者调用 `makeCall()` 发起通话 | 开发者主动调用 |
| **服务端发起通话** | 服务端推送通话状态，SDK 自动接听 SIP | 监听 `kSocketCallStatusNotification`，SDK 自动处理 |

### 1.3 架构与回调

iOS SDK 通过 **NSNotificationCenter** 推送状态，而非 Listener 接口：

```
┌──────────────────────────────────────────────────────────┐
│                     VoIPManager                           │
│                                                          │
│  ① initial / loginWithAccount  → 初始化 & 登录            │
│  ② NSNotificationCenter        → SIP 连接 / 通话状态     │
│  ③ kSocketCallStatusNotification → 服务端通话推送         │
│  ④ Block 回调                  → makeCall / 外显等结果    │
│  ⑤ CallKit                     → 系统锁屏通话条           │
└──────────────────────────────────────────────────────────┘
```

**重要约定：**

- 方法回调（`success` / `failure`）在调用线程或主线程返回，UI 更新建议放主线程
- `loginWithAccount` 返回成功仅表示请求已发出，真实 SIP 连接结果需监听 `kSIPConnectedNotification`
- **模拟器不支持 CallKit 外呼**（`CXErrorCodeRequestTransactionErrorUnentitled`），SDK 会回退 SIP 直拨；锁屏通话请用真机验收

---

## 2. 环境要求

| 项目 | 最低版本 | 说明 |
|------|----------|------|
| iOS | 12.4+ | 支持 iPhone |
| Xcode | 15.0+ | 建议最新稳定版 |
| Swift | 5.0+ | 推荐 5.9+ |
| 架构 | arm64（真机/模拟器）、x86_64（模拟器） | 不支持 Bitcode |

### 2.1 必要权限

| 权限 | Info.plist 键 | 说明 |
|------|---------------|------|
| 麦克风 | `NSMicrophoneUsageDescription` | **必需**，无权限呼叫失败 |
| 后台音频 | `UIBackgroundModes` = `audio` | **锁屏/后台通话必配** |

### 2.2 系统 Framework 依赖

`CoreAudio`、`AudioToolbox`、`AVFoundation`、`CallKit`（Do Not Embed）

### 2.3 Swift Bridging Header

```objc
#import <JJCallKit/VoIPManager.h>
```

---

## 3. 配置

### 3.1 VoIPEnvironment — 环境

| 值 | 说明 |
|----|------|
| `VoIPEnvironmentProduction` (0) | 生产环境 |
| `VoIPEnvironmentDevelopment` (1) | 开发/测试环境 |

Swift 调用示例中使用 `.production` / `.development`。

### 3.2 日志配置（类方法）

| 方法 | 说明 |
|------|------|
| `VoIPManager.setLogLevel(level)` | 日志级别：0=错误，1=一般，2=全量 |
| `VoIPManager.setLogFilePath(path)` | 日志文件路径，`nil` 默认 `Documents/VoIPLogs/voip.log` |
| `VoIPManager.setFileLoggingEnabled(enabled)` | 启用/禁用文件日志 |

---

## 4. API 参考

### 4.1 单例 & 属性

```objc
+ (instancetype)sharedManager;
```

| 属性 | 类型 | 说明 |
|------|------|------|
| `messageHandler` | `MessageHandler` | 日志消息回调 |
| `isSDKInitialized` | `BOOL` | SDK 是否已初始化 |
| `autoAnswerIncomingCall` | `BOOL` | 是否自动接听来电，默认 `YES`；设为 `NO` 需手动 `acceptCall` |

### 4.2 初始化 & 生命周期

| 方法 | 签名 | 返回值 / 回调 | 说明 |
|------|------|---------------|------|
| `initial` | `- (VoIPStatusCode)initial` | `0` 成功，`-1` 失败 | 初始化 SDK，线程安全，防重复初始化 |
| `loginWithAccount:password:environment:passwordPk:success:failure:` | 见下方 | success: `NSDictionary`；failure: `(code, message)` | 完整登录流程 |
| `reregisterSIPWithSuccess:failure:` | — | failure: `(code, message)` | 重新注册 SIP（需已登录成功） |
| `logout` | `- (void)logout` | — | 登出，断开 WebSocket、注销 SIP |
| `logoutWithCompletion:` | `- (void)logoutWithCompletion:(void(^)(void))completion` | 主线程 completion | 登出完成后回调，适合对齐 MethodChannel result |
| `cleanupSDK` | `- (void)cleanupSDK` | — | 清理 SDK 全部状态，需重新 `initial` |
| `canMakeCall` | `- (BOOL)canMakeCall` | `BOOL` | 检查当前是否可拨号 |

**loginWithAccount 参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `account` | `NSString` | 账号，格式 `user@domain`（如 `6000@useasy`） |
| `password` | `NSString` | 明文密码（与 `passwordPk` 二选一） |
| `environment` | `VoIPEnvironment` | 环境 |
| `passwordPk` | `NSString?` | RSA 加密密码（与 `password` 二选一，都填时优先用 `passwordPk`） |

**初始化顺序：**

```swift
let manager = VoIPManager.sharedManager()
let result = manager.initial()
guard result == 0 else { return }

manager.loginWithAccount(
    account: "6000@useasy",
    password: "password",
    environment: .production,
    passwordPk: nil,
    success: { _ in /* 请求已发出，等 kSIPConnectedNotification */ },
    failure: { code, message in /* 处理错误 */ }
)
```

### 4.3 通话

| 方法 | 签名 | 回调 | 说明 |
|------|------|------|------|
| `makeCall:success:failure:` | `makeCall(_:success:failure:)` | success: `callId`；failure: `(code, message)` | 发起外呼 |
| `makeCall:userData:success:failure:` | 同上 + `userData` | 同上 | 外呼携带自定义参数（JSON 字典，编码后 < 255 字节） |
| `hangupCall` | `- (void)hangupCall` | — | 挂断当前通话 |
| `acceptCall` | `- (void)acceptCall` | — | 接听来电（`autoAnswerIncomingCall = NO` 时使用） |
| `sendDTMF:` | `- (void)sendDTMF:(NSString *)dtmfNumber` | — | 发送 DTMF（0-9, *, #） |

### 4.4 通话控制

| 方法 | 签名 | 说明 |
|------|------|------|
| `openMute:` | `- (void)openMute:(BOOL)open` | 开启/关闭静音 |
| `isMuted` | `- (BOOL)isMuted` | 查询静音状态，无通话时返回 `NO` |
| `openLoudSpeaker:` | `- (void)openLoudSpeaker:(BOOL)open` | 开启/关闭扬声器 |
| `isLoudSpeakerOn` | `- (BOOL)isLoudSpeakerOn` | 查询扬声器状态（基于 AVAudioSession 输出端口） |
| `setAudioConfig:enabled:mode:` | `- (void)setAudioConfig:(int)type enabled:(bool)enabled mode:(int)mode` | 配置音频参数 |
| `refreshAudioDevice` | `- (void)refreshAudioDevice` | 刷新音频设备，通话建立后调用 |
| `resetRetryNumber` | `- (void)resetRetryNumber` | 重置呼叫重试计数 |

### 4.5 外显号码配置

| 方法 | 回调 success 返回 | 说明 |
|------|-------------------|------|
| `getCallerStrategyWithSuccess:failure:` | `NSDictionary` | 外显策略配置 |
| `getDisplayNumberListWithSuccess:failure:` | `NSArray<NSDictionary *>` | 外显号码列表 |
| `getDisplayNumberGroupListWithSuccess:failure:` | `NSArray<NSDictionary *>` | 外显号码组列表 |
| `updateAgentDisplayNumberWithSelectNumber:numberGroup:success:failure:` | `void` | 设置外显号码或号码组（二选一） |

**getCallerStrategy 返回字段：** `mobile`, `agentNumber`, `numbers`, `numberSelect`, `selectNumber`, `numberGroup`, `sipNumber`, `callerStrategy`

**DisplayNumber 字典字段：** `id`, `status`, `number`, `province`, `city`

**NumberGroup 字典字段：** `id`, `name`, `groupName`, `remark`

**updateAgentDisplayNumber 注意：** 必须指定 `selectNumber` 或 `numberGroup` 之一。

### 4.6 状态清理（高级）

| 方法 | 说明 |
|------|------|
| `cleanupCallStateOnFailure:` | 呼叫失败时清理通话状态 |
| `resetAudioDeviceState` | 重置音频设备到初始状态 |
| `cleanupCompleteCallState` | 完整清理通话相关状态 |

### 4.7 辅助方法（类方法）

| 方法 | 说明 |
|------|------|
| `+ errorDescriptionForCode:` | 获取 VoIPStatusCode 可读描述 |
| `+ sipStatusDescription:` | 获取 SIP 状态码描述（如 403 Forbidden） |

---

## 5. 通知（NSNotificationCenter）

Framework 通过 `NSNotificationCenter` 发送状态通知，Flutter 插件侧建议在 iOS 原生层统一转发为 EventChannel 事件。

### 5.1 连接相关通知

| 通知名称 | 说明 | UserInfo |
|---------|------|----------|
| `kSIPConnectedNotification` | SIP 连接成功 | — |
| `kSIPConnectFailedNotification` | SIP 连接失败 | `kSIPReasonDescriptionKey`, `kSIPVoIPStatusCodeKey` |
| `kSIPKickedOutNotification` | 被踢下线 (453) | — |
| `kSIPDisconnectedNotification` | SIP 断开连接 | `kSIPReasonKey`, `kSIPReasonDescriptionKey`, `kSIPIsPassiveKey`, `kSIPTimestampKey` |

### 5.2 呼叫相关通知

以下通知均包含通用字段：`kSIPCallIdKey`, `kSIPRemoteNumberKey`, `kSIPCallRoleKey`, `kSIPCallIdStringKey`

| 通知名称 | 说明 | 额外 UserInfo |
|---------|------|---------------|
| `kSIPCallCallingNotification` | 正在呼叫 | — |
| `kSIPCallConnectingNotification` | 振铃中 | — |
| `kSIPCallConfirmNotification` | 呼叫接通 | — |
| `kSIPCallDisconnectNotification` | 呼叫挂断 | `kSIPReasonKey`, `kSIPReasonDescriptionKey`, `kSIPHangupTypeKey`, `kSIPTimestampKey`, `kSIPVoIPStatusCodeKey` |
| `kSIPCallRetryNotification` | 呼叫重试 | 当前未发送 |

**对应 Android CallState 映射建议：**

| iOS 通知 | 建议映射状态 |
|---------|-------------|
| `kSIPCallCallingNotification` | `CALLING` |
| `kSIPCallConnectingNotification` | `ALERTING` |
| `kSIPCallConfirmNotification` | `ANSWERED` |
| `kSIPCallDisconnectNotification` | `RELEASED` / `FAILED`（视 reason 而定） |

### 5.3 服务端通话推送

| 通知名称 | 说明 |
|---------|------|
| `kSocketCallStatusNotification` | WebSocket 服务端推送的通话状态事件 |

**UserInfo 字段：**

| Key | 类型 | 说明 |
|-----|------|------|
| `kSocketCallIdKey` | String | 通话 ID |
| `kSocketCallTypeKey` | String | `callin`（呼入）/ `callout`（呼出） |
| `kSocketCallStateKey` | Int | 状态码（1=忙碌，2=呼叫中，3=振铃等，以服务端约定为准） |
| `kSocketCallStateNameKey` | String | 状态名称（如「振铃」） |
| `kSocketCustomerNumberKey` | String | 客户号码 |
| `kSocketDisNumberKey` | String | 外显号码 |
| `kSocketEventDataKey` | NSDictionary | 完整事件数据 |

**对接注意：**

- 同一次通话可能收到多条推送，建议用 `callId` 去重
- 通知回调可能不在主线程，UI 更新需 `DispatchQueue.main.async`
- 对应 Android 的 `OnServerCallListener`

### 5.4 UserInfo Keys 汇总

**SIP 通话通用 Keys：**

| Key | 说明 |
|-----|------|
| `kSIPCallIdKey` | PJSIP 内部通话 ID |
| `kSIPRemoteNumberKey` | 对方号码 |
| `kSIPCallRoleKey` | 主叫/被叫（0=主叫，1=被叫） |
| `kSIPCallIdStringKey` | SIP Dialog Call-ID 字符串 |
| `kSIPReasonKey` | SIP 错误码 |
| `kSIPReasonDescriptionKey` | SIP 错误描述 |
| `kSIPIsPassiveKey` | 是否被动断开 |
| `kSIPTimestampKey` | 时间戳 |
| `kSIPHangupTypeKey` | 挂断类型（0=主叫挂断，1=被叫挂断） |
| `kSIPVoIPStatusCodeKey` | 映射后的 VoIPStatusCode |

### 5.5 SIPHangupType 枚举

| 值 | 说明 |
|----|------|
| `SIPHangupTypeCaller` (0) | 主叫挂断 |
| `SIPHangupTypeCallee` (1) | 被叫挂断 |

---

## 6. 错误码（VoIPStatusCode）

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

### 6.2 初始化错误（-1 ~ -99）

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -1 | `VoIPStatusCodeSDKInitFailed` | SDK 初始化失败 |
| -2 | `VoIPStatusCodeSDKNotInitialized` | SDK 未初始化 |
| -3 | `VoIPStatusCodePJSIPCreateFailed` | PJSIP 创建失败 |
| -4 | `VoIPStatusCodePJSIPInitFailed` | PJSIP 初始化失败 |
| -5 | `VoIPStatusCodeTransportCreateFailed` | 传输层创建失败 |
| -6 | `VoIPStatusCodePJSIPStartFailed` | PJSIP 启动失败 |

### 6.3 参数验证错误（-100 ~ -199）

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -100 | `VoIPStatusCodeInvalidAccount` | 账号无效 |
| -101 | `VoIPStatusCodeInvalidPassword` | 密码无效 |
| -104 | `VoIPStatusCodeAccountFormatError` | 账号格式错误 |
| -105 | `VoIPStatusCodeEmptyAccount` | 账号为空 |
| -106 | `VoIPStatusCodeEmptyPassword` | 密码为空 |
| -107 | `VoIPStatusCodeEmptyBaseURL` | 服务器 URL 为空 |
| -108 | `VoIPStatusCodeEmptyToken` | Token 为空 |

### 6.4 登录流程错误（-200 ~ -299）

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -200 | `VoIPStatusCodeLoginRequestFailed` | 登录请求失败 |
| -201 | `VoIPStatusCodeLoginAuthFailed` | 登录认证失败 |
| -202 | `VoIPStatusCodeLoginConfigFailed` | 获取登录配置失败 |
| -203 | `VoIPStatusCodeSocketConnectFailed` | Socket 连接失败 |
| -205 | `VoIPStatusCodeSIPConfigFailed` | 获取 SIP 配置失败 |
| -206 | `VoIPStatusCodeSIPConfigIncomplete` | SIP 配置信息不完整 |
| -207 | `VoIPStatusCodeSIPRegisterFailed` | SIP 注册失败（通用） |
| -209 | `VoIPStatusCodeSIPRegisterForbidden` | SIP 注册被拒绝 (403) |
| -210 | `VoIPStatusCodeAccountFrozen` | 账号已被冻结 |
| -211 | `VoIPStatusCodeAgentDisabled` | 坐席已停用 |
| -212 | `VoIPStatusCodeAccountNotFound` | 账户未找到 |
| -213 | `VoIPStatusCodeAgentNotFound` | 坐席未找到 |
| -215 | `VoIPStatusCodeSIPRegisterNotFound` | SIP 注册未找到 (404) |
| -216 | `VoIPStatusCodeSIPRegisterServerError` | SIP 注册服务器错误 (5xx) |
| -217 | `VoIPStatusCodePublicKeyFetchFailed` | 获取公钥失败 |

### 6.5 通话相关错误（-300 ~ -399）

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -300 | `VoIPStatusCodeCallFailed` | 呼叫失败（通用） |
| -301 | `VoIPStatusCodeCallPermissionDenied` | 通话权限被拒绝（麦克风） |
| -302 | `VoIPStatusCodeCallNotLoggedIn` | 未登录无法呼叫 |
| -303 | `VoIPStatusCodeCallEmptyNumber` | 呼叫号码为空 |
| -304 | `VoIPStatusCodeCallForbidden` | 呼叫被拒绝 (403) / 黑名单 |
| -305 | `VoIPStatusCodeCallNotFound` | 号码不存在 (404) |
| -306 | `VoIPStatusCodeCallBusy` | 用户忙线 (486) |
| -307 | `VoIPStatusCodeCallTerminated` | 请求已终止 (487) |
| -308 | `VoIPStatusCodeCallTimeout` | 呼叫超时 (408) |
| -309 | `VoIPStatusCodeCallUnavailable` | 暂时不可用 (480) |
| -310 | `VoIPStatusCodeCallFailedBlacklist` | 号码在黑名单中 |
| -311 | `VoIPStatusCodeCallFailedRiskLimit` | 呼叫次数已达上限（风控） |
| -312 | `VoIPStatusCodeCallFailedUserDataTooLarge` | userData 超过 255 字节 |
| -313 | `VoIPStatusCodeCallNotAcceptable` | 媒体协商失败 (488) |
| -314 | `VoIPStatusCodeCallRegistrationDropped` | SIP 注册掉线 (477) |
| -315 | `VoIPStatusCodeCallNotExist` | 通话不存在 (481) |
| -316 | `VoIPStatusCodeCallAddressIncomplete` | 号码不完整 (484) |
| -317 | `VoIPStatusCodeCallDeclined` | 对方拒绝接听 (603) |
| -318 | `VoIPStatusCodeCallBusyEverywhere` | 全局忙线 (600) |
| -319 | `VoIPStatusCodeCallServerError` | 服务器内部错误 (500) |
| -320 | `VoIPStatusCodeCallBadGateway` | 网关错误 (502) |
| -321 | `VoIPStatusCodeCallServiceUnavailable` | 服务不可用 (503) |
| -322 | `VoIPStatusCodeCallServerTimeout` | 服务器超时 (504) |
| -323 | `VoIPStatusCodeCallNetworkLost` | 通话中网络中断 |

### 6.6 网络 / HTTP / WebSocket / 外显号码错误

| 错误码 | 常量名 | 原因 |
|--------|--------|------|
| -401 | `VoIPStatusCodeNetworkTimeout` | 网络超时 |
| -2001 | `VoIPStatusCodeHTTPInvalidURL` | 无效 URL |
| -2007 | `VoIPStatusCodeHTTPError` | HTTP 错误 (4xx, 5xx) |
| -2008 | `VoIPStatusCodeHTTPEmptyResponseData` | 空响应数据 |
| -2009 | `VoIPStatusCodeHTTPJSONParseFailed` | JSON 解析失败 |
| -2100 | `VoIPStatusCodeWebSocketInvalidURL` | 无效 WebSocket URL |
| -2101 | `VoIPStatusCodeWebSocketConnectFailed` | WebSocket 连接失败 |
| -4001 | `VoIPStatusCodeEmptyAgentId` | 坐席 ID 为空 |
| -4002 | `VoIPStatusCodeDisplayNumberConfigFailed` | 获取外显号码配置失败 |
| -9999 | `VoIPStatusCodeUnknown` | 未知错误 |

### 6.7 获取错误描述

```swift
let description = VoIPManager.errorDescriptionForCode(errorCode)
let sipDesc = VoIPManager.sipStatusDescription(403)  // "403 Forbidden - 禁止访问"
```

### 6.8 通知中的 VoIPStatusCode 映射

| 通知 | kSIPVoIPStatusCodeKey 可能出现的值 |
|------|-----------------------------------|
| `kSIPConnectFailedNotification` | -100, -207 |
| `kSIPCallDisconnectNotification` | -304 ~ -309（SIP 状态码映射） |

---

## 7. iOS 接入要点

### 7.1 CallKit

- SDK 已接入 CallKit，外呼/来电会上报系统通话条
- 一个 App 内**不要再挂第二套 `CXProvider`**
- 审核时 CallKit 必须对应真实通话
- 模拟器无法 CallKit 外呼，SDK 自动回退 SIP 直拨

### 7.2 后台保活

锁屏/后台通话必须在**宿主 App** Info.plist 配置 `UIBackgroundModes` → `audio`。Framework 自身 plist 无效。

### 7.3 注意事项

1. **初始化顺序**：先 `initial()` 再 `loginWithAccount`
2. **登录异步**：`loginWithAccount` success 仅表示请求发出，等 `kSIPConnectedNotification`
3. **拨号前检查**：`canMakeCall()` 返回 YES 再拨
4. **通话控制时机**：静音、免提、DTMF 在接通后使用
5. **音频会话**：Framework 内部处理 AVAudioSession，应用层避免冲突
6. **被踢下线**：监听 `kSIPKickedOutNotification`，建议调用 `logout` 并引导重新登录
7. **重新初始化**：需先 `cleanupSDK` 再 `initial`

### 7.4 Build Settings

```
Framework Search Paths: $(PROJECT_DIR)
Header Search Paths: $(PROJECT_DIR)/JJCallKit.framework/Headers
Preprocessor Macros: PJ_IS_LITTLE_ENDIAN=1, PJ_IS_BIG_ENDIAN=0
```

---

## 8. Flutter 插件对接建议

### 8.1 通道划分

| 类型 | 建议通道 | 对应 Native API |
|------|----------|-----------------|
| 初始化 / 登录 / 拨号 / 挂断 / 控制 | MethodChannel | `initial`, `loginWithAccount`, `makeCall`, `hangupCall`, `openMute` 等 |
| SIP 连接 / 通话状态 / 被踢 / 服务端推送 | EventChannel | `kSIP*Notification`, `kSocketCallStatusNotification` |
| 外显号码 | MethodChannel + callback | `getDisplayNumberList`, `updateAgentDisplayNumber` 等 |

### 8.2 Android ↔ iOS API 映射

| 能力 | Android (CallSDK) | iOS (VoIPManager) |
|------|-------------------|-------------------|
| 初始化+登录 | `CallSDK.init()` | `initial()` + `loginWithAccount()` |
| 发起外呼 | `makeCall(phone, callback)` | `makeCall(_:success:failure:)` |
| 挂断 | `hangupCall()` | `hangupCall()` |
| 静音 | `openMute(open)` | `openMute(_:)` |
| 扬声器 | `openLoudSpeaker(open)` | `openLoudSpeaker(_:)` |
| DTMF | `sendDTMF(dtmf)` | `sendDTMF(_:)` |
| 服务端来电 | `setOnServerCallListener` | `kSocketCallStatusNotification` |
| 通话状态 | `CallStateListener` | `kSIPCall*Notification` |
| 被踢下线 | `setOnKickedListener` | `kSIPKickedOutNotification` |
| 外显策略 | `getAgentConfig` | `getCallerStrategyWithSuccess` |
| 外显号码列表 | `queryDisplayNumberList` | `getDisplayNumberListWithSuccess` |
| 外显号码组列表 | `queryNumberGroupList` | `getDisplayNumberGroupListWithSuccess` |
| 设置外显 | `updateAgentSelectNumber` / `updateAgentNumberGroupById` | `updateAgentDisplayNumberWithSelectNumber:numberGroup:` |
| 销毁 | `release()` | `cleanupSDK()` |
| 登出 | `logout()` | `logout()` / `logoutWithCompletion:` |

### 8.3 事件命名建议（Dart 层统一）

| 事件 | 建议 payload 字段 |
|------|-------------------|
| `onInitSuccess` / `onInitFailed` | `errorCode`, `errorMsg` |
| `onSipConnected` | — |
| `onSipConnectFailed` | `errorCode`, `errorMsg` |
| `onKicked` | — |
| `onCallAlerting` | `callId`, `phoneNumber`, `direction` |
| `onCallAnswered` | `callId`, `phoneNumber` |
| `onCallReleased` | `callId`, `hangupType`, `reason` |
| `onCallFailed` | `callId`, `errorCode`, `errorMsg` |
| `onServerCall` | `callId`, `callType`, `customerNumber`, `callState` |
| `onDtmfReceived` | `callId`, `dtmf` |
