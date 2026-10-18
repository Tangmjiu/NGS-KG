// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import '../theme/app_theme_tokens.dart';
import '../ui/components/app_components.dart';
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
        if (url != null && _urlCtrl.text.isEmpty) _urlCtrl.text = url;
        if (user != null && _userCtrl.text.isEmpty) _userCtrl.text = user;
        if (pass != null && _passCtrl.text.isEmpty) _passCtrl.text = pass;
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
    if (_testing || context.read<NavidromeProvider>().connecting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    final service = NavidromeService();
    var ok = false;
    try {
      service.configure(
        _urlCtrl.text.trim(),
        _userCtrl.text.trim(),
        _passCtrl.text,
      );
      ok = await service.ping();
    } catch (_) {
      ok = false;
    } finally {
      service.dispose();
    }

    if (mounted) {
      setState(() {
        _testing = false;
        _testSuccess = ok;
        _testResult = ok ? '服务器连接正常，可以开始连接' : '连接失败，请检查地址和账号信息';
      });
    }
  }

  Future<void> _connect() async {
    final provider = context.read<NavidromeProvider>();
    if (_testing || provider.connecting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testResult = null;
      _testSuccess = null;
    });
    final ok = await provider.connect(
      _urlCtrl.text.trim(),
      _userCtrl.text.trim(),
      _passCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _testSuccess = false;
        _testResult = provider.error ?? '连接失败，请检查地址和账号信息';
      });
    }
  }

  void _clearTestResult(String _) {
    if (_testResult == null) return;
    setState(() {
      _testResult = null;
      _testSuccess = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = AppThemeTokens.of(context);
    final connecting =
        context.select<NavidromeProvider, bool>((p) => p.connecting);
    final busy = _testing || connecting;
    return Scaffold(
      body: SafeArea(
        child: AppPageBody(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: EdgeInsets.all(tokens.pagePadding),
                children: [
                  const AppPageHeader(
                    padding: EdgeInsets.zero,
                    title: '连接音乐服务器',
                    subtitle: '在这里聆听你的 Navidrome 音乐库',
                    showBack: true,
                  ),
                  SizedBox(height: tokens.sectionSpacing),
                  AppSurface(
                    child: Row(children: [
                      Icon(Icons.dns_outlined, size: 32, color: cs.primary),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Text(
                        '填写服务器地址与账号，即可浏览私人音乐收藏。',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      )),
                    ]),
                  ),
                  SizedBox(height: tokens.sectionSpacing),
                  Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _urlCtrl,
                            enabled: !busy,
                            decoration: const InputDecoration(
                              labelText: '服务器地址',
                              hintText: 'https://music.example.com',
                              prefixIcon: Icon(Icons.link_rounded),
                            ),
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            onChanged: _clearTestResult,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '请输入服务器地址';
                              }
                              return NavidromeConfig.validateUrl(value.trim());
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _userCtrl,
                            enabled: !busy,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: '用户名',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            onChanged: _clearTestResult,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? '请输入用户名'
                                    : null,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passCtrl,
                            enabled: !busy,
                            obscureText: _obscurePass,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: '密码',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _obscurePass ? '显示密码' : '隐藏密码',
                                icon: Icon(_obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: busy
                                    ? null
                                    : () => setState(
                                        () => _obscurePass = !_obscurePass),
                              ),
                            ),
                            onChanged: _clearTestResult,
                            onFieldSubmitted: (_) => _connect(),
                            validator: (value) =>
                                value == null || value.isEmpty ? '请输入密码' : null,
                          ),
                          const SizedBox(height: 24),
                          if (_testResult != null) ...[
                            AppSurface(
                              color: _testSuccess == true
                                  ? cs.secondaryContainer
                                  : cs.errorContainer,
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                Icon(
                                    _testSuccess == true
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.error_outline_rounded,
                                    color: _testSuccess == true
                                        ? cs.onSecondaryContainer
                                        : cs.onErrorContainer),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(_testResult!,
                                        style: TextStyle(
                                          color: _testSuccess == true
                                              ? cs.onSecondaryContainer
                                              : cs.onErrorContainer,
                                        ))),
                              ]),
                            ),
                            const SizedBox(height: 20),
                          ],
                          FilledButton.icon(
                            onPressed: busy ? null : _connect,
                            icon: connecting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.headphones_rounded),
                            label: Text(connecting ? '正在连接' : '连接音乐库'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: busy ? null : _testConnection,
                            icon: _testing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.wifi_find_rounded),
                            label: Text(_testing ? '正在测试' : '测试连接'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
