// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../widgets/round_list_tile.dart';
import '../widgets/watch_player_primitives.dart';
import '../widgets/watch_scaffold.dart';

// 账号流程、设备页和全屏提示共用同一个滚动视口。每页只留一次圆屏边距。
class WatchFlowPage extends StatefulWidget {
  const WatchFlowPage({
    super.key,
    required this.title,
    required this.children,
    this.symbol,
    this.center = false,
    this.swipeBack = true,
    this.active = true,
  });

  final String title;
  final List<Widget> children;
  final Widget? symbol;
  final bool center;
  final bool swipeBack;
  final bool active;

  @override
  State<WatchFlowPage> createState() => _WatchFlowPageState();
}

class _WatchFlowPageState extends State<WatchFlowPage> {
  final _scroll = ScrollController(keepScrollOffset: false);
  late final StreamSubscription<RotaryEvent> _rotary;

  @override
  void initState() {
    super.initState();
    _rotary = rotaryEvents.listen((event) {
      if (!mounted ||
          !widget.active ||
          ModalRoute.of(context)?.isCurrent != true ||
          !_scroll.hasClients ||
          !_scroll.position.hasContentDimensions) {
        return;
      }
      final pos = _scroll.position;
      final step = pos.viewportDimension * .25;
      final offset =
          pos.pixels +
          (event.direction == RotaryDirection.clockwise ? step : -step);
      _scroll.jumpTo(
        offset.clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble(),
      );
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _rotary.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WatchScaffold(
      showTime: false,
      swipeBack: widget.swipeBack,
      scrollController: _scroll,
      body: WatchPlayerInsets(
        child: WatchSpringReveal(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(
                  mainAxisAlignment: widget.center
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.symbol != null) ...[
                      Center(child: widget.symbol),
                      const SizedBox(height: 4),
                    ],
                    Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.children,
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

bool _current(BuildContext context) =>
    ModalRoute.of(context)?.isCurrent == true;

class WatchLoginScreen extends StatelessWidget {
  const WatchLoginScreen({super.key});

  Future<void> _choose(BuildContext context, Widget method) async {
    if (!_current(context)) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => method),
    );
    if (result == true && context.mounted && _current(context)) {
      // 只退出登录入口，保留进入登录前的设置或播放页。
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) => WatchFlowPage(
    title: '登录',
    children: [
      RoundListTile(
        title: '二维码登录',
        leading: const Icon(Icons.qr_code_rounded),
        onTap: () => _choose(context, const _QrLogin()),
      ),
      RoundListTile(
        title: '手机验证码登录',
        leading: const Icon(Icons.sms_outlined),
        onTap: () => _choose(context, const _PhoneLogin()),
      ),
      TextButton(
        onPressed: () => Navigator.maybePop(context),
        child: const Text('暂不登录'),
      ),
    ],
  );
}

class _QrLogin extends StatefulWidget {
  const _QrLogin();
  @override
  State<_QrLogin> createState() => _QrLoginState();
}

class _QrLoginState extends State<_QrLogin> {
  Uint8List? _image;
  String? _error;
  bool _scanned = false;
  Timer? _timer;
  int _request = 0;
  int _failedPolls = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Uint8List _decode(String encoded) {
    final bytes = base64Decode(
      encoded.substring(encoded.indexOf(',') + 1).trim(),
    );
    if (bytes.isEmpty) throw const FormatException();
    return bytes;
  }

  Future<void> _load() async {
    final request = ++_request;
    _timer?.cancel();
    setState(() {
      _image = null;
      _error = null;
      _scanned = false;
      _failedPolls = 0;
    });
    try {
      final service = context.read<AuthService>();
      final data = await service.getQrKey();
      final key = data['key'] as String;
      if (key.isEmpty) throw const FormatException();
      Uint8List? bytes;
      try {
        final created = await service.getQrCreate(key, qrimg: true);
        if (created['qrimg'] is String) {
          bytes = _decode(created['qrimg'] as String);
        }
      } catch (_) {
        if (data['qrimg'] == null) rethrow;
      }
      bytes ??= _decode(data['qrimg'] as String);
      if (!mounted || request != _request) return;
      setState(() => _image = bytes);
      _schedule(key, request);
    } catch (_) {
      if (mounted && request == _request) setState(() => _error = '没能加载二维码');
    }
  }

  void _schedule(String key, int request) {
    _timer = Timer(const Duration(seconds: 2), () => _poll(key, request));
  }

  Future<void> _poll(String key, int request) async {
    if (!mounted || request != _request) return;
    if (!_current(context)) {
      _schedule(key, request);
      return;
    }
    try {
      final response = await context.read<AuthService>().checkQrStatus(key);
      if (!mounted || request != _request) return;
      if (!_current(context)) {
        _schedule(key, request);
        return;
      }
      final (status, user) = AuthService.parseQrResponse(response);
      if (status == 4 && user != null) {
        await context.read<AuthProvider>().loginWithQr(user);
        if (mounted && _current(context)) Navigator.of(context).pop(true);
        return;
      }
      if (status == 0 || status == 4) {
        setState(() => _error = status == 0 ? '二维码已过期' : '没能确认账号');
        return;
      }
      _failedPolls = 0;
      if (status == 2 && !_scanned) setState(() => _scanned = true);
    } catch (_) {
      if (!mounted || request != _request) return;
      if (++_failedPolls >= 3) {
        setState(() => _error = '连接中断，请重试');
        return;
      }
    }
    _schedule(key, request);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return WatchFlowPage(
      title: _scanned && _error == null ? '已扫码' : '扫码登录',
      center: true,
      children: [
        if (_error != null) ...[
          Icon(Icons.qr_code_rounded, color: colors.onSurfaceVariant),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: const Text('重新生成')),
        ] else if (_image == null) ...[
          const Center(
            child: CircularProgressIndicator(semanticsLabel: '正在加载二维码'),
          ),
        ] else if (_scanned) ...[
          Icon(Icons.phone_android_rounded, size: 44, color: colors.primary),
          const Text('请在手机酷狗上确认登录', textAlign: TextAlign.center),
        ] else ...[
          LayoutBuilder(
            builder: (context, box) {
              final size = math.min(
                box.maxWidth,
                MediaQuery.sizeOf(context).shortestSide * .49,
              );
              return Center(
                child: Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(4),
                  color: Colors.white,
                  child: Image.memory(
                    _image!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    semanticLabel: '酷狗登录二维码',
                    errorBuilder: (_, __, ___) => IconButton(
                      tooltip: '重新生成二维码',
                      icon: const Icon(Icons.refresh, color: Colors.black),
                      onPressed: _load,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          const Text('用手机酷狗扫码', textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _PhoneLogin extends StatefulWidget {
  const _PhoneLogin();
  @override
  State<_PhoneLogin> createState() => _PhoneLoginState();
}

class _PhoneLoginState extends State<_PhoneLogin> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  Timer? _timer;
  int _wait = 0;
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  String? _sentTo;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_current(context)) return;
    final phone = _phone.text.trim();
    if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
      setState(() => _error = '请输入 11 位手机号');
      return;
    }
    if (_wait > 0 && phone == _sentTo) {
      setState(() {
        _codeStep = true;
        _error = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().sendCaptcha(phone);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _codeStep = true;
        _sentTo = phone;
        _wait = 60;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _wait--);
        if (_wait == 0) timer.cancel();
      });
    } catch (_) {
      if (mounted) setState(() => _error = '验证码没发出去，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (_busy || !_current(context)) return;
    if (_code.text.isEmpty) {
      setState(() => _error = '请输入短信验证码');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await context.read<AuthProvider>().loginWithPhone(
        _phone.text,
        _code.text,
      );
      if (!mounted) return;
      if (ok && _current(context)) {
        Navigator.of(context).pop(true);
        return;
      }
      if (!ok) setState(() => _error = '登录失败，请检查验证码');
    } catch (_) {
      if (mounted) setState(() => _error = '连接失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return WatchFlowPage(
      key: ValueKey(_codeStep),
      title: _codeStep ? '短信验证码' : '手机登录',
      children: [
        if (_codeStep)
          Text('已发送至尾号 ${_sentTo!.substring(7)}', textAlign: TextAlign.center),
        TextField(
          key: ValueKey(_codeStep),
          controller: _codeStep ? _code : _phone,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: [
            _codeStep
                ? AutofillHints.oneTimeCode
                : AutofillHints.telephoneNumberNational,
          ],
          enableSuggestions: false,
          autocorrect: false,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            if (!_codeStep) LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            hintText: _codeStep ? '验证码' : '11 位手机号',
            filled: true,
            fillColor: colors.surfaceContainerHigh,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(28)),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => _codeStep ? _login() : _send(),
        ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error),
            ),
          ),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: _busy ? null : (_codeStep ? _login : _send),
          child: Text(
            _busy
                ? (_codeStep ? '正在登录…' : '正在发送…')
                : (_codeStep ? '登录' : '获取验证码'),
          ),
        ),
        if (_codeStep) ...[
          TextButton(
            onPressed: _wait > 0 || _busy ? null : _send,
            child: Text(_wait > 0 ? '$_wait 秒后可重发' : '重新发送'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _codeStep = false;
                    _error = null;
                  }),
            child: const Text('更换手机号'),
          ),
        ],
      ],
    );
  }
}
