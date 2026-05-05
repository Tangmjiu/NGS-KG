# NGS-KG+

基于酷狗音乐第三方 API 的跨平台音乐播放器。

## 分支说明

| 分支 | 平台 | 说明 |
|------|------|------|
| `android` | Android | 移动端主分支 |
| `windows-desktop` | Windows | 桌面端（开发中） |
| `linux-debian-desktop` | Linux | 桌面端（开发中） |

## 功能

- 用户登录（手机验证码）
- 热门歌单浏览与收藏
- 音乐搜索（热榜 + 搜索建议）
- 在线播放（支持音质切换 128K/320K/Hi-Res）
- 歌词同步显示
- 排行榜
- 本地音乐播放
- 云盘音乐
- 听歌历史
- 歌手关注
- 曲谱浏览
- 电台

## 技术栈

| 模块 | 技术 |
|------|------|
| 框架 | Flutter |
| 状态管理 | Provider |
| 网络请求 | Dio + CookieJar |
| 音频播放 | audioplayers |
| 本地存储 | sqflite + path_provider |

## 快速开始

### 环境要求

- Flutter SDK >= 3.0
- Android SDK / Windows / Linux

### 构建

```bash
# 获取依赖
flutter pub get

# 构建 Android
flutter build apk --debug
```

## API

本项目使用酷狗音乐第三方 API：

```
http://171.80.2.129:42980
```

### 注意事项

- 播放地址有效期约 15 分钟
- 部分 VIP 歌曲需要登录后才能播放
- 请勿用于商业用途

## License

仅供个人学习研究使用。