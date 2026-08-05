// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:smtc_windows/smtc_windows.dart';
import '../utils/logger.dart';

/// audio_service 的 [AudioHandler] 实现。
///
/// 扮演 Dart 端与系统 MediaSession 之间的薄桥接层：
/// * PlayerProvider 调用 [updateNotification] / [cancelNotification] 来更新
///   系统媒体通知和锁屏/蓝牙元数据。
/// * 系统控制（通知栏按钮、蓝牙耳机、锁屏）→ 通过回调通知 PlayerProvider。
class MusicAudioHandler extends BaseAudioHandler {
  SMTCWindows? _smtc;

  MusicAudioHandler() {
    if (Platform.isWindows) {
      _initSMTC();
    }
  }

  Future<void> _initSMTC() async {
    try {
      // smtc_windows 底层是 flutter_rust_bridge，必须先初始化 RustLib，
      // 否则 SMTCWindows 构造会抛 "flutter_rust_bridge has not been initialized"
      await SMTCWindows.initialize();
      _smtc = SMTCWindows(
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          stopEnabled: true,
          nextEnabled: true,
          prevEnabled: true,
          fastForwardEnabled: false,
          rewindEnabled: false,
        ),
      );
      _smtc?.buttonPressStream.listen((event) {
        switch (event) {
          case PressedButton.play:
            play();
            break;
          case PressedButton.pause:
            pause();
            break;
          case PressedButton.next:
            skipToNext();
            break;
          case PressedButton.previous:
            skipToPrevious();
            break;
          case PressedButton.stop:
            stop();
            break;
          default:
            break;
        }
      });
    } catch (e) {
      Log.e('audio_handler', 'SMTC init failed', e);
    }
  }

  // ─── 使用系统原生 @android:drawable/ic_media_* 图标的按钮 ───
  static const _prevControl = MediaControl(
    androidIcon: 'drawable/ic_notif_prev',
    label: 'Previous',
    action: MediaAction.skipToPrevious,
  );
  static const _playControl = MediaControl(
    androidIcon: 'drawable/ic_notif_play',
    label: 'Play',
    action: MediaAction.play,
  );
  static const _pauseControl = MediaControl(
    androidIcon: 'drawable/ic_notif_pause',
    label: 'Pause',
    action: MediaAction.pause,
  );
  static const _nextControl = MediaControl(
    androidIcon: 'drawable/ic_notif_next',
    label: 'Next',
    action: MediaAction.skipToNext,
  );

  // ─── 系统控制 → PlayerProvider 回调 ───

  void Function()? onPlay;
  void Function()? onPause;
  void Function()? onSkipNext;
  void Function()? onSkipPrevious;
  void Function(Duration)? onSeek;
  void Function()? onStop;
  void Function()? onLike;
  void Function()? onSwitchMode;

  // ─── 向系统推送媒体信息 ───

  /// 更新媒体通知/锁屏/蓝牙元数据及播放状态。
  void updateNotification({
    required String id,
    required String title,
    required String artist,
    String? albumArtUrl,
    String? lyricLine,
    required bool isPlaying,
    required int durationSec,
    required int positionSec,
    required bool isBuffering,
    required double speed,
    bool liked = false,
    String playMode = 'sequential',
  }) {
    // ── MediaItem（→ 通知标题/歌手/封面 + 锁屏/蓝牙歌词） ──
    // 本地封面（file:// 或裸路径）不传给系统媒体会话：audio_service/SMTC
    // 的 artUri 只支持 http(s) 可下载 URL，本地路径会导致 "No host specified"。
    final art = albumArtUrl?.replaceFirst('{size}', '480');
    final isRemoteArt = art != null &&
        (art.startsWith('http://') || art.startsWith('https://'));
    final uri = isRemoteArt ? Uri.tryParse(art) : null;
    mediaItem.add(MediaItem(
      id: id,
      title: title,
      artist: artist,
      duration: Duration(seconds: durationSec),
      artUri: uri,
      displaySubtitle: lyricLine, // 蓝牙/锁屏设备读取
    ));

    // ── 通知按钮（系统原生样式） ──
    final controls = <MediaControl>[
      _prevControl,
      if (isPlaying) _pauseControl else _playControl,
      _nextControl,
      // 自定义按钮（展开通知显示）—— 临时注释，等 drawable 资源就绪后取消注释
      // MediaControl.custom(
      //   androidIcon: liked
      //       ? 'drawable/audio_service_favorite'
      //       : 'drawable/audio_service_favorite_border',
      //   label: liked ? '已收藏' : '收藏',
      //   name: 'like',
      // ),
      // MediaControl.custom(
      //   androidIcon: 'drawable/audio_service_shuffle',
      //   label: playMode == 'shuffle'
      //       ? '随机'
      //       : playMode == 'repeatOne'
      //           ? '单曲'
      //           : '顺序',
      //   name: 'switch_mode',
      // ),
    ];

    // ── 播放状态（→ 通知进度/播放暂停图标） ──
    playbackState.add(playbackState.value.copyWith(
      playing: isPlaying,
      processingState: isBuffering
          ? AudioProcessingState.buffering
          : AudioProcessingState.ready,
      controls: controls,
      androidCompactActionIndices: const [0, 1, 2], // 紧凑模式只显示前三个
      systemActions: const {MediaAction.seek},
      updatePosition: Duration(seconds: positionSec),
      bufferedPosition: Duration(seconds: durationSec),
      speed: speed,
    ));

    if (Platform.isWindows && _smtc != null) {
      _smtc!.updateMetadata(MusicMetadata(
        title: title,
        artist: artist,
        album: artist,
        thumbnail: isRemoteArt ? art : null,
      ));
      _smtc!.setPlaybackStatus(
          isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused);
      // 同步进度时间线，让系统媒体控件显示/拖动进度
      _smtc!.updateTimeline(PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: durationSec * 1000,
        positionMs: positionSec * 1000,
        minSeekTimeMs: 0,
        maxSeekTimeMs: durationSec * 1000,
      ));
    }
  }

  /// 更新 SMTC 播放进度时间线（Windows 系统媒体控件进度显示/拖动）。
  /// 由 PlayerProvider 在位置变化时以节流频率调用，避免高频 IPC。
  void updateTimeline(
      {required Duration position, required Duration duration}) {
    if (!Platform.isWindows || _smtc == null) return;
    _smtc!.updateTimeline(PlaybackTimeline(
      startTimeMs: 0,
      endTimeMs: duration.inMilliseconds,
      positionMs: position.inMilliseconds,
      minSeekTimeMs: 0,
      maxSeekTimeMs: duration.inMilliseconds,
    ));
  }

  /// 清除当前媒体通知，释放资源。
  void cancelNotification() {
    Log.i('audio_handler', 'cancelNotification');
    mediaItem.add(null);
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));

    if (Platform.isWindows && _smtc != null) {
      _smtc!.setPlaybackStatus(PlaybackStatus.stopped);
      _smtc!.clearMetadata();
    }
  }

  // ─── 系统控制回调处理 ───

  @override
  Future<void> play() async {
    onPlay?.call();
  }

  @override
  Future<void> pause() async {
    onPause?.call();
  }

  @override
  Future<void> skipToNext() async {
    onSkipNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipPrevious?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    onSeek?.call(position);
  }

  @override
  Future<void> stop() async {
    onStop?.call();
    await super.stop();
  }

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'like':
        onLike?.call();
      case 'switch_mode':
        onSwitchMode?.call();
    }
    return super.customAction(name, extras);
  }
}
