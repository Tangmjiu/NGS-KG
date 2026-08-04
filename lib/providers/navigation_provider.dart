// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// 全局导航与标签页状态管理
class NavigationProvider extends ChangeNotifier {
  int _currentHomeTab = 0;

  int get currentHomeTab => _currentHomeTab;

  /// 设置当前首页的活跃标签页索引（0: 首页, 1: 发现, 2: 我的）
  void setHomeTab(int index) {
    if (_currentHomeTab == index) return;
    _currentHomeTab = index;
    notifyListeners();
  }
}
