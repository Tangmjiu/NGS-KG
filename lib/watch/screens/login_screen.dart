// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表登录页 — 方式选择列表 → 二维码登录 / 手机验证码登录

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/logger.dart';
import '../utils/watch_layout.dart';
import '../widgets/round_list_tile.dart';
import '../widgets/watch_scaffold.dart';

/// 手表版登录入口：先选方式（Wear 上 TabBar 太挤，改为列表）。
class WatchLoginScreen extends StatelessWidget {
  const WatchLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    return WatchScaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          layout.listHorizontal,
          4,
          layout.listHorizontal,
          layout.bottomInset + 16,
        ),
        children: [
          RoundListTile(
            title: '二维码登录',
            subtitle: '手机酷狗 App 扫码',
            leading: const Icon(Icons.qr_code_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _WatchQrLoginScreen()),
            ),
          ),
          RoundListTile(
            title: '手机验证码登录',
            subtitle: '输入手机号与验证码',
            leading: const Icon(Icons.phone_iphone_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _WatchPhoneLoginScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  二维码登录：生成二维码 → 轮询扫码状态 → 成功自动返回
// ═══════════════════════════════════════════════════════════

class _WatchQrLoginScreen extends StatefulWidget {
  const _WatchQrLoginScreen();

  @override
  State<_WatchQrLoginScreen> createState() => _WatchQrLoginScreenState();
}

class _WatchQrLoginScreenState extends State<_WatchQrLoginScreen> {
  bool _loading = true;
  String? _error;
  Uint8List? _qrBytes;
  int _pollStatus = 1; // 1=等待扫码 2=已扫码 4=成功 0=过期
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  Future<void> _loadQr() async {
    setState(() {
      _loading = true;
      _error = null;
      _qrBytes = null;
      _pollStatus = 1;
    });
    try {
      final authService = context.read<AuthService>();
      final keyData = await authService.getQrKey();
      final key = keyData['key'] as String?;
      if (key == null || key.isEmpty) {
        throw const FormatException('二维码接口未返回有效凭据');
      }

      final fallbackImage = keyData['qrimg'] as String?;
      Uint8List? qrBytes;
      try {
        final qrData = await authService.getQrCreate(key, qrimg: true);
        final createdImage = qrData['qrimg'] as String?;
        if (createdImage != null && createdImage.isNotEmpty) {
          qrBytes = _decodeQrImage(createdImage);
        }
      } catch (e, stack) {
        if (fallbackImage == null || fallbackImage.isEmpty) rethrow;
        Log.w('WATCH_QR', '二维码 create 接口失败，使用 key 接口图片', e, stack);
      }

      qrBytes ??= _decodeQrImage(fallbackImage);
      if (!mounted) return;
      setState(() {
        _qrBytes = qrBytes;
        _loading = false;
      });
      _startPolling(key);
    } catch (e, stack) {
      if (!mounted) return;
      Log.e('WATCH_QR', '二维码生成失败', e, stack);
      setState(() {
        _loading = false;
        _error = e is FormatException ? e.message.toString() : '二维码生成失败，请重试';
      });
    }
  }

  Uint8List _decodeQrImage(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      throw const FormatException('二维码接口未返回图片');
    }
    final separator = encoded.indexOf(',');
    final raw = separator >= 0 ? encoded.substring(separator + 1) : encoded;
    try {
      final bytes = base64Decode(raw.trim());
      if (bytes.isEmpty) throw const FormatException('二维码图片数据为空');
      return bytes;
    } on FormatException {
      throw const FormatException('二维码图片数据无效');
    }
  }

  void _startPolling(String key) {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || _loggedIn) return false;
      try {
        final authService = context.read<AuthService>();
        final res = await authService.checkQrStatus(key);
        final (status, user) = AuthService.parseQrResponse(res);
        if (!mounted) return false;
        if (status == 4 && user != null) {
          _loggedIn = true;
          await context.read<AuthProvider>().loginWithQr(user);
          if (mounted) {
            // 弹回根（登录页是二级页面，连同入口页一起退出）
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          return false;
        }
        if (status == 0) {
          setState(() => _error = '二维码已过期，请重新生成');
          return false;
        }
        if (status == 2) setState(() => _pollStatus = 2);
        return true;
      } catch (_) {
        return mounted;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = WatchLayout.of(context);

    Widget content;
    if (_loading) {
      content =
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    } else if (_error != null) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 36, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(_error!,
                style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadQr, child: const Text('重新生成')),
          ],
        ),
      );
    } else {
      // 二维码：白底方形，圆屏按直径 0.62 保证完整可读
      final qrSize = layout.diameter * (layout.isRound ? 0.62 : 0.7);
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: qrSize,
            height: qrSize,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.memory(_qrBytes!, fit: BoxFit.contain),
          ),
          const SizedBox(height: 10),
          Text(
            _pollStatus == 2 ? '已扫码，请在手机上确认' : '手机酷狗 App 扫码登录',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return WatchScaffold(body: Center(child: content));
  }
}

// ═══════════════════════════════════════════════════════════
//  手机验证码登录
// ═══════════════════════════════════════════════════════════

class _WatchPhoneLoginScreen extends StatefulWidget {
  const _WatchPhoneLoginScreen();

  @override
  State<_WatchPhoneLoginScreen> createState() => _WatchPhoneLoginScreenState();
}

class _WatchPhoneLoginScreenState extends State<_WatchPhoneLoginScreen> {
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

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 11) {
      setState(() => _error = '请输入 11 位手机号');
      return;
    }
    setState(() {
      _sendingCode = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().sendCaptcha(phone);
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _countdown = 60;
      });
      _startCountdown();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _error = '验证码发送失败';
      });
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_countdown > 0) _countdown--;
      });
      return _countdown > 0;
    });
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (phone.isEmpty || code.isEmpty) return;
    setState(() {
      _loggingIn = true;
      _error = null;
    });
    try {
      final ok = await context.read<AuthProvider>().loginWithPhone(phone, code);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() {
          _error = '登录失败，请检查验证码';
          _loggingIn = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loggingIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = WatchLayout.of(context);

    InputDecoration fieldDecoration(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        );

    return WatchScaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          layout.isRound ? layout.diameter * 0.12 : 14,
          8,
          layout.isRound ? layout.diameter * 0.12 : 14,
          layout.bottomInset + 16,
        ),
        child: Column(
          children: [
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: theme.textTheme.bodyMedium,
              decoration: fieldDecoration('手机号'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.bodyMedium,
                    decoration: fieldDecoration('验证码'),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed:
                        _countdown > 0 || _sendingCode ? null : _sendCode,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: _sendingCode
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_countdown > 0 ? '${_countdown}s' : '获取'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _loggingIn ? null : _login,
                child: _loggingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
