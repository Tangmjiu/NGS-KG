<p align="center">
  <img src="assets/icon.png" width="120" alt="NGS-KG+">
</p>

<h1 align="center">NGS-KG+</h1>

<p align="center">
  基于酷狗音乐第三方 API 的 Flutter 音乐播放器
</p>

<p align="center">
  <a href="#功能">功能</a> ·
  <a href="#截图">截图</a> ·
  <a href="#快速开始">快速开始</a> ·
  <a href="#构建">构建</a> ·
  <a href="#API">API</a> ·
  <a href="FAQ.md">FAQ</a>
</p>

---

## 功能

- **登录**：手机验证码 / 二维码 / 密码登录
- **首页**：每日推荐、新歌速递、6 种推荐卡片、继续播放
- **发现**：推荐歌单、热门榜单、新碟上架、场景音乐、电台、编辑精选
- **搜索**：综合 / 单曲 / 歌单 / 专辑 / 歌手 / MV / 歌词 多类型搜索
- **播放器**：专辑封面、滚动歌词、音质切换、播放列表、后台播放
- **歌手**：歌手详情、热门单曲、专辑列表、MV
- **专辑**：专辑详情、歌曲列表、专辑简介
- **歌单**：创建 / 收藏 / 删除歌单
- **音质**：WiFi / 蜂窝 / 下载 三套独立音质设置 + 智能模式
- **通知**：通知栏控制、专辑封面、当前歌词显示
- **本地音乐**：扫描设备音频文件并播放
- **云盘**：查看和播放酷狗云盘音乐

## 截图

```
首页                 播放器               搜索

┌──────────┐     ┌──────────┐     ┌──────────┐
│ 🔍 搜索   │     │  专辑封面 │     │ 🔍 周杰伦│
│ ▶ 继续播放│     │  歌词    │     │ 综合 单曲│
│ 推荐歌单  │     │ ◀⏸▶     │     │ [🖼] 晴天│
│ 新歌推荐  │     │ 音质:无损│     │ [🖼] 告白│
│ 每日推荐  │     │          │     │ [🖼] 七里│
│ 6 卡片推荐 │     │          │     │          │
└──────────┘     └──────────┘     └──────────┘
```

## 快速开始

### 环境要求

- Flutter SDK（最新稳定版）
- Android SDK 36
- JDK 17

### 配置镜像源（国内）

```bash
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
```

### 获取依赖

```bash
flutter pub get
```

### 运行

```bash
flutter run
```

### API 服务器

默认连接公共代理 `http://111.170.14.52:42980`，可在 **设置 → API 服务** 中自定义。

也可自建服务端：https://github.com/MakcRe/KuGouMusicApi

## 构建

### APK

```bash
flutter build apk --release
```

### GitHub Actions

每次推送 `android` 分支自动编译：\
https://github.com/Tangmjiu/NGS-KG/actions

## 技术栈

| 层 | 技术 |
|------|------|
| 框架 | Flutter + Dart |
| 状态管理 | Provider |
| 网络请求 | Dio + CookieJar |
| 音频播放 | just_audio |
| 本地存储 | sqflite + SharedPreferences |
| 图片加载 | cached_network_image |
| 通知 | flutter_local_notifications |
| 权限 | permission_handler |

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   ├── song.dart             # 歌曲
│   ├── album.dart            # 专辑
│   ├── artist.dart           # 歌手
│   ├── playlist.dart         # 歌单
│   ├── song_mapper.dart      # 歌曲映射器
│   └── ...
├── providers/                # 状态管理
│   ├── player_provider.dart  # 播放器
│   ├── audio_engine.dart     # 音频引擎
│   ├── audio_settings_provider.dart  # 音质设置
│   ├── auth_provider.dart    # 认证
│   └── ...
├── repositories/             # API 数据层
│   ├── song_repository.dart
│   ├── album_repository.dart
│   ├── artist_repository.dart
│   ├── playlist_repository.dart
│   └── user_repository.dart
├── services/                 # 服务层
│   ├── api_client.dart       # HTTP 客户端
│   ├── music_service.dart    # 音乐服务
│   ├── auth_service.dart     # 认证服务
│   └── notification_service.dart  # 通知服务
├── screens/                  # 页面
│   ├── home_screen.dart      # 首页
│   ├── player_screen.dart    # 播放器
│   ├── search_screen.dart    # 搜索
│   ├── discover_screen.dart  # 发现
│   ├── profile_screen.dart   # 我的
│   └── ...
├── widgets/                  # 通用组件
│   ├── song_tile.dart        # 歌曲行
│   ├── playlist_card.dart    # 歌单卡片
│   └── ...
└── routes/                   # 路由
    └── app_routes.dart
```

## API

基于 [MakcRe/KuGouMusicApi](https://github.com/MakcRe/KuGouMusicApi) 的 RESTful API。

### 已使用的主要接口

| 分类 | 端点 |
|------|------|
| 登录 | `/login/cellphone` `/login/qr/key` `/login/qr/create` `/login/qr/check` |
| 验证码 | `/captcha/sent` |
| 歌曲 | `/song/url` `/search` `/search/complex` `/top/song` `/top/card` |
| 专辑 | `/album/detail` `/album/songs` `/top/album` |
| 歌手 | `/artist/detail` `/artist/audios` `/artist/albums` `/artist/videos` |
| 歌单 | `/top/playlist` `/playlist/detail` `/playlist/track/all` |
| 推荐 | `/everyday/recommend` `/personal/fm` `/history/recommend` `/ai/recommend` |
| 用户 | `/user/detail` `/user/playlist` `/user/history` `/user/listen` |
| 电台 | `/fm/recommend` `/fm/songs` `/fm/class` |
| 乐库 | `/yueku` `/yueku/fm` |
| 排行榜 | `/rank/list` `/rank/audio` |
| 编辑精选 | `/top/ip` `/ip/zone` |

### 音质参数

| 参数 | 说明 | 码率 |
|------|------|------|
| `128` | 标准 | ~1 MB/min |
| `320` | HQ | ~2.4 MB/min |
| `high` | 无损 | ~10 MB/min |
| `viper_clear` | 蝰蛇超清 | 音质增强 |
| `super` | DSD | 超高解析 |

## 免责声明

1. 本项目仅供学习研究使用，请尊重版权
2. 使用产生的版权数据请在 24 小时内清除
3. 禁止用于商业行为及非法用途
4. 音乐平台不易，请支持正版

## 协议

[MIT](LICENSE)
