import 'models.dart';

/// 通话与登录状态。订阅 [JJCallKit.events]，不要自己监听原生通知。
sealed class CallEvent {
  const CallEvent();

  factory CallEvent.fromMap(Map<String, dynamic> raw) {
    final type = raw['type']?.toString() ?? '';
    final payload = raw['payload'] is Map
        ? Map<String, dynamic>.from(raw['payload'] as Map)
        : <String, dynamic>{};
    switch (type) {
      case 'sipConnected':
        return const SipConnectedEvent();
      case 'sipConnectFailed':
        return SipConnectFailedEvent(
          errorCode: _intOf(payload['errorCode']),
          errorMsg: payload['errorMsg']?.toString() ?? '',
        );
      case 'kicked':
        return const KickedEvent();
      case 'callCalling':
        return CallCallingEvent(CallInfo.fromMap(payload));
      case 'callAlerting':
        return CallAlertingEvent(CallInfo.fromMap(payload));
      case 'callAnswered':
        return CallAnsweredEvent(CallInfo.fromMap(payload));
      case 'callReleased':
        return CallReleasedEvent(
          call: CallInfo.fromMap(payload),
          hangupType: _intOf(payload['hangupType']),
          reason: payload['reason']?.toString(),
        );
      case 'callFailed':
        return CallFailedEvent(
          call: CallInfo.fromMap(payload),
          errorCode: _intOf(payload['errorCode']),
          errorMsg: payload['errorMsg']?.toString() ?? '',
        );
      case 'dtmfReceived':
        return DtmfReceivedEvent(
          call: CallInfo.fromMap(payload),
          dtmf: payload['dtmf']?.toString() ?? '',
        );
      case 'serverCall':
        return ServerCallEvent(
          call: CallInfo.fromMap(payload),
          disNumber: payload['disNumber']?.toString(),
          callState: payload['callState'] is num
              ? (payload['callState'] as num).toInt()
              : null,
          callStateName: payload['callStateName']?.toString(),
        );
      case 'audioRouteChanged':
        return AudioRouteChangedEvent(AudioRoute.parse(payload['route']));
      case 'sipDisconnected':
        return const SipDisconnectedEvent();
      default:
        return UnknownCallEvent(type, payload);
    }
  }
}

final class SipConnectedEvent extends CallEvent {
  const SipConnectedEvent();
}

final class SipConnectFailedEvent extends CallEvent {
  const SipConnectFailedEvent({required this.errorCode, required this.errorMsg});

  final int errorCode;
  final String errorMsg;
}

final class KickedEvent extends CallEvent {
  const KickedEvent();
}

final class CallCallingEvent extends CallEvent {
  const CallCallingEvent(this.call);

  final CallInfo call;
}

final class CallAlertingEvent extends CallEvent {
  const CallAlertingEvent(this.call);

  final CallInfo call;
}

final class CallAnsweredEvent extends CallEvent {
  const CallAnsweredEvent(this.call);

  final CallInfo call;
}

final class CallReleasedEvent extends CallEvent {
  const CallReleasedEvent({
    required this.call,
    required this.hangupType,
    this.reason,
  });

  final CallInfo call;

  /// 0 主叫挂断，1 被叫挂断。
  final int hangupType;
  final String? reason;
}

final class CallFailedEvent extends CallEvent {
  const CallFailedEvent({
    required this.call,
    required this.errorCode,
    required this.errorMsg,
  });

  final CallInfo call;
  final int errorCode;
  final String errorMsg;
}

final class DtmfReceivedEvent extends CallEvent {
  const DtmfReceivedEvent({required this.call, required this.dtmf});

  final CallInfo call;
  final String dtmf;
}

/// 服务端来电。SDK 已经自动接听 SIP，打开页面即可，不要再 [JJCallKit.makeCall]。
final class ServerCallEvent extends CallEvent {
  const ServerCallEvent({
    required this.call,
    this.disNumber,
    this.callState,
    this.callStateName,
  });

  final CallInfo call;
  final String? disNumber;
  final int? callState;
  final String? callStateName;
}

final class AudioRouteChangedEvent extends CallEvent {
  const AudioRouteChangedEvent(this.route);

  final AudioRoute route;
}

final class SipDisconnectedEvent extends CallEvent {
  const SipDisconnectedEvent();
}

final class UnknownCallEvent extends CallEvent {
  const UnknownCallEvent(this.type, this.payload);

  final String type;
  final Map<String, dynamic> payload;
}

int _intOf(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
