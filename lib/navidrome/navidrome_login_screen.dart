import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'package:provider/provider.dart';
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
    if (ok && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('连接 Navidrome')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '输入 Navidrome 服务器信息',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Navidrome 是一个开源的自托管音乐服务器，\n支持 Subsonic 协议。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),

              // Server URL
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: 'http://192.168.1.100:4533',
                  prefixIcon: Icon(Icons.dns_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入服务器地址';
                  return NavidromeConfig.validateUrl(v.trim());
                },
              ),
              const SizedBox(height: 16),

              // Username
              TextFormField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入用户名';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入密码';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Test result
              if (_testResult != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _testSuccess == true
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: AppShape.sm,
                    border: Border.all(
                      color: _testSuccess == true ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess == true
                            ? Icons.check_circle
                            : Icons.error,
                        color:
                            _testSuccess == true ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testSuccess == true
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Test button
              OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(_testing ? '测试中...' : '测试连接'),
              ),
              const SizedBox(height: 12),

              // Connect button
              FilledButton.icon(
                onPressed: _connect,
                icon: const Icon(Icons.link),
                label: const Text('连接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
