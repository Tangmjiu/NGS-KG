# CLAUDE.md

本文件为 Claude 提供项目上下文、技术规范及 API 接口参考。

## 项目概述

- **项目名称**：NGS-KG+
- **目标平台**：移动端（Android），桌面端（Electron + Vue3/React，待开发）
- **核心功能**：基于酷狗音乐第三方 API，实现用户登录、歌单管理、音乐搜索、在线播放、歌词显示、排行榜、本地音乐播放等
- **主要技术栈**：
  - 移动端：Flutter（Dart）
  - 桌面端：Electron + Vue3/React（待开发）
  - 音频播放：just_audio
  - 状态管理：Provider
  - 网络请求：Dio + CookieJar
  - 本地存储：sqflite + path_provider
  - 权限管理：permission_handler
- **开发环境**：Linux ARM64 无桌面版 Ubuntu（只能通过 GitHub Actions 构建 APK）

## 环境配置

```bash
# Android SDK (ARM64)
export ANDROID_HOME="$HOME/Android/Sdk"
# Flutter SDK
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export PATH="$PATH:$HOME/flutter/bin"
```

## 目录结构

```

├── lib/                    # Dart 源码
│   ├── main.dart           # 应用入口
│   ├── models/             # 数据模型
│   ├── providers/          # 状态管理 (Provider)
│   ├── routes/             # 路由配置
│   ├── screens/            # 页面
│   ├── services/           # API 服务
│   ├── utils/              # 工具
│   └── widgets/            # 通用组件
├── android/                # Android 原生工程
├── assets/                 # 静态资源
├── test/                   # 测试
├── web/                    # Web 平台（未使用）
├── .github/workflows/      # GitHub Actions 构建配置
└── desktop/                # 桌面端（待创建）
```

## 常用命令

```bash
# 获取依赖
flutter pub get

# 构建 Android APK（debug）
flutter build apk --debug

# 构建 Android APK（release）
flutter build apk --release

# 静态分析
flutter analyze

# 格式化
dart format lib/
```

### 桌面端

```bash
cd desktop && npm install
npm run dev
```



### 注意事项

1. 播放地址有效期约 15 分钟，播放前实时获取，播放中遇到 403 重试
2. Cookie 需持久化保存（CookieJar 自动管理），token/userid 需显式传递
3. User-Agent 需模拟酷狗官方客户端
4. 存在反爬限制，建议做本地缓存
5. 接口仅供个人学习研究
6. 音质切换使用 `/song/url` 的 `quality` 参数：128/320/high/flac
7. 推荐卡片 `/top/card` 的 card_id：1=私人专属好歌，2=经典怀旧金曲，3=热门好歌精选，4=小众宝藏佳作，5=潮流尝鲜，6=VIP专属推

## 代码风格

- Flutter（Dart）：遵循官方 Dart 风格指南，使用 `dart format` 自动格式化
- 类名：PascalCase，变量/方法：lowerCamelCase
- 提交信息：Conventional Commits（feat/fix/docs/refactor/chore）
- Provider 作为状态管理方案，避免 UI 层直接创建 Service 实例