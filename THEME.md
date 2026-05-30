# 主题包制作指南

NGS-KG+ 支持通过 ZIP 文件导入自定义主题包，可替换状态图片和主题色。

## 文件结构

一个完整的主题包是一个 `.zip` 文件，内部结构如下：

```
my_theme.zip
├── manifest.json          # 主题元数据（必填）
├── sthiswrong.png         # 搜索无结果/请求失败提示图（可选）
├── codecrash.png          # 渲染崩溃提示图（可选）
├── loading.png            # 加载中提示图（可选）
├── ban.png                # 搜索屏蔽关键词提示图（可选）
├── supportme.png          # 支持作者弹窗图（可选）
└── icon.png               # 应用桌面图标（可选）
```

> 所有图片文件均为 **PNG 格式**，文件名需与 manifest.json 中声明的路径一致。

## manifest.json

主题包根目录必须包含 `manifest.json`，格式如下：

```json
{
  "name": "暗夜红",
  "author": "你的名字",
  "version": 1,
  "colors": {
    "light_primary": "#FF6633",
    "dark_primary": "#FF8866"
  },
  "assets": {
    "sthiswrong": "sthiswrong.png",
    "codecrash": "codecrash.png",
    "loading": "loading.png",
    "ban": "ban.png",
    "supportme": "supportme.png",
    "icon": "icon.png"
  }
}
```

### 字段说明

| 字段 | 必填 | 说明 |
|------|:----:|------|
| `name` | ✅ | 主题包显示名称 |
| `author` | ✅ | 作者名 |
| `version` | ✅ | 主题包版本号（整数） |
| `colors.light_primary` | ❌ | 浅色模式强调色（十六进制，带 `#`） |
| `colors.dark_primary` | ❌ | 深色模式强调色（十六进制，带 `#`） |
| `assets.*` | ❌ | 图片资源路径映射，key 为资源 ID，value 为 ZIP 内的路径 |

### 颜色色值

颜色使用 **6 位十六进制** 格式（`#RRGGBB`），不要包含 alpha 通道。

示例：`#FF6633`、`#2CA1F4`、`#1DB954`

### 资源文件

`assets` 中的 key 是固定的资源 ID，可用的 key：

| Key | 默认图片 | 显示场景 |
|-----|----------|----------|
| `sthiswrong` | `assets/images/sthiswrong.png` | 搜索无结果、API 请求失败弹窗 |
| `codecrash` | `assets/images/codecrash.png` | Flutter 渲染崩溃页面 |
| `loading` | `assets/images/loading.png` | 加载中状态 |
| `ban` | `assets/images/ban.png` | 搜索屏蔽关键词提示 |
| `supportme` | `assets/images/supportme.png` | 支持作者弹窗 |
| `icon` | `assets/images/icon.png` | 应用桌面图标 |

其中 `icon` 比较特殊，导入主题包后需要**重启应用**才会更新桌面图标。

未在 assets 中声明的资源会继续使用内置默认文件。

## 快速开始

### 方法一：手动打包

1. 新建文件夹 `my_theme/`
2. 放入 `manifest.json`（参考上面的格式）
3. 放入你要替换的 PNG 图片
4. 选中文件夹内所有文件，压缩为 ZIP
5. 将 ZIP 文件传到手机，在 App 的 **设置 → 主题 → 主题包 → 导入 .zip 主题** 中选择该文件

### 方法二：修改默认主题

直接复制 `assets/images/` 目录下的默认图片，替换后打包：

```
cp -r assets/images/ my_custom_theme/
# 修改图片
# 创建 manifest.json
zip -r my_theme.zip my_custom_theme/
```

## 注意事项

1. **图片推荐尺寸**：`480×480` 像素左右即可，过大的图片会影响加载速度
2. **图标特殊处理**：替换 `icon` 后桌面图标不会立即改变，需要重启应用（从最近任务划掉重新打开）
3. **颜色优先级**：主题包的 `light_primary` / `dark_primary` 会覆盖 App 设置页中选择的强调色
4. **资源优先级**：主题包的图片资源会覆盖内置默认图片，但未提供的资源保留默认
5. **删除主题包**：在 App 设置页可以删除已导入的主题包，删除后自动恢复默认

## 示例

一个最小主题包（只改颜色不改图）：

```
minimal_theme.zip
└── manifest.json
```

```json
{
  "name": "极简红",
  "author": "Example",
  "version": 1,
  "colors": {
    "light_primary": "#E53935",
    "dark_primary": "#EF5350"
  }
}
```

一个完整主题包（改颜色 + 全部图片）：

```
full_theme.zip
├── manifest.json
├── sthiswrong.png
├── codecrash.png
├── loading.png
├── ban.png
├── supportme.png
└── icon.png
```
