import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jj_callkit/jj_callkit.dart';

import 'pages/call_page.dart';
import 'pages/dial_page.dart';
import 'pages/login_page.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(const JJCallApp());
}

class JJCallApp extends StatefulWidget {
  const JJCallApp({super.key});

  @override
  State<JJCallApp> createState() => _JJCallAppState();
}

class _JJCallAppState extends State<JJCallApp> {
  StreamSubscription<CallEvent>? _events;
  bool _callOpen = false;

  @override
  void initState() {
    super.initState();
    _events = JJCallKit.events.listen(_onEvent, onError: (_) {});
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _onEvent(CallEvent event) {
    switch (event) {
      case ServerCallEvent(:final call):
        _openCall(call, incoming: true);
      case CallReleasedEvent():
        _closeCall();
      case CallFailedEvent(:final errorCode, :final errorMsg):
        _closeCall();
        _toast(errorMsg.isEmpty ? JJCallKit.errorDescription(errorCode) : errorMsg);
      case KickedEvent():
        _closeCall();
        _toast('账号在其他端登录，请重新登录');
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
          (_) => false,
        );
      case SipDisconnectedEvent():
        _closeCall();
        _toast('SIP 已断开，请重新登录');
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
          (_) => false,
        );
      default:
        break;
    }
  }

  void _openCall(CallInfo call, {required bool incoming}) {
    if (_callOpen) return;
    _callOpen = true;
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => CallPage(call: call, incoming: incoming),
      ),
    ).whenComplete(() => _callOpen = false);
  }

  void _closeCall() {
    if (!_callOpen) return;
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  void _toast(String message) {
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      title: 'JJ CallKit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6B4C)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
      routes: {
        DialPage.route: (_) => const DialPage(),
      },
    );
  }
}
