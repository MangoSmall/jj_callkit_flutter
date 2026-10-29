-keep class com.useasy.callsdk.** { *; }
-keep interface com.useasy.callsdk.** { *; }

# PJSIP / pjsua2 JNI 绑定；release R8 若不 keep 会裁掉导致通话崩溃
-keep class org.pjsip.pjsua2.** { *; }
-keep interface org.pjsip.pjsua2.** { *; }
