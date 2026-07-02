<p align="center">
  <img src="assets/images/icon.png" width="120" alt="NGS-KG+">
</p>

<h1 align="center">NGS-KG+</h1>

English | [简体中文](../README.md)

<p align="center">
  A Flutter music player based on a third-party KuGou Music API
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#quick-start">Quick Start</a> ·
  <a href="#build">Build</a> ·
  <a href="#support">Support</a> ·
  <a href="#community">Community</a> ·
  <a href="#api">API</a> ·
  <a href="#disclaimer">Disclaimer</a> ·
  <a href="FAQ.md">FAQ</a> ·
  <a href="https://github.com/Tangmjiu/NGS-KG/blob/android/THEME.md">Theme Guide</a> ·
  <a href="https://github.com/Tangmjiu/ngs-kg-themes">Theme Market</a>
</p>

> **Project Name Origin**
>
> **NGS** = Nagisa (from *Ensemble Stars!!*)
> **KG** = KuGou
>
> This project is a Flutter music player developed by the author (a Nagisa fan 🚩) based on a third-party KuGou Music API.
> Built-in image assets are sourced from the official Chinese server sticker pack of *Ensemble Stars!!*. The app supports customizing all images and color schemes via ZIP theme packs.

---

## Features

- **Login**: Phone verification code / QR code login
- **Home**: Daily recommendations, new songs, 6 recommendation cards, resume playback
- **Discover**: Recommended playlists, hot charts, new albums, scene music, radio, editor's picks
- **Search**: Multi-type search — comprehensive / tracks / playlists / albums / artists / MV / lyrics
- **Player**: Album art, scrolling lyrics, quality switching, playlist, background playback
- **Artist**: Artist details, hot tracks, album list, MV
- **Album**: Album details, track list, album description
- **Playlist**: Create / favorite / delete playlists (work in progress)
- **Audio Quality**: Three independent quality settings for WiFi / cellular / download + smart mode (work in progress; music downloads currently unavailable)
- **Notifications**: Notification bar controls, album art, current lyrics display
- **Local Music**: Scan device audio files and play (work in progress)
- **Cloud Drive**: View and play KuGou cloud drive music (work in progress)
- **Theme Market**: Browse, download, and apply community themes (v2.0.0+)

- ![**Screenshots** (v1.0.1)](https://github.com/Tangmjiu/NGS-KG/blob/android/1.png)![](https://github.com/Tangmjiu/NGS-KG/blob/android/2.png)![](https://github.com/Tangmjiu/NGS-KG/blob/android/3.png) ![](https://github.com/Tangmjiu/NGS-KG/blob/android/4.png) ![Dynamic flow light mode player](https://github.com/Tangmjiu/NGS-KG/blob/android/5.png)![](https://github.com/Tangmjiu/NGS-KG/blob/android/6.png)

## Quick Start

### Prerequisites

- Flutter SDK (latest stable version)

### Set Up Mirror (China)

```bash
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
```

### Get Dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### API Server

By default, it uses the Cloudflare public node provided by mjiutang. You can select a route or set a custom address in **Settings → API Server**.

You can also self-host: https://github.com/MakcRe/KuGouMusicApi

## Build

### APK

```bash
flutter build apk --release
```

### GitHub Actions

Automatically built on every push:  
https://github.com/Tangmjiu/NGS-KG/actions

## Community

| Region | Group |
|--------|-------|
| China | QQ: 933027332 |
| International | Telegram: [t.me/mjiutangducks](https://t.me/mjiutangducks) |

## Support

Server maintenance and software development require significant time and money. If you like this app, feel free to support via [爱发电 (Aifadian)](https://www.ifdian.net/a/mjiutang). Your support is my motivation to keep updating ❤️

mjiutang also encourages the community to self-host servers to help share the server load.

[![Support on Aifadian](https://img.shields.io/badge/爱发电-Support-orange?style=flat-square&logo=githubsponsors)](https://www.ifdian.net/a/mjiutang)

## Tech Stack

- Flutter & Dart

## API

Based on the RESTful API from [MakcRe/KuGouMusicApi](https://github.com/MakcRe/KuGouMusicApi).

## Disclaimer

1. Please use this software in compliance with local laws. The final interpretation rights of the online service agreement belong to Guangzhou KuGou Computer Technology Co., Ltd.
2. This project does not store any music files. All music data comes from the official KuGou Music API.
3. This project does not provide VIP cracking. Please purchase VIP from the official KuGou Music app.

## License

This project is open-sourced under the [MIT](LICENSE) license.

Copyright © 2025-2026 mjiutang. All Rights Reserved.
