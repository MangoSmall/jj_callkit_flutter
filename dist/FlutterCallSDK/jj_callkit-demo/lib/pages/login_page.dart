import 'package:flutter/material.dart';
import 'package:jj_callkit/jj_callkit.dart';
import 'package:permission_handler/permission_handler.dart';

import '../login_cache.dart';
import 'dial_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  CallEnvironment _environment = CallEnvironment.production;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final saved = await LoginCache.load();
    if (!mounted) return;
    setState(() {
      _username.text = saved.username;
      _password.text = saved.password;
      _environment = saved.environment;
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      _toast('请输入账号和密码');
      return;
    }
    await LoginCache.save(
      username: username,
      password: password,
      environment: _environment,
    );
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _toast('需要麦克风权限才能通话');
      return;
    }
    setState(() => _busy = true);
    try {
      await JJCallKit.init(CallConfig(
        username: username,
        password: password,
        environment: _environment,
        logConfig: const LogConfig(
          enableLog: true,
          logLevel: 1,
          consoleLogEnabled: true,
          fileLoggingEnabled: true,
        ),
      ));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(DialPage.route);
    } on JJCallException catch (error) {
      _toast('${error.code} ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: '账号',
              hintText: '6000@useasy',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: '密码'),
            obscureText: true,
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 12),
          SegmentedButton<CallEnvironment>(
            segments: const [
              ButtonSegment(value: CallEnvironment.production, label: Text('生产')),
              ButtonSegment(value: CallEnvironment.debug, label: Text('测试')),
            ],
            selected: {_environment},
            onSelectionChanged: (value) {
              setState(() => _environment = value.first);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _login,
            child: Text(_busy ? '登录中…' : '登录'),
          ),
          const SizedBox(height: 16),
          const Text(
            '登录会等到 SIP 注册成功才返回。返回前不要拨号。',
          ),
        ],
      ),
    );
  }
}
