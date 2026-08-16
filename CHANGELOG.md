# NGS-KG+ 更新日志

## v1.5.3-preview-watch-hotfix1（2026-08-16）

> **Hotfix 1**：修复三星 Watch4 Classic（One UI 8.0 / Wear OS 6.0）启动闪退，新增日志导出界面。

### 修复

- **三星 Watch4 Classic / Wear OS 6.0 启动闪退**：
  - 移除旧版 Google Play Core（`com.google.android.play:core:1.10.3`），该依赖在 Android 14+ 会因未指定 `RECEIVER_EXPORTED / RECEIVER_NOT_EXPORTED` 抛 `SecurityException` 闪退
  - 前台播放服务 `PlaybackService` 在 Android 14+（API 34+）显式声明 `mediaPlayback` 前台服务类型，避免 `MissingForegroundServiceTypeException`
  - 原生库（`.so`）按 16KB 内存页对齐打包（`useLegacyPackaging = false`），适配 Wear OS 6（Android 15+），避免 `dlopen` 失败导致启动闪退
  - 完善 release 混淆 ProGuard 规则，补全 `wear_plus`、`wearable_rotary`、`just_audio`、`flutter_local_notifications`、`permission_handler`、`on_audio_query`、Wear OS Tiles 等插件原生类 keep 规则，防止 `NoClassDefFoundError` 闪退

### 新增

- **日志导出界面**（设置 → 导出日志）：
  - 独立页面，一键导出完整日志文件
  - 导出内容：设备 / 应用信息头 + Android logcat（本进程）+ Flutter 内存日志（含 `FlutterError` / 平台错误）+ 磁盘历史日志
  - 导出后展示文件路径，并提供三种取回方式的操作指引：
    - **电脑 / 平板**：通过 adb pull 取回
    - **手机**：通过甲壳虫ADB助手（国内推荐）/ LADB / Bugjaeger 无线连接取回
    - **USB 数据线**：文件管理器直接复制
  - 文件位置：`{appDocDir}/logs/ngskg_watch_log_<时间戳>.txt`

### 构建

- 版本号：`1.5.3-preview-watch-hotfix1`（versionCode `251`，高于旧版 `21`，应用商店可正常推送更新）
- 发布多架构 Release APK：`arm64-v8a` / `armeabi-v7a` / `x86_64`

## v1.5.0-preview（2026-07-xx）

> **首次发布**：Wear OS 手表版基于 Android 分支移植，针对圆形屏幕和手表交互优化。

### 新增

- **圆形屏幕适配**：RoundSafeArea 组件，确保内容不被圆形屏幕裁剪
- **旋钮支持**：wearable_rotary 包，支持旋转表冠滚动内容
- **独立运行模式**：无需手机 companion，可独立安装和使用（com.google.android.wearable.standalone = true）
- **语音搜索**：支持语音识别搜索歌曲
- **紧凑布局**：针对手表小屏幕优化的 UI 布局（歌曲列表、迷你播放器、设置页等）
- **始终深色模式**：手表端强制深色主题，适配 AMOLED 屏幕
- **手表主题系统**：WatchThemeProvider，强制深色模式
- **中文本地化**：手表端界面中文化
- **FM 支持**：手表端 FM 播放功能

### 变更

- **精简代码**：移除移动端专属功能，保留手表端核心功能
- **入口点**：使用 main.dart 作为手表端入口
- **主题适配**：替换硬编码颜色为主题颜色

### 修复

- **FM 行崩溃**：修复 null currentSong 导致的崩溃
- **FM 无限重载**：停止发现页 FM 无限重载循环
- **API 错误处理**：未登录时静默抑制非登录 API 错误；safe int parsing
- **登录界面**：添加滚动支持，修复 dispose 安全的 auth 回调
- **循环依赖**：将 navKey 移至独立文件解决编译错误

### 基础设施

- **CI 工作流**：Wear OS 平台构建配置
- **构建命令**：`flutter build apk --debug`
- **项目文档**：更新目录结构/技术栈/开源说明
