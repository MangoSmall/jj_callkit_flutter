# JJCallKit Flutter SDK

当前版本：**0.1.3**  
内置原生 SDK：Android callsdk **1.3.9**、iOS JJCallKit **1.1.1**

## 目录

| 内容 | 说明 |
|------|------|
| `JJCallKit_Flutter_接入文档.md` | 接入说明（请先读这份） |
| `jj_callkit/` | Flutter 插件（已内置双端原生 SDK） |
| `jj_callkit-demo/` | 可运行示例工程 |

## 快速开始

1. 阅读《JJCallKit_Flutter_接入文档.md》
2. 业务工程 `pubspec.yaml` 用 path 依赖本目录下的 `jj_callkit/`
3. 可选：用 `jj_callkit-demo/` 先真机跑通登录 / 外呼

```bash
cd jj_callkit-demo
flutter pub get
flutter run
```

> Android 请用 **arm64 真机**验收（当前 so 不含 x86）。  
> 业务工程只需依赖本插件，不要再单独集成 AAR / xcframework。
