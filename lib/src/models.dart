/// 服务器环境。`debug` 走测试环境，其余走生产环境。
enum CallEnvironment {
  production,
  debug;

  String get wireName => this == CallEnvironment.debug ? 'debug' : 'production';
}

/// 通话方向。`app` 是本机外呼，`server` 是服务端发起、SDK 自动接听。
enum CallDirection {
  app,
  server;

  static CallDirection parse(Object? raw) {
    return raw?.toString().toLowerCase() == 'server'
        ? CallDirection.server
        : CallDirection.app;
  }

  String get wireName => name;
}

/// 通话状态。
enum CallState {
  calling,
  alerting,
  answered,
  released,
  failed;

  static CallState parse(Object? raw) {
    switch (raw?.toString().toLowerCase()) {
      case 'alerting':
        return CallState.alerting;
      case 'answered':
        return CallState.answered;
      case 'released':
        return CallState.released;
      case 'failed':
        return CallState.failed;
      default:
        return CallState.calling;
    }
  }

  String get wireName => name;
}

/// 音频输出。iOS 以及当前内置的 Android SDK 1.3.3 只保证听筒和扬声器。
enum AudioRoute {
  receiver,
  speaker,
  bluetooth;

  static AudioRoute parse(Object? raw) {
    switch (raw?.toString().toLowerCase()) {
      case 'speaker':
        return AudioRoute.speaker;
      case 'bluetooth':
        return AudioRoute.bluetooth;
      default:
        return AudioRoute.receiver;
    }
  }

  String get wireName => name;
}

/// 日志。`logLevel`：0 错误，1 一般，2 全量。两端插件会各自映射到原生级别。
class LogConfig {
  const LogConfig({
    this.enableLog = false,
    this.logLevel = 1,
    this.consoleLogEnabled = false,
    this.fileLoggingEnabled = false,
    this.logFilePath,
  });

  final bool enableLog;
  final int logLevel;
  final bool consoleLogEnabled;
  final bool fileLoggingEnabled;
  final String? logFilePath;

  Map<String, dynamic> toMap() => {
        'enableLog': enableLog,
        'logLevel': logLevel,
        'consoleLogEnabled': consoleLogEnabled,
        'fileLoggingEnabled': fileLoggingEnabled,
        'logFilePath': logFilePath,
      };
}

/// 登录参数。`password` 与 `passwordPk` 二选一，都传时原生优先用 `passwordPk`。
class CallConfig {
  const CallConfig({
    required this.username,
    this.password,
    this.passwordPk,
    this.environment = CallEnvironment.production,
    this.logConfig,
  });

  final String username;
  final String? password;
  final String? passwordPk;
  final CallEnvironment environment;
  final LogConfig? logConfig;

  Map<String, dynamic> toMap() => {
        'username': username,
        'password': password,
        'passwordPk': passwordPk,
        'environment': environment.wireName,
        'logConfig': logConfig?.toMap(),
      };
}

/// 一通通话的快照。字段在两端一致。
class CallInfo {
  const CallInfo({
    required this.callId,
    required this.phoneNumber,
    required this.direction,
    required this.state,
    this.startTime = 0,
  });

  final String callId;
  final String phoneNumber;
  final CallDirection direction;
  final CallState state;
  final int startTime;

  factory CallInfo.fromMap(Map<String, dynamic> map) {
    return CallInfo(
      callId: '${map['callId'] ?? ''}',
      phoneNumber: '${map['phoneNumber'] ?? ''}',
      direction: CallDirection.parse(map['direction']),
      state: CallState.parse(map['state']),
      startTime: _asInt(map['startTime']),
    );
  }
}

/// 登录后业务需要的字段。不包含 token。
class LoginInfo {
  const LoginInfo({
    this.agentId,
    this.agentNumber,
    this.mobile,
    this.accountId,
  });

  final String? agentId;
  final String? agentNumber;
  final String? mobile;
  final String? accountId;

  factory LoginInfo.fromMap(Map<String, dynamic> map) {
    return LoginInfo(
      agentId: _asString(map['agentId']),
      agentNumber: _asString(map['agentNumber']),
      mobile: _asString(map['mobile']),
      accountId: _asString(map['accountId']),
    );
  }
}

/// 座席外显配置。`callerStrategy` 在 Android 是列表，iOS 可能是字符串，这里统一成列表。
class AgentConfig {
  const AgentConfig({
    this.id,
    this.agentName,
    this.mobile,
    this.agentNumber,
    this.callerStrategy = const [],
    this.selectNumber,
    this.numberGroup,
    this.sipNumber,
    this.numbers = const [],
    this.numberSelect,
  });

  final String? id;
  final String? agentName;
  final String? mobile;
  final String? agentNumber;
  final List<String> callerStrategy;
  final String? selectNumber;
  final String? numberGroup;
  final String? sipNumber;
  final List<String> numbers;
  final bool? numberSelect;

  bool get usesNumberGroup =>
      callerStrategy.any((item) => item.toLowerCase().contains('group'));

  factory AgentConfig.fromMap(Map<String, dynamic> map) {
    return AgentConfig(
      id: _asString(map['id'] ?? map['_id']),
      agentName: _asString(map['agentName']),
      mobile: _asString(map['mobile']),
      agentNumber: _asString(map['agentNumber']),
      callerStrategy: _asStringList(map['callerStrategy']),
      selectNumber: _asString(map['selectNumber']),
      numberGroup: _asString(map['numberGroup']),
      sipNumber: _asString(map['sipNumber']),
      numbers: _asStringList(map['numbers']),
      numberSelect: map['numberSelect'] as bool?,
    );
  }
}

class DisplayNumber {
  const DisplayNumber({
    this.id,
    this.status,
    this.number,
    this.province,
    this.city,
  });

  final String? id;
  final String? status;
  final String? number;
  final String? province;
  final String? city;

  factory DisplayNumber.fromMap(Map<String, dynamic> map) {
    return DisplayNumber(
      id: _asString(map['id']),
      status: _asString(map['status']),
      number: _asString(map['number']),
      province: _asString(map['province']),
      city: _asString(map['city']),
    );
  }
}

class NumberGroup {
  const NumberGroup({
    this.id,
    this.groupName,
    this.name,
    this.remark,
  });

  final String? id;
  final String? groupName;
  final String? name;
  final String? remark;

  String get displayName => groupName ?? name ?? id ?? '';

  factory NumberGroup.fromMap(Map<String, dynamic> map) {
    return NumberGroup(
      id: _asString(map['id']),
      groupName: _asString(map['groupName']),
      name: _asString(map['name']),
      remark: _asString(map['remark']),
    );
  }
}

class PageInfo {
  const PageInfo({
    this.pageSize,
    this.pageNumber,
    this.totalPage,
    this.total,
  });

  final int? pageSize;
  final int? pageNumber;
  final int? totalPage;
  final int? total;

  factory PageInfo.fromMap(Map<String, dynamic> map) {
    return PageInfo(
      pageSize: _asIntOrNull(map['pageSize']),
      pageNumber: _asIntOrNull(map['pageNumber']),
      totalPage: _asIntOrNull(map['totalPage']),
      total: _asIntOrNull(map['total']),
    );
  }
}

class NumberGroupListResult {
  const NumberGroupListResult({
    required this.list,
    this.pageInfo,
  });

  final List<NumberGroup> list;
  final PageInfo? pageInfo;

  factory NumberGroupListResult.fromMap(Map<String, dynamic> map) {
    final rawList = map['list'];
    final list = <NumberGroup>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map) {
          list.add(NumberGroup.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    final page = map['pageInfo'];
    return NumberGroupListResult(
      list: list,
      pageInfo: page is Map
          ? PageInfo.fromMap(Map<String, dynamic>.from(page))
          : null,
    );
  }
}

String? _asString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

int? _asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }
  if (value is String && value.isNotEmpty) return [value];
  return const [];
}
