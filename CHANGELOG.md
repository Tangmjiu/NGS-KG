# NGS-KG+ 更新日志

## v1.5.3-preview（2026-08-06）

### 新增（Material 3 Expressive 重构 · 对标 Rhythm）

- **Material Symbols 可变权重图标系统**：引入 `material_symbols_icons`（wght/FILL/GRAD/opsz 四轴可变字体），新增 `AppIcon` 封装（常规/选中/轻盈三档预设）与语义化图标常量
- **Rhythm 式播放控制动效**：播放/暂停图标弹性切换（easeOutBack overshoot + 回旋 + 淡入）、按钮按压缩放反馈、切换/切歌触感反馈（haptic）
- **进度条增强拖拽**：拖动时滑块放大、目标时间气泡跟随拇指位置弹性弹出
- **歌词渐变扫光高亮**：播放行从纯白渐变至透明尾迹（`activeHighlightGradient`），同步滚动/锚点机制不变
- **封面双击喜欢**：双击专辑封面快速喜欢/取消（未登录引导登录），带触感反馈
- **全局图标升级**：播放页底栏、MiniPlayer、首页 NavigationBar、播放队列改用 Material Symbols；NavigationBar 选中态用 weight 700 + fill 1 表达
- **播放队列交错入场动画**：队列行 30ms 间隔交错滑入

### 保留（硬约束）

- 播放界面布局、歌词展示方式（同步高亮机制）、动态流光背景均未改动

## v1.5.0-preview（2026-07-xx）

### 新增

- **FM 系统重构**：隔离 FM 队列系统，替换「上一首」为「不喜欢」，QueueType 枚举实现队列隔离
- **FM 播放改进**：缓冲管理、去重、顺序模式、fetchNextFmBatch 主动填充、非破坏性模式切换
- **FM 反馈循环**：updateFmFeedback 完整实现，修复 deadlock 路径
- **歌词设置**：字体大小 / 对齐 / 字重 / 模糊度可调
- **Hi-Res 标识**：设置页开关控制，官方 JPG 标识覆盖在专辑封面上
- **跨淡入淡出（Crossfade）**：播放切换时自动淡入淡出
- **系统均衡器**：Android 系统均衡器集成
- **KRC 歌词翻译/罗马音**：支持翻译 / 罗马音切换显示
- **多队列系统**：多队列底部 sheet、跳转到当前播放、将队列存为歌单
- **专辑详情多选**：批量添加到歌单
- **歌单滑动删除**：歌单详情页滑动删除歌曲 + 收藏歌单 + 评论入口
- **SongTile 喜欢按钮**：长按菜单（下一首播放 / 添加到歌单 / 查看专辑）
- **收藏歌单 API**：PlaylistProvider 封装 create/delete/collect 并自动刷新
- **流光帧率监控**：自动降频 + elapsed 模运算修复三角函数精度丢失
- **队列持久化**：完整歌单序列化 + palette 缓存 + enqueuePlaylist
- **调色板突变动画**：AnimatedSwitcher 600ms 淡入淡出过渡
- **相似歌单 API**：/playlist/similar 端点
- **新歌单歌曲接口**：/playlist/track/all/new 版本
- **PreviewConfig 系统**：preview.yaml 开关与运行时加载器，设置页显示 preview 标记
- **主题市场 UI**：MarketService 配套（Screen/Provider/Loader）
- **主题资源系统**：空状态插画、emptyStateWidget 组件、全局主题背景
- **主题包模型扩展**：动效 / 组件 / 字重 / 空状态资源字段
- **主题构建器**：支持 surface 半透明与形状 / 动效 / 组件覆盖

### 变更

- **UI 重构**：温和版 + 沉浸歌词风格
- **Provider 层重构**：三处 UI 改为通过 Provider 获取 MusicService，统一访问模式
- **播放列表 sheet**：支持滑动删除和长按拖拽排序；区分 radio 模式图标
- **迷你播放栏**：gap 从 8px 增加到 16px，NavigatorObserver 修复设置页/登录页隐藏失效
- **队列引擎**：修复崩溃 bug 3 项，新增 removeAt/move/insertAt/playNextSong 方法
- **LikedSongsProvider**：新增 clear() 方法供退出登录时清理缓存
- **版本管理**：版本号从 PackageInfo 动态读取
- **CI 调整**：取消 push 自动触发编译，仅手动/PR 触发

### 修复

- **FM UI 问题**：动态流光背景全黑（调色板颜色不足时补充派生色 + 流光未就绪时回退封面）
- **FM 数据加载**：修复 FM data loading bug，add buffer management
- **每日推荐 ID**：修复 MixSongID 错误 + 历史上传重试+服务端时间戳
- **登出清理**：清空 likedSongs 缓存 + 修复 auth 竞态条件
- **jsonDecode 安全**：处理 null 安全（res.data 为 String?）
- **Gradle 版本号**：正则缺少 (?m) multiline 标志导致始终回退默认值
- **数据库路径**：sqflite_common_ffi 降级至 ^2.4.0+3 以兼容 Dart 3.11
- **MiniPlayer 点击**：通过 navKey 推播放器页面并管理可见性状态
- **切歌音频**：resetForNewSong 时停掉播放器，避免旧音频继续播放

### 基础设施

- **主题市场迁移**：marketplace/ 目录移至独立仓库 ngs-kg-themes
- **资源目录注册**：assets/config/ 资源目录
- **connectivity_plus 自动注册**：插件自动注册

---

## v1.0.1（2026-06-14）

### 新增

- **Apple Music 风格动态流光播放器背景**：基于 HSL 色彩空间在色相环上生成 8 个流动光斑，每 5 秒循环一次，通过每帧偏移 0.005 色相 + per-blob 锚点实现各色区域独立运动，配合大半径高斯模糊 (`sigmaX=420, sigmaY=320`) 呈现柔光混色效果
- **MD3 设计令牌系统**：新增 `AppShape`（xs/sm/md/lg/xl/full 圆角体系）、`AppMotion`（标准/强调/减速/舒缓时长 + 缓动曲线）、`AppBreakpoint`（MD3 响应式断点 `compact/medium/expanded`）三大设计令牌类
- **跨平台更新检测器**：通过 GitHub Releases API 检查最新版本，识别 Android ABI（arm64-v8a / armeabi-v7a / x86_64）并下载对应 APK，支持 Play Store 方案（同一定位）
- **设置重构 - 音质子页面**：原 WiFi/蜂窝/下载三套独立音质设置从设置列表移入独立子页面，设置组按「播放」「音频」「更新」「关于」重新组织

### 变更

- **Android 包名迁移**：`com.kugou.ngskg` → `com.mjiutang.ngskg`，变更涉及 AndroidManifest、MainActivity、PlaybackService、MediaButtonReceiver 及所有 Kotlin 文件
- **版本管理统一**：版本号单一源 `pubspec.yaml`，`build.gradle` 通过脚本读取，消除版本号漂移
- **低版本版号策略**：`version` 锁定为 `1.0.0+1`（与显示版本一致），不跟随 CI 或 commit 号
- **通知歌词前缀**：移除通知标题中的「♪」前缀，纯文本歌词
- **锁屏播放修复**：后台服务切换为 `START_STICKY` + 持久化播放状态，防止进程被系统回收后静音

### 修复

- **播放器背景**：流光效果覆盖全屏范围，8 色斑独立错开锚点避免颜色区域重叠；色彩明度钳制在 `[0.12, 0.85]` 防止过曝/过暗；新增 `HSLColor` 导入避免类型推断错误；8 量化调色板提升颜色丰富度
- **锁屏歌词延迟**：锁屏界面歌词切换不再滞后，流光动画参数优化（5s 周期替代 10s）
- **排行榜底部溢出 49px**：`SafeArea` 边距适配
- **日志详情行溢出 8.5px**：`itemExtent` 从 64 调整至 72
- **发现页集合字面量语法错误**：纠正 `[...if(...) ...]` 内联变量表达式
- **CI debug 构建**：仅输出 `arm64-v8a` 单架构，速度从 `~25min` 降至 `~12min`
- **历史 API pagesize**：播放历史/听歌记录增加 `pagesize=300` 参数

### 基础设施

- **MIT 许可证**：项目根目录添加 `LICENSE` 文件，主要源文件添加 SPDX 头部
- **版本读取兼容 CI**：`build.gradle` 改为从 `pubspec.yaml` 读取版本号，统一 CI 与本地构建行为
- **GitHub Actions**：debug 工作流仅单架构快速构建，release 工作流保留三架构（arm64-v8a / armeabi-v7a / x86_64）手动触发

---

## v1.0.0（2026-06-13）

### 新增

- **歌词引擎迁移至 flutter_lyric**：KRC 解析后直接构造 LyricModel，逐字卡拉 OK 时序 100% 保留，零字符串格式转换
- **Android 通知栏歌词**：Media3 系统媒体控件现在正确显示当前歌词行（标题 = ♪ 歌词，正文 = 歌名 - 歌手）
- **歌词行切换动画**：进入/退出行缩放 + 颜色过渡
- **歌词顶部/底部渐隐**：视口边缘半透明渐变
- **API 请求静默降级**：专辑/歌单列表先试 `pagesize=1000`，502 不弹窗自动降级重试

### 修复

- 播放器通知不显示歌词（Kotlin 侧 `lyricLine` 参数未存储/使用）
- 逐字卡拉 OK 效果不可见（`activeStyle.color` 与 `activeHighlightColor` 同为白色）
- 拖拽进度条后进入歌词页焦点丢失
- 发现页私人 FM 列表为空（`Song.fromJson` 不兼容酷狗数据格式）
- 发现页「播放全部」触发全页刷新
- 专辑/歌单列表因缺少 `pagesize` 参数返回空结果
- 歌单列表 `gid` 字段缺失拼错 `gcId`
- 专辑详情页 `songCount` 显示为 0

### 移除

- 乐库电台（`/yueku/fm`）UI 及代码
- 自建歌词模型/渲染/视图（`LyricLine`/`LyricSpan`/`LyricLinePainter`/`AMLyricsView`）

### 已有 UI 但未实现的功能

| 功能 | 状态 |
|------|------|
| **MV/视频播放** | 搜索中有 MV 类型选项、歌手页有 MV 选项卡、路由中有 `MvPlayerScreen`，但所有后端代码已注释暂停适配 |
| **私人 FM（猜你喜欢）** | 发现页有 UI 入口和「播放全部」按钮，但 `/personal/fm` API 端点可能因服务器节点不支持而失效 |
| **网络类型检测** | `_isWifi` 硬编码返回 `true`，未接入 `connectivity_plus`，WiFi/蜂窝独立音质设置无法按实际网络生效 |
| **收藏检测** | 暂未实现 |
