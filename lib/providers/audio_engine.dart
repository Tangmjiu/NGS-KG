import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../utils/logger.dart';
import '../utils/error_dialog.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';
import '../constants/quality.dart';
import '../services/music_service.dart';
import '../services/api_exception.dart';
import '../services/equalizer_service.dart';
import '../utils/navigation.dart' as app;
import '../providers/auth_provider.dart';
import '../widgets/login_required_dialog.dart';

class AudioEngine {
  final MusicService _musicService;
  final AudioPlayer _player;
  bool _disposed = false;

  int _playAttempts = 0;
  int _playRequestVersion = 0;
  DateTime? _lastUrlFetchTime;
  bool _playWhenReady = true;

  static const int _maxRetries = 2;
  static const _urlStaleDuration = Duration(minutes: 10);
  int qualityLevel = 0;
  bool uploadHistory = true;
  int crossfadeMs = 0; // 0 = off, >0 = fade-in duration
  double _speed = 1.0;
  double get speed => _speed;

  /// 最终解析出的音质 key（MoeKoeMusic 风格：记录实际可用的最高级别）
  final ValueNotifier<String?> resolvedQualityNotifier = ValueNotifier(null);

  /// 当前歌曲可用编码音质选项（来自 privilege 预查）
  List<QualityOption> _currentQualityOptions = [];

  /// 当前歌曲可用音效选项（来自 privilege 预查）
  List<QualityOption> _currentEffectOptions = [];

  /// Privilege 缓存（hash → PrivilegeInfo），避免重复请求
  final Map<String, PrivilegeInfo> _privilegeCache = {};

  /// 合并预查和播放链的并发查询；失效后的旧请求不得重新填充缓存。
  final Map<String, Future<PrivilegeInfo>> _privilegeInFlight = {};

  Future<PrivilegeInfo> _getPrivilege(String hash) {
    final cached = _privilegeCache[hash];
    if (cached != null) return Future.value(cached);
    final pending = _privilegeInFlight[hash];
    if (pending != null) return pending;

    late final Future<PrivilegeInfo> request;
    request = Future.sync(() => _musicService.getPrivilegeLite(hash))
        .then((res) {
      final info = PrivilegeInfo.fromJson(res);
      if (!_disposed && identical(_privilegeInFlight[hash], request) &&
          (info.options.isNotEmpty || info.effectOptions.isNotEmpty)) {
        _privilegeCache[hash] = info;
      }
      return info;
    }).whenComplete(() {
      if (identical(_privilegeInFlight[hash], request)) {
        _privilegeInFlight.remove(hash);
      }
    });
    _privilegeInFlight[hash] = request;
    return request;
  }

  /// 清除指定歌曲的 privilege 缓存及正在进行的查询引用。
  void invalidatePrivilege(String? hash) {
    if (hash != null && hash.isNotEmpty) {
      _privilegeCache.remove(hash);
      _privilegeInFlight.remove(hash);
    }
  }

  void clearPrivilegeCache() {
    _privilegeCache.clear();
    _privilegeInFlight.clear();
  }

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _processingStateSub;
  StreamSubscription? _playbackSub;
  bool _hasActivePlayback = false;

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);
  final ValueNotifier<bool> isCompleting = ValueNotifier(false);

  VoidCallback? onComplete;
  VoidCallback? onReady;

  AudioEngine(this._musicService,
      {AudioPlayer? player, bool initializeSession = true})
      : _player = player ?? AudioPlayer() {
    if (initializeSession) _initSession();
    _positionSub = _player.positionStream.listen((p) {
      position.value = p;
    });
    _durationSub = _player.durationStream.listen((d) {
      if (d != null) duration.value = d;
    });
    _processingStateSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (!isCompleting.value) {
          isCompleting.value = true;
          onComplete?.call();
        }
      } else if (state == ProcessingState.ready) {
        isCompleting.value = false;
        onReady?.call();
      } else if (state == ProcessingState.idle) {
        if (_hasActivePlayback) {
          _hasActivePlayback = false;
          isLoading.value = false;
          error.value = '播放出错，请重试';
          _showLoginIfUnauth();
        }
      }
    });
    // playingStream 是播放意图的唯一事实来源（play/pause/stop 都会同步广播），
    // 其余地方不再手动赋值 isPlaying，避免事件乱序导致状态颠倒。
    _playbackSub = _player.playingStream.listen((playing) {
      isPlaying.value = playing;
    });
    // 系统均衡器需挂在播放器自己的音频会话上才会生效
    _sessionIdSub = _player.androidAudioSessionIdStream.listen((id) {
      if (id != null) EqualizerService.instance.attachSession(id);
    });
  }

  StreamSubscription? _sessionIdSub;

  /// 下一次加载音源时的起始位置（冷启动恢复进度用），加载时取出并清空。
  Duration? startPosition;

  Duration? _takeStartPosition() {
    final p = startPosition;
    startPosition = null;
    return (p != null && p > Duration.zero) ? p : null;
  }

  /// 播放器当前没有已加载的音源（冷启动恢复后 / stop 之后）。
  bool get needsLoad => _player.processingState == ProcessingState.idle;

  /// 启动播放但不等待。
  ///
  /// just_audio 的 play() 返回的 Future 要到暂停/停止/播完才完成，
  /// 若 await 它，后续的 isLoading 复位、通知刷新、历史上报都会被拖到
  /// 整首歌结束之后才执行——这也是此前播放/暂停状态反复颠倒的根源。
  void _startPlayback() {
    _hasActivePlayback = true;
    if (crossfadeMs > 0) _startFadeIn();
    _player.play().catchError((Object e, StackTrace s) {
      Log.w('audio_engine', 'play() failed', e, s);
    });
  }

  void _initSession() {
    AudioSession.instance.then((session) => session.configure(const AudioSessionConfiguration(
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ))).catchError((e) {
      Log.e('audio_engine', 'AudioSession init failed', e);
    });
  }

  int get requestVersion => _playRequestVersion;

  double get progress {
    final d = duration.value.inMilliseconds;
    return d > 0 ? position.value.inMilliseconds / d : 0.0;
  }

  int get currentVersion => _playRequestVersion;
  bool get isPlaying_ => _player.playing;

  /// 最后一次播放成功解析到的音质 key（供 Provider 读取）
  String? get resolvedQuality => resolvedQualityNotifier.value;

  /// 当前歌曲的可用编码音质选项列表
  List<QualityOption> get currentQualityOptions =>
      List.unmodifiable(_currentQualityOptions);

  /// 当前歌曲的可用音效选项列表（来自 privilege）
  List<QualityOption> get currentEffectOptions =>
      List.unmodifiable(_currentEffectOptions);

  /// 获取当前音质 key（用于 refresh 等场景）
  String _currentQualityKey() {
    final keys = Song.qualityKeys;
    return keys[qualityLevel % keys.length];
  }

  /// 异步预查特权与音质选项，让 UI 能在播放前显示正确的实际最高音质，避免冷启动及切歌时回退显示"标准"
  Future<void> precheckPrivilege(Song song) async {
    if (_disposed) return;
    final version = _playRequestVersion;
    final hash = song.hash;
    if (song.isLocal && hash == null) {
      resolvedQualityNotifier.value = '128';
      _currentQualityOptions = [QualityOption(value: '128', label: '标准', hash: '')];
      _currentEffectOptions = [];
      return;
    }
    if (hash != null && hash.isNotEmpty) {
      try {
        final info = await _getPrivilege(hash);
        if (_disposed || version != _playRequestVersion) return;
        if (info.options.isNotEmpty || info.effectOptions.isNotEmpty) {
          _currentQualityOptions = info.options;
          _currentEffectOptions = info.effectOptions;
          final preferredQuality = _currentQualityKey();
          final available = info.options.map((o) => o.value).toList();
          final bestMatch = Quality.fallbackChain(preferredQuality)
              .firstWhere((q) => available.contains(q), orElse: () => '128');
          resolvedQualityNotifier.value = bestMatch;
        }
      } catch (e) {
        Log.w('audio_engine', 'precheck privilege failed', e);
      }
    }
  }

  /// ─── 核心：构建候选音质列表 ───
  ///
  /// 1. 优先使用 /privilege/lite 获取歌曲可用音质变体（含独立 hash）
  /// 2. 回退到根据 qualityLevel 构建降级链（使用歌曲原始 hash）
  Future<List<_Candidate>> _buildCandidates(Song song, String preferredQuality) async {
    final version = _playRequestVersion;
    bool stale() => _disposed || version != _playRequestVersion;
    if (stale()) return [];
    final hash = song.hash;

    // 本地歌曲不需要特权查询
    if (song.isLocal && hash == null) {
      return [_Candidate(quality: '128', hash: '', label: '标准')];
    }

    // 尝试从 privilege 获取
    if (hash != null && hash.isNotEmpty) {
      try {
        final info = await _getPrivilege(hash);
        if (stale()) return [];
        if (info.options.isNotEmpty || info.effectOptions.isNotEmpty) {
          _currentQualityOptions = info.options;
          _currentEffectOptions = info.effectOptions;
          final candidates = info.candidates(preferredQuality, fallbackHash: hash);
          return candidates.map((opt) => _Candidate(
            quality: opt.value,
            hash: opt.hash,
            label: opt.label,
          )).toList();
        }
      } catch (e, s) {
        Log.w('audio_engine', 'privilege query failed, fallback to chain', e, s);
      }
    }

    if (stale()) return [];
    // 回退：基于 qualityLevel 的降级链，使用歌曲原始 hash
    // privilege 失败时清空选项列表，让 UI 按全量 levels 回退显示
    _currentQualityOptions = [];
    _currentEffectOptions = [];
    final chain = Quality.fallbackChain(preferredQuality);
    return chain.map((q) => _Candidate(
      quality: q,
      hash: hash ?? '',
      label: Quality.label(q),
    )).toList();
  }

  /// ─── 核心播放方法 ───
  Future<void> play(Song song, {int? version, String effectKey = 'none'}) async {
    final requestVersion = version ?? _playRequestVersion;
    bool stale() => _disposed || requestVersion != _playRequestVersion;
    if (stale()) return;
    if (_playAttempts > _maxRetries) {
      isLoading.value = false;
      error.value = '播放失败: 已重试 $_maxRetries 次';
      _showLoginIfUnauth();
      return;
    }
    try {
      // Direct filePath URL (cloud disk, local, etc.)
      if (song.filePath != null && song.filePath!.isNotEmpty) {
        final fp = song.filePath!;
        final startAt = _takeStartPosition();
        if (fp.startsWith('http') || fp.startsWith('https')) {
          await _player.setUrl(fp, initialPosition: startAt);
          if (stale()) return;
          _lastUrlFetchTime = DateTime.now();
          if (_playWhenReady) _startPlayback();
        } else {
          // 本地文件：尝试 setFilePath，若失败则用 file:// URI + setUrl 重试
          try {
            await _player.setFilePath(fp, initialPosition: startAt);
          } catch (_) {
            if (stale()) return;
            final fileUri = Uri.file(fp).toString();
            await _player.setUrl(fileUri, initialPosition: startAt);
          }
          if (stale()) return;
          _lastUrlFetchTime = DateTime.now();
          if (_playWhenReady) _startPlayback();
        }
        isLoading.value = false;
        return;
      }

      // 在线歌曲：优先尝试音效 → 特权查询 → 候选链 → 逐个尝试
      bool played = false;

      // 有效果选中时，先尝试效果 URL（需先加载 privilege）
      if (effectKey != 'none') {
        await _buildCandidates(song, _currentQualityKey());
        if (stale()) return;
        final effectOpts = _currentEffectOptions;
        if (effectOpts.isNotEmpty) {
          final matched = effectOpts.where((o) => o.value == effectKey);
          if (matched.isNotEmpty) {
            final opt = matched.first;
            try {
              final songUrl = await _musicService.getSongUrl(
                song.id,
                hash: opt.hash.isNotEmpty ? opt.hash : song.hash,
                quality: opt.value,
              );
              if (stale()) return;
              if (!songUrl.isVideo && songUrl.url.isNotEmpty) {
                await _player.setUrl(songUrl.url,
                    initialPosition: _takeStartPosition());
                if (stale()) return;
                _lastUrlFetchTime = DateTime.now();
                if (_playWhenReady) _startPlayback();
                played = true;
                resolvedQualityNotifier.value = opt.value;
                Log.i('audio_engine', 'effect resolved: ${opt.value} (${opt.label})');
              }
            } catch (_) {
              // 效果失败，降级到编码音质
            }
          }
        }
      }

      // 编码音质候选链
      if (stale()) return;
      if (!played) {
        final preferred = _currentQualityKey();
        final candidates = await _buildCandidates(song, preferred);
        if (stale()) return;
        for (final c in candidates) {
        if (stale()) return;
        if (c.hash.isEmpty && c.quality == '128') continue; // 无 hash 跳过

        try {
          final songUrl = await _musicService.getSongUrl(
            song.id,
            hash: c.hash.isNotEmpty ? c.hash : song.hash,
            quality: c.quality,
          );
          if (stale()) return;

          // 跳过 mp4 格式（Kugou 对部分 VIP 歌曲返回视频而非音频）
          if (songUrl.isVideo) {
            Log.w('audio_engine', 'skip mp4 quality=${c.quality}');
            continue;
          }

          if (songUrl.url.isNotEmpty) {
            await _player.setUrl(songUrl.url,
                initialPosition: _takeStartPosition());
            if (stale()) return;
            _lastUrlFetchTime = DateTime.now();
            if (_playWhenReady) _startPlayback();
            played = true;

            // ✅ 记录最终解析到的音质
            resolvedQualityNotifier.value = c.quality;
            Log.i('audio_engine', 'resolved quality: ${c.quality} (${c.label})');
            break;
          }
        } catch (e) {
          if (stale()) return;
          // 特殊异常直接抛出让外层 catch 处理
          if (e is NoCopyrightException || e is NeedLoginException) rethrow;
          Log.w('audio_engine', 'candidate quality=${c.quality} failed: $e');
          // 继续尝试下一个候选
        }
      } // end for
      } // end if (!played) quality candidates

      if (stale()) return;
      if (!played) {
        // 所有候选都失败，重试
        _playAttempts++;
        await play(song, version: requestVersion, effectKey: effectKey);
        return;
      }
    } catch (e, s) {
      if (stale()) return;
      _playAttempts++;
      Log.w('audio_engine', 'play error (attempt $_playAttempts)', e, s);
      if (e is NoCopyrightException) {
        isLoading.value = false;
        error.value = e.message;
        showErrorDialog(title: '播放失败', errorCode: 'API 3', message: e.message);
        return;
      }
      if (e is NeedLoginException) {
        isLoading.value = false;
        error.value = '播放需要重新登录';
        showErrorDialog(title: '登录失效', errorCode: 'API 20010', message: '播放需要重新登录', showLogin: true);
        return;
      }
      if (_playAttempts <= _maxRetries) {
        await play(song, version: requestVersion, effectKey: effectKey);
        return;
      }
      isLoading.value = false;
      error.value = '播放失败：${friendlyError(e)}';
      Log.e('audio_engine', '', e, s);
      _showLoginIfUnauth();
      return;
    }
    if (!stale()) isLoading.value = false;
  }

  /// 继续播放当前歌曲（幂等：已在播放时什么都不做）。
  ///
  /// 播放器没有音源（冷启动恢复后 / stop 后）或已播完时重新加载；
  /// 音源加载超过 10 分钟时先刷新地址再从原位置继续。
  Future<void> resume(Song currentSong, {String effectKey = 'none'}) async {
    if (_player.playing) return;
    _playWhenReady = true;
    // 正在加载：只需恢复"就绪即播"意图，进行中的 play() 会据此启动播放
    if (isLoading.value) return;
    final completed = _player.processingState == ProcessingState.completed;
    if (needsLoad || completed) {
      if (completed) startPosition = null;
      error.value = null;
      isLoading.value = true;
      _playRequestVersion++;
      _playAttempts = 0;
      await play(currentSong, effectKey: effectKey);
      return;
    }
    final lastFetch = _lastUrlFetchTime;
    final isStale = lastFetch != null &&
        DateTime.now().difference(lastFetch) > _urlStaleDuration;
    if (isStale && !currentSong.isLocal) {
      await _refreshUrlAndPlay(currentSong);
    } else {
      _startPlayback();
    }
  }

  Future<void> _refreshUrlAndPlay(Song song) async {
    final version = _playRequestVersion;
    bool cancelled() => _disposed || version != _playRequestVersion || !_playWhenReady;
    try {
      final quality = _currentQualityKey();
      final pos = position.value;
      final songUrl = await _musicService.getSongUrl(song.id,
          hash: song.hash, quality: quality);
      if (cancelled()) return;
      if (songUrl.url.isEmpty) {
        _startPlayback();
        return;
      }
      _lastUrlFetchTime = DateTime.now();
      await _player.setUrl(songUrl.url, initialPosition: pos);
      if (cancelled()) return;
      _startPlayback();
    } catch (e, s) {
      Log.e('audio_engine', 'refresh URL error', e, s);
      // 刷新失败时退回旧地址继续播放（多数情况下仍有效，403 由 idle 分支兜底）
      if (!cancelled()) _startPlayback();
    }
  }

  /// 切换音质（保持播放进度）
  ///
  /// [qualityKey] 编码音质 key，[effectKey] 可选音效 key（'none' 表示无效果）。
  /// 有效果时优先尝试音效 URL，失败后回退到编码音质候选链。
  ///
  /// 解析新地址期间旧音源继续播放，拿到地址后才替换，切换几乎无感；
  /// 期间若用户切歌（请求版本变化）则放弃本次切换，避免旧歌音源覆盖新歌。
  Future<bool> switchQuality(Song song, String qualityKey,
      {Duration? currentPosition, String effectKey = 'none'}) async {
    if (song.hash == null || song.hash!.isEmpty) return false;
    final version = _playRequestVersion;
    bool stale() => _disposed || version != _playRequestVersion;

    try {
      // 失效缓存，_buildCandidates 会重新查询
      invalidatePrivilege(song.hash);

      String? url;
      String? resolved;

      // 有效果选中时有 privilege 数据 → 优先尝试效果 URL
      if (effectKey != 'none') {
        await _buildCandidates(song, qualityKey);
        if (stale()) return false;
        final matched =
            _currentEffectOptions.where((o) => o.value == effectKey);
        if (matched.isNotEmpty) {
          final opt = matched.first;
          try {
            final songUrl = await _musicService.getSongUrl(
              song.id,
              hash: opt.hash.isNotEmpty ? opt.hash : song.hash,
              quality: opt.value,
            );
            if (!songUrl.isVideo && songUrl.url.isNotEmpty) {
              url = songUrl.url;
              resolved = opt.value;
            }
          } catch (_) {
            // 效果失败，降级到编码音质
          }
        }
      }

      // 效果未选中或效果失败 → 编码音质候选链
      if (stale()) return false;
      if (url == null) {
        final candidates = await _buildCandidates(song, qualityKey);
        for (final c in candidates) {
          if (stale()) return false;
          try {
            final songUrl = await _musicService.getSongUrl(
              song.id,
              hash: c.hash.isNotEmpty ? c.hash : song.hash,
              quality: c.quality,
            );
            if (songUrl.isVideo || songUrl.url.isEmpty) continue;
            url = songUrl.url;
            resolved = c.quality;
            break;
          } catch (_) {
            continue;
          }
        }
      }

      if (stale() || url == null) return false;

      // 以替换瞬间的实际进度为准（解析地址期间旧音源仍在播放）
      final pos = currentPosition ?? position.value;
      final wasPlaying = _player.playing;
      await _player.setUrl(url, initialPosition: pos);
      if (stale()) return false;
      _lastUrlFetchTime = DateTime.now();
      resolvedQualityNotifier.value = resolved;
      if (wasPlaying) _startPlayback();
      Log.i('audio_engine', 'quality switch: -> $resolved');
      return true;
    } catch (e, s) {
      Log.e('audio_engine', 'quality switch error', e, s);
      return false;
    }
  }

  void clearError() {
    error.value = null;
  }

  void resetForNewSong() {
    _playAttempts = 0;
    _playRequestVersion++;
    // 新歌从头播放：丢弃冷启动恢复/stop 时留下的起播位置
    startPosition = null;
    _fadeTimer?.cancel();
    error.value = null;
    isLoading.value = true;
    isCompleting.value = false;
    resolvedQualityNotifier.value = null;
    _currentQualityOptions = [];
    _currentEffectOptions = [];
    _playWhenReady = true;
    _hasActivePlayback = false;
    // 切歌前显式同步播放状态为 false，避免 stop() 的异步事件与新歌播放事件
    // 乱序时把 isPlaying 覆盖成错误值（UI 与系统控制栏显示颠倒）
    isPlaying.value = false;
    _player.stop(); // 立即停止上一首播放
  }

  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
  }

  Future<void> seekAndPlay(Duration pos) async {
    _playWhenReady = true;
    await _player.seek(pos);
    _startPlayback();
    isLoading.value = false;
  }

  Future<void> pause() async {
    _playWhenReady = false; // 暂停时标记为不需要播放
    _fadeTimer?.cancel();
    // 正在加载新歌时也取消待播：play() 的后续步骤会检查 _playWhenReady
    await _player.pause();
  }

  /// 停止播放并释放音源（系统 STOP 指令）。之后 resume 会重新加载。
  Future<void> stop() async {
    _playWhenReady = false;
    _playRequestVersion++; // 作废进行中的加载
    _fadeTimer?.cancel();
    _hasActivePlayback = false;
    startPosition = position.value;
    isLoading.value = false;
    await _player.stop();
  }


  void setVolume(double volume) {
    _player.setVolume(volume);
  }

  void setSpeed(double speed) {
    _speed = speed;
    _player.setSpeed(speed);
  }

  Timer? _fadeTimer;

  /// 淡入：从静音逐渐升到正常音量。
  ///
  /// 只在真正开始播放（新歌 / 继续播放）时调用，seek 和缓冲恢复不会触发；
  /// 新的淡入会取消上一个，避免多个计时器同时改音量。
  void _startFadeIn() {
    final dur = crossfadeMs;
    if (dur <= 0) return;
    _fadeTimer?.cancel();
    final steps = (dur / 50).round().clamp(5, 100);
    final interval = Duration(milliseconds: dur ~/ steps);
    _player.setVolume(0.0);
    double vol = 0.0;
    _fadeTimer = Timer.periodic(interval, (timer) {
      vol += 1.0 / steps;
      if (vol >= 1.0) {
        _player.setVolume(1.0);
        timer.cancel();
      } else {
        _player.setVolume(vol);
      }
    });
  }

  /// 未登录时播放失败 → 弹出登录提醒
  void _showLoginIfUnauth() {
    final ctx = app.navKey.currentContext;
    if (ctx == null) return;
    final auth = ctx.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showLoginRequiredDialog(ctx);
    }
  }

  void dispose() {
    _disposed = true;
    _playRequestVersion++;
    onComplete = null;
    onReady = null;
    clearPrivilegeCache();
    _fadeTimer?.cancel();
    _sessionIdSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _processingStateSub?.cancel();
    _playbackSub?.cancel();
    position.dispose();
    duration.dispose();
    isLoading.dispose();
    isPlaying.dispose();
    error.dispose();
    isCompleting.dispose();
    resolvedQualityNotifier.dispose();
    _player.dispose();
  }
}

/// 内部候选结构：一个音质候选项的 quality + hash + label
class _Candidate {
  final String quality;
  final String hash;
  final String label;
  const _Candidate({
    required this.quality,
    required this.hash,
    required this.label,
  });
}
