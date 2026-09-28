import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jj_callkit/jj_callkit.dart';

class CallPage extends StatefulWidget {
  const CallPage({super.key, required this.call, this.incoming = false});

  final CallInfo call;
  final bool incoming;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  StreamSubscription<CallEvent>? _events;
  late CallInfo _call;
  bool _muted = false;
  bool _speaker = false;
  DateTime? _answeredAt;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _call = widget.call;
    _events = JJCallKit.events.listen(_onEvent);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _answeredAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  void _onEvent(CallEvent event) {
    switch (event) {
      case CallAlertingEvent(:final call):
      case CallAnsweredEvent(:final call):
      case CallCallingEvent(:final call):
        setState(() {
          _call = call;
          if (event is CallAnsweredEvent) {
            _answeredAt ??= DateTime.now();
          }
        });
      case CallReleasedEvent():
        if (mounted) Navigator.of(context).maybePop();
      case CallFailedEvent(:final errorMsg, :final errorCode):
        _toast(errorMsg.isEmpty ? JJCallKit.errorDescription(errorCode) : errorMsg);
        if (mounted) Navigator.of(context).maybePop();
      case AudioRouteChangedEvent(:final route):
        setState(() => _speaker = route == AudioRoute.speaker);
      default:
        break;
    }
  }

  Future<void> _hangup() async {
    try {
      await JJCallKit.hangupCall();
    } on JJCallException catch (error) {
      _toast(error.message);
    }
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await JJCallKit.setMute(next);
    setState(() => _muted = next);
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speaker;
    await JJCallKit.setSpeaker(next);
    setState(() => _speaker = next);
  }

  String get _timer {
    final start = _answeredAt;
    if (start == null) return _call.state == CallState.alerting ? '振铃中' : '呼叫中';
    final elapsed = DateTime.now().difference(start);
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.incoming ? '来电' : '通话中')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(_call.phoneNumber, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(_call.direction == CallDirection.server ? '服务端发起' : '本机外呼'),
            const SizedBox(height: 8),
            Text(_timer, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            Wrap(
              spacing: 12,
              children: [
                for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'])
                  SizedBox(
                    width: 72,
                    child: OutlinedButton(
                      onPressed: () => JJCallKit.sendDTMF(digit),
                      child: Text(digit),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Action(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: _muted ? '取消静音' : '静音',
                  onPressed: _toggleMute,
                ),
                _Action(
                  icon: _speaker ? Icons.volume_up : Icons.hearing,
                  label: _speaker ? '扬声器' : '听筒',
                  onPressed: _toggleSpeaker,
                ),
                _Action(
                  icon: Icons.call_end,
                  label: '挂断',
                  color: Colors.red,
                  onPressed: _hangup,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(backgroundColor: color),
        ),
        Text(label),
      ],
    );
  }
}
