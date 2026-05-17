# 任务计划：NGS-KG+

## 目标
打造 Apple Music 风格的酷狗第三方播放器 UI，修复所有运行时错误。

## 当前状态

| 阶段 | 状态 | 说明 |
|------|------|------|
| Phase 0-3: 架构重构 | ✓ 完成 | Repository 模式、DI、类型安全、Provider 重构 |
| Phase 4: UI 大改 | ✓ 完成 | Player/Discover/Home 重写，冗余页面清理 |
| Phase 5: Bug 修复 | ▶ 进行中 | setState during build、布局溢出、PlayerProvider timing bugs |

## Phase 4 变更汇总
- 重写: player_screen.dart (PageView 滑动歌词/封面, 模糊背景, 平板自适应)
- 重写: discover_screen.dart (Banner, 快捷操作, 歌单/榜单/电台卡片)
- 修改: home_screen.dart (网格→列表样式)
- 删除: lyrics_screen, sheet_list/detail/collection screens
- 清理: user_profile_screen (移除重复的"我喜欢的歌曲")
- 提交: a0f0281

## Phase 5 — Bug 修复

| # | 问题 | 状态 | 修复 |
|---|------|------|------|
| 1 | setState() called during build | ✓ 完成 | addPostFrameCallback |
| 2 | 布局溢出 (横向 Row 溢出) | ✓ 完成 | SingleChildScrollView wrapper |
| 3 | PlayerProvider repeatOne 循环 | ✓ 完成 | seek(0)+play() 替代 playIndex() |
| 4 | 负值时间格式化 | ✓ 完成 | clamp to 0 |
