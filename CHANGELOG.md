# NGS-KG+ 更新日志

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
