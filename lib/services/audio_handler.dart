// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:audio_service/audio_service.dart';
import '../utils/logger.dart';

/// audio_service 的 [AudioHandler] 实现。
///
/// 扮演 Dart 端与系统 MediaSession 之间的薄桥接层：
/// * PlayerProvider 调用 [updateNotification] / [cancelNotification] 来更新
///   系统媒体通知和锁屏/蓝牙元数据。
/// * 系统控制（通知栏按钮、蓝牙耳机、锁屏）→ 通过回调通知 PlayerProvider。
class MusicAudioHandler extends BaseAudioHandler {
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
    final uri = albumArtUrl != null
        ? Uri.tryParse(albumArtUrl.replaceFirst('{size}', '480'))
        : null;
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
      processingState:
          isBuffering ? AudioProcessingState.buffering : AudioProcessingState.ready,
      controls: controls,
      androidCompactActionIndices: const [0, 1, 2], // 紧凑模式只显示前三个
      systemActions: const {MediaAction.seek},
      updatePosition: Duration(seconds: positionSec),
      bufferedPosition: Duration(seconds: durationSec),
      speed: speed,
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
