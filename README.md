<p align="center">
  <img src="assets/images/icon.png" width="120" alt="NGS-KG+">
</p>

<h1 align="center">NGS-KG+</h1>

<p align="center">
  基于酷狗音乐第三方 API 的 Flutter 音乐播放器（Wear OS 手表版 · Lite）
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.5.9--preview--watch-blue?style=flat-square" alt="v1.5.9-preview-watch">
  <img src="https://img.shields.io/badge/Nightcord-v2.0.0-purple?style=flat-square" alt="Nightcord v2.0.0">
</p>

<p align="center">
  <sub>代号 Nightcord 来自 QQ 群代号投票。至于为什么选这个，我也不知道。</sub>
</p>

<p align="center">
  <a href="#功能">功能</a> ·
  <a href="#快速开始">快速开始</a> ·
  <a href="#构建">构建</a> ·
  <a href="#交流群组">交流群组</a> ·
  <a href="#赞助支持">赞助支持</a> ·
  <a href="#API">API</a> ·
  <a href="#免责声明">免责声明</a>
</p>

> **项目名称释义**
>
> **NGS** = 凪砂（出自《偶像梦幻祭2》）
> **KG** = 酷狗 (KuGou)
>
> 这是作者（本人 ngs 推🚩）基于酷狗音乐第三方 API 做的 Flutter 音乐播放器。
> 当前分支只保留手表版需要的功能。

---

## 功能

- **登录**：二维码登录、手机验证码登录
- **聆听**：继续播放、快捷操作、私人 FM、排行榜、播放队列
- **发现**：搜索、私人 FM、排行榜
- **音乐库**：歌单、收藏、本地音乐、播放队列
- **设备与我**：账号、Wi-Fi 音质、音频输出、设置、日志导出
- **播放**：专辑封面、同步歌词、音量、播放模式、倍速、音质信息
- **系统入口**：桌面磁贴显示当前曲目，点击打开应用

### Wear OS 手表适配

- 圆形屏幕按直径 12% 留白，适配 192dp 和 225dp 表盘
- 表冠按当前页面滚动列表，播放页转动表冠调音量
- 支持右滑返回、双击播放页暂停或继续
- 独立运行，不依赖手机 companion
- 深色主题，适配 AMOLED 屏幕
- 息屏显示时间、曲目和播放状态

---

## 快速开始

### 环境要求

- Flutter SDK 3.44.0
- Android SDK API 36
- JDK 17

### 配置镜像源（国内）

```bash
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
```

### 获取依赖

```bash
flutter pub get --enforce-lockfile
```

### 运行

```bash
flutter run -d <emulator_id>
```

### API 服务器

默认使用 mjiutang 提供的 Cloudflare 公共节点。设置页可切换内置路线，也可自建服务端：

https://github.com/MakcRe/KuGouMusicApi

## 构建

本地构建会同时生成 arm64-v8a 和 armeabi-v7a 架构的 APK：

```bash
flutter build apk --debug --target-platform android-arm64,android-arm
flutter build apk --release --target-platform android-arm64,android-arm
```

Watch CI 先执行静态分析和单元测试，再构建 Debug 与 Release APK：

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
