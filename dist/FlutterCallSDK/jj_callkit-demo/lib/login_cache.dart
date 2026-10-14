import 'dart:io' show Platform;

import 'package:jj_callkit/jj_callkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 示例工程把上次登录的账号、密码和环境留在本机。
/// 注销和杀掉进程都不会清掉，下次打开登录页直接填上。
///
/// 鸿蒙官方 shared_preferences 暂无 ohos 实现，走内存缓存，避免登录卡住。
class LoginCache {
  static const _usernameKey = 'jj_callkit.username';
  static const _passwordKey = 'jj_callkit.password';
  static const _environmentKey = 'jj_callkit.environment';

  static String _memUsername = '';
  static String _memPassword = '';
  static CallEnvironment _memEnvironment = CallEnvironment.production;

  static bool get _useMemoryOnly => Platform.operatingSystem == 'ohos';

  static Future<({String username, String password, CallEnvironment environment})>
      load() async {
    if (_useMemoryOnly) {
      return (
        username: _memUsername,
        password: _memPassword,
        environment: _memEnvironment,
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final environmentName = prefs.getString(_environmentKey);
      return (
        username: prefs.getString(_usernameKey) ?? '',
        password: prefs.getString(_passwordKey) ?? '',
        environment: environmentName == CallEnvironment.debug.wireName
            ? CallEnvironment.debug
            : CallEnvironment.production,
      );
    } catch (_) {
      return (
        username: _memUsername,
        password: _memPassword,
        environment: _memEnvironment,
      );
    }
  }

  static Future<void> save({
    required String username,
    required String password,
    required CallEnvironment environment,
  }) async {
    _memUsername = username;
    _memPassword = password;
    _memEnvironment = environment;
    if (_useMemoryOnly) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_passwordKey, password);
      await prefs.setString(_environmentKey, environment.wireName);
    } catch (_) {
      // 无平台实现时忽略，内存已保存
    }
  }
}
