# NGS-KG+ 更新日志

## v1.5.0-preview（2026-07-xx）

> **首次发布**：Linux 桌面版基于 Windows 分支移植，使用 MPRIS D-Bus 实现系统媒体控制。

### 新增

- **MPRIS 集成**：D-Bus 音乐播放器接口，支持系统媒体控制（播放/暂停/上一首/下一首），正确设置 MPRIS 元数据（标题、艺术家、专辑、封面）
- **窗口拖动**：通过 window_manager 实现窗口拖动（排除 m3_title_bar 区域）
- **Navidrome 登录**：从全屏路由改为弹窗覆盖层形式，添加关闭按钮和 surface 背景
- **桌面外壳（DesktopShell）**：自定义侧边栏导航 + 窗口装饰组件
- **本地音乐系统**：文件扫描、元数据读取、播放支持
- **歌词设置**：字体大小 / 对齐 / 字重 / 模糊度可调
- **Hi-Res 标识**：设置页开关控制，官方 JPG 标识覆盖在专辑封面上
- **桌面适配**：响应式布局适配所有屏幕

### 变更

- **播放器引擎**：使用 media_kit 作为音频后端
- **桌面 UI 重构**：二级页面 UI 全面更新
- **Provider 层重构**：统一访问模式，移除 AppShell/IndexedStack 兼容层
- **歌词系统**：适配桌面端至新版 flutter_lyric 系统

### 修复

- **FM 行崩溃**：修复 null currentSong 导致的崩溃
- **FM 无限重载**：停止发现页 FM 无限重载循环
- **MPRIS 元数据**：修复 D-Bus variant 类型问题
- **API 错误处理**：未登录时静默抑制非登录 API 错误；safe int parsing
- **登录界面**：添加滚动支持，修复 dispose 安全的 auth 回调
- **底部播放栏**：LayoutBuilder+Flexible 修复右侧溢出
- **循环依赖**：将 navKey 移至独立文件解决编译错误
- **合并冲突**：替换合并中损坏的文件为 Android 原始版本 + 补充缺失方法
- **VS 2026 兼容**：添加 _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
- **Navidrome 登录**：从全屏路由改为弹窗覆盖层，添加关闭按钮和 surface 背景
- **API 错误处理**：未登录时静默抑制非登录 API 错误；safe int parsing

### 基础设施

- **CI 工作流**：Linux 平台构建配置（待补充）
- **项目文档**：更新目录结构/技术栈/开源说明
- **依赖更新**：降级 sqflite_common_ffi 至 ^2.4.0+3 以兼容 Dart 3.11
