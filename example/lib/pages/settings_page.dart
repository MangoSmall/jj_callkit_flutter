import 'package:flutter/material.dart';
import 'package:jj_callkit/jj_callkit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AgentConfig? _config;
  List<DisplayNumber> _numbers = const [];
  List<NumberGroup> _groups = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await JJCallKit.getAgentConfig();
      if (config.usesNumberGroup) {
        final groups = await JJCallKit.getNumberGroupList(page: 1, pageSize: 50);
        _groups = groups.list;
        _numbers = const [];
      } else {
        _numbers = await JJCallKit.getDisplayNumberList();
        _groups = const [];
      }
      _config = config;
    } on JJCallException catch (error) {
      _error = '${error.code} ${error.message}';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectNumber(DisplayNumber item) async {
    final number = item.number;
    if (number == null) return;
    try {
      await JJCallKit.updateDisplayNumber(number);
      _toast('已切换外显号码 $number');
      await _load();
    } on JJCallException catch (error) {
      _toast(error.message);
    }
  }

  Future<void> _selectGroup(NumberGroup item) async {
    final id = item.id;
    if (id == null) return;
    try {
      await JJCallKit.updateNumberGroup(id: id);
      _toast('已切换号码组 ${item.displayName}');
      await _load();
    } on JJCallException catch (error) {
      _toast(error.message);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Scaffold(
      appBar: AppBar(title: const Text('外显号码')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_error != null)
                  ListTile(title: Text(_error!), textColor: Colors.red),
                if (config != null)
                  ListTile(
                    title: Text(config.usesNumberGroup ? '当前策略：号码组' : '当前策略：外显号码'),
                    subtitle: Text(
                      config.usesNumberGroup
                          ? '组 ID ${config.numberGroup ?? '未设置'}'
                          : '号码 ${config.selectNumber ?? '未设置'}',
                    ),
                  ),
                for (final item in _numbers)
                  ListTile(
                    title: Text(item.number ?? ''),
                    subtitle: Text('${item.province ?? ''} ${item.city ?? ''}'.trim()),
                    trailing: item.number == config?.selectNumber
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => _selectNumber(item),
                  ),
                for (final item in _groups)
                  ListTile(
                    title: Text(item.displayName),
                    subtitle: Text(item.id ?? ''),
                    trailing: item.id == config?.numberGroup
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => _selectGroup(item),
                  ),
              ],
            ),
    );
  }
}
