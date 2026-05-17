# 任务计划：NGS-KG+ 全项目重构

## 目标
根治"API 正常但前端展示异常"的问题，建立可持续维护的架构。

## 状态：全部完成 ✓

| 阶段 | 状态 | 说明 |
|------|------|------|
| Phase 0: 基础设施 | ✓ 完成 | ApiException, SongMapper, CacheInterceptor, RetryInterceptor |
| Phase 1: 数据层 | ✓ 完成 | 5 个 Repository，770 行 MusicService → Facade |
| Phase 2: Provider 重构 | ✓ 完成 | DI 注入、PlayerProvider mixins、LikedSongsProvider 修复、AuthProvider 清理 |
| Phase 3: 屏幕修复 | ✓ 完成 | 16 个类型错误消除，8 个屏幕文件修复 |

## 关键成果
- `flutter analyze`: 0 error, 0 warning
- MusicService: 770 行 → 290 行 (Facade)
- 新增 10 个文件 (models + repos + mixins)
- Song parsing 从 4 个 factory 合并为 SongMapper 单一入口
- 所有 Provider 不再 new 自己的 Service 实例
- 29 个文件变更: +880 / -981 行