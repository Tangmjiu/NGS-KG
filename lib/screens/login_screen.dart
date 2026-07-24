import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/logger.dart';
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
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 880;
    final tabBody = TabBarView(
      controller: _tabCtrl,
      children: const [
        _PhoneLogin(),
        _QrLogin(),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '手机'),
            Tab(text: '二维码'),
          ],
        ),
      ),
      body: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: tabBody,
              ),
            )
          : tabBody,
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
  final _captchaCtrl = TextEditingController();
  String? _errorMsg;
  bool _showCaptcha = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (username.isEmpty) {
      setState(() => _errorMsg = '请输入用户名');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMsg = '请输入密码');
      return;
    }
    setState(() => _errorMsg = null);
    final auth = context.read<AuthProvider>();
    String? captcha;
    if (_showCaptcha) {
      captcha = _captchaCtrl.text.trim();
      if (captcha.isEmpty) {
        setState(() => _errorMsg = '请输入验证码');
        return;
      }
    }
    final ok = await auth.loginWithPassword(
      username,
      password,
      captcha: captcha,
    );
    if (ok && mounted) {
      Navigator.pop(context);
    } else if (auth.errorMessage != null) {
      setState(() {
        _errorMsg = auth.errorMessage;
        if (_errorMsg?.contains('验证') == true) {
          _showCaptcha = true;
        }
      });
    }
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
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '用户名',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (_showCaptcha) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _captchaCtrl,
              decoration: InputDecoration(
                labelText: '验证码',
                prefixIcon: const Icon(Icons.security),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
          if (_errorMsg != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Theme.of(context).colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          const SizedBox(height: 16),
          Text(
            '提示：密码登录可能需要验证码验证，建议使用手机验证码登录',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
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
  String? _phoneError;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    setState(() => _phoneError = null);
    if (!_validatePhone(phone)) return;
    setState(() => _sendingCode = true);
    try {
      await context.read<AuthProvider>().sendCaptcha(phone);
    } catch (e, s) { Log.e('login_screen', 'error', e, s); }
    setState(() => _sendingCode = false);
    _startCountdown();
  }

  bool _validatePhone(String phone) {
    if (phone.isEmpty) {
      setState(() => _phoneError = '请输入手机号');
      return false;
    }
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      setState(() => _phoneError = '请输入正确的11位手机号');
      return false;
    }
    return true;
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
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.next,
            maxLength: 11,
            decoration: InputDecoration(
              labelText: '手机号',
              prefixIcon: const Icon(Icons.phone_android),
              errorText: _phoneError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '验证码',
                    prefixIcon: const Icon(Icons.message),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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

/// 二维码状态码（来自 API 文档）
///   0 → 已过期
///   1 → 等待扫码
///   2 → 已扫码，待确认
///   4 → 授权成功（返回 token）
const _qrStatusText = {
  0: '二维码已过期，请点击刷新',
  1: '请使用酷狗 App 扫描二维码',
  2: '已扫码，请在手机上确认登录',
  4: '登录成功',
};

class _QrLogin extends StatefulWidget {
  const _QrLogin();

  @override
  State<_QrLogin> createState() => _QrLoginState();
}

class _QrLoginState extends State<_QrLogin> {
  String? _base64Img;
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

      // 1. 获取二维码 key
      final keyData = await auth.getQrKey();
      final key = keyData['qrcode'] as String?;
      if (key == null || key.isEmpty) {
        setState(() { _isLoading = false; _statusText = '获取二维码失败，请重试'; });
        return;
      }
      _qrKey = key;

      // 2. 用 key 生成二维码图片（base64）
      final qrData = await auth.getQrCreate(key, qrimg: true);
      _base64Img = qrData['base64'] as String?;

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = _qrStatusText[1]!;
        });
        _startPolling();
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _statusText = '获取二维码失败，请重试'; });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // 1.5 秒间隔轮询（API 推荐 + 响应速度平衡）
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_qrKey == null) return;
      try {
        final auth = context.read<AuthProvider>();
        final code = await auth.checkQrStatus(_qrKey!);
        if (!mounted) return;

        // 4 = 授权成功
        if (code == 4) {
          _pollTimer?.cancel();
          setState(() => _statusText = '登录成功');
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context);
          return;
        }

        setState(() {
          _statusText = _qrStatusText[code] ?? '请使用酷狗 App 扫描二维码';
        });

        // 0 = 过期 → 停止轮询
        if (code == 0) _pollTimer?.cancel();
      } catch (e, s) { Log.e('login_screen', 'qr poll error', e, s); }
    });
  }

  Widget _buildQrImage() {
    final b64 = _base64Img;
    if (b64 == null || b64.isEmpty) {
      return Icon(Icons.qr_code, size: 100, color: Theme.of(context).colorScheme.onSurface);
    }
    // base64 格式: data:image/png;base64,xxxx
    try {
      final data = b64.contains(',') ? b64.split(',')[1] : b64;
      return Image.memory(
        base64Decode(data),
        width: 176, height: 176, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.qr_code, size: 100,
            color: Theme.of(context).colorScheme.onSurface),
      );
    } catch (_) {
      return Icon(Icons.qr_code, size: 100, color: Theme.of(context).colorScheme.onSurface);
    }
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
                width: 200, height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: _base64Img != null ? _buildQrImage()
                    : Icon(Icons.qr_code, size: 100,
                        color: Theme.of(context).colorScheme.onSurface),
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
