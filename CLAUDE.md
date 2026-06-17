# CLAUDE.md

本文件为 Claude 提供项目上下文、技术规范及 API 接口参考。

## 项目概述

- **项目名称**：NGS-KG+
  - **NGS** = 凪砂（出自《偶像梦幻祭2》）
  - **KG** = 酷狗 (KuGou)
- **目标平台**：移动端（Android），桌面端（Flutter Windows，开发中）
- **核心功能**：基于酷狗音乐第三方 API，实现用户登录、歌单管理、音乐搜索、在线播放、歌词显示、排行榜、本地音乐播放、云盘、FM 电台、MV 播放等
- **主要技术栈**：
  - 框架：Flutter（Dart）
  - 状态管理：Provider
  - 网络请求：Dio + CookieJar (dio_cookie_manager)
  - 音频播放：just_audio + audio_session
  - 前台媒体服务：PlaybackService（Kotlin，Android 原生 MediaSession）
  - 图片加载：cached_network_image
  - 颜色提取：palette_generator
  - 主题系统：flex_color_scheme + dynamic_color（Material You 动态取色）+ ZIP 主题包（archive）
  - 本地存储：sqflite + SharedPreferences
  - 通知：flutter_local_notifications + 原生 MediaStyle 通知
  - 权限管理：permission_handler
  - 歌词显示：ym_lyric / flutter_lyric
  - 其他：wakelock_plus（屏幕常亮）、url_launcher、file_picker、flutter_svg、package_info_plus
- **开发环境**：Windows（本地构建 Android APK 与 Windows 桌面）

## 目录结构

```
lib/                        # Dart 源码
├── main.dart               # 应用入口
├── constants/              # 常量定义
│   ├── banned_words.dart
│   ├── discover_constants.dart
│   └── quality.dart
├── models/                 # 数据模型
│   ├── song.dart           # 歌曲
│   ├── album.dart          # 专辑
│   ├── artist.dart         # 歌手
│   ├── playlist.dart       # 歌单
│   ├── user.dart           # 用户
│   ├── video.dart          # MV/视频
│   ├── vip_info.dart       # VIP 信息
│   ├── scene_category.dart # 场景分类
│   ├── response.dart       # API 响应封装
│   └── song_mapper.dart    # 歌曲映射器（多数据源归一）
├── repositories/           # 数据层（API 封装）
│   ├── base_repository.dart
│   ├── song_repository.dart
│   ├── album_repository.dart
│   ├── artist_repository.dart
│   ├── playlist_repository.dart
│   └── user_repository.dart
├── providers/              # 状态管理 (Provider)
│   ├── player_provider.dart      # 播放器
│   ├── audio_engine.dart         # 音频引擎
│   ├── audio_settings_provider.dart  # 音质设置
│   ├── auth_provider.dart        # 认证
│   ├── playlist_provider.dart    # 歌单
│   ├── liked_songs_provider.dart # 收藏歌曲
│   ├── discover_provider.dart    # 发现页
│   ├── theme_provider.dart       # 主题
│   ├── playlist_queue.dart       # 播放队列
│   └── mixins.dart               # 通用 mixin
├── services/               # 服务层
│   ├── api_client.dart           # HTTP 客户端（Dio 封装）
│   ├── api_config.dart           # API 配置
│   ├── api_exception.dart        # 异常处理
│   ├── auth_service.dart         # 认证服务
│   ├── music_service.dart        # 音乐服务
│   ├── notification_service.dart # 通知服务
│   ├── cache_service.dart        # 缓存服务
│   ├── cache_interceptor.dart    # 缓存拦截器
│   ├── device_service.dart       # 设备信息
│   ├── kugou_signer.dart         # 酷狗签名
│   ├── local_music_service.dart  # 本地音乐扫描
│   ├── metadata_reader.dart      # 元数据读取
│   └── update_checker.dart       # 更新检查
├── screens/                # 页面
│   ├── home_screen.dart          # 首页
│   ├── discover_screen.dart      # 发现
│   │   └── sections/             # 发现页各模块
│   │       ├── discover_banner.dart
│   │       ├── discover_song_row.dart
│   │       ├── discover_playlist_row.dart
│   │       ├── discover_rank_row.dart
│   │       ├── discover_album_row.dart
│   │       ├── discover_scene_row.dart
│   │       ├── discover_fm_row.dart
│   │       ├── discover_ip_row.dart
│   │       ├── discover_personal_fm_row.dart
│   │       ├── discover_quick_actions.dart
│   │       └── discover_section_header.dart
│   ├── player_screen.dart        # 播放器
│   ├── search_screen.dart        # 搜索
│   ├── profile_screen.dart       # 我的
│   ├── login_screen.dart         # 登录
│   ├── settings_screen.dart      # 设置
│   ├── theme_settings_screen.dart # 主题设置
│   ├── api_settings_screen.dart  # API 服务器设置
│   ├── audio_quality_screen.dart # 音质设置
│   ├── audio_effects_screen.dart # 音效
│   ├── playlist_detail_screen.dart # 歌单详情
│   ├── playlist_category_screen.dart # 歌单分类
│   ├── album_detail_screen.dart  # 专辑详情
│   ├── artist_detail_screen.dart # 歌手详情
│   ├── artist_list_screen.dart   # 歌手列表
│   ├── rank_detail_screen.dart   # 排行榜
│   ├── mv_player_screen.dart     # MV 播放
│   ├── local_music_screen.dart   # 本地音乐
│   ├── cloud_disk_screen.dart    # 云盘
│   ├── fm_screen.dart            # FM 电台
│   ├── comments_screen.dart      # 评论
│   ├── history_screen.dart       # 播放历史
│   ├── messages_screen.dart      # 消息
│   ├── user_profile_screen.dart  # 用户主页
│   ├── videos_screen.dart        # 视频
│   ├── recommended_playlists_screen.dart # 推荐歌单
│   ├── about_screen.dart         # 关于
│   └── log_viewer_screen.dart    # 日志查看器
├── theme/                  # 主题系统
│   ├── theme_assets.dart         # 主题资源
│   └── theme_loader.dart         # 主题加载器（ZIP 包）
├── routes/                 # 路由
│   └── app_routes.dart
├── utils/                  # 工具
│   ├── constants.dart
│   ├── theme.dart
│   ├── logger.dart
│   ├── responsive.dart
│   ├── error_dialog.dart
│   ├── palette_extractor.dart
│   └── about_config.dart
└── widgets/                # 通用组件
    ├── song_tile.dart
    ├── playlist_card.dart
    ├── player_bar.dart
    ├── player_background.dart
    ├── player_cover_art.dart
    ├── player_controls_bar.dart
    ├── player_progress_bar.dart
    ├── playback_controls.dart
    ├── horizontal_card_section.dart
    ├── create_playlist_dialog.dart
    ├── login_required_dialog.dart
    ├── support_me_dialog.dart
    └── update_dialog.dart
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

### 桌面端（Windows）

```bash
flutter build windows --debug
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

## 开源说明

- 本项目基于 MIT 协议开源
- 所有音乐数据来自酷狗音乐官方 API，不存储任何音乐文件
- 遵循当地法律使用，在线服务协议最终解释权归广州酷狗计算机科技有限公司所有
