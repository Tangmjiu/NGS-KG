# NGS-KG+

基于酷狗音乐第三方 API 的跨平台音乐播放器。

## 关于名称

- **NGS** - 取自 [乱凪砂](https://mzh.moegirl.org.cn/乱凪砂)（らん なぎさ / Ran Nagisa）
- **KG** - KuGouMusic（酷狗音乐）
- **+** - Plus（增强版）

## 功能

- 用户登录（手机验证码 / 密码 / 二维码）
- 热门歌单浏览与收藏
- 音乐搜索
- 在线播放
- 歌词显示
- 排行榜
- 个性推荐

## 技术栈

| 平台   | 技术              |
| ------ | ----------------- |
| 移动端 | Flutter + Dart    |
| 状态管理 | Provider         |
| 网络请求 | Dio + CookieJar  |
| 音频播放 | audioplayers     |
| 本地存储 | sqflite          |
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

### 桌面端

```bash
cd desktop
npm install
npm run dev
```

## API

本项目使用酷狗音乐第三方 API，基础地址：

```
https://kugouapi.mjiutang.qzz.io
```

支持的接口包括：登录、歌单、搜索、播放、歌词、排行榜、评论、曲谱等。详见 `CLAUDE.md`。

### 注意事项

- Cookie 需持久化保存并在后续请求中携带
- 播放地址有效期约 15 分钟，播放前实时获取
- User-Agent 需模拟酷狗官方客户端
- 请勿用于商业用途

## 项目结构

```
├── android/          # Android 原生工程
├── lib/              # Dart 源码
│   ├── main.dart     # 应用入口
│   ├── models/       # 数据模型
│   ├── providers/    # 状态管理
│   ├── routes/       # 路由配置
│   ├── screens/      # 页面
│   ├── services/     # API 服务
│   ├── utils/        # 工具
│   └── widgets/      # 通用组件
├── assets/           # 静态资源
├── test/             # 测试
├── web/              # Web 平台
└── desktop/          # 桌面端
```

## 未来进展

- 开发 Windows 桌面端
- 开发 HarmonyOS 端（实验性）

## License

仅供个人学习研究使用。
