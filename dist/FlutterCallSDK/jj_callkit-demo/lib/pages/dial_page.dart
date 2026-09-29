import 'package:flutter/material.dart';
import 'package:jj_callkit/jj_callkit.dart';

import 'call_page.dart';
import 'login_page.dart';
import 'settings_page.dart';

class DialPage extends StatefulWidget {
  const DialPage({super.key});

  static const route = '/dial';

  @override
  State<DialPage> createState() => _DialPageState();
}

class _DialPageState extends State<DialPage> {
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _call() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      _toast('请输入号码');
      return;
    }
    setState(() => _busy = true);
    try {
      final call = await JJCallKit.makeCall(phone);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CallPage(call: call)),
      );
    } on JJCallException catch (error) {
      _toast('${error.code} ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await JJCallKit.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拨号'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: '外显号码',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: '登出',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '对方号码',
                hintText: '13800138000',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _call,
              child: Text(_busy ? '呼叫中…' : '呼叫'),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () async {
                await JJCallKit.release();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              },
              child: const Text('销毁 SDK'),
            ),
          ],
        ),
      ),
    );
  }
}
