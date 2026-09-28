import 'dart:async';

import 'package:flutter/services.dart';

import 'events.dart';
import 'jj_callkit_platform.dart';

class MethodChannelJjCallkit extends JjCallkitPlatform {
  MethodChannelJjCallkit() {
    _events.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _controller.add(CallEvent.fromMap(Map<String, dynamic>.from(event)));
        }
      },
      onError: _controller.addError,
    );
  }

  static const MethodChannel _methods = MethodChannel('com.jj/callkit/methods');
  static const EventChannel _events = EventChannel('com.jj/callkit/events');

  final StreamController<CallEvent> _controller =
      StreamController<CallEvent>.broadcast();

  @override
  Stream<CallEvent> get events => _controller.stream;

  @override
  Future<void> init(Map<String, dynamic> args) async {
    await _methods.invokeMethod<void>('init', args);
  }

  @override
  Future<void> logout() async {
    await _methods.invokeMethod<void>('logout');
  }

  @override
  Future<void> release() async {
    await _methods.invokeMethod<void>('release');
  }

  @override
  Future<bool> canMakeCall() async {
    return await _methods.invokeMethod<bool>('canMakeCall') ?? false;
  }

  @override
  Future<Map<String, dynamic>?> getLoginInfo() async {
    return asStringKeyMap(await _methods.invokeMethod<dynamic>('getLoginInfo'));
  }

  @override
  Future<Map<String, dynamic>?> getCurrentCallInfo() async {
    return asStringKeyMap(
      await _methods.invokeMethod<dynamic>('getCurrentCallInfo'),
    );
  }

  @override
  Future<Map<String, dynamic>> makeCall(Map<String, dynamic> args) async {
    final value = await _methods.invokeMethod<dynamic>('makeCall', args);
    return asStringKeyMap(value) ?? <String, dynamic>{};
  }

  @override
  Future<void> hangupCall() async {
    await _methods.invokeMethod<void>('hangupCall');
  }

  @override
  Future<void> sendDTMF(String digit) async {
    await _methods.invokeMethod<void>('sendDTMF', {'digit': digit});
  }

  @override
  Future<void> setMute(bool enabled) async {
    await _methods.invokeMethod<void>('setMute', {'enabled': enabled});
  }

  @override
  Future<bool> isMuted() async {
    return await _methods.invokeMethod<bool>('isMuted') ?? false;
  }

  @override
  Future<void> setSpeaker(bool enabled) async {
    await _methods.invokeMethod<void>('setSpeaker', {'enabled': enabled});
  }

  @override
  Future<bool> isSpeakerOn() async {
    return await _methods.invokeMethod<bool>('isSpeakerOn') ?? false;
  }

  @override
  Future<String> getCurrentAudioRoute() async {
    return await _methods.invokeMethod<String>('getCurrentAudioRoute') ??
        'receiver';
  }

  @override
  Future<Map<String, dynamic>> getAgentConfig() async {
    final value = await _methods.invokeMethod<dynamic>('getAgentConfig');
    return asStringKeyMap(value) ?? <String, dynamic>{};
  }

  @override
  Future<List<Map<String, dynamic>>> getDisplayNumberList() async {
    final value = await _methods.invokeMethod<dynamic>('getDisplayNumberList');
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getNumberGroupList(int page, int pageSize) async {
    final value = await _methods.invokeMethod<dynamic>('getNumberGroupList', {
      'page': page,
      'pageSize': pageSize,
    });
    return asStringKeyMap(value) ?? <String, dynamic>{'list': <dynamic>[]};
  }

  @override
  Future<void> updateDisplayNumber(String selectNumber) async {
    await _methods.invokeMethod<void>('updateDisplayNumber', {
      'selectNumber': selectNumber,
    });
  }

  @override
  Future<void> updateNumberGroup({String? id, String? name}) async {
    await _methods.invokeMethod<void>('updateNumberGroup', {
      'id': id,
      'name': name,
    });
  }
}
