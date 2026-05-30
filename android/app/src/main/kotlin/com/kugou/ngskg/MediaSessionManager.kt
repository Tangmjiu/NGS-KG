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
import androidx.core.app.NotificationCompat
import java.net.URL

/**
 * 原生媒体通知 & MediaSession 管理
 *
 * 纯平台 API（API 21+），MediaStyle 需要 API 31+，
 * 低版本使用 NotificationCompat（同样锁屏+通知栏控制）。
 */
class MediaSessionManager(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "music_playback_media"
        const val NOTIF_ID = 1
        const val ACTION_PREV = "com.kugou.ngskg.PREV"
        const val ACTION_PLAY_PAUSE = "com.kugou.ngskg.PLAY_PAUSE"
        const val ACTION_NEXT = "com.kugou.ngskg.NEXT"
    }

    private val notificationManager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val mediaSession: MediaSession = MediaSession(context, "NGSKGPlayer")

    var onPrev: (() -> Unit)? = null
    var onPlayPause: (() -> Unit)? = null
    var onNext: (() -> Unit)? = null
    private var cachedArt: Bitmap? = null

    init {
        createChannel()
        setupMediaSession()
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "音乐播放", NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "音乐播放控制（含锁屏和车载蓝牙）"
            setShowBadge(false)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun setupMediaSession() {
        mediaSession.setCallback(object : MediaSession.Callback() {
            override fun onPlay() { onPlayPause?.invoke() }
            override fun onPause() { onPlayPause?.invoke() }
            override fun onSkipToNext() { onNext?.invoke() }
            override fun onSkipToPrevious() { onPrev?.invoke() }
            override fun onStop() { release() }
        })
        mediaSession.setFlags(
            MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
            MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
        )
    }

    fun updateMetadata(title: String, artist: String, albumArtUrl: String?, duration: Long, lyricLine: String?) {
        mediaSession.isActive = true
        if (albumArtUrl != null) {
            try {
                val url = URL(albumArtUrl.replace("{size}", "480"))
                cachedArt = BitmapFactory.decodeStream(url.openStream())
            } catch (_: Exception) { }
        }
        val metadata = android.media.MediaMetadata.Builder()
            .putString(android.media.MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(android.media.MediaMetadata.METADATA_KEY_ARTIST, artist)
            .putLong(android.media.MediaMetadata.METADATA_KEY_DURATION, duration)
            .apply {
                cachedArt?.let { putBitmap(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART, it) }
            }
            .build()
        mediaSession.setMetadata(metadata)
    }

    fun updatePlaybackState(isPlaying: Boolean, position: Long) {
        val state = if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED
        val playbackState = PlaybackState.Builder()
            .setActions(
                PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                PlaybackState.ACTION_STOP
            )
            .setState(state, position, 1.0f)
            .build()
        mediaSession.setPlaybackState(playbackState)
        showNotification(isPlaying)
    }

    private fun showNotification(isPlaying: Boolean) {
        val metadata = mediaSession.controller.metadata
        val title = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE) ?: "未知歌曲"
        val artist = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST) ?: "未知歌手"

        val openPi = PendingIntent.getActivity(context, 0,
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_player", true)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val prevPi = PendingIntent.getBroadcast(context, 1,
            Intent(ACTION_PREV).setPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val ppPi = PendingIntent.getBroadcast(context, 2,
            Intent(ACTION_PLAY_PAUSE).setPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val nextPi = PendingIntent.getBroadcast(context, 3,
            Intent(ACTION_NEXT).setPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // API 31+：原生 MediaStyle → 系统媒体中心
            val style = Notification.MediaStyle()
                .setMediaSession(mediaSession.sessionToken)
                .setShowActionsInCompactView(0, 1, 2)
            val notification = Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle(title).setContentText(artist)
                .setLargeIcon(cachedArt).setContentIntent(openPi)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOngoing(isPlaying).setStyle(style)
                .addAction(android.R.drawable.ic_media_previous, "上一首", prevPi)
                .addAction(if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                    if (isPlaying) "暂停" else "播放", ppPi)
                .addAction(android.R.drawable.ic_media_next, "下一首", nextPi)
                .build()
            notificationManager.notify(NOTIF_ID, notification)
        } else {
            // API 21-30：NotificationCompat
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle(title).setContentText(artist)
                .setLargeIcon(cachedArt).setContentIntent(openPi)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOngoing(isPlaying).setPriority(NotificationCompat.PRIORITY_HIGH)
                .addAction(android.R.drawable.ic_media_previous, "上一首", prevPi)
                .addAction(if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                    if (isPlaying) "暂停" else "播放", ppPi)
                .addAction(android.R.drawable.ic_media_next, "下一首", nextPi)
                .build()
            notificationManager.notify(NOTIF_ID, notification)
        }
    }

    fun release() {
        mediaSession.isActive = false
        mediaSession.release()
        notificationManager.cancel(NOTIF_ID)
    }
}
