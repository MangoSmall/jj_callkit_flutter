# 错误码

`JJCallException.code` 与 Android、iOS 原生一致。文案用 `JJCallKit.errorDescription(code)`，原生带回的 `message` 优先。

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
| -4002 | 外显号码配置失败。iOS 只传号码组名称时也会是这个码 |
| -9999 | 未知错误 |

完整分段：

- `-1 ~ -99` 初始化
- `-100 ~ -199` 参数
- `-200 ~ -299` 登录 / SIP 注册
- `-300 ~ -399` 通话
- `-400 ~ -499` 网络
- `-2000 ~ -2099` HTTP
- `-2100 ~ -2199` WebSocket
- `-4000 ~ -4099` 外显号码

```dart
try {
  await JJCallKit.makeCall(phone);
} on JJCallException catch (e) {
  switch (e.code) {
    case -301:
      // 去申请麦克风
    case -310:
    case -311:
      // 把 e.message 提示给用户
    default:
      break;
  }
}
```
