# iOS 集成

业务工程不要再拖 `JJCallKit.xcframework`，也不要写 Bridging Header。Framework 在插件的 `ios/Frameworks` 里。

宿主 `ios/Runner/Info.plist` 必须有：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>用于语音通话</string>
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

Xcode：Signing & Capabilities → Background Modes → Audio。没配 `audio` 时，锁屏可能有通话条但没有声音。

插件和业务 App 都不要再 `import CallKit` 后创建 `CXProvider`。Framework 已经接了系统通话，第二套会抢通话。

模拟器可以走 SIP，但没有锁屏绿条，并可能看到 `CXErrorCodeRequestTransactionErrorUnentitled`。锁屏和 CallKit 用真机看。

`permission_handler` 需要在 Podfile 的 `post_install` 里打开麦克风权限宏：

```ruby
config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
  '$(inherited)',
  'PERMISSION_MICROPHONE=1',
]
```

`example/ios/Podfile` 里有一份可以直接抄。

设置外显号码组时传组 ID。只传名称会得到 `-4002`。

插件 pod 是 static，里面带的是动态 Framework。如果真机启动报找不到 `JJCallKit`，说明宿主没有把它 embed 进 App。先在 example 上 `pod install` 确认 `[CP] Embed Pods Frameworks` 里有这个 Framework。
