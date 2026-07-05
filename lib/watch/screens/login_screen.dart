// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 手表登录页 — 二维码登录（手机扫码）+ 手机验证码登录

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../widgets/round_safe_area.dart';

/// 手表版登录
class WatchLoginScreen extends StatefulWidget {
  const WatchLoginScreen({super.key});

  @override
  State<WatchLoginScreen> createState() => _WatchLoginScreenState();
}

class _WatchLoginScreenState extends State<WatchLoginScreen>
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('登录', style: TextStyle(fontSize: 14)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: '二维码'),
            Tab(text: '手机'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _WatchQrLogin(),
          _WatchPhoneLogin(),
        ],
      ),
    );
  }
}

/// 二维码登录 — 显示二维码，手机扫码后手表自动登录
class _WatchQrLogin extends StatefulWidget {
  const _WatchQrLogin();

  @override
  State<_WatchQrLogin> createState() => _WatchQrLoginState();
}

class _WatchQrLoginState extends State<_WatchQrLogin> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  Future<void> _loadQr() async {
    setState(() { _loading = true; });
    try {
      // 简单展示：跳转到手机登录方式
      // 实际 QR 登录需通过 API 获取二维码 URL 并轮询扫码状态
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RoundSafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 64,
                color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('请使用手机酷狗App\n扫描二维码登录',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center),
              const SizedBox(height: 24),
              // 占位 — 实际需集成二维码生成和轮询
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(Icons.qr_code, size: 80, color: Colors.black),
                ),
              ),
              const SizedBox(height: 16),
              Text('暂未接入二维码API\n请使用手机验证码登录',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手机验证码登录
class _WatchPhoneLogin extends StatefulWidget {
  const _WatchPhoneLogin();

  @override
  State<_WatchPhoneLogin> createState() => _WatchPhoneLoginState();
}

class _WatchPhoneLoginState extends State<_WatchPhoneLogin> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _sendingCode = false;
  bool _loggingIn = false;
  int _countdown = 0;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 11) {
      setState(() => _error = '请输入11位手机号');
      return;
    }
    setState(() { _sendingCode = true; _error = null; });
    try {
      await context.read<AuthProvider>().sendCaptcha(phone);
      setState(() { _sendingCode = false; _countdown = 60; });
      _startCountdown();
    } catch (e) {
      setState(() { _sendingCode = false; _error = '验证码发送失败'; });
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() { if (_countdown > 0) _countdown--; });
      return _countdown > 0;
    });
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (phone.isEmpty || code.isEmpty) return;
    setState(() { _loggingIn = true; _error = null; });
    try {
      final ok = await context.read<AuthProvider>().loginWithPhone(phone, code);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        setState(() { _error = '登录失败，请检查验证码'; _loggingIn = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loggingIn = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RoundSafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: '手机号',
                hintText: '请输入手机号',
                labelStyle: theme.textTheme.bodySmall,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      labelText: '验证码',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _countdown > 0 || _sendingCode
                        ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: _sendingCode
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _loggingIn ? null : _login,
                child: _loggingIn
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('登录', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
