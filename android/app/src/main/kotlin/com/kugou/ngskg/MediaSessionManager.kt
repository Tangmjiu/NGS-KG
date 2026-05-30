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
import android.os.Bundle
import android.support.v4.media.session.MediaSessionCompat
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import io.flutter.view.FlutterCallbackInformation
import java.net.URL

/**
 * 原生媒体通知 & MediaSession 管理
 *
 * 功能：
 * - 向系统注册 MediaSession（锁屏控制、车载蓝牙 A2DP 元数据广播）
 * - 使用 MediaStyle 发布通知（显示在系统快捷面板媒体中心）
 * - 处理媒体按钮事件（上一首/播放暂停/下一首/停止）
 */
class MediaSessionManager(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "music_playback_media"
        const val NOTIF_ID = 1
        const val ACTION_PREV = "com.kugou.ngskg.PREV"
        const val ACTION_PLAY_PAUSE = "com.kugou.ngskg.PLAY_PAUSE"
        const val ACTION_NEXT = "com.kugou.ngskg.NEXT"
        const val ACTION_STOP = "com.kugou.ngskg.STOP"
    }

    private val notificationManager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private val mediaSession: MediaSessionCompat = MediaSessionCompat(context, "NGSKGPlayer")

    var onPrev: (() -> Unit)? = null
    var onPlayPause: (() -> Unit)? = null
    var onNext: (() -> Unit)? = null

    private var cachedArt: Bitmap? = null

    init {
        createChannel()
        setupMediaSession()
    }

    // ─── 通知渠道 ───

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "音乐播放",
            NotificationManager.IMPORTANCE_LOW  // LOW = 不弹横幅但有声音布局
        ).apply {
            description = "音乐播放控制（含锁屏和车载蓝牙）"
            setShowBadge(false)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(channel)
    }

    // ─── MediaSession ───

    private fun setupMediaSession() {
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() { onPlayPause?.invoke() }
            override fun onPause() { onPlayPause?.invoke() }
            override fun onSkipToNext() { onNext?.invoke() }
            override fun onSkipToPrevious() { onPrev?.invoke() }
            override fun onStop() {
                // 停止时会自动清除通知
                mediaSession.isActive = false
                notificationManager.cancel(NOTIF_ID)
            }
        })
        mediaSession.setFlags(
            MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
            MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
        )
    }

    // ─── 更新元数据 ───

    fun updateMetadata(
        title: String,
        artist: String,
        albumArtUrl: String?,
        duration: Long,
        lyricLine: String?
    ) {
        mediaSession.isActive = true

        // 下载封面
        if (albumArtUrl != null) {
            try {
                val url = URL(albumArtUrl.replace("{size}", "480"))
                cachedArt = BitmapFactory.decodeStream(url.openStream())
            } catch (_: Exception) {
                // 封面加载失败，使用已有缓存
            }
        }

        // 构建 MediaMetadata
        val metadata = android.media.MediaMetadata.Builder()
            .putString(android.media.MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(android.media.MediaMetadata.METADATA_KEY_ARTIST, artist)
            .putLong(android.media.MediaMetadata.METADATA_KEY_DURATION, duration)
            .apply {
                cachedArt?.let {
                    putBitmap(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART, it)
                }
            }
            .build()

        mediaSession.setMetadata(metadata)

        // 同时缓存封面用于通知
    }

    // ─── 更新播放状态 ───

    fun updatePlaybackState(isPlaying: Boolean, position: Long) {
        val state = if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED

        val playbackState = PlaybackState.Builder()
            .setActions(
                PlaybackState.ACTION_PLAY or
                PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_SKIP_TO_NEXT or
                PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                PlaybackState.ACTION_STOP
            )
            .setState(state, position, 1.0f)
            .build()

        mediaSession.setPlaybackState(playbackState)

        // 更新通知
        showNotification(isPlaying, position)
    }

    // ─── 通知 ───

    private fun showNotification(isPlaying: Boolean, position: Long) {
        val metadata = mediaSession.controller.metadata

        val title = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE) ?: "未知歌曲"
        val artist = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST) ?: "未知歌手"

        // PendingIntent: 点击通知打开 App
        val openIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_player", true)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 动作：上一首
        val prevIntent = Intent(ACTION_PREV).setPackage(context.packageName)
        val prevPendingIntent = PendingIntent.getBroadcast(
            context, 1, prevIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 动作：播放/暂停
        val ppIntent = Intent(ACTION_PLAY_PAUSE).setPackage(context.packageName)
        val ppPendingIntent = PendingIntent.getBroadcast(
            context, 2, ppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 动作：下一首
        val nextIntent = Intent(ACTION_NEXT).setPackage(context.packageName)
        val nextPendingIntent = PendingIntent.getBroadcast(
            context, 3, nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(artist)
            .setSubText(metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM) ?: "")
            .setLargeIcon(cachedArt)
            .setContentIntent(openPendingIntent)
            .setDeleteIntent(prevPendingIntent) // 滑动关闭 = 上一首
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC) // 锁屏显示
            .setOngoing(isPlaying) // 播放中不可滑动清除
            .setShowWhen(false)
            // MediaStyle：集成 MediaSession，显示在系统媒体中心
            .setStyle(androidx.media.app.NotificationCompat.MediaStyle()
                .setMediaSession(mediaSession.sessionToken)
                .setShowActionsInCompactView(0, 1, 2) // 紧凑视图显示三个按钮
                .setShowCancelButton(true))
            // 动作按钮
            .addAction(android.R.drawable.ic_media_previous, "上一首", prevPendingIntent)
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "暂停" else "播放",
                ppPendingIntent
            )
            .addAction(android.R.drawable.ic_media_next, "下一首", nextPendingIntent)
            .build()

        notificationManager.notify(NOTIF_ID, notification)
    }

    // ─── 释放 ───

    fun release() {
        mediaSession.isActive = false
        mediaSession.release()
        notificationManager.cancel(NOTIF_ID)
    }
}
