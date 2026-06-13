// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

package com.kugou.ngskg

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.net.URL

/**
 * 前台媒体播放服务
 *
 * 管理 MediaSession + MediaStyle 通知，支持：
 * - Android 13+ 5 槽位系统媒体控件
 * - OPPO ColorOS 流体云
 * - 自定义命令按钮（收藏、播放模式切换）
 * - 锁屏/蓝牙进度拖拽
 *
 * 通过 Binder 与 MainActivity 通信，Activity 转发 Flutter 的 MethodChannel 调用至此。
 */
class PlaybackService : android.app.Service() {

    companion object {
        const val CHANNEL_ID = "music_playback_media3"
        const val NOTIF_ID = 1

        // Notification actions (for BroadcastReceiver)
        const val ACTION_PREV = "com.kugou.ngskg.PREV"
        const val ACTION_PLAY_PAUSE = "com.kugou.ngskg.PLAY_PAUSE"
        const val ACTION_NEXT = "com.kugou.ngskg.NEXT"
        const val ACTION_STOP = "com.kugou.ngskg.STOP"

        // Custom session commands (for system media controls)
        const val CMD_LIKE = "LIKE"
        const val CMD_SWITCH_MODE = "SWITCH_MODE"
        const val CMD_SEEK_TO = "SEEK_TO"

        // PlaybackState custom action bits (bit 29+ for custom)
        const val CUSTOM_ACTION_LIKE: Long = 1L shl 29
        const val CUSTOM_ACTION_SWITCH_MODE: Long = 1L shl 30
    }

    // ─── MediaSession ───
    private lateinit var mediaSession: MediaSession
    private lateinit var notificationManager: NotificationManager
    private var cachedArt: Bitmap? = null
    private var scope = CoroutineScope(Dispatchers.IO + Job())

    // ─── 状态缓存 ───
    private var currentTitle: String = "NGS-KG+"
    private var currentArtist: String = ""
    private var currentDuration: Long = 0L
    private var currentPosition: Long = 0L
    private var currentLyricLine: String? = null
    private var isCurrentlyPlaying: Boolean = false
    private var isCurrentlyBuffering: Boolean = false
    private var isLiked: Boolean = false
    private var playModeLabel: String = "sequential"  // sequential | shuffle | repeatOne

    // ─── Flutter 回调（由 MainActivity 设置） ───
    var onPrev: (() -> Unit)? = null
    var onPlayPause: (() -> Unit)? = null
    var onNext: (() -> Unit)? = null
    var onSeekTo: ((Long) -> Unit)? = null
    var onLike: (() -> Unit)? = null
    var onSwitchMode: (() -> Unit)? = null

    // ─── Binder ───
    private val binder = LocalBinder()

    inner class LocalBinder : android.os.Binder() {
        fun getService(): PlaybackService = this@PlaybackService
    }

    override fun onBind(intent: Intent): IBinder = binder

    // ─── 生命周期 ───

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createChannel()
        setupMediaSession()
        startForeground(NOTIF_ID, buildNotification(isPlaying = false))
    }

    override fun onDestroy() {
        mediaSession.isActive = false
        mediaSession.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    // ─── 通知频道 ───

    private fun createChannel() {
        val ch = NotificationChannel(
            CHANNEL_ID, "音乐播放",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "音乐播放控制（支持锁屏、蓝牙、流体云）"
            setShowBadge(false)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(ch)
    }

    // ─── MediaSession ───

    @Suppress("DEPRECATION")
    private fun setupMediaSession() {
        mediaSession = MediaSession(this, "NGSKGPlayer")
        mediaSession.setCallback(object : MediaSession.Callback() {
            override fun onPlay() {
                onPlayPause?.invoke()
            }
            override fun onPause() {
                onPlayPause?.invoke()
            }
            override fun onSkipToNext() {
                onNext?.invoke()
            }
            override fun onSkipToPrevious() {
                onPrev?.invoke()
            }
            override fun onStop() {
                exitService()
            }
            override fun onSeekTo(pos: Long) {
                onSeekTo?.invoke(pos)
            }
        })
        mediaSession.setFlags(
            MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
            MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
        )
        mediaSession.isActive = true
    }

    // ─── Flutter 调用的更新方法（通过 MainActivity → Binder → 这里） ───

    fun updateMetadata(
        title: String,
        artist: String,
        albumArtUrl: String?,
        durationSec: Long,       // 秒
        lyricLine: String?
    ) {
        currentTitle = title
        currentArtist = artist
        currentDuration = durationSec * 1000L  // 毫秒
        currentLyricLine = lyricLine

        // 异步加载封面（避免主线程 ANR）
        if (albumArtUrl != null) {
            scope.launch {
                try {
                    val u = URL(albumArtUrl.replace("{size}", "480"))
                    cachedArt = BitmapFactory.decodeStream(u.openStream())
                    pushMetadata()
                } catch (_: Exception) {
                    cachedArt = null
                    pushMetadata()
                }
            }
        } else {
            cachedArt = null
            pushMetadata()
        }
    }

    fun updatePlaybackState(
        isPlaying: Boolean,
        positionSec: Long,       // 秒
        isBuffering: Boolean = false
    ) {
        isCurrentlyPlaying = isPlaying
        currentPosition = positionSec * 1000L
        isCurrentlyBuffering = isBuffering
        pushPlaybackState()
        updateNotification()
    }

    fun updateCustomButtons(
        liked: Boolean,
        modeLabel: String        // "sequential" | "shuffle" | "repeatOne"
    ) {
        isLiked = liked
        playModeLabel = modeLabel
        pushPlaybackState()
    }

    // ─── MediaSession 状态推送 ───

    private fun pushMetadata() {
        val metaBuilder = android.media.MediaMetadata.Builder()
            .putString(android.media.MediaMetadata.METADATA_KEY_TITLE, currentTitle)
            .putString(android.media.MediaMetadata.METADATA_KEY_ARTIST, currentArtist)
            .putLong(android.media.MediaMetadata.METADATA_KEY_DURATION, currentDuration)
            .apply {
                cachedArt?.let {
                    putBitmap(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART, it)
                }
            }
        // 歌词行写入 MediaMetadata extras（供系统/蓝牙/穿戴设备读取）
        currentLyricLine?.let { line ->
            val bundle = android.os.Bundle()
            bundle.putString("lyricLine", line)
            metaBuilder.putString(
                android.media.MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE,
                line
            )
        }
        mediaSession.setMetadata(metaBuilder.build())
        updateNotification()
    }

    /** 当前歌词行（用于通知栏显示） */
    private fun currentLyricDisplay(): String? {
        val line = currentLyricLine ?: return null
        if (line.isBlank()) return null
        return "♪ $line"
    }

    @Suppress("DEPRECATION")
    private fun pushPlaybackState() {
        val state = when {
            isCurrentlyBuffering -> PlaybackState.STATE_BUFFERING
            isCurrentlyPlaying -> PlaybackState.STATE_PLAYING
            else -> PlaybackState.STATE_PAUSED
        }

        var actions = PlaybackState.ACTION_PLAY or
                PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_SKIP_TO_NEXT or
                PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                PlaybackState.ACTION_STOP or
                PlaybackState.ACTION_SEEK_TO

        actions = actions or CUSTOM_ACTION_LIKE or CUSTOM_ACTION_SWITCH_MODE

        val extras = android.os.Bundle().apply {
            putBoolean("is_liked", isLiked)
            putString("play_mode", playModeLabel)
        }

        val pbs = PlaybackState.Builder()
            .setActions(actions)
            .setState(state, currentPosition, 1.0f)
            .setExtras(extras)
            .build()
        mediaSession.setPlaybackState(pbs)
        updateNotification()
    }

    // ─── 通知 ───

    @Suppress("DEPRECATION")
    private fun buildNotification(isPlaying: Boolean): Notification {
        val openPi = PendingIntent.getActivity(this, 0,
            packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_player", true)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val prevPi = PendingIntent.getBroadcast(this, 1,
            Intent(ACTION_PREV).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val ppPi = PendingIntent.getBroadcast(this, 2,
            Intent(ACTION_PLAY_PAUSE).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val nextPi = PendingIntent.getBroadcast(this, 3,
            Intent(ACTION_NEXT).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopPi = PendingIntent.getBroadcast(this, 4,
            Intent(ACTION_STOP).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val playIcon = if (isPlaying) android.R.drawable.ic_media_pause
                       else android.R.drawable.ic_media_play
        val playText = if (isPlaying) "暂停" else "播放"

        // 通知：有歌词时标题显示歌词，正文显示"歌名 - 歌手"
        // 这样 Media3 系统控件的大字是歌词，小字是歌曲信息
        val lyricDisplay = currentLyricDisplay()
        val displayTitle = lyricDisplay ?: currentTitle
        val displayContent = if (lyricDisplay != null) {
            "$currentTitle - $currentArtist"
        } else {
            currentArtist
        }

        // Android 12+: 原生 MediaStyle API
        // 注意：setSubText 在 Android 12+ 系统媒体通知模板中不显示，
        // 歌词必须放在 setContentText 中才能在所有版本可见
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val style = Notification.MediaStyle()
                .setMediaSession(mediaSession.sessionToken)
                .setShowActionsInCompactView(0, 1, 2)

            return Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle(displayTitle)
                .setContentText(displayContent)
                .setLargeIcon(cachedArt)
                .setContentIntent(openPi)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOngoing(isPlaying)
                .setStyle(style)
                .addAction(android.R.drawable.ic_media_previous, "上一首", prevPi)
                .addAction(playIcon, playText, ppPi)
                .addAction(android.R.drawable.ic_media_next, "下一首", nextPi)
                .build()
        } else {
            // Android < 12: 兼容模式（仅 3 按钮，无自定义图标库）
            val style = androidx.media.app.NotificationCompat.MediaStyle()
                .setShowActionsInCompactView(0, 1, 2)

            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle(displayTitle)
                .setContentText(displayContent)
                .setLargeIcon(cachedArt)
                .setContentIntent(openPi)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOngoing(isPlaying)
                .setStyle(style)
                .addAction(android.R.drawable.ic_media_previous, "上一首", prevPi)
                .addAction(playIcon, playText, ppPi)
                .addAction(android.R.drawable.ic_media_next, "下一首", nextPi)
                .build()
        }
    }

    private fun updateNotification() {
        val n = buildNotification(isCurrentlyPlaying)
        notificationManager.notify(NOTIF_ID, n)
    }

    fun exitService() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
}
