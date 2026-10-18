# 界面重构验证记录

界面采用 Material 3 Expressive 的排版、形状与动效层级；全屏播放器保留原有 Apple Music 风格。业务状态继续由 Provider 管理，主题兼容集中在迁移层。

| 要求 | 实现与验证入口 |
| --- | --- |
| 首页、发现、搜索、资料库统一导航 | `AppNavigation` 使用原生导航组件；`home_navigation_test.dart` 验证懒加载、切页与跨宽度断点后的状态保留 |
| 私人 FM 与正常播放功能保留 | `discover_fm_concurrency_test.dart` 验证切换、退出、迟到响应和暂停/停止；原播放、队列与音质测试继续运行 |
| 动态流光恢复 | `player_background_test.dart` 使用解码后的在线封面缓存，检查实际像素运动、开关、暂停缓停与前后台切换 |
| 旧主题与设置继续生效 | `theme_migration_test.dart` 覆盖 v1/v2/v3 清单、旧偏好键、旧主题 ID、资源与歌词覆盖；`market_theme_install_test.dart` 验证安装提交后市场记录失败仍更新当前资源 |
| 动效可打断并遵从系统偏好 | `app_motion_test.dart` 验证弹簧反向连续性、减少动效、隐藏停帧、拖动取消和计时器释放 |
| 加载形变不重建页面 | `app_loading_indicator_test.dart` 验证实际像素变化、组件复用、前后台与主题速度倍率 |
| 主要/普通操作有层级 | `button_interaction_test.dart` 验证实际材质、触摸外沿、按压形状及旧主题显式圆角 |
| 可访问导航与播放控制 | `app_navigation_accessibility_test.dart` 运行 48dp/标签检查、选中语义与键盘操作；播放器测试检查加载状态和可调整的时间语义 |
| Android 返回手势 | `theme_navigation_test.dart` 向系统通道发送开始、更新、取消、提交事件，检查实际预览和页面状态 |
| 小屏、大字、深色与宽屏 | 页面布局测试与 `lib/ui/previews.dart`；本地已检查 390 宽浅/深色、320 宽 1.5 倍字体、840 宽真实页面截图 |

视觉核验发现的窄屏英文入口断行已通过随字号调整资料库列数解决。页面转场不会重新创建已访问页面；进入后台、隐藏页面或减少动效时，持续动画停止运行。

设计参数核对来源：AndroidX Material 3 的 [动效令牌](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/ExpressiveMotionTokens.kt)、[按钮](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/Button.kt)和[排版令牌](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt)。

复核命令：

```bash
flutter test --no-pub --concurrency=1
flutter analyze --no-pub
git diff --check
```

本地全套结果：213 项正式测试通过，1 项原有测试跳过；设置页四种配置的临时预览测试也已通过。静态分析 0 个错误、10 个既有警告、102 个提示。改动的 Dart 文件已格式化，差异空白检查通过。日志为 `/tmp/ngskg-nagisa-final-tests.log` 与 `/tmp/ngskg-nagisa-final-analyze.log`。

默认主题为 Ran Nagisa，沿用橙红配色、角色插画和 `ngs_nagisa` ID，接入新版 MD3E 设计参数。旧偏好与 v3 快照均验证主题选择、强调色、动态取色、流光、Hi-Res、歌词和支持弹窗设置的保留；`ngs_default` 只在设置读取时转换为 `ngs_nagisa`。

完整预览位于手机共享存储 `/storage/emulated/0/NGS-KG-UI预览/`，包括 296 张静态页面、16 张分页总览和 2 个动效 GIF，可通过 `index.html` 离线浏览。首页每日推荐使用推荐首曲的「歌名-歌手」，私人 FM 小字为「概念同款」。

本地验证环境为 Flutter 3.44.0 / Dart 3.12.0。CI 仍固定 Flutter 3.41.0；本次未更改依赖与版本。当前没有连接 Android 设备，Widget 像素、停帧与行为测试不代表真机 GPU 帧率、温度或电量结果；在线音乐服务的实际登录与播放也仍需设备端验收。
