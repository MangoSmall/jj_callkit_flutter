## 0.1.1

- Android 内置 callsdk 升级至 1.3.8（PCMA/PCMU + TCP INVITE 兜底，修复部分 Wi‑Fi/NAT 下外呼失败）。

## 0.1.0

- 对外提供 `JJCallKit`。业务方只依赖插件，不再直接集成 Android AAR 或 iOS xcframework。
- 统一登录、外呼、挂断、静音、扬声器、DTMF、外显号码，以及 SIP / 通话 / 被踢事件。
- 内置 Android callsdk 1.3.7、iOS JJCallKit 1.1.1。
