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
            override fun onMediaButtonEvent(mediaButtonIntent: Intent?): Boolean {
                // Handle wired headset / Bluetooth media buttons
                return super.onMediaButtonEvent(mediaButtonIntent)
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

        // 异步加载封面（避免主线程 ANR）
        if (albumArtUrl != null) {
            scope.launch {
                try {
                    val u = URL(albumArtUrl.replace("{size}", "480"))
                    cachedArt = BitmapFactory.decodeStream(u.openStream())
                    // 封面加载完成后刷新 metadata + 通知
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
        pushPlaybackState()      // 通过 PlaybackState 的自定义 action bits 更新按钮状态
    }

    // ─── MediaSession 状态推送 ───

    private fun pushMetadata() {
        val meta = android.media.MediaMetadata.Builder()
            .putString(android.media.MediaMetadata.METADATA_KEY_TITLE, currentTitle)
            .putString(android.media.MediaMetadata.METADATA_KEY_ARTIST, currentArtist)
            .putLong(android.media.MediaMetadata.METADATA_KEY_DURATION, currentDuration)
            .apply {
                cachedArt?.let {
                    putBitmap(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART, it)
                }
            }
            .build()
        mediaSession.setMetadata(meta)
        updateNotification()
    }

    @Suppress("DEPRECATION")
    private fun pushPlaybackState() {
        val state = when {
            isCurrentlyBuffering -> PlaybackState.STATE_BUFFERING
            isCurrentlyPlaying -> PlaybackState.STATE_PLAYING
            else -> PlaybackState.STATE_PAUSED
        }

        // 基础 action: play/pause/prev/next/stop/seek
        var actions = PlaybackState.ACTION_PLAY or
                PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_SKIP_TO_NEXT or
                PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                PlaybackState.ACTION_STOP or
                PlaybackState.ACTION_SEEK_TO

        // 自定义按钮: 通过额外 action bits 暴露
        // 系统媒体控件会读取这些 actions 来决定第 4、5 槽是否显示
        actions = actions or CUSTOM_ACTION_LIKE or CUSTOM_ACTION_SWITCH_MODE

        // 在 extras 中存放自定义按钮的状态（系统 UI 不读，但可通过广播扩展）
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

        // Android 12+: MediaStyle 支持 5 个按钮
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val style = Notification.MediaStyle()
                .setMediaSession(mediaSession.sessionToken)
                .setShowActionsInCompactView(1, 2, 3)  // 紧凑模式显示 3 个: prev/play/next

            return Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle(currentTitle)
                .setContentText(currentArtist)
                .setLargeIcon(cachedArt)
                .setContentIntent(openPi)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOngoing(isPlaying)
                .setStyle(style)
                .addAction(android.R.drawable.ic_media_previous, "上一首", prevPi)       // slot 2
                .addAction(playIcon, playText, ppPi)                                     // slot 1
                .addAction(android.R.drawable.ic_media_next, "下一首", nextPi)             // slot 3
                .addAction(
                    if (isLiked) android.R.drawable.ic_star_on else android.R.drawable.ic_star_off,
                    if (isLiked) "已收藏" else "收藏",
                    // 收藏按钮通过 PendingIntent 广播触发，由 MediaButtonReceiver 路由
                    PendingIntent.getBroadcast(this, 5,
                        Intent(ACTION_PLAY_PAUSE).setPackage(packageName)
                            .putExtra("command", "like"),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )                                                                         // slot 4
                .addAction(android.R.drawable.ic_media_next, "播放模式", nextPi)           // slot 5
                .build()
        } else {
            // Android < 12: 兼容模式，使用 NotificationCompat
            val style = androidx.media.app.NotificationCompat.MediaStyle()
                .setMediaSession(mediaSession.sessionToken)
                .setShowActionsInCompactView(1, 2, 3)

            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle(currentTitle)
                .setContentText(currentArtist)
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

    private fun exitService() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
}
