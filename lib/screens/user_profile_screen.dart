import 'package:flutter/material.dart';
import '../utils/theme.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
          _isLoading = false;
        });
      }
    } catch (e, s) {
      Log.e('UserProfile', 'load error', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isWide = MediaQuery.of(context).size.width >= 880;
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 头像 ──
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: user?.avatarUrl != null
                      ? NetworkImage(user!.avatarUrl!)
                      : null,
                  child: user?.avatarUrl == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(user?.nickname ?? '未知',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              if (user != null && user.userId != null)
                Center(
                  child: Text('ID: ${user.userId}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              // ── VIP 信息 ──
              if (_vipInfo?.isVipActive ?? false) ...[
                const SizedBox(height: 8),
                _buildVipBadge(),
              ],
              const SizedBox(height: 24),

              // ── 会员卡片 ──
              if (_vipInfo?.isVipActive ?? false)
                _buildVipCard(),

              // ── 账号卡片 ──
              if (_detail != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('账号信息',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _infoRow('昵称', _detail!['nickname']?.toString() ?? ''),
                        _infoRow('性别', _detail!['sex'] == 1 ? '男' : _detail!['sex'] == 2 ? '女' : '未设置'),
                        _infoRow('地区', _detail!['city']?.toString() ?? ''),
                        _infoRow('等级', _detail!['level']?.toString() ?? ''),
                        if (_detail!['birthday']?.toString().isNotEmpty == true)
                          _infoRow('生日', _detail!['birthday'].toString()),
                        _infoRow('注册时间', _detail!['reg_time']?.toString() ?? ''),
                      ],
                    ),
                  ),
                ),

              // ── 签名 ──
              if (_detail?['sign']?.toString().isNotEmpty == true)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('个人签名',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(_detail!['sign'].toString()),
                      ],
                    ),
                  ),
                ),
            ],
          );
    return Scaffold(
      appBar: AppBar(title: Text(user?.nickname ?? '个人主页')),
      body: isWide
          ? Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: body,
            ))
          : body,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('会员信息',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _infoRow('会员类型', info.displayName),
              if (info.vipBeginTime != null)
                _infoRow('开通时间', _fmt(info.vipBeginTime!)),
              if (info.vipEndTime != null) ...[
                _infoRow('到期时间', _fmt(info.vipEndTime!)),
                _infoRow('状态', info.expirationText),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
