import 'package:flutter_test/flutter_test.dart';
import 'package:jj_callkit/jj_callkit.dart';

void main() {
  test('parses server call and failure events', () {
    final server = CallEvent.fromMap({
      'type': 'serverCall',
      'payload': {
        'callId': 'c1',
        'phoneNumber': '13800138000',
        'direction': 'server',
        'state': 'calling',
        'disNumber': '0210000',
        'callState': 2,
      },
    });
    expect(server, isA<ServerCallEvent>());
    final event = server as ServerCallEvent;
    expect(event.call.direction, CallDirection.server);
    expect(event.call.phoneNumber, '13800138000');
    expect(event.disNumber, '0210000');

    final failed = CallEvent.fromMap({
      'type': 'callFailed',
      'payload': {
        'callId': 'c1',
        'phoneNumber': '13800138000',
        'direction': 'app',
        'state': 'failed',
        'errorCode': -310,
        'errorMsg': '黑名单',
      },
    });
    expect(failed, isA<CallFailedEvent>());
    expect((failed as CallFailedEvent).errorCode, -310);
  });

  test('error descriptions stay aligned with native codes', () {
    expect(JJCallKit.errorDescription(-301), '通话权限被拒绝');
    expect(JJCallKit.errorDescription(-302), '未登录无法呼叫');
    expect(JJCallKit.errorDescription(-312), contains('255'));
  });

  test('agent config accepts a string or a list strategy', () {
    final fromList = AgentConfig.fromMap({
      'callerStrategy': ['enterpriseGroup'],
      'numberGroup': 'g1',
    });
    expect(fromList.usesNumberGroup, isTrue);

    final fromString = AgentConfig.fromMap({
      'callerStrategy': 'enterprise',
      'selectNumber': '0210000',
    });
    expect(fromString.callerStrategy, ['enterprise']);
    expect(fromString.usesNumberGroup, isFalse);
  });
}
