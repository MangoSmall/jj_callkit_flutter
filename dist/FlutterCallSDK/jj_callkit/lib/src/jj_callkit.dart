import 'dart:convert';

import 'package:flutter/services.dart';

import 'error_descriptions.dart';
import 'events.dart';
import 'exceptions.dart';
import 'jj_callkit_platform.dart';
import 'models.dart';

/// 给业务 App 用的唯一入口。
///
/// 不要再集成 `callsdk` AAR 或 `JJCallKit.xcframework`，也不要自己建 MethodChannel。
/// 登录、外呼、通话控制和外显号码都走这里。通话状态走 [events]。
class JJCallKit {
  JJCallKit._();

  static JjCallkitPlatform get _platform => JjCallkitPlatform.instance;

  /// SIP、通话、被踢、音频路由。可以多处监听。
  static Stream<CallEvent> get events => _platform.events;

  /// 初始化并登录。Future 在 SIP 注册成功后才结束，结束前不要拨号。
  static Future<void> init(CallConfig config) {
    return _guard(() => _platform.init(config.toMap()));
  }

  static Future<void> logout() => _guard(_platform.logout);

  /// 拆掉原生 SDK。下次使用必须重新 [init]。不要放在页面 `dispose` 里。
  static Future<void> release() => _guard(_platform.release);

  static Future<bool> canMakeCall() => _guard(_platform.canMakeCall);

  static Future<LoginInfo?> getLoginInfo() {
    return _guard(() async {
      final map = await _platform.getLoginInfo();
      if (map == null) return null;
      return LoginInfo.fromMap(map);
    });
  }

  static Future<CallInfo?> getCurrentCallInfo() {
    return _guard(() async {
      final map = await _platform.getCurrentCallInfo();
      if (map == null) return null;
      return CallInfo.fromMap(map);
    });
  }

  /// 主动外呼。[userData] 编码后必须小于 255 字节。
  ///
  /// 返回值只表示呼叫已发出。振铃、接通、挂断看 [events]，不要在这个 Future 里等接通。
  static Future<CallInfo> makeCall(
    String phoneNumber, {
    Map<String, dynamic>? userData,
  }) {
    return _guard(() async {
      _ensureUserDataSize(userData);
      final map = await _platform.makeCall({
        'phoneNumber': phoneNumber,
        'userData': userData,
      });
      return CallInfo.fromMap(map);
    });
  }

  static Future<void> hangupCall() => _guard(_platform.hangupCall);

  static Future<void> sendDTMF(String digit) =>
      _guard(() => _platform.sendDTMF(digit));

  static Future<void> setMute(bool enabled) =>
      _guard(() => _platform.setMute(enabled));

  static Future<bool> isMuted() => _guard(_platform.isMuted);

  static Future<void> setSpeaker(bool enabled) =>
      _guard(() => _platform.setSpeaker(enabled));

  static Future<bool> isSpeakerOn() => _guard(_platform.isSpeakerOn);

  static Future<AudioRoute> getCurrentAudioRoute() {
    return _guard(() async {
      return AudioRoute.parse(await _platform.getCurrentAudioRoute());
    });
  }

  static Future<AgentConfig> getAgentConfig() {
    return _guard(() async {
      return AgentConfig.fromMap(await _platform.getAgentConfig());
    });
  }

  static Future<List<DisplayNumber>> getDisplayNumberList() {
    return _guard(() async {
      final list = await _platform.getDisplayNumberList();
      return list.map(DisplayNumber.fromMap).toList();
    });
  }

  /// iOS 没有分页，会忽略 [page] / [pageSize] 并一次返回全量。
  static Future<NumberGroupListResult> getNumberGroupList({
    int page = 1,
    int pageSize = 20,
  }) {
    return _guard(() async {
      final map = await _platform.getNumberGroupList(page, pageSize);
      return NumberGroupListResult.fromMap(map);
    });
  }

  static Future<void> updateDisplayNumber(String selectNumber) {
    return _guard(() => _platform.updateDisplayNumber(selectNumber));
  }

  /// Android 可以传 [id] 或 [name]。iOS 只接受号码组 [id]，只传 [name] 会得到 `-4002`。
  static Future<void> updateNumberGroup({String? id, String? name}) {
    return _guard(() => _platform.updateNumberGroup(id: id, name: name));
  }

  static String errorDescription(int code) => describeJJCallError(code);

  static void _ensureUserDataSize(Map<String, dynamic>? userData) {
    if (userData == null || userData.isEmpty) return;
    final size = utf8.encode(jsonEncode(userData)).length;
    if (size >= 255) {
      throw JJCallException(-312, describeJJCallError(-312));
    }
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on JJCallException {
      rethrow;
    } on PlatformException catch (error) {
      final code = int.tryParse(error.code) ?? -9999;
      final message = (error.message == null || error.message!.isEmpty)
          ? describeJJCallError(code)
          : error.message!;
      throw JJCallException(code, message);
    }
  }
}
