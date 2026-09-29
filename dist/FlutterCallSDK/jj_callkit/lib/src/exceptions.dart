/// 插件抛给业务方的统一异常。
///
/// [code] 与 Android / iOS 原生错误码一致，例如 `-301` 麦克风、`-302` 未登录。
class JJCallException implements Exception {
  const JJCallException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'JJCallException($code): $message';
}
