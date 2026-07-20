# NGS-KG+ — 公告系统维护指南

为了降低维护成本，保障系统的高可用性以及国内的加载速度，**NGS-KG+** 的公告系统并不依赖自建服务器接口，也避开了受 GitHub API 访问频次限制（Rate Limit）的 Issues 方案。

它采用 **GitHub 仓库静态文件 + 免费 CDN (jsDelivr) + 微软 Office 预览** 的三合一架构。

---

## 🚀 公告工作原理

1. **编写与推送**：开发者修改 `android` 分支上的 `/assets/config/announcement.json` 文件并 push/merge 到 GitHub。
2. **CDN 镜像同步**：jsDelivr CDN 会在数分钟内自动同步该静态文件。
3. **客户端获取**：应用启动时，会静默拉取无速率限制、国内加载极速的 CDN 镜像链接：
   `https://fastly.jsdelivr.net/gh/Tangmjiu/NGS-KG@android/assets/config/announcement.json`
4. **版本与已读过滤**：客户端在本地解析公告列表，自动过滤不符版本约束的公告，并去重本地已读的公告，然后依次显示。
5. **富文本与文档渲染**：
   * **Markdown**：应用使用 `flutter_markdown` 在弹窗中排版渲染公告。
   * **图片**：Markdown 内含的图片直接使用 jsDelivr 的 CDN 图片托管链接，客户端直接加载。
   * **Word 文档 (.docx)**：点击公告中的 docx 链接时，客户端会自动拦截并调用微软 Office 预览服务进行免下载的网页端排版阅读。

---

## ✍️ 如何发布公告？

### 步骤 1：参考模板配置
仓库中提供了一份模板文件：[`assets/config/announcement.json.example`](file:///home/mjiutang/NGS-KG/assets/config/announcement.json.example)。
在正式发布公告时，请在 `android` 分支的 `/assets/config/` 目录下新建（或直接编辑）正式的公告配置文件 **`announcement.json`**（**请注意：应用只读取不带 `.example` 后缀的正式文件**）。

### 步骤 2：编辑 JSON 参数
在 `announcement.json` 数组中添加公告项，格式如下：

```json
[
  {
    "id": "global_maintenance_20260720",
    "title": "全服网络维护公告",
    "publishTime": "2026-07-20T17:00:00+08:00",
    "versionConstraint": "*",
    "force": false,
    "dismissible": true,
    "content": "### 📢 系统公告\n\n我们将于今晚维护服务器，若遇到加载缓慢请谅解。"
  }
]
```

#### 📌 JSON 字段定义：
* **`id`** (`String`，必填)：公告唯一 ID，用于本地已读过滤。每次发布新公告时请起一个**全新**的 ID（如使用日期 `notice_20260720`），否则已读过的用户将不会再次弹出。
* **`title`** (`String`，必填)：公告弹窗的标题。
* **`publishTime`** (`String`，必填)：发布时间，格式为 ISO 8601 标准（例如 `2026-07-20T17:00:00+08:00`）。
* **`versionConstraint`** (`String`，选填)：版本约束限制。
  * `*` 或 `all` 或不填：面向**所有版本**发布。
  * `1.5.0`：**仅限**指定版本弹出。
  * `<1.5.0`：面向**低于**指定版本的客户端弹出（可用于强制升级提醒）。
  * `<=1.5.1` / `>=1.5.0` / `>1.4.0`：各种常见版本号比较符均完美支持。
* **`force`** (`Boolean`，选填，默认 `false`)：是否强制弹出。
  * 为 `false` 时，用户关闭过一次（勾选了不再提示）之后，下次启动就不会再弹。
  * 为 `true` 时，无视本地已读状态，**每次启动应用都会弹出**（适用于极其重大的故障通告，请谨慎使用）。
* **`dismissible`** (`Boolean`，选填，默认 `true`)：是否允许关闭。
  * 为 `false` 时，屏蔽物理返回键和外部空白点击，用户必须点击“我知道了”等确认动作（通常用于强制升级公告，限制用户继续使用旧版）。
* **`actionUrl`** (`String`，选填)：点击“了解详情”按钮后在系统外部浏览器中打开的链接。
* **`content`** (`String`，必填)：公告主体正文，**完整支持 Markdown 语法**（可折行，换行请使用 `\n`）。

---

## 🖼️ 图片与 Word 文档 (.docx) 托管

不要把图片和文档直接放到你吃紧的服务器中。直接将它们提交到 GitHub，然后使用 **jsDelivr CDN 地址**进行极速加载：

1. **托管图片**：
   * 将图片推送到 GitHub 仓库的 `/assets/images/my_banner.png`。
   * 在 Markdown 的 `content` 中使用 CDN 地址引用它：
     `![Banner](https://fastly.jsdelivr.net/gh/Tangmjiu/NGS-KG@android/assets/images/my_banner.png)`
2. **托管 docx 文档**：
   * 将 Word 文档推送到 GitHub 仓库的 `/assets/docs/manual.docx`。
   * 在 Markdown 的 `content` 中直接插入超链接：
     `[查看手册.docx](https://fastly.jsdelivr.net/gh/Tangmjiu/NGS-KG@android/assets/docs/manual.docx)`
   * 客户端检测到 `.docx` 结尾的链接被点击时，会自动转换为微软免下载预览服务的 URL，并在用户的手机浏览器中完美呈现 Word 的完整排版。
