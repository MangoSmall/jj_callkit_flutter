import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'events.dart';
import 'method_channel_jj_callkit.dart';

abstract class JjCallkitPlatform extends PlatformInterface {
  JjCallkitPlatform() : super(token: _token);

  static final Object _token = Object();
  static JjCallkitPlatform _instance = MethodChannelJjCallkit();

  static JjCallkitPlatform get instance => _instance;

  static set instance(JjCallkitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<CallEvent> get events;

  Future<void> init(Map<String, dynamic> args);
  Future<void> logout();
  Future<void> release();
  Future<bool> canMakeCall();
  Future<Map<String, dynamic>?> getLoginInfo();
  Future<Map<String, dynamic>?> getCurrentCallInfo();
  Future<Map<String, dynamic>> makeCall(Map<String, dynamic> args);
  Future<void> hangupCall();
  Future<void> sendDTMF(String digit);
  Future<void> setMute(bool enabled);
  Future<bool> isMuted();
  Future<void> setSpeaker(bool enabled);
  Future<bool> isSpeakerOn();
  Future<String> getCurrentAudioRoute();
  Future<Map<String, dynamic>> getAgentConfig();
  Future<List<Map<String, dynamic>>> getDisplayNumberList();
  Future<Map<String, dynamic>> getNumberGroupList(int page, int pageSize);
  Future<void> updateDisplayNumber(String selectNumber);
  Future<void> updateNumberGroup({String? id, String? name});
}

Map<String, dynamic>? asStringKeyMap(Object? value) {
  if (value == null) return null;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
