# CLAUDE.md

本文件为 Claude 提供项目上下文、技术规范及 API 接口参考。

## 项目概述

- **项目名称**：NGS-KG+
- **目标平台**：移动端（Android / iOS），桌面端（Electron + Vue3/React）
- **核心功能**：基于酷狗音乐第三方 API，实现用户登录、歌单管理、音乐搜索、在线播放、歌词显示、排行榜、曲谱查看等
- **主要技术栈**：
  - 移动端：Flutter（Dart）
  - 桌面端：Electron + Vue3/React
  - 音频播放：移动端 just_audio，桌面端 HTML5 Audio / Zeaker
  - 本地存储：移动端 sqflite，桌面端 SQLite
- **开发环境**：Linux ARM64 无桌面版 Ubuntu（只能构建 APK，无法运行模拟器）

## 环境配置

```bash
# Android SDK (ARM64)
export ANDROID_HOME="$HOME/Android/Sdk"
# Flutter SDK
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export PATH="$PATH:$HOME/flutter/bin"
```

这些已在 `~/.bashrc` 中配置好。

## 目录结构

```
KuGouMusic/
├── mobile/                 # Flutter 移动端项目（主要）
│   ├── lib/               # Dart 源码
│   ├── android/           # Android 原生工程
│   └── test/              # 测试
├── desktop/               # Electron 桌面端（待创建）
└── docs/                  # 文档
```

## 常用命令

### 移动端（Flutter）— 在 mobile/ 目录下执行

```bash
# 获取依赖
cd mobile && flutter pub get

# 构建 Android APK（debug）
cd mobile && flutter build apk --debug

# 构建 Android APK（release，需要签名配置）
cd mobile && flutter build apk --release

# 构建 Android App Bundle
cd mobile && flutter build appbundle

# Flutter 静态分析
cd mobile && flutter analyze
```

### 桌面端（Electron + Vue/React）

```bash
# 安装依赖
cd desktop && npm install

# 开发模式（启动渲染进程 + Electron）
cd desktop && npm run dev

# 打包各平台安装包
cd desktop && npm run build:win     # Windows
cd desktop && npm run build:mac     # macOS
cd desktop && npm run build:linux   # Linux
```

### 代码质量

```bash
# Flutter 格式化
cd mobile && dart format lib/

# Flutter 静态分析
cd mobile && flutter analyze

# 前端代码
cd desktop && npm run lint
```

代码风格与约定

· 前端（JavaScript/TypeScript）：
  · 使用 ESLint + Prettier，配置基于 Airbnb 或 Vue/React 官方规则
  · 行宽 100 字符
  · 变量/函数：camelCase，组件：PascalCase
  · 常量：UPPER_SNAKE_CASE
  · 优先使用 async/await 处理异步逻辑
· Flutter（Dart）：
  · 遵循官方 Dart 风格指南
  · 使用 flutter format 自动格式化
  · 类名：PascalCase，变量/方法：lowerCamelCase
· 提交信息：采用 Conventional Commits 格式
  · feat: 新功能
  · fix: 修复 bug
  · docs: 文档更新
  · refactor: 重构
  · chore: 构建/工具变动

项目结构

```
KuGouMusic/
├── mobile/                # Flutter 移动端代码
│   ├── lib/               # Dart 源码
│   ├── android/           # Android 原生工程
│   └── test/              # 测试
├── desktop/               # Electron 桌面端代码（待创建）
│   ├── main/              # 主进程
│   ├── renderer/          # 渲染进程（Vue/React）
│   └── resources/         # 图标、静态资源
├── shared/                # 跨端共享模块（如有）
│   └── api-client/        # 统一的 API 调用封装
└── docs/                  # 文档
```

第三方 API 参考（酷狗音乐精简版）

本项目直接调用酷狗音乐第三方 API，所有接口均基于 https://kugoumusicapi-docs.4everland.app 提供的文档。
以下为已采纳的核心接口列表（不含短视频、听书等非音乐功能）。

一、登录与用户

接口路径 说明
/login/cellphone 手机验证码登录
/login 用户名密码登录
/login/qr/key 二维码登录：生成 key
/login/qr/create 二维码登录：生成二维码
/login/qr/check 二维码登录：检测扫码状态
/login/token 刷新登录状态
/captcha/sent 发送验证码
/user/detail 获取用户额外信息
/user/playlist 获取用户歌单
/user/history 获取用户最近听歌历史

二、歌单管理

接口路径 说明
/playlist/add 收藏歌单 / 新建歌单
/playlist/del 取消收藏歌单 / 删除歌单
/playlist/tracks/add 对歌单添加歌曲
/playlist/tracks/del 对歌单删除歌曲

三、专辑与音乐信息

接口路径 说明
/album 专辑信息
/album/detail 专辑详情
/album/songs 专辑音乐列表
/song/url 获取音乐 URL
/song/url/new 获取音乐 URL（新版）
/lyric 获取歌词

四、搜索与推荐

接口路径 说明
/search 通用搜索（单曲、歌单等）
/search/hot 热搜列表
/search/suggest 搜索建议
/personal/fm 私人 FM
/everyday/recommend 每日推荐
/top/card 歌曲推荐

五、歌单与主题

接口路径 说明
/playlist/tags 歌单分类
/top/playlist 歌单列表
/playlist/detail 获取歌单详情
/playlist/track/all 获取歌单所有歌曲

六、歌手相关

接口路径 说明
/artist/list 获取歌手列表
/artist/detail 获取歌手详情
/artist/albums 获取歌手专辑
/artist/audios 获取歌手单曲

七、排行榜

接口路径 说明
/rank/list 排行列表
/rank/audio 排行榜歌曲列表
/top/song 新歌速递

八、评论

接口路径 说明
/comment/music 歌曲评论
/comment/playlist 歌单评论
/comment/album 专辑评论

九、曲谱

接口路径 说明
/sheet/list 歌曲曲谱
/sheet/detail 曲谱详情
/sheet/hot 推荐曲谱

十、电台 / 乐库 / 编辑精选

接口路径 说明
/yueku/banner 乐库 Banner
/fm/recommend 推荐电台
/fm/songs 电台音乐列表
/top/ip 编辑精选
/ip/playlist 编辑精选歌单

十一、实用工具

接口路径 说明
/playhistory/upload 提交听歌历史
/server/now 获取服务器时间

调用 API 时的注意事项

1. 跨域问题：Electron 桌面端须从主进程使用 Node.js 网络库（如 axios）发起请求，避免浏览器 CORS 限制；移动端无跨域问题可直接请求。
2. Cookie 管理：登录接口返回的 Set-Cookie 需持久化保存，并在后续每个请求中带上 Cookie 头。
3. User-Agent：必须设置合理的 User-Agent，推荐模仿酷狗官方客户端，否则可能被拒绝请求。
4. 播放地址有效期：通过 /song/url 获取的播放链接通常 15 分钟内有效，播放前实时获取，播放中遇到 403 需重试获取新链接。
5. 请求频率：存在反爬限制，建议对热门搜索和歌单列表做本地缓存（TTL 1-2 小时），并实现失败重试（指数退避）。
6. 合规声明：这些接口并非酷狗官方公开 API，仅供个人学习研究，请勿用于商业盈利或大量请求。

测试要求

· 单元测试覆盖核心工具函数和 API 请求模块
· 桌面端需测试各平台（Windows/macOS/Linux）的音频播放和窗口适配
· 移动端需测试后台播放、锁屏控制、网络切换场景
· 测试覆盖率目标：>70%

与 Claude 交互约定

· 当我请求添加新功能时，请同时提供对应的 API 接口（参照上述列表）和代码示例。
· 当需要重构时，请先说明改动影响范围。
· 所有生成的代码注释和文档中不得出现 Emoji 图标。
· 涉及酷狗 API 的部分，请优先使用上述列表中已有的接口，不要杜撰不存在的路径。
