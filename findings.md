# 研究发现

## 项目现状 (2026-05-14)

### 代码规模
- 总 Dart 代码: ~8,765 行, 55 文件
- `dart analyze`: 0 error, 0 warning, 23 info
- 测试: 0 (空目录)

### 核心问题诊断

#### 1. 没有数据层 (Repository Pattern)
`music_service.dart` (770 行) 直接返回 `Map<String, dynamic>`，每个方法里手写 `as` 强转。调用方(Screens/Providers)必须知道 API 响应结构。

#### 2. 模型解析碎片化
Song 有 4 个 factory constructor，解析不同 API 的字段名：
- `fromJson`: id/name/artists
- `fromKugouJson`: Audioid/OriSongName/SingerName
- `fromTrackJson`: audio_id/name(含 "Artist - Title" 拆分)
- `fromRankJson`: audio_id/songname/audio_info
30+ API 返回 `List<Map<String, dynamic>>` 无类型约束。

#### 3. God Class
| 文件 | 行数 | 问题 |
|------|------|------|
| player_screen.dart | 995 | 巨型 UI |
| music_service.dart | 770 | API+解析+缓存混合 |
| player_provider.dart | 452 | 播放器+队列+定时器+屏幕状态 |
| search_screen.dart | 512 | 搜索+结果+历史混合 |
| home_screen.dart | 405 | 多页面聚合 |
| login_screen.dart | 511 | 登录+注册+第三方 |

#### 4. API 层薄弱
- `api_client.dart` 只有 107 行，无重试、无统一错误处理
- `_get()` 假设响应 `data` 永远是 `Map<String, dynamic>`，否则 crash
- `throw Exception('...')` 字符串异常无法按类型捕获
- `NEED_LOGIN` 检查硬编码在 `api_client.dart` 中
