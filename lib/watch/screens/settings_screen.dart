// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 手表设置页

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/audio_settings_provider.dart';
import '../widgets/round_safe_area.dart';
import 'login_screen.dart';

/// 手表版设置
class WatchSettingsScreen extends StatelessWidget {
  const WatchSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('设置', style: TextStyle(fontSize: 14)),
      ),
      body: RoundSafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          children: const [
            _LoginSection(),
            SizedBox(height: 8),
            _AudioSection(),
            SizedBox(height: 8),
            _AboutSection(),
          ],
        ),
      ),
    );
  }
}

class _LoginSection extends StatelessWidget {
  const _LoginSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoggedIn) {
          return Card(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person, size: 22),
                  title: Text('已登录', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          );
        }
        return Card(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Icon(Icons.login, size: 22,
              color: theme.colorScheme.primary),
            title: const Text('登录账号',
              style: TextStyle(fontSize: 13)),
            subtitle: const Text('登录后可使用收藏等功能',
              style: TextStyle(fontSize: 11)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WatchLoginScreen()),
            ),
          ),
        );
      },
    );
  }
}

class _AudioSection extends StatelessWidget {
  const _AudioSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AudioSettingsProvider>(
      builder: (context, settings, _) {
        final wifiQ = settings.wifiQuality;
        return Card(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Text('音质', style: theme.textTheme.titleSmall),
              ),
              ListTile(
                dense: true,
                title: const Text('WiFi音质',
                  style: TextStyle(fontSize: 12)),
                trailing: Text(_qualityLabel(wifiQ),
                  style: const TextStyle(fontSize: 11)),
                onTap: () => _cycleQuality(context, settings),
              ),
            ],
          ),
        );
      },
    );
  }

  String _qualityLabel(String q) {
    switch (q) {
      case '128': return '标准';
      case '320': return '高品';
      case 'high': return '无损';
      case 'flac': return 'Hi-Res';
      default: return q;
    }
  }

  void _cycleQuality(BuildContext context, AudioSettingsProvider settings) {
    const qualities = ['128', '320', 'high', 'flac'];
    final current = settings.wifiQuality;
    final idx = qualities.indexOf(current);
    final next = qualities[(idx + 1) % qualities.length];
    settings.setWifiQuality(next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('WiFi音质: ${_qualityLabel(next)}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14)),
      child: const ListTile(
        leading: Icon(Icons.info_outline, size: 22),
        title: Text('NGS-KG Watch', style: TextStyle(fontSize: 13)),
        subtitle: Text('v1.5.0 | Wear OS', style: TextStyle(fontSize: 11)),
      ),
    );
  }
}
