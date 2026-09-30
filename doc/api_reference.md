# API

入口类是 `JJCallKit`。方法在 SIP 未就绪或参数不合法时抛 `JJCallException`。

## 生命周期

| 方法 | 说明 |
|------|------|
| `init(CallConfig)` | 初始化并登录。Future 在 SIP 注册成功后结束 |
| `logout()` | 登出，不断掉插件本身 |
| `release()` | 销毁原生 SDK。下次必须重新 `init` |
| `canMakeCall()` | 当前能否外呼 |
| `getLoginInfo()` | `agentId`、`agentNumber`、`mobile`、`accountId`。不含 token |
| `errorDescription(code)` | 错误码文案 |

`CallConfig`：`username`、`password`、`passwordPk`、`environment`（`production` / `debug`）、`logConfig`。

`LogConfig.logLevel`：0 错误，1 一般，2 全量。

## 通话

| 方法 | 说明 |
|------|------|
| `makeCall(phone, {userData})` | 呼叫已发出就返回。接通看事件 |
| `hangupCall()` | 挂断当前通话 |
| `sendDTMF(digit)` | `0-9`、`*`、`#` |
| `getCurrentCallInfo()` | 没有通话时为 `null` |

`userData` 编码后必须小于 255 字节，否则 `-312`。

## 音频

| 方法 | 说明 |
|------|------|
| `setMute` / `isMuted` | 静音 |
| `setSpeaker` / `isSpeakerOn` | 扬声器 |
| `getCurrentAudioRoute()` | `receiver` / `speaker` / `bluetooth` |

Android（callsdk 1.3.9）可返回 `receiver` / `speaker` / `bluetooth`。iOS 仍主要按扬声器开关近似，不保证 `bluetooth`。

## 外显号码

| 方法 | 说明 |
|------|------|
| `getAgentConfig()` | `callerStrategy`、`selectNumber`、`numberGroup` |
| `getDisplayNumberList()` | 外显号码 |
| `getNumberGroupList(page, pageSize)` | 号码组。iOS 忽略分页，一次返回全量 |
| `updateDisplayNumber(selectNumber)` | 指定外显号码 |
| `updateNumberGroup(id / name)` | Android 支持 id 或 name。iOS 只支持 id |

服务端来电收到 `ServerCallEvent` 后只打开页面。SDK 已经自动接听，不要再 `makeCall`。
