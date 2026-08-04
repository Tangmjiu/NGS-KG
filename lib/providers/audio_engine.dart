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
import '../utils/navigation.dart' as app;
import '../providers/auth_provider.dart';
import '../widgets/login_required_dialog.dart';

class AudioEngine {
  final MusicService _musicService;
  final AudioPlayer _player = AudioPlayer();

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
  double _userVolume = 1.0;
  double get volume => _userVolume;
  double get speed => _speed;

  /// 最终解析出的音质 key（MoeKoeMusic 风格：记录实际可用的最高级别）
  final ValueNotifier<String?> resolvedQualityNotifier = ValueNotifier(null);

  /// 当前歌曲可用编码音质选项（来自 privilege 预查）
  List<QualityOption> _currentQualityOptions = [];

  /// 当前歌曲可用音效选项（来自 privilege 预查）
  List<QualityOption> _currentEffectOptions = [];

  /// Privilege 缓存（hash → PrivilegeInfo），避免重复请求
  final Map<String, PrivilegeInfo> _privilegeCache = {};

  /// 清除指定歌曲的 privilege 缓存
  void invalidatePrivilege(String? hash) {
    if (hash != null && hash.isNotEmpty) {
      _privilegeCache.remove(hash);
    }
  }

  /// 清除所有 privilege 缓存
  void clearPrivilegeCache() => _privilegeCache.clear();

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

  AudioEngine(this._musicService) {
    _initSession();
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
        // 淡入效果：从 0 逐渐升到 1.0
        if (crossfadeMs > 0) {
          _startFadeIn();
        }
      } else if (state == ProcessingState.idle) {
        if (_hasActivePlayback) {
          _hasActivePlayback = false;
          isLoading.value = false;
          error.value = '播放出错，请重试';
          _showLoginIfUnauth();
        }
      }
    });
    _playbackSub = _player.playbackEventStream.listen((event) {
      isPlaying.value = _player.playing;
    });
  }

  void _initSession() {
    AudioSession.instance
        .then((session) => session.configure(const AudioSessionConfiguration(
              androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
              androidWillPauseWhenDucked: true,
            )))
        .catchError((e) {
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
    final hash = song.hash;
    if (song.isLocal && hash == null) {
      resolvedQualityNotifier.value = '128';
      _currentQualityOptions = [
        QualityOption(value: '128', label: '标准', hash: '')
      ];
      _currentEffectOptions = [];
      return;
    }
    if (hash != null && hash.isNotEmpty) {
      try {
        PrivilegeInfo? info = _privilegeCache[hash];
        if (info == null) {
          final res = await _musicService.getPrivilegeLite(hash);
          info = PrivilegeInfo.fromJson(res);
          if (info.options.isNotEmpty) {
            _privilegeCache[hash] = info;
          }
        }
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
  Future<List<_Candidate>> _buildCandidates(
      Song song, String preferredQuality) async {
    final hash = song.hash;

    // 本地歌曲不需要特权查询
    if (song.isLocal && hash == null) {
      return [_Candidate(quality: '128', hash: '', label: '标准')];
    }

    // 尝试从 privilege 获取
    if (hash != null && hash.isNotEmpty) {
      try {
        PrivilegeInfo? info = _privilegeCache[hash];
        if (info == null) {
          final res = await _musicService.getPrivilegeLite(hash);
          info = PrivilegeInfo.fromJson(res);
          if (info.options.isNotEmpty) {
            _privilegeCache[hash] = info;
          }
        }
        if (info.options.isNotEmpty || info.effectOptions.isNotEmpty) {
          _currentQualityOptions = info.options;
          _currentEffectOptions = info.effectOptions;
          final candidates =
              info.candidates(preferredQuality, fallbackHash: hash);
          return candidates
              .map((opt) => _Candidate(
                    quality: opt.value,
                    hash: opt.hash,
                    label: opt.label,
                  ))
              .toList();
        }
      } catch (e, s) {
        Log.w(
            'audio_engine', 'privilege query failed, fallback to chain', e, s);
      }
    }

    // 回退：基于 qualityLevel 的降级链，使用歌曲原始 hash
    // privilege 失败时清空选项列表，让 UI 按全量 levels 回退显示
    _currentQualityOptions = [];
    _currentEffectOptions = [];
    final chain = Quality.fallbackChain(preferredQuality);
    return chain
        .map((q) => _Candidate(
              quality: q,
              hash: hash ?? '',
              label: Quality.label(q),
            ))
        .toList();
  }

  /// ─── 核心播放方法 ───
  Future<void> play(Song song,
      {int? version, String effectKey = 'none'}) async {
    version ??= _playRequestVersion;
    if (version != _playRequestVersion) {
      isLoading.value = false;
      return;
    }
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
        if (fp.startsWith('http') || fp.startsWith('https')) {
          await _player.setUrl(fp);
          if (version != _playRequestVersion) {
            isLoading.value = false;
            return;
          }
          _lastUrlFetchTime = DateTime.now();
          if (_playWhenReady) {
            await _player.play();
            _hasActivePlayback = true;
          }
        } else {
          // 本地文件：尝试 setFilePath，若失败则用 file:// URI + setUrl 重试
          try {
            await _player.setFilePath(fp);
          } catch (_) {
            final fileUri = Uri.file(fp).toString();
            await _player.setUrl(fileUri);
          }
          if (version != _playRequestVersion) {
            isLoading.value = false;
            return;
          }
          _lastUrlFetchTime = DateTime.now();
          if (_playWhenReady) {
            await _player.play();
            _hasActivePlayback = true;
          }
        }
        isLoading.value = false;
        return;
      }

      // 在线歌曲：优先尝试音效 → 特权查询 → 候选链 → 逐个尝试
      bool played = false;

      // 有效果选中时，先尝试效果 URL（需先加载 privilege）
      if (effectKey != 'none') {
        await _buildCandidates(song, _currentQualityKey());
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
              if (version != _playRequestVersion) {
                isLoading.value = false;
                return;
              }
              if (!songUrl.isVideo && songUrl.url.isNotEmpty) {
                await _player.setUrl(songUrl.url);
                if (version != _playRequestVersion) {
                  isLoading.value = false;
                  return;
                }
                _lastUrlFetchTime = DateTime.now();
                if (_playWhenReady) {
                  await _player.play();
                  _hasActivePlayback = true;
                }
                played = true;
                resolvedQualityNotifier.value = opt.value;
                Log.i('audio_engine',
                    'effect resolved: ${opt.value} (${opt.label})');
              }
            } catch (_) {
              // 效果失败，降级到编码音质
            }
          }
        }
      }

      // 编码音质候选链
      if (!played) {
        final preferred = _currentQualityKey();
        final candidates = await _buildCandidates(song, preferred);
        for (final c in candidates) {
          if (version != _playRequestVersion) {
            isLoading.value = false;
            return;
          }
          if (c.hash.isEmpty && c.quality == '128') continue; // 无 hash 跳过

          try {
            final songUrl = await _musicService.getSongUrl(
              song.id,
              hash: c.hash.isNotEmpty ? c.hash : song.hash,
              quality: c.quality,
            );
            if (version != _playRequestVersion) {
              isLoading.value = false;
              return;
            }

            // 跳过 mp4 格式（Kugou 对部分 VIP 歌曲返回视频而非音频）
            if (songUrl.isVideo) {
              Log.w('audio_engine', 'skip mp4 quality=${c.quality}');
              continue;
            }

            if (songUrl.url.isNotEmpty) {
              await _player.setUrl(songUrl.url);
              if (version != _playRequestVersion) {
                isLoading.value = false;
                return;
              }
              _lastUrlFetchTime = DateTime.now();
              if (_playWhenReady) {
                await _player.play();
                _hasActivePlayback = true;
              }
              played = true;

              // ✅ 记录最终解析到的音质
              resolvedQualityNotifier.value = c.quality;
              Log.i('audio_engine',
                  'resolved quality: ${c.quality} (${c.label})');
              break;
            }
          } catch (e) {
            // 特殊异常直接抛出让外层 catch 处理
            if (e is NoCopyrightException || e is NeedLoginException) rethrow;
            Log.w('audio_engine', 'candidate quality=${c.quality} failed: $e');
            // 继续尝试下一个候选
          }
        } // end for
      } // end if (!played) quality candidates

      if (!played) {
        // 所有候选都失败，重试
        _playAttempts++;
        await play(song, version: version);
        return;
      }
    } catch (e, s) {
      _playAttempts++;
      Log.w('audio_engine', 'play error (attempt $_playAttempts)', e, s);
      if (e is NoCopyrightException) {
        isLoading.value = false;
        error.value = '播放失败: $e';
        showErrorDialog(title: '播放失败', errorCode: 'API 3', message: '$e');
        return;
      }
      if (e is NeedLoginException) {
        isLoading.value = false;
        error.value = '播放失败: $e';
        showErrorDialog(
            title: '登录失效',
            errorCode: 'API 20010',
            message: '播放需要重新登录',
            showLogin: true);
        return;
      }
      if (_playAttempts <= _maxRetries) {
        await play(song, version: version);
        return;
      }
      isLoading.value = false;
      error.value = '播放失败: $e';
      Log.e('audio_engine', '', e, s);
      _showLoginIfUnauth();
      return;
    }
    isLoading.value = false;
  }

  Future<void> togglePlayPause(Song? currentSong) async {
    if (currentSong == null) return;
    if (_player.playing) {
      _playWhenReady = false; // 暂停时设为 false
      await _player.pause();
    } else {
      _playWhenReady = true; // 播放时设为 true
      if (position.value == Duration.zero || position.value >= duration.value) {
        error.value = null;
        isLoading.value = true;
        _playRequestVersion++;
        _playAttempts = 0;
        await play(currentSong);
      } else {
        final lastFetch = _lastUrlFetchTime;
        final isStale = lastFetch != null &&
            DateTime.now().difference(lastFetch) > _urlStaleDuration;
        if (isStale && !currentSong.isLocal) {
          await _refreshUrlAndPlay(currentSong);
        } else {
          await _player.play();
        }
      }
    }
  }

  Future<void> _refreshUrlAndPlay(Song song) async {
    try {
      final quality = _currentQualityKey();
      final pos = position.value;
      final songUrl = await _musicService.getSongUrl(song.id,
          hash: song.hash, quality: quality);
      if (songUrl.url.isEmpty) return;
      _lastUrlFetchTime = DateTime.now();
      await _player.setUrl(songUrl.url);
      await _player.seek(pos);
      await _player.play();
      isLoading.value = false;
    } catch (e, s) {
      Log.e('audio_engine', 'refresh URL error', e, s);
      error.value = '刷新播放地址失败';
    }
  }

  /// 切换音质（保持播放进度）
  ///
  /// [qualityKey] 编码音质 key，[effectKey] 可选音效 key（'none' 表示无效果）。
  /// 有效果时优先尝试音效 URL，失败后回退到编码音质候选链。
  Future<bool> switchQuality(Song song, String qualityKey,
      {Duration? currentPosition, String effectKey = 'none'}) async {
    if (song.hash == null || song.hash!.isEmpty) return false;

    final pos = currentPosition ?? position.value;
    final wasPlaying = _player.playing;

    // 暂停当前播放
    await _player.pause();

    try {
      // 失效缓存，_buildCandidates 会重新查询
      invalidatePrivilege(song.hash);

      bool played = false;

      // 有效果选中时有 privilege 数据 → 优先尝试效果 URL
      if (effectKey != 'none') {
        // 先触发 privilege 加载
        await _buildCandidates(song, qualityKey);
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
              if (!songUrl.isVideo && songUrl.url.isNotEmpty) {
                await _player.setUrl(songUrl.url);
                _lastUrlFetchTime = DateTime.now();
                resolvedQualityNotifier.value = opt.value;
                await _player.seek(pos);
                if (wasPlaying) await _player.play();
                played = true;
                Log.i('audio_engine',
                    'effect switch: -> ${opt.value} (${opt.label})');
              }
            } catch (_) {
              // 效果失败，降级到编码音质
            }
          }
        }
      }

      // 效果未选中或效果失败 → 编码音质候选链
      if (!played) {
        final candidates = await _buildCandidates(song, qualityKey);
        for (final c in candidates) {
          try {
            final songUrl = await _musicService.getSongUrl(
              song.id,
              hash: c.hash.isNotEmpty ? c.hash : song.hash,
              quality: c.quality,
            );
            if (songUrl.isVideo) continue;
            if (songUrl.url.isNotEmpty) {
              await _player.setUrl(songUrl.url);
              _lastUrlFetchTime = DateTime.now();
              resolvedQualityNotifier.value = c.quality;

              await _player.seek(pos);

              if (wasPlaying) {
                await _player.play();
              }
              played = true;
              Log.i('audio_engine',
                  'quality switch: -> ${c.quality} (${c.label})');
              break;
            }
          } catch (_) {
            continue;
          }
        }
      }

      if (!played) {
        // 切换失败，尝试恢复
        if (wasPlaying) await _player.play();
        return false;
      }

      return true;
    } catch (e, s) {
      Log.e('audio_engine', 'quality switch error', e, s);
      if (wasPlaying) await _player.play();
      return false;
    }
  }

  void clearError() {
    error.value = null;
  }

  void resetForNewSong() {
    _playAttempts = 0;
    _playRequestVersion++;
    error.value = null;
    isLoading.value = true;
    isCompleting.value = false;
    resolvedQualityNotifier.value = null;
    _currentQualityOptions = [];
    _currentEffectOptions = [];
    _playWhenReady = true;
    _hasActivePlayback = false;
    _player.stop(); // 立即停止上一首播放
  }

  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
  }

  Future<void> seekAndPlay(Duration pos) async {
    await _player.seek(pos);
    await _player.play();
    isPlaying.value = true;
    isLoading.value = false;
  }

  Future<void> pause() async {
    _playWhenReady = false; // 暂停时标记为不需要播放
    await _player.pause();
  }

  void setVolume(double volume) {
    _userVolume = volume;
    _player.setVolume(volume);
  }

  void setSpeed(double speed) {
    _speed = speed;
    _player.setSpeed(speed);
  }

  /// 淡入：从静音逐渐升到正常音量
  void _startFadeIn() {
    final dur = crossfadeMs;
    if (dur <= 0) return;
    final steps = (dur / 50).round().clamp(5, 100);
    final interval = Duration(milliseconds: dur ~/ steps);
    _player.setVolume(0.0);
    double vol = 0.0;
    Timer.periodic(interval, (timer) {
      vol += _userVolume / steps;
      if (vol >= _userVolume) {
        _player.setVolume(_userVolume);
        timer.cancel();
      } else {
        _player.setVolume(vol);
      }
    });
  }

  /// 上报播放历史，重试最多 3 次，指数退避
  Future<void> _uploadHistoryWithRetry(int songId,
      {int? duration, int retries = 3}) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        await _musicService.uploadPlayHistory(songId, duration: duration);
        return; // 成功
      } catch (e, s) {
        Log.w('audio_engine',
            'uploadPlayHistory failed (attempt ${attempt + 1}/$retries): $e');
        if (attempt < retries - 1) {
          // 指数退避：1s, 2s, 4s
          await Future.delayed(Duration(seconds: 1 << attempt));
        } else {
          Log.e('audio_engine', 'uploadPlayHistory exhausted retries', e, s);
        }
      }
    }
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
