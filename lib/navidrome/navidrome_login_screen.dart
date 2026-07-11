import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_route_wrapper.dart';
import 'navidrome_config.dart';
import 'navidrome_provider.dart';
import 'navidrome_service.dart';

class NavidromeLoginScreen extends StatefulWidget {
  const NavidromeLoginScreen({super.key});

  @override
  State<NavidromeLoginScreen> createState() => _NavidromeLoginScreenState();
}

class _NavidromeLoginScreenState extends State<NavidromeLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final config = NavidromeConfig.instance;
    final url = await config.getServerUrl();
    final user = await config.getUsername();
    final pass = await config.getPassword();
    if (mounted) {
      setState(() {
        if (url != null) _urlCtrl.text = url;
        if (user != null) _userCtrl.text = user;
        if (pass != null) _passCtrl.text = pass;
      });
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    final prov = context.read<NavidromeProvider>();
    // Create a temporary connection just for testing
    final service = NavidromeService();
    service.configure(
      _urlCtrl.text.trim(),
      _userCtrl.text.trim(),
      _passCtrl.text,
    );
    final ok = await service.ping();

    if (mounted) {
      setState(() {
        _testing = false;
        _testSuccess = ok;
        _testResult = ok ? '连接成功 ✓' : '连接失败，请检查地址和认证信息';
      });
    }
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<NavidromeProvider>();
    final ok = await prov.connect(
      _urlCtrl.text.trim(),
      _userCtrl.text.trim(),
      _passCtrl.text,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prov.error ?? '连接失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final form = _buildForm(cs);

    return ResponsiveLayoutBuilder(
      mobile: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('连接 Navidrome'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: form,
        ),
      ),
      desktop: (_) => Container(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: SizedBox(
              width: 420,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '关闭',
                    ),
                    SingleChildScrollView(child: form),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ColorScheme cs) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.wifi_tethering, size: 48, color: cs.primary),
          const SizedBox(height: 12),
          Text('连接到 Navidrome 服务器',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          TextFormField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: '服务器地址 *',
              hintText: 'http://192.168.1.100:4533',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入服务器地址';
              final err = NavidromeConfig.validateUrl(v.trim());
              return err;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _userCtrl,
            decoration: const InputDecoration(
              labelText: '用户名 *',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '请输入用户名' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscurePass,
            decoration: InputDecoration(
              labelText: '密码 *',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscurePass
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscurePass = !_obscurePass),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? '请输入密码' : null,
          ),
          const SizedBox(height: 8),
          if (_testResult != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testSuccess == true ? Colors.green : Colors.red,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: _testing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: cs.primary))
                      : const Icon(Icons.wifi_find, size: 18),
                  label: const Text('测试连接'),
                  onPressed: _testing ? null : _testConnection,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Consumer<NavidromeProvider>(
                  builder: (_, prov, __) => FilledButton.icon(
                    icon: prov.connecting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: cs.onPrimary))
                        : const Icon(Icons.link, size: 18),
                    label: const Text('连接'),
                    onPressed:
                        (prov.connecting || _testing) ? null : _connect,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Saved config indicator
          FutureBuilder<bool>(
            future: NavidromeConfig.instance.hasConfig(),
            builder: (_, snapshot) {
              if (snapshot.data == true) {
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.history, size: 20, color: cs.onSurfaceVariant),
                  title: Text('上次连接的服务器已保存',
                      style: Theme.of(context).textTheme.bodySmall),
                  subtitle: Text(_urlCtrl.text.isNotEmpty ? _urlCtrl.text : '',
                      style: Theme.of(context).textTheme.labelSmall),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
