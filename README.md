# NGS-KG+

基于酷狗音乐第三方 API 的跨平台音乐播放器。

## 关于名称

- **NGS** - 取自 [乱凪砂](https://mzh.moegirl.org.cn/乱凪砂)（らん なぎさ / Ran Nagisa）
- **KG** - KuGouMusic（酷狗音乐）
- **+** - Plus（增强版）

## 功能

- 用户登录（手机验证码 / 密码 / 二维码）
- 热门歌单浏览与收藏
- 音乐搜索（热榜 + 搜索建议）
- 在线播放（支持音质切换 128K/320K/FLAC）
- 歌词同步显示
- 排行榜
- 本地音乐播放
- 云盘音乐
- 听歌历史
- 歌手关注
- 曲谱浏览
- 电台
- 手机/平板自适应布局（横屏自动切换分栏 UI）

## 技术栈

| 平台     | 技术              |
| -------- | ----------------- |
| 移动端   | Flutter + Dart    |
| 状态管理 | Provider          |
| 网络请求 | Dio + CookieJar   |
| 音频播放 | audioplayers      |
| 本地存储 | sqflite + path_provider |
| 权限管理 | permission_handler |
| 桌面端   | Electron + Vue3/React（待开发） |

## 快速开始

### 环境要求

- Flutter SDK >= 3.0
- Android SDK
- JDK 17+

### 运行

```bash
# 获取依赖
flutter pub get

# 构建 Android Debug APK
flutter build apk --debug

# 构建 Android Release APK
flutter build apk --release

# 静态分析
flutter analyze
```

## 项目结构

```
├── lib/
│   ├── main.dart            # 应用入口 + 全局播放栏 + 继续播放弹窗
│   ├── models/              # 数据模型
│   │   ├── song.dart        # 歌曲（支持多音质 qualities map）
│   │   ├── playlist.dart    # 歌单
│   │   ├── user.dart        # 用户（含 VIP 等级）
│   │   ├── artist.dart      # 歌手/评论模型
│   │   └── local_song.dart  # 本地歌曲
│   ├── providers/           # 状态管理
│   │   ├── auth_provider.dart     # 登录态（持久化）
│   │   ├── player_provider.dart   # 播放器（含 shuffle、音质、重试）
│   │   └── playlist_provider.dart # 歌单数据
│   ├── screens/             # 页面
│   │   ├── home_screen.dart       # 首页（手机/平板自适应）
│   │   ├── login_screen.dart      # 登录（密码/验证码/二维码）
│   │   ├── search_screen.dart     # 搜索（含排行榜）
│   │   ├── discover_screen.dart   # 发现（分类/电台/曲谱）
│   │   ├── profile_screen.dart    # 我的（用户/VIP/云盘/歌单）
│   │   ├── player_screen.dart     # 全屏播放器（歌词同步）
│   │   ├── playlist_detail_screen.dart
│   │   ├── rank_detail_screen.dart
│   │   ├── lyrics_screen.dart
│   │   ├── local_music_screen.dart
│   │   ├── cloud_disk_screen.dart
│   │   ├── history_screen.dart
│   │   ├── artist_list/artist_detail_screen.dart
│   │   ├── comments_screen.dart
│   │   ├── sheet_list/collection/detail_screen.dart
│   │   └── fm_screen.dart
│   ├── services/            # 网络层
│   │   ├── api_client.dart        # Dio + CookieJar + dfid
│   │   ├── auth_service.dart      # 登录 API
│   │   └── music_service.dart     # 所有音乐 API（50+ 端点）
│   ├── utils/
│   │   ├── constants.dart         # API 地址
│   │   ├── theme.dart             # 主题
│   │   └── responsive.dart        # 平板自适应检测
│   └── widgets/
│       ├── player_bar.dart        # 底部播放栏
│       ├── song_tile.dart         # 歌曲列表项
│       ├── playlist_card.dart     # 歌单卡片
│       └── tablet_scaffold.dart   # 平板分栏布局
├── android/                 # Android 原生工程
├── assets/                  # 静态资源
├── test/                    # 测试
└── .github/workflows/       # GitHub Actions 构建
```

## API

本项目使用酷狗音乐第三方 API，基础地址：

```
https://kugouapi.mjiutang.qzz.io
```

支持的接口包括：登录、歌单、搜索、播放、歌词、排行榜、评论、曲谱、电台、云盘、歌手等。详见 `CLAUDE.md`。

### 注意事项

- Cookie 需持久化保存（CookieJar + token/userid 显式传递）
- 播放地址有效期约 15 分钟，播放前实时获取
- User-Agent 需模拟酷狗官方客户端
- 请求需携带 dfid（/register/dev 获取）
- 请勿用于商业用途

## License

仅供个人学习研究使用。
