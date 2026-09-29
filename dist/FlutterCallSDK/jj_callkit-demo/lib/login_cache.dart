import 'package:jj_callkit/jj_callkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 示例工程把上次登录的账号、密码和环境留在本机。
/// 注销和杀掉进程都不会清掉，下次打开登录页直接填上。
class LoginCache {
  static const _usernameKey = 'jj_callkit.username';
  static const _passwordKey = 'jj_callkit.password';
  static const _environmentKey = 'jj_callkit.environment';

  static Future<({String username, String password, CallEnvironment environment})>
      load() async {
    final prefs = await SharedPreferences.getInstance();
    final environmentName = prefs.getString(_environmentKey);
    return (
      username: prefs.getString(_usernameKey) ?? '',
      password: prefs.getString(_passwordKey) ?? '',
      environment: environmentName == CallEnvironment.debug.wireName
          ? CallEnvironment.debug
          : CallEnvironment.production,
    );
  }

  static Future<void> save({
    required String username,
    required String password,
    required CallEnvironment environment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_passwordKey, password);
    await prefs.setString(_environmentKey, environment.wireName);
  }
}
