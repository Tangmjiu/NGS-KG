<p align="center">
  <img src="assets/images/icon.png" width="120" alt="NGS-KG+">
</p>

<h1 align="center">NGS-KG+</h1>

<p align="center">
  基于酷狗音乐第三方 API 的 Flutter 音乐播放器
</p>

<p align="center">
  <a href="#功能">功能</a> ·
  <a href="#快速开始">快速开始</a> ·
  <a href="#构建">构建</a> ·
  <a href="#API">API</a> ·
  <a href="FAQ.md">FAQ</a> ·
  <a href="THEME.md">主题制作</a>
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


## 快速开始

### 环境要求

- Flutter SDK（最新稳定版）

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

可在 **设置 → API 服务** 中自定义。

也可自建服务端：https://github.com/MakcRe/KuGouMusicApi

## 构建

### APK

```bash
flutter build windows --release
```

### GitHub Actions

每次推送分支自动编译：\
https://github.com/Tangmjiu/NGS-KG/actions



## API

基于 [MakcRe/KuGouMusicApi](https://github.com/MakcRe/KuGouMusicApi) 的 RESTful API。


## 协议

[MIT](LICENSE)
