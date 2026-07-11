<p align="center">
  <img src="assets/images/icon.png" width="120" alt="NGS-KG+">
</p>

<h1 align="center">NGS-KG+</h1>

<p align="center">
  基于酷狗音乐第三方 API 的 Flutter 音乐播放器（Wear OS 手表版 · Lite）
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.5.0--preview-blue?style=flat-square" alt="v1.5.0 preview">
  <img src="https://img.shields.io/badge/Nightcord-v2.0.0-purple?style=flat-square" alt="Nightcord v2.0.0">
</p>

<p align="center">
  <sub>代号 **Nightcord** 来源于 QQ 群代号投票——至于为什么选这个，我也不知道。</sub>
</p>

<p align="center">
  <a href="#功能">功能</a> ·
  <a href="#快速开始">快速开始</a> ·
  <a href="#构建">构建</a> ·
  <a href="#赞助支持">赞助支持</a> ·
  <a href="#交流群组">交流群组</a> ·
  <a href="#API">API</a> ·
  <a href="#免责声明">免责声明</a>
</p>

> **项目名称释义**
>
> **NGS** = 凪砂（出自《偶像梦幻祭2》）
> **KG** = 酷狗 (KuGou)
>
> 本项目是作者（本人 ngs 推🚩）基于酷狗音乐第三方 API 开发的 Flutter 音乐播放器。
> 内置图片素材来源于《偶像梦幻祭2》国服官方表情包，支持通过 ZIP 主题包自定义全套图片与配色。

---

## 功能

- **登录**：手机验证码 / 二维码登录
- **首页**：每日推荐、新歌速递、6 种推荐卡片、继续播放
- **发现**：推荐歌单、热门榜单、新碟上架、场景音乐、电台、编辑精选
- **搜索**：综合 / 单曲 / 歌单 / 专辑 / 歌手 / 歌词 多类型搜索
- **播放器**：专辑封面、滚动歌词、音质切换、播放列表、后台播放
- **歌手**：歌手详情、热门单曲、专辑列表
- **专辑**：专辑详情、歌曲列表、专辑简介
- **歌单**：创建 / 收藏 / 删除歌单
- **音质**：WiFi / 蜂窝 / 下载 三套独立音质设置
- **本地音乐**：扫描设备音频文件并播放

### Wear OS 手表专属

- **圆形屏幕适配**：RoundSafeArea 组件，确保内容不被圆形屏幕裁剪
- **旋钮支持**：wearable_rotary 包，支持旋转表冠滚动内容
- **独立运行**：无需手机 companion，可独立安装和使用
- **语音搜索**：支持语音识别搜索歌曲
- **紧凑布局**：针对手表小屏幕优化的 UI 布局
- **始终深色模式**：手表端强制深色主题，适配 AMOLED 屏幕

---

## 快速开始

### 环境要求

- Flutter SDK（最新稳定版）
- Android SDK（API 33+，Wear OS 3.0+）
- JDK 17+

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
flutter run -d <emulator_id> --target lib/main_watch.dart
```

### API 服务器

默认使用 mjiutang 提供的 Cloudflare 公共节点，可在 **设置 → API 服务器** 中选择路线或自定义地址。

也可自建服务端：https://github.com/MakcRe/KuGouMusicApi

## 构建

### Debug 构建

```bash
flutter build apk --debug --target lib/main_watch.dart
```

### Release 构建

```bash
flutter build apk --release --target lib/main_watch.dart
```

### GitHub Actions

每次推送分支自动编译：\
https://github.com/Tangmjiu/NGS-KG/actions

## 交流群组

| 区域 | 群组 |
|------|------|
| 中国区交流群 | QQ：933027332 |
| International group | Telegram：[t.me/mjiutangducks](https://t.me/mjiutangducks) |

## 赞助支持

服务器的运维以及软件开发需要大量的金钱和精力。如果你喜欢这个软件，欢迎在 [爱发电](https://www.ifdian.net/a/mjiutang) 上打赏支持，你的支持是我持续更新的动力 ❤️

同时，mjiutang 本人倡议社区内自建服务器，以分担 mjiutang 本人的服务器压力。

[![爱发电](https://img.shields.io/badge/爱发电-赞助支持-orange?style=flat-square&logo=githubsponsors)](https://www.ifdian.net/a/mjiutang)

## API

基于 [MakcRe/KuGouMusicApi](https://github.com/MakcRe/KuGouMusicApi) 的 RESTful API。

## 免责声明

1. 请遵循当地法律使用该软件，在线服务协议最终解释权由广州酷狗计算机科技有限公司所有
2. 本项目不存储任何音乐文件，所有音乐数据均来自酷狗音乐官方 API
3. 本项目不提供 VIP 破解，请前往酷狗音乐官方 APP 购买 VIP

## 协议

本项目基于 [MIT](LICENSE) 协议开源。

Copyright © 2025-2026 mjiutang. All Rights Reserved.
