import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/api_client.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final _urlCtrl = TextEditingController();
  String _mode = ApiConfig.modeMjiutang;
  String _route = ApiConfig.routeCloudflare;
  bool _testing = false;
  String? _testResult;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = ApiConfig.instance;
    final mode = await config.getMode();
    final route = await config.getMjiutangRoute();
    final url = await config.getBaseUrl();
    final customUrl = await config.getCustomUrl();
    setState(() {
      _mode = mode;
      _route = route;
      _currentUrl = url;
      if (customUrl != null) _urlCtrl.text = customUrl;
    });
  }

  Future<void> _apply() async {
    final config = ApiConfig.instance;
    await config.setMode(_mode);
    if (_mode == ApiConfig.modeMjiutang) {
      await config.setMjiutangRoute(_route);
    } else {
      final custom = _urlCtrl.text.trim();
      if (custom.isNotEmpty) {
        final err = ApiConfig.validateUrl(custom);
        if (err != null) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(err)));
          }
          return;
        }
        await config.setCustomUrl(custom);
      }
    }
    _currentUrl = await config.getBaseUrl();
    ApiClient.instance.reinitialize();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API 地址已更新，即时生效')),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final config = ApiConfig.instance;
    final url = _mode == ApiConfig.modeMjiutang
        ? (_route == ApiConfig.routeCloudflare
            ? ApiConfig.cloudflareUrl
            : ApiConfig.chinaUrl)
        : _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final result = await ApiClient.testConnection(url);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult =
          result['ok'] == true ? '连接成功' : '连接失败: ${result['error'] ?? '未知错误'}';
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('API 服务器')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── 模式选择 ──
          const _SectionHeader('模式'),
          RadioListTile<String>(
            title: const Text('mjiutang'),
            subtitle: const Text('内置服务器，开箱即用'),
            value: ApiConfig.modeMjiutang,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
          ),
          RadioListTile<String>(
            title: const Text('自定义'),
            subtitle: const Text('使用自己搭建的 API 服务器'),
            value: ApiConfig.modeCustom,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
          ),
          const Divider(),

          // ── mjiutang 路线 ──
          if (_mode == ApiConfig.modeMjiutang) ...[
            const _SectionHeader('路线'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Cloudflare（海外路线）'),
                    subtitle: const Text(
                      'https://kugouapi.mjiutang.top\n中国大陆延迟较高，部分地区无法访问',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: ApiConfig.routeCloudflare,
                    groupValue: _route,
                    onChanged: (v) => setState(() => _route = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('中国内地'),
                    subtitle: const Text(
                      '不带域名可能不稳定',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: ApiConfig.routeChina,
                    groupValue: _route,
                    onChanged: (v) => setState(() => _route = v!),
                  ),
                ],
              ),
            ),
          ],

          // ── 自定义输入 ──
          if (_mode == ApiConfig.modeCustom) ...[
            const _SectionHeader('服务器地址'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  hintText: 'http://your-server:port',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: _urlCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _urlCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                style: Theme.of(context).textTheme.bodyMedium,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── 操作按钮 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.wifi_find, size: 18),
                    label: Text(_testing ? '测试中...' : '测试连接'),
                    onPressed: _testing ? null : _testConnection,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('恢复默认'),
                    onPressed: () async {
                      await ApiConfig.instance.resetToDefault();
                      ApiClient.instance.reinitialize();
                      _load();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已恢复默认设置')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testResult!.startsWith('连接成功')
                      ? Colors.green
                      : Colors.redAccent,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── 应用按钮 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _apply,
                child: const Text('应用'),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── 当前地址状态 ──
          Center(
            child: Text(
              '当前: $_currentUrl',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              )),
    );
  }
}
