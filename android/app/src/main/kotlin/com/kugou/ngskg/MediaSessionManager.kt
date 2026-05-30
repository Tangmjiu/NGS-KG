package com.kugou.ngskg

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.session.MediaSession
import android.media.session.PlaybackState
import androidx.media.session.MediaSessionCompat
import androidx.core.app.NotificationCompat
import java.net.URL

/**
 * 原生媒体通知 & MediaSession 管理
 *
 * 使用平台 MediaSession API（API 21+），
 * MediaStyle 通知通过 MediaSessionCompat.Token.fromToken() 桥接。
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

    // 使用平台 MediaSession（API 21+），避免 compat 库版本冲突
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
            override fun onStop() {
                mediaSession.isActive = false
                notificationManager.cancel(NOTIF_ID)
            }
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

        // 使用平台 android.media.MediaMetadata
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
    }

    fun updatePlaybackState(isPlaying: Boolean, position: Long) {
        val state = if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED

        // 使用平台 PlaybackState
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

        val openIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_player", true)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val prevIntent = Intent(ACTION_PREV).setPackage(context.packageName)
        val prevPi = PendingIntent.getBroadcast(context, 1, prevIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val ppIntent = Intent(ACTION_PLAY_PAUSE).setPackage(context.packageName)
        val ppPi = PendingIntent.getBroadcast(context, 2, ppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val nextIntent = Intent(ACTION_NEXT).setPackage(context.packageName)
        val nextPi = PendingIntent.getBroadcast(context, 3, nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        // 桥接：平台 MediaSession.Token → MediaSessionCompat.Token
        val compatToken = MediaSessionCompat.Token.fromToken(mediaSession.sessionToken)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(artist)
            .setLargeIcon(cachedArt)
            .setContentIntent(openPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(isPlaying)
            .setShowWhen(false)
            .setStyle(androidx.media.app.NotificationCompat.MediaStyle()
                .setMediaSession(compatToken)
                .setShowActionsInCompactView(0, 1, 2)
                .setShowCancelButton(true))
            .addAction(android.R.drawable.ic_media_previous, "上一首", prevPi)
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "暂停" else "播放",
                ppPi
            )
            .addAction(android.R.drawable.ic_media_next, "下一首", nextPi)
            .build()

        notificationManager.notify(NOTIF_ID, notification)
    }

    fun release() {
        mediaSession.isActive = false
        mediaSession.release()
        notificationManager.cancel(NOTIF_ID)
    }
}
