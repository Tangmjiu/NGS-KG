# Watch (Wear OS) Architecture Assessment

> Wave 7-A assessment — 2026-07-05
> Evaluates 6 watch features from UI audit for feasibility and effort.

## Dependencies (Current)
| Package | Version | Status |
|---------|---------|--------|
| `wear_plus` | ^1.2.5 | ✅ In use (shape detection, ambient mode) |
| `wearable_rotary` | ^2.0.4 | ❌ Installed but unused |
| `wear_os_scrollbar` | ^0.2.1 | ❌ Installed but unused |
| `ym_lyric` | ^0.0.4 | ✅ In use by main app, not watch |
| `speech_to_text` | ^7.3.0 | ✅ Used by voice search |

## Feature Assessment

### 1. Crown Support (Digital Crown Scrolling)
- **Effort**: Medium (~1 file, 20 lines)
- **Dependency**: `wearable_rotary` (already installed)
- **Approach**: Add `RotaryScrollController` to `WatchScrollList`. The `wearable_rotary` package provides `RotaryScrollController` which wraps a `ScrollController` and handles rotary scroll events automatically.
- **Risk**: Low. Pure Flutter, additive change, no regression.
- **Decision**: ✅ IMPLEMENT

### 2. Horologist Library Integration
- **Effort**: High (architecture change)
- **Dependency**: Not installed; would add `com.google.wear.horologist`
- **Approach**: Horologist is Google's Wear OS Flutter toolkit providing crown, tiles, complications, and more. It would replace `wear_plus` and `wearable_rotary`.
- **Risk**: Major refactor. Would need to re-test all existing watch screens.
- **Decision**: ❌ DEFER (requires dedicated branch)

### 3. Watch Tile (Quick-launch Complication)
- **Effort**: High (requires native Android Kotlin)
- **Dependency**: Android `WearableTileService`
- **Approach**: Write Kotlin service extending `TileService`, bundle in `android/app/src/main/kotlin/`
- **Risk**: Platform-specific, hard to test from Flutter.
- **Decision**: ❌ DEFER (native Android work)

### 4. Watch Complication (Data-driven Now Playing)
- **Effort**: High (requires native Android Kotlin)
- **Dependency**: Android `ComplicationProviderService`
- **Approach**: Write Kotlin service providing current song info to watch face complications.
- **Risk**: Platform-specific, hard to test.
- **Decision**: ❌ DEFER (native Android work)

### 5. Watch-only Lyrics View
- **Effort**: Medium (~1 new screen file, 80-120 lines)
- **Dependency**: `ym_lyric` (already installed)
- **Approach**: Create `lib/watch/screens/lyrics_screen.dart` with simplified lyric display optimized for round screen. Use `LyricParser` from `ym_lyric` to parse LRC, sync position from `PlayerProvider`.
- **Risk**: Low-medium. `ym_lyric` may have rendering issues on small round screens.
- **Decision**: ✅ IMPLEMENT (if time permits)

### 6. Watch-only Queue Management
- **Effort**: Low-medium (~1 new screen file, 80-120 lines)
- **Dependency**: None (uses `PlayerProvider.playlist`)
- **Approach**: Create `lib/watch/screens/queue_screen.dart`. Display `PlayerProvider.playlist` with `currentIndex` highlighted. Use `WatchScrollList` for scrolling. Support tap-to-select song.
- **Risk**: Low. Pure Flutter, no new dependencies.
- **Decision**: ✅ IMPLEMENT

## Implementation Order
1. Crown support (`WatchScrollList` + `wearable_rotary`)
2. Queue screen (new screen + add to `WatchHome` pages)
3. Lyrics screen (optional, time permitting)
