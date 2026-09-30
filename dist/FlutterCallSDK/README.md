# FlutterCallSDK 交付包

本目录是 **jj_callkit_flutter** 仓库对外交付物（与 Android 侧 `AndroidCallSDK` 同级用途）。

| 内容 | 说明 |
|------|------|
| `JJCallKit_Flutter_接入文档.md` | 客户接入文档（主文档） |
| `jj_callkit/` | Flutter 插件快照（含 Android callsdk 1.3.9 + iOS JJCallKit 1.1.1） |
| `jj_callkit-demo/` | 可运行示例工程 |

当前插件版本：**0.1.3**

源码与桥接开发文档在仓库根目录；发版时把当前插件/example 同步进本目录后再交付。

## 客户怎么用

1. 阅读《JJCallKit_Flutter_接入文档.md》
2. 业务工程 `pubspec.yaml` 依赖 `jj_callkit/`（path 或私有 git）
3. 可选：用 `jj_callkit-demo/` 先真机跑通登录 / 外呼

```bash
cd jj_callkit-demo
flutter pub get
flutter run
```

## 维护：从仓库根刷新本交付目录

在仓库根执行：

```bash
rsync -a --delete \
  --exclude '.git' --exclude 'docs' --exclude 'example' --exclude 'test' --exclude 'dist' \
  --exclude '.dart_tool' --exclude 'build' --exclude '**/Pods' --exclude '**/.symlinks' \
  ./ dist/FlutterCallSDK/jj_callkit/

rsync -a --delete \
  --exclude '.dart_tool' --exclude 'build' --exclude '**/Pods' --exclude '**/.symlinks' \
  example/ dist/FlutterCallSDK/jj_callkit-demo/

# Demo 依赖路径
# jj_callkit-demo/pubspec.yaml → path: ../jj_callkit
```
