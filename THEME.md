# 主题制作与兼容指南

NGS-KG+ 使用统一的 Material 3 主题引擎。颜色、字体、页面留白、组件圆角、图片和歌词设置均来自主题模型；浅色、深色与系统动态取色共用同一套组件规则。

默认主题「Ran Nagisa」保留橙红配色和角色插画，并使用新版 MD3E 组件与统一设计参数。已经安装的用户继续使用原先选中的主题、强调色和动态取色设置。「Ran Nagisa」与「MD3 全局」仍保留各自的 ID 和配色行为。

## ZIP 格式 v3

```text
my_theme.zip
├── manifest.json
├── preview.png
├── fonts/
│   ├── Regular.ttf
│   └── Bold.ttf
└── images/
    ├── cover.png
    └── player.png
```

`manifest.json` 必须位于 ZIP 根目录。其余文件可选；所有路径均相对 ZIP 根目录。主题 ID 沿用 ZIP 文件名去除 `.zip`，相同 ID 的导入会更新原主题。内置主题 ID 不能被 ZIP 覆盖。

```json
{
  "version": 3,
  "name": "林间",
  "author": "主题作者",
  "description": "柔和的绿色与清晰的内容层次",
  "colors": {
    "light": {
      "primary": "#216A53",
      "surface": "#F5F9F6",
      "surfaceContainerLow": "#EDF4EE",
      "secondaryContainer": "#EAE3F5"
    },
    "dark": {
      "primary": "#A4D6BB",
      "surface": "#101C17",
      "surfaceContainerLow": "#18251D",
      "secondaryContainer": "#494058"
    }
  },
  "design": {
    "pagePadding": 20,
    "sectionSpacing": 28,
    "cardRadius": 24,
    "controlRadius": 16,
    "contentMaxWidth": 1120
  },
  "typography": {
    "family": "MyFont",
    "weight": {
      "regular": "fonts/Regular.ttf",
      "bold": "fonts/Bold.ttf"
    }
  },
  "assets": {
    "album_placeholder": "images/cover.png"
  },
  "wallpaper": {
    "player": "images/player.png"
  },
  "lyricSettings": {
    "fontSize": 20,
    "fontWeight": 600,
    "centerAlign": false,
    "blurEffect": false
  },
  "motion": {
    "durationScale": 1.0,
    "curve": "emphasized"
  },
  "components": {
    "navigationBar": { "elevation": 0 },
    "card": { "elevation": 0 },
    "dialog": { "elevation": 0 }
  }
}
```

## 配色

`colors.light` 和 `colors.dark` 可分别提供 Flutter `ColorScheme` 的颜色角色，包括：

- 主色、次色、第三色及其 `on*`、`*Container`、`*Fixed` 角色。
- `surface`、`surfaceDim`、`surfaceBright`、五级 `surfaceContainer*` 与对应文字颜色。
- 错误色、描边色、反色、阴影、遮罩与 `surfaceTint`。

已提供的颜色逐项保留；缺失项根据该模式的 `primary` 自动生成。支持 `#RRGGBB`，v3 还支持 `#AARRGGBB`。无效色值回退到生成色。不要使用接近背景的文字颜色，以免内容难以阅读。

有效配色优先级为：系统动态取色、用户强调色、主题自带色板、默认种子色。用户调整强调色时，字体、图片、圆角和歌词配置仍继续生效。

## 设计参数

v3 的 `design` 定义页面和组件共用的尺寸，单位为逻辑像素。

| 字段 | 默认值 | 有效范围 | 用途 |
|---|---:|---:|---|
| `pagePadding` | 20 | 8–48 | 页面左右留白 |
| `sectionSpacing` | 28 | 8–64 | 内容分区间距 |
| `cardRadius` | 24 | 0–48 | 卡片与对话框圆角 |
| `controlRadius` | 16 | 0–32 | 输入框、按钮和导航指示器圆角 |
| `contentMaxWidth` | 1120 | 600–1920 | 宽屏内容最大宽度 |

越界数值会限制到有效范围；错误类型或非有限数值使用默认值。深浅模式切换时尺寸支持插值，不要求页面单独维护主题状态。

旧 `shapes` 的 `xs`、`sm`、`md`、`lg`、`xl` 仍可使用。`lg` 会迁移为 `cardRadius`，`md` 会迁移为 `controlRadius`；其余尺寸保留给对应组件。两者同时存在时，显式 `design` 字段优先。

## 字体、图片与歌词

`typography.family` 指定字体名称；`weight.regular`、`weight.medium`、`weight.bold` 指向字体文件。未指定字体时使用内置 HarmonyOS Sans。字体在应用主题前完成加载，安装记录使用相对路径，启动后恢复为应用目录下的实际文件位置。

支持的图片资源键包括：

| 键 | 用途 |
|---|---|
| `sthiswrong`、`codecrash`、`loading`、`ban` | 错误、加载及屏蔽状态图片 |
| `supportme`、`icon` | 支持页面与图标展示资源 |
| `album_placeholder`、`playlist_placeholder`、`artist_placeholder` | 封面和头像占位图 |
| `empty_playlist`、`empty_content`、`load_failed` | 空状态与加载失败图片 |
| `hi_res_badge` | Hi-Res 标识 |

`wallpaper.player` 为播放器壁纸，保留封面、壁纸与动态流光的现有显示功能。`icon` 是应用内资源，不会通过主题 ZIP 修改 Android 已安装应用的启动器图标。

歌词参数支持 `fontSize`（12–28）、`fontWeight`（100–900）、`centerAlign`、`blurEffect`。主题仅提供默认值；用户手动调整过的歌词设置始终优先，切换主题或重新启动不会被覆盖。

## 动效与组件

`motion.durationScale` 支持 0.5–2.0；`motion.curve` 支持 `emphasized`、`standard`、`linear`。组件 `elevation` 支持 0–24。主题不能替换导航语义、播放器交互方式或组件结构。

## 旧主题与设置迁移

v1、v2 ZIP 无需重新制作即可导入；省略版本的旧包按 v1 解析。历史磁盘 JSON 中的 `lightScheme`、`darkScheme`、`fontWeightFiles`、`assetFiles`、`playerBgPath`、`lyricSettingsOverride` 均由专门适配层读取，安装目录和已有主题 ID 保持兼容。

磁盘记录使用 `schemaVersion: 3`，并保留主题原 `version` 信息。既有 `theme_*` 偏好在首次启动时读取，转换为 `theme_settings_v3` 的完整设置快照。原设置不会因主题引擎升级而重置，主题文件临时不可读时也不会自动删除。

此前新增的 `ngs_default` 仅在读取设置时兼容映射为 `ngs_nagisa`，其余设置保持不变。「MD3 全局」和导入主题的选择不受影响。

## 安装与管理

在设置中的主题页导入 ZIP，或从主题市场安装。主题页提供当前设置下的浅色与深色预览。导入成功后会应用并保存选中状态；删除当前导入主题后回到「Ran Nagisa」。内置主题不可删除。

社区主题注册表：[NGS-KG+ 主题仓库](https://github.com/Tangmjiu/ngs-kg-themes)。提交时附上主题 ZIP、预览图和注册表信息，主题包格式版本使用 `3`。
