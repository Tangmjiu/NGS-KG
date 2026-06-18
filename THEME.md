# 主题包制作指南

NGS-KG+ 支持通过 ZIP 文件导入自定义主题包，可替换全套配色、字体、形状和图片资源。

## 主题市场

v2.0.0 起内置主题市场。App 内 **设置 → 主题市场** 可浏览、下载、应用社区主题。

市场注册表托管在 [Tangmjiu/ngs-kg-themes](https://github.com/Tangmjiu/ngs-kg-themes)：
- 主题包 ZIP 文件直接存放在 `themes/<id>/` 目录中
- 注册表 `registry.json` 索引所有可用主题
- 提交主题 → Fork 该仓库 → 添加主题目录和注册表条目 → Pull Request

## 内置主题包

软件内置两个主题包，不可删除：

| 名称 | 说明 |
|------|------|
| **NGS 凪砂**（默认） | 完整 30 色硬编码色板 + 角色状态图 |
| **MD3 全局** | 纯 Material Design 3 规范，无自定义图片，适合偏好原生 MD3 风格的用户 |

## 文件结构

一个完整的主题包是一个 `.zip` 文件，内部结构如下：

```
my_theme.zip
├── manifest.json              # 主题配置（必填）
├── preview.png                # 主题预览封面（可选，显示在列表卡片上）
├── fonts/
│   ├── NotoSansSC-Regular.ttf # 常规字重（可选）
│   ├── NotoSansSC-Medium.ttf  # 中等字重（可选）
│   └── NotoSansSC-Bold.ttf    # 粗体字重（可选）
└── images/
    ├── sthiswrong.png          # 搜索无结果/请求失败提示图
    ├── codecrash.png           # 渲染崩溃提示图
    ├── loading.png             # 加载中提示图
    ├── ban.png                 # 搜索屏蔽关键词提示图
    ├── supportme.png           # 支持作者弹窗图
    ├── icon.png                # 应用桌面图标（需重启应用生效）
    ├── album_placeholder.png   # 专辑封面加载失败占位图
    ├── playlist_placeholder.png# 歌单封面加载失败占位图
    ├── artist_placeholder.png  # 歌手头像加载失败占位图
    ├── player_bg.png           # 播放器无封面时的背景壁纸
    ├── empty_playlist.png      # 歌单/收藏为空插画（可选）
    ├── empty_content.png       # 通用空数据插画（可选）
    └── load_failed.png         # 加载失败插画（可选）
```

> `images/` 内所有文件均为可选，缺失的项使用默认资源。
> 图片格式支持 `.png` 和 `.jpg`，推荐尺寸 480×480px。

---

## manifest.json 完整字段说明

### 基本信息

```json
{
  "name": "凪砂主题",
  "author": "mjiutang",
  "version": 2,
  "description": "以凪砂角色色系为灵感的完整主题"
}
```

| 字段 | 必填 | 说明 |
|------|:----:|------|
| `name` | ✅ | 主题包显示名称 |
| `author` | ✅ | 作者名 |
| `version` | ✅ | 固定为 `2`（当前格式版本号） |
| `description` | ❌ | 主题描述文案，显示在详情区域 |

---

### 颜色 — `colors`

可分别定义浅色/深色模式的完整 **ColorScheme**（15 个色值）。每个颜色项均为**可选**，缺失的颜色自动回退到 flex 自动生成。

```json
{
  "colors": {
    "light": {
      "primary":              "#FF6633",
      "onPrimary":            "#FFFFFF",
      "primaryContainer":     "#FFDBC9",
      "onPrimaryContainer":   "#361400",
      "secondary":            "#A85A3A",
      "onSecondary":          "#FFFFFF",
      "secondaryContainer":   "#FFDBC9",
      "onSecondaryContainer": "#3A1500",
      "tertiary":             "#8B4E6B",
      "onTertiary":           "#FFFFFF",
      "tertiaryContainer":    "#FFD8E5",
      "onTertiaryContainer":  "#390A27",
      "error":                "#BA1A1A",
      "onError":              "#FFFFFF",
      "errorContainer":       "#FFDAD6",
      "onErrorContainer":     "#410002",
      "surface":              "#FFF8F6",
      "surfaceDim":           "#E8D6D0",
      "surfaceBright":        "#FFF8F6",
      "surfaceContainerLowest":  "#FFFFFF",
      "surfaceContainerLow":  "#FFF1EC",
      "surfaceContainer":     "#F6E3DC",
      "surfaceContainerHigh": "#EFDCD6",
      "surfaceContainerHighest":"#E3D1CA",
      "onSurface":            "#231A17",
      "onSurfaceVariant":     "#53443E",
      "outline":              "#85736C",
      "outlineVariant":       "#D8C2BA",
      "inverseSurface":       "#392E2B",
      "inversePrimary":       "#FFB59A"
    },
    "dark": {
      "primary":              "#FFB59A",
      "onPrimary":            "#552500",
      "primaryContainer":     "#7A3600",
      "onPrimaryContainer":   "#FFDBC9",
      "secondary":            "#FFB59A",
      "onSecondary":          "#552500",
      "secondaryContainer":   "#7A3600",
      "onSecondaryContainer": "#FFDBC9",
      "tertiary":             "#FFB0CA",
      "onTertiary":           "#55213E",
      "tertiaryContainer":    "#6F3755",
      "onTertiaryContainer":  "#FFD8E5",
      "error":                "#FFB4AB",
      "onError":              "#690005",
      "errorContainer":       "#93000A",
      "onErrorContainer":     "#FFDAD6",
      "surface":              "#1A110F",
      "surfaceDim":           "#1A110F",
      "surfaceBright":        "#423734",
      "surfaceContainerLowest":  "#140C0A",
      "surfaceContainerLow":  "#231A17",
      "surfaceContainer":     "#271E1B",
      "surfaceContainerHigh": "#322825",
      "surfaceContainerHighest":"#3E332F",
      "onSurface":            "#F0DFD9",
      "onSurfaceVariant":     "#D8C2BA",
      "outline":              "#A08D85",
      "outlineVariant":       "#53443E",
      "inverseSurface":       "#F0DFD9",
      "inversePrimary":       "#FF6633"
    }
  }
}
```

颜色使用 **6 位十六进制** 格式（`#RRGGBB`），不含 alpha 通道。

---

### 字体 — `typography`

```json
{
  "typography": {
    "family": "NotoSansSC",
    "weight": {
      "regular": "fonts/NotoSansSC-Regular.ttf",
      "medium":  "fonts/NotoSansSC-Medium.ttf",
      "bold":    "fonts/NotoSansSC-Bold.ttf"
    }
  }
}
```

| 字段 | 必填 | 说明 |
|------|:----:|------|
| `family` | ✅ | 字体家族名称 |
| `weight.regular` | ✅ | 常规字重 .ttf 文件路径 |
| `weight.medium` | ❌ | 中等字重 .ttf 文件路径 |
| `weight.bold` | ❌ | 粗体字重 .ttf 文件路径 |

不提供此字段 → 使用系统默认字体。

---

### 形状 — `shapes`

覆盖 MD3 5 级形状 token，每项**可选**，缺失的使用全局默认值。

```json
{
  "shapes": {
    "xs": 4,
    "sm": 8,
    "md": 12,
    "lg": 16,
    "xl": 28
  }
}
```

| 字段 | 默认值 | 适用组件 |
|------|--------|----------|
| `xs` | 4 | Chips、Snackbars |
| `sm` | 8 | 输入框、菜单、按钮 |
| `md` | 12 | 卡片、Dialog |
| `lg` | 16 | FAB、导航抽屉 |
| `xl` | 28 | Bottom Sheet |

---

### 图片资源 — `assets`

定义 ZIP 内图片文件到各 UI 位置的映射。每项**可选**。

```json
{
  "assets": {
    "sthiswrong":    "images/sthiswrong.png",
    "codecrash":     "images/codecrash.png",
    "loading":       "images/loading.png",
    "ban":           "images/ban.png",
    "supportme":     "images/supportme.png",
    "icon":          "images/icon.png",
    "album_placeholder":    "images/album_placeholder.png",
    "playlist_placeholder": "images/playlist_placeholder.png",
    "artist_placeholder":   "images/artist_placeholder.png",
    "empty_playlist":       "images/empty_playlist.png",
    "empty_content":        "images/empty_content.png",
    "load_failed":          "images/load_failed.png"
  }
}
```

| Key | 默认图片 | 显示场景 |
|-----|----------|----------|
| `sthiswrong` | `assets/images/sthiswrong.png` | 搜索无结果、API 请求失败弹窗 |
| `codecrash` | `assets/images/codecrash.png` | Flutter 渲染崩溃页面 |
| `loading` | `assets/images/loading.png` | 加载中状态 |
| `ban` | `assets/images/ban.png` | 搜索屏蔽关键词提示 |
| `supportme` | `assets/images/supportme.png` | 支持作者弹窗 |
| `icon` | `assets/images/icon.png` | 应用桌面图标（需重启） |
| `album_placeholder` | 无（回退到系统图标） | 专辑封面加载失败 |
| `playlist_placeholder` | 无（回退到系统图标） | 歌单封面加载失败 |
| `artist_placeholder` | 无（回退到系统图标） | 歌手头像加载失败 |
| `empty_playlist` | 无（回退到图标+文字） | 歌单、收藏列表为空 |
| `empty_content` | 无（回退到图标+文字） | 通用空数据（暂无歌曲/评论/动态/日志等） |
| `load_failed` | 无（回退到图标+文字） | 加载失败提示 |

---

### 壁纸 — `wallpaper`

```json
{
  "wallpaper": {
    "player": "images/player_bg.png"
  }
}
```

播放器无专辑封面时的默认背景，会以高斯模糊方式渲染。未提供则回退到专辑封面模糊或纯色。

---

### 动效偏好 — `motion`

```json
{
  "motion": {
    "durationScale": 1.0,
    "curve": "emphasized"
  }
}
```

| 字段 | 可选值 | 说明 |
|------|--------|------|
| `durationScale` | `0.5` ~ `2.0` | 动画速度倍率，`1.0`=默认 |
| `curve` | `emphasized` / `standard` / `linear` | 动画曲线 |

---

### 组件偏好 — `components`

```json
{
  "components": {
    "navigationBar": {
      "elevation": 0,
      "indicatorStyle": "compact"
    },
    "card": {
      "elevation": 0,
      "style": "filled"
    },
    "dialog": {
      "style": "filled"
    }
  }
}
```

---

## 强调色覆盖

导入主题包后，你仍可以在设置页中**修改强调色**：
- 若设置了强调色 → 主题包的颜色被覆盖，但图片/字体/形状不变
- 若清除了强调色 → 使用主题包内置的完整色板

---

## 完整示例

### 最小主题包（只改颜色）

```
minimal_theme.zip
└── manifest.json
```

```json
{
  "name": "极简红",
  "author": "Example",
  "version": 2,
  "colors": {
    "light": { "primary": "#E53935", "onPrimary": "#FFFFFF" },
    "dark":  { "primary": "#EF5350", "onPrimary": "#FFFFFF" }
  }
}
```

未指定的颜色由 flex 自动推导，未指定的图片用默认资源。

### 完整主题包

```
full_theme.zip
├── manifest.json
├── preview.png
├── fonts/
│   └── NotoSansSC-Regular.ttf
└── images/
    ├── sthiswrong.png
    ├── codecrash.png
    ├── loading.png
    ├── ban.png
    ├── supportme.png
    ├── icon.png
    ├── album_placeholder.png
    ├── playlist_placeholder.png
    ├── artist_placeholder.png
    └── player_bg.png
```

---

## MD3 合规提醒

以下内容主题包**不可以**修改：
- 导航栏图标（`Icons.home` / `Icons.explore` / `Icons.person`）
- 搜索图标（`Icons.search`）
- MD3 组件结构（NavigationBar / TabBar / Dialog / BottomSheet 的行为模式）

以下内容主题包**可以**自由定义：
- 所有 ColorScheme 颜色（30 个色值）
- 字体（任意 .ttf）
- 形状圆角（5 级 Shape token）
- 主题装饰图片（10 张）
- 播放器背景壁纸
- 动效曲线/速度
- 组件微调（elevation、indicator style 等）

---

## 如何导入

### 从主题市场安装（推荐）

App 内进入 **设置 → 主题市场** → 浏览主题 → 点击 **安装** → 安装完成后可选择立即应用。

### 从 ZIP 文件导入

1. 准备 `.zip` 文件
2. App 内进入 **设置 → 主题设置**
3. 在主题包列表最右侧点击 **「导入」卡片**
4. 选择 ZIP 文件即可
5. 导入成功后，在列表中点击即可应用

### 管理

- 删除已导入的主题包：长按卡片 → 删除。内置主题包不可删除。
- 从市场安装的主题可在 **主题市场** 中再次安装更新。

---

## 提交主题到市场

主题市场注册表托管在独立的 GitHub 仓库 [Tangmjiu/ngs-kg-themes](https://github.com/Tangmjiu/ngs-kg-themes)。

### 提交流程

1. Fork [ngs-kg-themes](https://github.com/Tangmjiu/ngs-kg-themes)
2. 在 `themes/` 下创建你的主题目录 `themes/<your-theme-id>/`
3. 放入 `manifest.json`（按本文档字段填写）和 `preview.png`（270×270px 预览图）
4. 将主题文件打包为 ZIP：`themes/<your-theme-id>/<your-theme-id>.zip`
5. 编辑 `registry.json`，在 `themes` 数组中添加你的条目
6. 创建 Pull Request，等待审核合并

### 示例参考

[Jekyll](https://github.com/Tangmjiu/ngs-kg-themes/tree/main/themes/jekyll) 是一个完整的示例主题包：

```
themes/jekyll/
├── manifest.json       # 完整 30 色 Light/Dark 色板，无自定义图片
├── preview.png         # 270×270 预览图（左 Light 右 Dark）
└── jekyll.zip          # 打包后的主题文件
```

对应的 `registry.json` 条目：

```json
{
  "id": "jekyll",
  "name": "Jekyll",
  "author": "mjiutang",
  "version": 2,
  "description": "Light 暖琥珀 · Dark 冷靛蓝 — 展示 30 色系统能力",
  "preview_url": "https://raw.githubusercontent.com/Tangmjiu/ngs-kg-themes/main/themes/jekyll/preview.png",
  "download_url": "https://raw.githubusercontent.com/Tangmjiu/ngs-kg-themes/main/themes/jekyll/jekyll.zip",
  "tags": ["demo", "light", "dark"],
  "file_size_bytes": 7287,
  "min_app_version": "2.0.0"
}
```

### 提交 PR 时的注意事项

- 预览图建议 270×270px，能清晰展示主题风格
- ZIP 内只包含 `manifest.json` + 图片资源，不要嵌套多余的目录层
- `file_size_bytes` 填写 ZIP 文件的实际字节数
- 如果主题只改色板（无图片/字体），可以放一个极小（甚至空 assets）的 ZIP
