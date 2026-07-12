# NGS-KG+ — Agent Guide

### 所有思考和回答必须使用简体中文 ###
### ALL THINKING AND RESPONSES MUST BE IN SIMPLIFIED CHINESE ###

## Project identity

- **NGS-KG+** (ngskg_plus): Flutter music player based on KuGou third-party API.
- **State management**: Provider. **Networking**: Dio + CookieJar. **Audio**: just_audio.
- **Target**: Linux desktop (primary).
- **Version**: `pubspec.yaml` is the single source; CI reads it too.
- **Package name**: `com.mjiutang.ngskg` (migrated from `com.kugou.ngskg`).

## Entrypoints & architecture

- **App entry**: `lib/main.dart` → `MultiProvider` wraps 8+ providers → `NGSKGApp` → `DesktopShell` (home).
- **Desktop shell** (`lib/widgets/desktop_shell.dart`) owns the sidebar + nav; mobile screens nest inside it.
  - On mobile, only `PlayerScreen` and `SettingsScreen` are pushed on top of the shell.
  - On desktop, the shell renders charts, playlists, player inline — routes are used mainly for mobile.
- **Global nav key**: `lib/utils/navigation.dart` exports `navKey` — used by notification actions, dialogs, and anything that needs `BuildContext` outside the widget tree.
- **Router**: `lib/routes/app_routes.dart` — named routes via `onGenerateRoute`. Not a router package.
- **Layer stack**: `ApiClient` (Dio) → `BaseRepository` → `SongRepository` etc. → `MusicService` → `*Provider` → UI.
  - `MusicService` aggregates all 5 repositories. Providers depend on `MusicService`, never on repositories directly.
- **Dependency injection**: All providers are wired in `main.dart`'s `MultiProvider`; some are `.value` (singletons), some are `create` (per-widget).

## API & networking

- **Base URL**: Dynamic — two built-in routes (`https://kugouapi.mjiutang.top` / `http://111.170.14.52:42980`) or user custom. Configured in Settings → API Server.
- **Interceptor chain (order matters)**:
  1. `_DynamicBaseUrlInterceptor` — sets `baseUrl` per-request from `ApiConfig`
  2. `_AuthInterceptor` — injects `Authorization` header (token+userid+dfid+mid+guid+serverDev+mac)
  3. `_RetryInterceptor` — retries network errors (2 tries, exponential backoff)
  4. `CookieManager` — cookie persistence
  5. `CacheInterceptor` — key-value cache with TTL via `CacheService`
  6. `LogInterceptor`
  7. `_ErrorDialogInterceptor` — shows error dialogs for unhandled errors
- **Auth token**: Stored as static fields on `ApiClient` (`_authToken`, `_authUserId`). Set by `AuthProvider._loadSavedUser()`. Cleared on error 20010.
- **Search/playlist endpoints**: Some require `cookie` as a query parameter — use `withCookie: true` in `BaseRepository.get()`.
- **Playback URLs expire in ~15 min**. Always fetch fresh before playing. Handle 403 with retry.
- **User-Agent**: `Mozilla/5.0 (Linux; Android 14; NGS-KG+) AppleWebKit/537.36` (in `AppConstants`).
- **Signing**: `KugouSigner` (Lite mode by default, appid=3116, clientver=11440). Used for direct KuGou endpoints (not the proxy API).
- **Silent requests**: Set `extra['silent'] = true` to suppress error dialogs for known-failing endpoints.
- **`oneShotGet()` in MusicService**: Creates a *separate* Dio instance for each call (play history, etc.). Not routed through the main `ApiClient` singleton.

## Key data quirks

- **SongMapper** (`lib/models/song_mapper.dart`) handles 3+ KuGou API response formats (search/kugou, track/playlist, rank). Always use `SongMapper.*` methods instead of raw `Song.fromJson()` for KuGou data.
- **Cover URLs** contain `{size}` placeholder — always replaced with `'480'`.
- **Quality system**: 7 tiers — `128`(标准) → `320`(HQ) → `flac`(SQ) → `high`(Hi-Res) → `viper_atmos`(全景声) → `viper_clear`(蝰蛇超清) → `viper_tape`(母带). Fallback chain drops down from preferred level.
- **Privilege cache** in `AudioEngine`: Caches `/privilege/lite` responses by song hash. Use `invalidatePrivilege(hash)` for fresh lookups.
- **Card IDs** for `/top/card`: 1=私人专属好歌, 2=经典怀旧金曲, 3=热门好歌精选, 4=小众宝藏佳作, 5=潮流尝鲜, 6=VIP专属推.
- **Error codes**: 20010=login expired (triggers `clearAuth()` + re-login dialog), 20028=account risk control, 20006=rate limited, 31136=bad params.

## Device flow

1. First launch: `_initDevice()` → `DeviceService.registerDevice()` → calls `/register/dev` → persists `DeviceInfo` (dfid/mid/guid/serverDev/mac) in `SharedPreferences`.
2. On subsequent launches: loaded from prefs, injected into Authorization header by `_AuthInterceptor`.
3. DFID is also set on `ApiClient` statically for fallback code paths.

## Themes

- Uses `flex_color_scheme` + `dynamic_color` (Android 12+ Material You).
- ZIP theme packages via `archive` — see `lib/theme/` and `THEME.md`.
- Custom fonts: bundled HarmonyOS Sans (Regular 400, Medium 500, Bold 700, Light 300).
- `ThemeAssets` in `lib/theme/theme_assets.dart` provides player background image path with `ImageFilter.blur`.

## Linux desktop specifics

- `windowManager.ensureInitialized()` must be called **before** `runApp()` (comment in `main.dart` line 45).
- `DesktopService` handles window management; MPRIS D-Bus integration for system media controls.
- Desktop build: `flutter build linux --debug` / `flutter build linux --release`.
- Flatpak packaging via `flutpak`; `.deb` via `flutter_distributor`; AUR `ngskg-plus-bin`.
- CI builds Linux on `linux-desktop` branch.

## Lint & analysis

- Rules: `package:flutter_lints/flutter.yaml` + `prefer_const_constructors`, `prefer_const_declarations`, `avoid_print`.
- Note: `print()` is used extensively by the `Log` class (replacement for `avoid_print` — this is intentional).
- Run: `flutter analyze` / `dart format lib/`.

## Tests

- **Model tests** (`test/models_test.dart`): Parse Song, SongUrl, Playlist, User from various JSON formats. Run with `flutter test --no-sound-null-safety` or just `flutter test`.
- **Lyrics tests** (`test/lyrics_test.dart`): LRC parser unit tests.
- **Widget smoke test** (`test/widget_test.dart`): **SKIPPED** — requires full Provider setup not available in test env. Don't enable without providing mock services.
- Test structure is simple: no mocks, no fixture files, no integration tests.

## Commands

```bash
flutter pub get            # install deps (run after any pubspec change)
flutter analyze            # static analysis
dart format lib/           # formatting
flutter test               # run tests (model + lyrics tests pass)
flutter build linux --debug  # debug Linux build
flutter build linux --release  # release Linux build
```

CI uses Flutter **3.41.0 stable** (pinned in GitHub Actions).

## MV features (blocked/commented out)

MV playback is **disabled**. Commented code exists in:
- `pubspec.yaml` — `video_player`, `chewie` commented
- `lib/routes/app_routes.dart` — MV/Video routes commented
- `lib/services/music_service.dart` — MV search commented
- Related screen files exist but are disconnected

Do not re-enable without explicit user request and dependency audit.

## Git workflow

- Branch naming: `linux-desktop` (primary for Linux), `android` (for mobile), `windows-desktop` (for Windows).
- Commit messages: Conventional Commits (`feat/fix/docs/refactor/chore`).
- CI triggers: PR to `android` builds debug APK; push to `windows-desktop` builds Windows; release workflow is manual with tag input.
- License: MIT — source files have SPDX headers.

## Things agents commonly miss

- `navKey` is used for all context-dependent operations outside widget tree — not `Navigator.of(context)`.
- `import '../utils/navigation.dart' as app;` and then `app.navKey.currentContext`.
- `withCookie: true` vs `withAuth: false` — two different BaseRepository options for different API quirks.
- `oneShotGet()` bypasses the main ApiClient interceptor chain — don't use for normal endpoints.
- Lyrics use `flutter_lyric`'s `LyricController` — the `activeIndexNotifiter` property has a typo in its name (inherited from the library).
- The `PreviewConfig` system (`assets/config/preview.yaml`) gates development-only features.
- Logs write to `{appDocDir}/logs/app_{date}.log` with 7-day auto-clean. View in-app via `LogViewerScreen`.
