# FlutterCallSDK 交付包

与 `AndroidCallSDK` 同级的 Flutter 通话 SDK 对外交付物。

| 内容 | 说明 |
|------|------|
| `JJCallKit_Flutter_接入文档.md` | 客户接入文档（主文档） |
| `jj_callkit/` | Flutter 插件（内置 Android callsdk 1.3.8 + iOS JJCallKit 1.1.1） |
| `jj_callkit-demo/` | 可运行示例工程 |

当前插件版本：**0.1.1**

## 客户怎么用

1. 阅读《JJCallKit_Flutter_接入文档.md》
2. 业务工程 `pubspec.yaml` 依赖 `jj_callkit/`（path 或私有 git）
3. 可选：用 `jj_callkit-demo/` 先真机跑通登录 / 外呼

```bash
cd jj_callkit-demo
flutter pub get
flutter run
```
