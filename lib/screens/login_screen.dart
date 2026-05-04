import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '密码'),
            Tab(text: '手机'),
            Tab(text: '二维码'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _PasswordLogin(),
          _PhoneLogin(),
          _QrLogin(),
        ],
      ),
    );
  }
}

// ─── 密码登录 ───

class _PasswordLogin extends StatefulWidget {
  const _PasswordLogin();

  @override
  State<_PasswordLogin> createState() => _PasswordLoginState();
}

class _PasswordLoginState extends State<_PasswordLogin> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithPassword(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text.trim(),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(
              labelText: '用户名',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Consumer<AuthProvider>(
            builder: (_, auth, __) => SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: auth.isLoading ? null : _login,
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('登录'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 手机验证码登录 ───

class _PhoneLogin extends StatefulWidget {
  const _PhoneLogin();

  @override
  State<_PhoneLogin> createState() => _PhoneLoginState();
}

class _PhoneLoginState extends State<_PhoneLogin> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _sendingCode = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() => _sendingCode = true);
    // API: /captcha/sent?phone=
    try {
      await context.read<AuthProvider>().sendCaptcha(phone);
    } catch (_) {}
    setState(() => _sendingCode = false);
    _startCountdown();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithPhone(
      _phoneCtrl.text.trim(),
      _codeCtrl.text.trim(),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '手机号',
              prefixIcon: Icon(Icons.phone_android),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    prefixIcon: Icon(Icons.message),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: FilledButton.tonal(
                  onPressed:
                      _sendingCode || _countdown > 0 ? null : _sendCode,
                  child: _sendingCode
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Consumer<AuthProvider>(
            builder: (_, auth, __) => SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: auth.isLoading ? null : _login,
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('登录'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 二维码登录 ───

class _QrLogin extends StatefulWidget {
  const _QrLogin();

  @override
  State<_QrLogin> createState() => _QrLoginState();
}

class _QrLoginState extends State<_QrLogin> {
  String? _qrUrl;
  String? _qrKey;
  bool _isLoading = true;
  String _statusText = '正在获取二维码...';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQr() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final keyData = await auth.getQrKey();
      _qrKey = keyData['key'] as String?;
      if (_qrKey != null) {
        _qrUrl = await auth.getQrCreate(_qrKey!);
        setState(() {
          _isLoading = false;
          _statusText = '请使用酷狗 App 扫描二维码';
        });
        _startPolling();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = '获取二维码失败，请重试';
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_qrKey == null) return;
      try {
        final auth = context.read<AuthProvider>();
        final code = await auth.checkQrStatus(_qrKey!);
        if (code == 200) {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() => _statusText = '登录成功');
            Navigator.pop(context);
          }
        } else if (code == 800) {
          setState(() => _statusText = '二维码已过期，请刷新');
          _pollTimer?.cancel();
        } else {
          setState(() => _statusText = '请使用酷狗 App 扫描二维码');
        }
      } catch (_) {}
    });
  }

  void _refresh() {
    _pollTimer?.cancel();
    _loadQr();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: _qrUrl != null
                    ? Image.network(
                        _qrUrl!,
                        width: 176,
                        height: 176,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.qr_code, size: 100, color: Colors.black),
                      )
                    : const Icon(Icons.qr_code, size: 100, color: Colors.black),
              ),
              const SizedBox(height: 20),
              Text(_statusText, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新二维码'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
