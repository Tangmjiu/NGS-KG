import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/responsive.dart';
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final tabBody = TabBarView(
      controller: _tabCtrl,
      children: const [
        _PhoneLogin(),
        _QrLogin(),
      ],
    );

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '登录',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '登录后同步歌单、收藏与播放记录',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 标准 Flutter TabBar
                    TabBar(
                      controller: _tabCtrl,
                      tabs: const [
                        Tab(text: '手机'),
                        Tab(text: '二维码'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: tabBody,
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: cs.outlineVariant),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    } catch (e, s) {
      Log.e('login_screen', 'error', e, s);
    }
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
    final cs = Theme.of(context).colorScheme;
    InputDecoration _dec({String? label, Widget? prefix, String? error}) {
      return InputDecoration(
        labelText: label,
        prefixIcon: prefix,
        errorText: error,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.next,
          maxLength: 11,
          decoration: _dec(
            label: '手机号',
            prefix: const Icon(Icons.phone_android),
            error: _phoneError,
          ),
          onChanged: (_) {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: _dec(
                  label: '验证码',
                  prefix: const Icon(Icons.message),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: FilledButton.tonal(
                onPressed: _sendingCode || _countdown > 0 ? null : _sendCode,
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
        setState(() {
          _isLoading = false;
          _statusText = '获取二维码失败，请重试';
        });
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
      if (mounted)
        setState(() {
          _isLoading = false;
          _statusText = '获取二维码失败，请重试';
        });
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
      } catch (e, s) {
        Log.e('login_screen', 'qr poll error', e, s);
      }
    });
  }

  Widget _buildQrImage() {
    final cs = Theme.of(context).colorScheme;
    final b64 = _base64Img;
    if (b64 == null || b64.isEmpty) {
      return Icon(Icons.qr_code, size: 80, color: cs.onSurface);
    }
    // base64 格式: data:image/png;base64,xxxx
    try {
      final data = b64.contains(',') ? b64.split(',')[1] : b64;
      return Image.memory(
        base64Decode(data),
        width: 136,
        height: 136,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.qr_code, size: 80, color: cs.onSurface),
      );
    } catch (_) {
      return Icon(Icons.qr_code, size: 80, color: cs.onSurface);
    }
  }

  void _refresh() {
    _pollTimer?.cancel();
    _loadQr();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading)
            const CircularProgressIndicator()
          else ...[
            // Music You 风格: 160×160 outlined 二维码卡片
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: _base64Img != null
                  ? _buildQrImage()
                  : Icon(Icons.qr_code, size: 80, color: cs.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新二维码'),
            ),
          ],
        ],
      ),
    );
  }
}
