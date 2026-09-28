# jj_callkit Flutter 插件实施计划

> **目标**：基于 `Android_Flutter桥接开发文档.md` 与 `iOS_Flutter桥接开发文档.md`，交付一套**面向外部用户**的 Flutter VoIP SDK（Plugin + Demo + 对接文档）。  
> **原则**：Dart 层 API 跨平台一致；能在 Plugin 层消化差异的，不改动原生 SDK；必须改原生 SDK 的，单独列版本与排期。

---

## 1. 交付物清单（对外用户）

| 交付物 | 路径/形式 | 说明 |
|--------|-----------|------|
| **Flutter Plugin** | `JJSDK/Flutter/jj_callkit/` | 业务方 `pubspec.yaml` 依赖的唯一入口 |
| **Example Demo** | `jj_callkit/example/` | 可独立运行的完整示例（登录、外呼、通话中、外显设置） |
| **用户对接文档** | `jj_callkit/README.md` + `doc/` | 集成步骤、权限、API、错误码、FAQ |
| **变更日志** | `jj_callkit/CHANGELOG.md` | 版本与 Breaking Changes |
| **内部桥接文档** | 现有 4 份 md | 维护者/二次开发用，不强制给用户 |
| **原生 SDK 二进制** | 内嵌于 Plugin | Android: `callsdk-xxx.aar`；iOS: `JJCallKit.xcframework` |

用户**不应**再手动集成 AAR / Framework、写 Bridging Header。

---

## 2. 工程结构

```
JJSDK/Flutter/
├── jj_callkit/                          # 【新建】对外 Plugin
│   ├── pubspec.yaml
│   ├── README.md                        # 用户主文档
│   ├── CHANGELOG.md
│   ├── doc/
│   │   ├── integration_android.md       # Android 宿主配置
│   │   ├── integration_ios.md           # iOS 宿主配置
│   │   ├── api_reference.md             # Dart API 全文
│   │   ├── events.md                    # 事件流说明
│   │   ├── error_codes.md               # 统一错误码
│   │   └── migration.md                 # 版本升级指南
│   ├── lib/
│   │   ├── jj_callkit.dart              # export
│   │   └── src/
│   │       ├── jj_callkit.dart          # 对外 Facade
│   │       ├── jj_callkit_platform.dart
│   │       ├── method_channel_jj_callkit.dart
│   │       ├── models/                  # CallConfig, CallInfo, AgentConfig...
│   │       ├── enums/                   # CallState, CallDirection, AudioRoute...
│   │       ├── events/                  # CallEvent sealed class
│   │       └── exceptions.dart          # JJCallException
│   ├── android/
│   │   ├── libs/callsdk-1.3.7.aar
│   │   └── src/main/kotlin/.../JjCallKitPlugin.kt
│   ├── ios/
│   │   ├── Frameworks/JJCallKit.xcframework
│   │   ├── Classes/JjCallKitPlugin.swift
│   │   └── jj_callkit.podspec
│   └── example/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── pages/                   # 登录、拨号、通话中、设置
│       │   └── services/                # 薄封装，演示最佳实践
│       ├── android/                     # 仅 example 必要配置
│       └── ios/
├── CallSDK_Android_API.md               # 内部参考
├── JJCallKit_iOS_API.md
├── Android_Flutter桥接开发文档.md
├── iOS_Flutter桥接开发文档.md
└── Flutter插件实施计划.md               # 本文
```

**Plugin 命名**：`jj_callkit`（pub 包名）；Dart 入口类 `JJCallKit`。

---

## 3. 统一 Flutter API 设计（对外契约）

以下 API 为**跨平台公开契约**，文档与 Demo 均以此为准。Native 差异在 Plugin 内消化。

### 3.1 初始化 & 生命周期

```dart
class JJCallKit {
  static Stream<CallEvent> get events;

  /// 初始化并登录，Future 在 SIP 注册成功后 complete（两端语义一致）
  static Future<void> init(CallConfig config);

  static Future<void> logout();
  static Future<void> release();

  static Future<bool> canMakeCall();
  static Future<LoginInfo?> getLoginInfo();
  static Future<CallInfo?> getCurrentCallInfo();
  static String errorDescription(int code);
}
```

### 3.2 通话

```dart
static Future<CallInfo> makeCall(String phoneNumber, {Map<String, dynamic>? userData});
static Future<void> hangupCall();
static Future<void> sendDTMF(String digit);
```

### 3.3 通话控制

```dart
static Future<void> setMute(bool enabled);
static Future<bool> isMuted();
static Future<void> setSpeaker(bool enabled);
static Future<bool> isSpeakerOn();
static Future<AudioRoute> getCurrentAudioRoute();
```

### 3.4 外显号码

```dart
static Future<AgentConfig> getAgentConfig();
static Future<List<DisplayNumber>> getDisplayNumberList();
static Future<NumberGroupListResult> getNumberGroupList({int page = 1, int pageSize = 20});
static Future<void> updateDisplayNumber(String selectNumber);
static Future<void> updateNumberGroup({String? id, String? name});
```

### 3.5 统一模型（Dart）

| 模型 | 字段（跨平台一致） |
|------|-------------------|
| `CallConfig` | `username`, `password?`, `passwordPk?`, `environment`, `logConfig?` |
| `CallInfo` | `callId`, `phoneNumber`, `direction`, `state`, `startTime` |
| `CallDirection` | `app`, `server` |
| `CallState` | `calling`, `alerting`, `answered`, `released`, `failed` |
| `AudioRoute` | `receiver`, `speaker`, `bluetooth` |
| `AgentConfig` | `callerStrategy`, `selectNumber`, `numberGroup`, ... |
| `CallEvent` | `sipConnected`, `callAlerting`, `callAnswered`, `serverCall`, `kicked`, ... |

枚举与事件名**一律小写字符串**过 Channel，Dart 侧转成强类型。

---

## 4. 原生 SDK 差异与调整策略

**结论先行**：**第一期不强制改 JJCallKit / CallSDK 源码**，90% 差异在 Plugin 适配层解决；下列「建议改原生」项可在 v1.1 原生 SDK 版本中补齐，降低 Plugin 维护成本。

### 4.1 差异总表

| 能力 | Android (CallSDK) | iOS (JJCallKit) | Flutter 统一行为 | 调整层级 |
|------|-------------------|-----------------|------------------|----------|
| 初始化 | `init` 一步 | `initial` + `loginWithAccount` | `init()` 一步，Future 等 SIP 就绪 | **Plugin**（iOS 等 `kSIPConnectedNotification`） |
| 登出 | `logout()` 同步 | `logoutWithCompletion:` | `logout()` Future 在完成后结束 | **Plugin**（iOS 用 completion） |
| 销毁 | `release()` | `cleanupSDK()` | `release()` | **Plugin** |
| 通话状态 | `CallStateListener` | `kSIPCall*Notification` | 统一 `CallEvent` | **Plugin** |
| 服务端来电 | `OnServerCallListener` 一次 | `kSocketCallStatusNotification` 多条 | `serverCall` + 后续状态事件；iOS Plugin 去重 | **Plugin** |
| 外呼失败 | `MakeCallCallback.onFailed` | `makeCall` failure Block | `JJCallException`，不发重复 `callFailed` | **Plugin** |
| 外显策略 | `getAgentConfig` | `getCallerStrategyWithSuccess` | `getAgentConfig()`，字段名 Plugin 归一 | **Plugin** |
| 外显号码列表 | `queryDisplayNumberList` | `getDisplayNumberListWithSuccess` | 同左 | **Plugin** |
| 号码组列表 | `queryNumberGroupList(page, pageSize)` | `getDisplayNumberGroupListWithSuccess`（无分页） | `getNumberGroupList`；iOS 忽略分页参数，一次返回全量 | **Plugin** + **文档说明** |
| 设号码组 | `ById` / `ByName` 两个 API | 仅 `numberGroup`（ID） | `updateNumberGroup(id: / name:)` | **Plugin**；iOS 仅支持 `id`，见 4.2 |
| 音频路由查询 | `getCurrentAudioRoute()` | 无等价 API，仅 `isLoudSpeakerOn` | `getCurrentAudioRoute()` | **Plugin 近似** + **建议 iOS 原生补** |
| 音频路由变化 | `AudioRouteChangeListener` | 无公开 Listener | `audioRouteChanged` 事件 | **Plugin 近似** + **建议 iOS 原生补** |
| 能否外呼 | 无直接 API | `canMakeCall()` | `canMakeCall()` | **Plugin**（Android 用 `getCurrentCallInfo` + 登录态推断） |
| 接听来电 | SDK 自动接听 | `acceptCall`（`autoAnswerIncomingCall=NO` 时） | 默认自动；文档说明 iOS 可关 | **文档**；Flutter v1 不暴露 |
| 错误文案 | 错误码在 Listener/Callback | `errorDescriptionForCode` | `JJCallKit.errorDescription(code)` | **Plugin/Dart** |
| 登录信息 | `getLoginInfo()` | 登录 success 字典 | `getLoginInfo()` | **Plugin**（iOS 缓存 login 结果） |
| userData 限制 | JSONObject < 256 字节 | NSDictionary < 255 字节 | 文档写 **255 字节** | **文档** |
| 后台保活 | 前台 Service（Demo） | `UIBackgroundModes` audio + CallKit | 用户文档写清宿主配置 | **文档** + **可选 Plugin 补 Android Service** |

### 4.2 是否必须改原生 SDK？

#### ✅ 第一期：不改原生 SDK 即可上线（Plugin 适配）

以下用 Plugin **完全可以**做，不阻塞 v1.0：

1. init / logout / release 语义统一  
2. 全部 MethodChannel 命令型 API  
3. EventChannel 事件名与 payload 统一  
4. 外显号码（iOS 号码组仅 by ID；by name 仅 Android 可用时在 Dart 做 `Platform.isAndroid` 或调用了直接报错）  
5. 错误码与 `errorDescription`  
6. `getNumberGroupList` 分页（iOS 返回 `{ list: 全量 }`）

#### ⚠️ 建议改原生 SDK（v1.1，非阻塞 v1.0）

| 建议项 | 平台 | 建议改动 | 收益 |
|--------|------|----------|------|
| 统一 init 入口 | iOS JJCallKit | 新增 `loginWithConfig:completion:`，内部 `initial`+`login`，成功回调与 `kSIPConnected` 对齐 | Plugin 代码更简单，减少竞态 |
| 音频路由 API | iOS JJCallKit | 对齐 Android：`getCurrentAudioRoute()` + `AudioRouteChangeListener` | Flutter `getCurrentAudioRoute` / `audioRouteChanged` 准确 |
| 号码组 by name | iOS JJCallKit | 新增 `updateAgentNumberGroupByName` | 与 Android API 对称 |
| 能否外呼 | Android CallSDK | 新增 `canMakeCall(): Boolean` | 与 iOS 一致，Plugin 不用猜状态 |
| 统一 AgentConfig 模型 | 双端 | 返回 JSON 字段名完全一致（`callerStrategy`、`numberGroup` 等） | 减少 Plugin 映射表 |
| logout 完成回调 | Android CallSDK | 新增 `logout(callback)` 或保证 logout 异步完成再返回 | 与 iOS `logoutWithCompletion` 对齐 |

#### ❌ 不建议为 Flutter 大改原生

- 不要把 PJSIP / CallKit 逻辑搬到 Dart  
- 不要为了 Flutter 改 SIP 协议或 WebSocket 格式  
- 不要合并 Android/iOS 成一套 Native 代码（成本过高）

### 4.3 对用户文档中的「平台差异」说明

即使 API 统一，以下行为需在 **用户对接文档** 中明确（不算 API 不一致，算平台特性）：

| 项 | Android | iOS |
|----|---------|-----|
| 锁屏通话 UI | 系统通知 + 应用内 UI | 系统 CallKit 绿条 + 应用内 UI |
| 模拟器 | 可测 SIP，音频有限 | 无 CallKit 外呼/绿条，锁屏需真机 |
| 号码组设置 | 支持 ID 或名称 | **仅 ID**（v1.0） |
| 蓝牙路由 | `bluetooth` 可准确返回 | v1.0 可能仅 `receiver`/`speaker`，蓝牙待 iOS 原生补 API |
| 麦克风权限 | 运行时 `permission_handler` | Info.plist 文案 + 运行时申请 |

---

## 5. Demo（example）计划

Demo 是**对外用户的第一份可运行参考**，功能对齐原生 Demo，UI 用 Flutter 自绘。

### 5.1 页面与流程

```
启动 → 登录页 → 拨号页 → 通话页
              ↓              ↑
         外显设置页    服务端来电（events 弹通话页）
```

| 页面 | 功能 | 对应原生 Demo |
|------|------|---------------|
| `LoginPage` | 账号/密码/环境，调 `init` | Android LoginActivity / iOS 登录 |
| `DialPage` | 拨号盘、userData 可选、外呼 | DialActivity / DialViewController |
| `ActiveCallPage` | 计时、静音、扬声器、DTMF、挂断 | CallActivity / ActiveCallViewController |
| `SettingsPage` | 外显号码/号码组 | CallSettingsActivity / CallSettingsViewController |

### 5.2 Demo 必须演示的集成要点

- [ ] `permission_handler` 申请麦克风  
- [ ] `JJCallKit.events` 全局监听（在 `main` 或顶层 `StatefulWidget`）  
- [ ] `ServerCallEvent` → `Navigator` 打开通话页，**不再 makeCall**  
- [ ] `KickedEvent` → 回登录页并 `logout`  
- [ ] 错误码 Toast（`-310` 黑名单、`-311` 风控等）  
- [ ] 退出登录 / 销毁 SDK 按钮（演示 `logout` / `release` 区别）

### 5.3 Demo 不提供

- 不提供「必须用这个 UI」——文档写明 UI 可完全自定义  
- 不把 Demo 代码打进 Plugin `lib/`（仅 `example/`）

---

## 6. 用户对接文档计划

### 6.1 README.md（Plugin 根目录，用户第一眼）

1. 简介与最低版本（Flutter / iOS 12.4+ / Android minSdk）  
2. 快速开始（3 步：依赖 → 权限 → init + makeCall）  
3. 链接到 `doc/` 详细文档  
4. 平台配置摘要（Android 权限自动合并；iOS 必须配 Info.plist）  
5. 与原生 SDK 版本对应表（如 jj_callkit 0.1.0 → callsdk 1.3.7 + JJCallKit x.x）

### 6.2 doc/integration_android.md

- `pubspec.yaml` 依赖方式（git / 私有 pub / path）  
- 无需手动拷 AAR  
- 混淆（consumer rules 已带）  
- 麦克风运行时权限示例  
- 可选：前台 Service 说明（若 Plugin 后续内置）

### 6.3 doc/integration_ios.md

- 无需手动拖 Framework  
- **必做**：`NSMicrophoneUsageDescription`、`UIBackgroundModes` audio  
- CallKit / 真机验收说明  
- 模拟器限制

### 6.4 doc/api_reference.md

- 完整 Dart API（与 3 节一致）  
- 每个方法的参数、返回值、异常  
- `CallConfig` / `CallInfo` 字段说明

### 6.5 doc/events.md

- `JJCallKit.events` 订阅方式  
- 每个 `CallEvent` 类型、触发时机、payload  
- 状态机图（calling → alerting → answered → released）  
- 服务端来电时序图

### 6.6 doc/error_codes.md

- 统一错误码表（与 Android/iOS 原生一致）  
- `JJCallException` 处理示例  
- 常见错误排查

### 6.7 doc/migration.md

- Plugin 版本升级  
- 若原生 SDK 升级导致行为变化

---

## 7. 实施阶段与排期

### Phase 0：准备（3~5 天）

- [ ] `flutter create --template=plugin` 创建 `jj_callkit`  
- [ ] 锁定原生二进制版本：callsdk-1.3.7.aar、JJCallKit xcframework（从 VoIPManagerFramework 编出）  
- [ ] 定稿 MethodChannel / EventChannel 协议（与桥接文档 4 节一致）  
- [ ] 定稿 Dart 公开 API（本文 3 节）

### Phase 1：MVP Plugin（2~3 周）

- [ ] Android `JjCallKitPlugin.kt`：init / logout / makeCall / hangup + 核心事件  
- [ ] iOS `JjCallKitPlugin.swift`：同上，init 等 SIP 连接  
- [ ] Dart：`JJCallKit`、`CallConfig`、`CallEvent`、`JJCallException`  
- [ ] example：登录 + 外呼 + 通话中 + 挂断  
- [ ] README 快速开始

**里程碑**：双端真机跑通一条外呼。

### Phase 2：完整能力（1~2 周）

- [ ] 静音 / 扬声器 / DTMF / getCurrentCallInfo  
- [ ] serverCall / kicked / audioRouteChanged（iOS 路由按 4.2 近似）  
- [ ] 外显号码全套 API  
- [ ] example：外显设置页 + 服务端来电  
- [ ] doc：integration_*、events、error_codes

**里程碑**：功能对齐原生 Demo 主路径。

### Phase 3：对外发布（1 周）

- [ ] API 文档 api_reference.md 补全  
- [ ] CHANGELOG、版本号、LICENSE  
- [ ] 真机回归清单（桥接文档验证顺序）  
- [ ] 评审：Platform 差异是否在文档写清  
- [ ] 发布：私有 Git tag / pub.dev（视公司策略）

### Phase 4：原生 SDK 对齐（可选，v1.1）

- [ ] iOS：`getCurrentAudioRoute` + 路由监听  
- [ ] iOS：号码组 by name  
- [ ] Android：`canMakeCall`  
- [ ] 双端：AgentConfig 字段统一  
- [ ] Plugin 删适配 hack，更新 migration.md

---

## 8. 质量与验收标准

### 8.1 功能验收（双端真机）

与桥接文档验证顺序一致：

1. init → `sipConnected`  
2. makeCall → callAlerting → callAnswered → hangup → callReleased  
3. 静音 / 扬声器 / DTMF  
4. serverCall（direction=server，不重复弹窗）  
5. kicked  
6. logout → release → 再 init 成功  
7. 外显查询与设置  
8. iOS 锁屏 CallKit 条；Android 后台通话（按 SDK 能力）

### 8.2 API 一致性验收

- [ ] 同一 Dart 调用在 Android/iOS 返回结构相同（字段名、类型）  
- [ ] 同一错误场景错误码相同（如 -302 未登录）  
- [ ] 文档中列出的平台差异均有对应说明或 `@platform` 标注

### 8.3 对外文档验收

- [ ] 新用户仅读 README + integration_* 能集成成功  
- [ ] 不读桥接文档也能完成业务开发  
- [ ] example 与文档代码片段一致

---

## 9. 版本与依赖关系

```
jj_callkit 0.1.0
├── embeds callsdk 1.3.7 (Android)
├── embeds JJCallKit x.x.x (iOS, 来自 VoIPManagerFramework 某 tag)
└── requires Flutter >= 3.16, Dart >= 3.2
```

Plugin 版本号**独立**于原生 SDK。原生 SDK 升级时：

1. 替换 `android/libs` / `ios/Frameworks`  
2. 跑回归清单  
3. 更新 CHANGELOG 与 README 中的「原生 SDK 对应版本」  
4. 若有 Breaking Change，升 Plugin minor/major

---

## 10. 决策摘要

| 问题 | 决策 |
|------|------|
| 按桥接文档做吗？ | **是**，Plugin 实现严格遵循两份桥接文档的 Channel 协议与事件名 |
| 给用户什么？ | **Plugin + example Demo + doc/**，不是只给内部桥接 md |
| 要改 JJCallKit / CallSDK 吗？ | **v1.0 不改**，Plugin 适配；**v1.1 建议**按 4.2 小步增强对称性 |
| Flutter API 谁定义？ | **Dart 层唯一契约**（本文 3 节），Native 向它对齐，不是向各自 Demo 暴露 |
| 和 Swift Demo 关系？ | Demo 是 UI/流程参考；Flutter example 复刻流程，API 走 `JJCallKit` |

---

## 11. 下一步行动

1. **确认** Plugin 包名 `jj_callkit` 与发布方式（私有 Git / pub.dev）  
2. **执行 Phase 0**：创建工程、拷贝 AAR/xcframework  
3. **并行**：一人 Android Plugin，一人 iOS Plugin，一人 Dart API + example 骨架  
4. **原生组 backlog**：评估 4.2「建议改原生」项是否纳入下一版 JJCallKit / CallSDK  

确认后可按 Phase 1 开始写代码；需要时可再拆「Phase 1 任务/issue 列表」到项目管理工具。
