import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';
import '../services/api_client.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/user/detail');
      _detail = res.data['data'] as Map<String, dynamic>?;
    } catch (e, s) {
      Log.e('UserProfile', 'load error', e, s);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: Text(user?.nickname ?? '个人主页')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!) // guarded by avatarUrl != null
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
                if (user != null && user.isVipActive)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(user.vipLevelDisplay,
                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 13)),
                    ),
                  ),
                const SizedBox(height: 24),
                if (_detail != null) ...[
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
                  if (_detail!['sign']?.toString().isNotEmpty == true)
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
              ],
          ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
