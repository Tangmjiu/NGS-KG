// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import '../ui/app_ui.dart';
import '../ui/components/cover_art.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';
import '../models/vip_info.dart';
import '../services/music_service.dart';
import '../services/api_client.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final MusicService _musicService = MusicService();
  Map<String, dynamic>? _detail;
  VipInfo? _vipInfo;
  bool _isLoading = true;
  bool _requestInFlight = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_requestInFlight) return;
    if (!context.read<AuthProvider>().isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }
    _requestInFlight = true;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _musicService.getVipInfo(),
        ApiClient.instance.get('/user/detail'),
      ]);
      if (mounted) {
        final vipInfo = results[0] as VipInfo?;
        final detailRes = results[1] as Response;
        setState(() {
          _vipInfo = vipInfo;
          _detail = detailRes.data['data'] as Map<String, dynamic>?;
        });
      }
    } catch (error, stack) {
      Log.e('UserProfile', 'load error', error, stack);
      if (mounted) setState(() => _error = '完整账号资料暂时无法加载');
    } finally {
      _requestInFlight = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final tokens = AppThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppPageHeader(
                title: '账号资料',
                subtitle: '查看个人信息与会员状态',
                showBack: true,
              ),
              Expanded(
                child: user == null
                    ? AppEmptyState(
                        icon: Icons.person_outline_rounded,
                        title: '登录后查看账号资料',
                        message: '同步你的音乐账号与个人信息。',
                        action: FilledButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/login').then((_) {
                            if (mounted) _load();
                          }),
                          child: const Text('登录音乐账号'),
                        ),
                      )
                    : _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                  tokens.pagePadding,
                                  0,
                                  tokens.pagePadding,
                                  32 + MediaQuery.paddingOf(context).bottom),
                              children: [
                                AppSurface(
                                  color: cs.primaryContainer,
                                  child: Row(children: [
                                    CoverArt(
                                      url: user.avatarUrl,
                                      size: 64,
                                      borderRadius: 32,
                                      placeholder: Icon(
                                          Icons.person_outline_rounded,
                                          size: 32,
                                          color: cs.primary),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(user.nickname ?? '音乐爱好者',
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                    color:
                                                        cs.onPrimaryContainer)),
                                        if (user.userId != null) ...[
                                          const SizedBox(height: 6),
                                          Text('账号 ID ${user.userId}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: cs
                                                          .onPrimaryContainer)),
                                        ],
                                      ],
                                    )),
                                  ]),
                                ),
                                if (_vipInfo?.isVipActive ?? false) ...[
                                  const SizedBox(height: 12),
                                  _buildVipBadge(),
                                  SizedBox(height: tokens.sectionSpacing),
                                  _buildVipCard(),
                                ],
                                if (_error != null) ...[
                                  const SizedBox(height: 16),
                                  AppSurface(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_error!,
                                            style: theme.textTheme.bodyMedium),
                                        TextButton(
                                            onPressed: _load,
                                            child: const Text('重新加载')),
                                      ],
                                    ),
                                  ),
                                ],
                                if (_detail != null) ...[
                                  SizedBox(height: tokens.sectionSpacing),
                                  const AppSectionHeader(
                                      padding: EdgeInsets.zero, title: '账号信息'),
                                  const SizedBox(height: 12),
                                  AppSurface(
                                      child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _infoRow(
                                          '昵称',
                                          _detail!['nickname']?.toString() ??
                                              ''),
                                      _infoRow(
                                          '性别',
                                          _detail!['sex'] == 1
                                              ? '男'
                                              : _detail!['sex'] == 2
                                                  ? '女'
                                                  : '未设置'),
                                      _infoRow('地区',
                                          _detail!['city']?.toString() ?? ''),
                                      _infoRow('等级',
                                          _detail!['level']?.toString() ?? ''),
                                      if (_detail!['birthday']
                                              ?.toString()
                                              .isNotEmpty ==
                                          true)
                                        _infoRow('生日',
                                            _detail!['birthday'].toString()),
                                      _infoRow(
                                          '注册时间',
                                          _detail!['reg_time']?.toString() ??
                                              ''),
                                    ],
                                  )),
                                ],
                                if (_detail?['sign']?.toString().isNotEmpty ==
                                    true) ...[
                                  SizedBox(height: tokens.sectionSpacing),
                                  const AppSectionHeader(
                                      padding: EdgeInsets.zero, title: '个人签名'),
                                  const SizedBox(height: 12),
                                  AppSurface(
                                      child: Text(_detail!['sign'].toString())),
                                ],
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVipBadge() {
    final cs = Theme.of(context).colorScheme;
    final isSvip = _vipInfo?.badgeType.$2 == true;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSvip ? cs.tertiary : cs.primary,
          borderRadius: AppShape.xs,
        ),
        child: Text(
          _vipInfo?.summary ?? '',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSvip ? cs.onTertiary : cs.onPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }

  Widget _buildVipCard() {
    final info = _vipInfo!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(padding: EdgeInsets.zero, title: '会员信息'),
        const SizedBox(height: 12),
        AppSurface(
            child: Column(
          children: [
            _infoRow('会员类型', info.displayName),
            if (info.vipBeginTime != null)
              _infoRow('开通时间', _fmt(info.vipBeginTime!)),
            if (info.vipEndTime != null) ...[
              _infoRow('到期时间', _fmt(info.vipEndTime!)),
              _infoRow('状态', info.expirationText),
            ],
          ],
        )),
      ],
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(builder: (context, constraints) {
          final labelWidget = Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant));
          final content = SelectableText(value.isEmpty ? '未设置' : value,
              style: Theme.of(context).textTheme.bodyMedium);
          if (constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), content],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 96, child: labelWidget),
              Expanded(child: content)
            ],
          );
        }),
      );
}
