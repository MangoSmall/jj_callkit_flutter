# 事件

```dart
JJCallKit.events.listen((event) { ... });
```

可以多处监听。页面销毁时 `cancel` 订阅，不要 `release()`。

| 事件 | 何时 |
|------|------|
| `SipConnectedEvent` | SIP 注册成功。`init` 同时完成 |
| `SipConnectFailedEvent` | 登录或 SIP 注册失败 |
| `SipDisconnectedEvent` | SIP 断开 |
| `KickedEvent` | 账号在其他端登录 |
| `CallCallingEvent` | 正在呼叫。可以不处理 |
| `CallAlertingEvent` | 对方振铃 |
| `CallAnsweredEvent` | 已接通 |
| `CallReleasedEvent` | 正常挂断。`hangupType` 0 主叫、1 被叫 |
| `CallFailedEvent` | 通话中失败，带 `errorCode` |
| `DtmfReceivedEvent` | 收到 DTMF。当前主要来自 Android |
| `ServerCallEvent` | 服务端来电，每个 callId 只推一次 |
| `AudioRouteChangedEvent` | 切换听筒 / 扬声器后 |

外呼失败走 `makeCall` 的 `JJCallException`，不会再发一条 `CallFailedEvent`。

主动外呼：`calling` → `alerting` → `answered` → `released`。失败则 `failed`。

服务端来电：先 `ServerCallEvent`（`direction == server`），后续振铃和接通仍走对应事件。iOS 上同一通 Socket 推送会被去重，避免重复打开页面。
