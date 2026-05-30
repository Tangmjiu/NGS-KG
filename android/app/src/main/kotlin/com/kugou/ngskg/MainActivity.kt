package com.kugou.ngskg

import android.content.IntentFilter
import android.media.MediaMetadataRetriever
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StringCodec
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    companion object {
        // 供 MediaButtonReceiver 访问
        var lastMediaSessionManager: MediaSessionManager? = null
    }

    private val CHANNEL_METADATA = "com.kugou.ngskg/metadata"
    private val CHANNEL_MEDIA = "com.kugou.ngskg/media_session"

    private lateinit var mediaSessionManager: MediaSessionManager
    private val mediaButtonReceiver = MediaButtonReceiver()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化 MediaSessionManager
        mediaSessionManager = MediaSessionManager(this)
        lastMediaSessionManager = mediaSessionManager

        // 注册广播接收器（通知栏按钮）
        registerReceiver(mediaButtonReceiver, IntentFilter().apply {
            addAction(MediaSessionManager.ACTION_PREV)
            addAction(MediaSessionManager.ACTION_PLAY_PAUSE)
            addAction(MediaSessionManager.ACTION_NEXT)
            addAction(MediaSessionManager.ACTION_STOP)
        }, RECEIVER_EXPORTED)

        // 读取本地音乐元数据
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_METADATA
        ).setMethodCallHandler { call, result ->
            if (call.method == "readMetadata") {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARG", "path required", null)
                    return@setMethodCallHandler
                }
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val meta = readMetadata(path)
                        result.success(meta)
                    } catch (e: Exception) {
                        result.error("READ_FAILED", e.message, null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }

        // 媒体播放控制（来自 Flutter 的元数据和状态更新）
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_MEDIA
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateMetadata" -> {
                    val title = call.argument<String>("title") ?: "未知歌曲"
                    val artist = call.argument<String>("artist") ?: "未知歌手"
                    val albumArtUrl = call.argument<String>("albumArtUrl")
                    val duration = (call.argument<Long>("duration") ?: 0L) * 1000L // 秒→毫秒
                    val lyricLine = call.argument<String>("lyricLine")
                    mediaSessionManager.updateMetadata(title, artist, albumArtUrl, duration, lyricLine)
                    result.success(null)
                }
                "updatePlaybackState" -> {
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val position = (call.argument<Long>("position") ?: 0L) * 1000L // 秒→毫秒
                    mediaSessionManager.updatePlaybackState(isPlaying, position)
                    result.success(null)
                }
                "setCallbacks" -> {
                    val dispatcher = flutterEngine.dartExecutor.binaryMessenger
                    val callbackChannel = BasicMessageChannel<String>(
                        dispatcher, "com.kugou.ngskg/media_callbacks", StringCodec.INSTANCE
                    )
                    mediaSessionManager.onPrev = {
                        callbackChannel.send("onPrev")
                    }
                    mediaSessionManager.onPlayPause = {
                        callbackChannel.send("onPlayPause")
                    }
                    mediaSessionManager.onNext = {
                        callbackChannel.send("onNext")
                    }
                    result.success(null)
                }
                "release" -> {
                    mediaSessionManager.release()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(mediaButtonReceiver)
        } catch (_: Exception) {}
        mediaSessionManager.release()
        lastMediaSessionManager = null
    }

    private fun readMetadata(path: String): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)

            val title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
            val artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
            val album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val bitrateStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
            val embeddedPicture = retriever.embeddedPicture

            val duration = durationStr?.toIntOrNull() ?: 0
            val bitrate = bitrateStr?.toIntOrNull()

            return mapOf(
                "title" to (title?.takeIf { it.isNotEmpty() }),
                "artist" to (artist?.takeIf { it.isNotEmpty() }),
                "album" to (album?.takeIf { it.isNotEmpty() }),
                "duration" to duration,
                "bitrate" to bitrate,
                "albumArt" to (embeddedPicture?.toList())
            )
        } finally {
            retriever.release()
        }
    }
}
