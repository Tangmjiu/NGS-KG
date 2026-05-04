# CLAUDE.md

本文件为 Claude 提供项目上下文、技术规范及 API 接口参考。

## 项目概述

- **项目名称**：NGS-KG+
- **目标平台**：移动端（Android），桌面端（Electron + Vue3/React，待开发）
- **核心功能**：基于酷狗音乐第三方 API，实现用户登录、歌单管理、音乐搜索、在线播放、歌词显示、排行榜、本地音乐播放等
- **主要技术栈**：
  - 移动端：Flutter（Dart）
  - 桌面端：Electron + Vue3/React（待开发）
  - 音频播放：audioplayers
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
KuGouMusic/
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

## API

本项目使用酷狗音乐第三方 API，基础地址：

```
http://171.80.2.129:42980
```

所有 API 请求需携带 `cookie=token=xxx;userid=xxx` 参数（通过 `ApiClient.getCookieString()` 自动附加）。

### 调用的 API 列表

| 类别 | 端点 | 说明 | 状态 |
|------|------|------|------|
| 登录 | `/login` | 密码登录 | 正常 |
| | `/login/cellphone` | 手机验证码登录（参数：mobile） | 正常 |
| | `/login/qr/key` | 生成二维码 key | 正常 |
| | `/login/qr/create` | 生成二维码图片 | 正常 |
| | `/login/qr/check` | 检测扫码状态 | 正常 |
| | `/captcha/sent` | 发送验证码（参数：mobile） | 正常 |
| 用户 | `/user/detail` | 用户详情 | 正常 |
| | `/user/playlist` | 用户歌单 | 正常 |
| | `/user/history` | 听歌历史 | 正常 |
| 搜索 | `/search` | 通用搜索（参数：keywords） | 正常 |
| | `/search/suggest` | 搜索建议 | 正常 |
| | `/search/hot` | 热搜列表 | 正常 |
| | `/search/lyric` | 搜索歌词参数（参数：hash） | 正常 |
| 播放 | `/song/url` | 获取播放地址（参数：hash） | 正常 |
| | `/lyric` | 获取歌词（参数：id, accesskey, fmt, decode） | 正常 |
| 歌单 | `/top/playlist` | 推荐歌单（参数：category_id, withsong） | 正常 |
| | `/playlist/detail` | 歌单详情（参数：ids=collection_xxx） | 正常 |
| | `/playlist/track/all` | 歌单歌曲列表（参数：id=collection_xxx） | 正常 |
| | `/playlist/tags` | 歌单分类 | 正常 |
| 排行榜 | `/rank/list` | 排行榜列表 | 正常 |
| | `/rank/audio` | 排行榜歌曲（参数：rankid） | 正常 |
| | `/top/song` | 新歌速递 | 正常 |
| 歌手 | `/artist/list` | 歌手列表 | 正常 |
| | `/artist/detail` | 歌手详情 | 正常 |
| | `/artist/audios` | 歌手歌曲 | 正常 |
| 电台 | `/fm/recommend` | 推荐电台 | 正常 |
| | `/fm/songs` | 电台歌曲（参数：fmid） | 正常 |
| 曲谱 | `/sheet/list` | 曲谱列表 | 正常 |
| | `/sheet/detail` | 曲谱详情 | 正常 |
| | `/sheet/hot` | 推荐曲谱 | 正常 |
| 评论 | `/comment/music` | 歌曲评论 | 正常 |
| | `/comment/playlist` | 歌单评论 | 正常 |
| 其他 | `/server/now` | 服务器时间 | 正常 |
| | `/album/detail` | 专辑详情 | 正常 |

### 注意事项

1. 播放地址有效期约 15 分钟，播放前实时获取，播放中遇到 403 重试
2. Cookie 需持久化保存（CookieJar 自动管理），token/userid 需显式传递
3. User-Agent 需模拟酷狗官方客户端
4. 存在反爬限制，建议做本地缓存
5. 接口仅供个人学习研究

## 已知问题

- `/song/url` 部分收费歌曲返回 status=3（无权限）
- 音质切换依赖于不同 hash（128K/320K），未完全实现
- 无缓存层，重复请求浪费资源
- 测试覆盖率低

## 代码风格

- Flutter（Dart）：遵循官方 Dart 风格指南，使用 `dart format` 自动格式化
- 类名：PascalCase，变量/方法：lowerCamelCase
- 提交信息：Conventional Commits（feat/fix/docs/refactor/chore）
- Provider 作为状态管理方案，避免 UI 层直接创建 Service 实例
