# NGS-KG+

基于酷狗音乐第三方 API 的 Flutter 跨平台音乐播放器。

目前原生支持 Android 端，并已适配 Windows 和 Linux 桌面端。

[![Version](https://img.shields.io/badge/Version-1.5.1--preview-blue?style=flat-square)](https://github.com/Tangmjiu/NGS-KG)
[![Nightcord](https://img.shields.io/badge/Nightcord-v2.0.0-purple?style=flat-square)](https://github.com/Tangmjiu/NGS-KG)

---

## 项目命名与背景

* **NGS**：凪砂（出自《偶像梦幻祭2》）
* **KG**：酷狗 (KuGou)

本项目支持通过 ZIP 主题包自定义界面图片与配色。

---

## 核心功能

* **登录管理**：支持手机验证码和酷狗 App 二维码扫码登录。
* **音乐播放**：支持专辑封面显示、LRC/KRC 歌词逐行高亮、音质自动切换与后台稳定播放。
* **音乐库与搜索**：多类型综合搜索（单曲/歌单/专辑/歌手/MV/歌词），支持每日推荐与场景音乐。
* **个人中心**：可创建、收藏或删除个人歌单。
* **本地音乐**：可扫描并播放设备本地存储的音频文件。
* **云盘集成**：支持读取并播放酷狗个人云盘中的音乐。
* **个性化**：内置主题市场，支持在线浏览、下载及一键应用社区主题。
---

## 快速开始

### 开发环境

* Flutter SDK（最新稳定版）
* Android SDK（API 26+）
* JDK 17+

### 初始化与运行

1. 获取依赖：
   ```bash
   flutter pub get
   ```
2. 启动应用：
   ```bash
   flutter run
   ```

### API 服务器

应用默认使用内置的 Cloudflare 节点。您可以在应用的 **“设置” -> “API 服务器”** 中切换路线，或使用以下开源项目自建 API 服务：
[MakcRe/KuGouMusicApi](https://github.com/MakcRe/KuGouMusicApi)

---

## 构建发布

* 构建 Debug 包：
  ```bash
  flutter build apk --debug
  ```
* 构建 Release 拆分包（分架构缩小体积）：
  ```bash
  flutter build apk --release --split-per-abi
  ```

---

## 交流与赞助

* **交流群组**：QQ 群：933027332 | Telegram：[t.me/mjiutangducks](https://t.me/mjiutangducks)
* **赞助支持**：项目运维和维护需要成本，如果觉得好用，可以在爱发电赞助作者。同时鼓励有能力的用户自建 API 节点分担公用服务器压力。

---

## 免责声明

1. 本项目仅供学习交流，请在当地法律法规允许的范围内使用。
2. 本项目不存储任何音乐文件，所有音乐数据均来自酷狗音乐官方 API，在线服务协议最终解释权归酷狗音乐所有。
3. 本项目不提供 VIP 破解功能，如需享受高品质音乐请支持正版。

---

## 许可协议

本项目基于 [MIT](LICENSE) 协议开源。

Copyright © 2025-2026 mjiutang. All Rights Reserved.
