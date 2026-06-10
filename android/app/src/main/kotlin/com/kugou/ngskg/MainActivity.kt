package com.kugou.ngskg

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.media.MediaMetadataRetriever
import android.os.IBinder
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
        var lastService: PlaybackService? = null
    }

    private val CHANNEL_METADATA = "com.kugou.ngskg/metadata"
    private val CHANNEL_MEDIA = "com.kugou.ngskg/media_session"

    private var playbackService: PlaybackService? = null
    private var callbackChannel: BasicMessageChannel<String>? = null
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            playbackService = (service as PlaybackService.LocalBinder).getService()
            lastService = playbackService
            // 重新连接后恢复回调
            playbackService?.onPrev = { callbackChannel?.send("onPrev") }
            playbackService?.onPlayPause = { callbackChannel?.send("onPlayPause") }
            playbackService?.onNext = { callbackChannel?.send("onNext") }
            playbackService?.onSeekTo = { posMs ->
                callbackChannel?.send("onSeekTo|$posMs")
            }
            playbackService?.onLike = { callbackChannel?.send("onLike") }
            playbackService?.onSwitchMode = { callbackChannel?.send("onSwitchMode") }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            playbackService = null
            lastService = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 启动前台媒体服务
        val serviceIntent = Intent(this, PlaybackService::class.java)
        startForegroundService(serviceIntent)
        bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)

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
            val svc = playbackService
            if (svc == null) {
                result.error("SERVICE_NOT_READY", "PlaybackService not bound", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "updateMetadata" -> {
                    val title = call.argument<String>("title") ?: "未知歌曲"
                    val artist = call.argument<String>("artist") ?: "未知歌手"
                    val albumArtUrl = call.argument<String>("albumArtUrl")
                    val durationSec = call.argument<Long>("duration") ?: 0L
                    val lyricLine = call.argument<String>("lyricLine")
                    svc.updateMetadata(title, artist, albumArtUrl, durationSec, lyricLine)
                    result.success(null)
                }
                "updatePlaybackState" -> {
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val positionSec = call.argument<Long>("position") ?: 0L
                    val isBuffering = call.argument<Boolean>("isBuffering") ?: false
                    svc.updatePlaybackState(isPlaying, positionSec, isBuffering)
                    result.success(null)
                }
                "updateCustomButtons" -> {
                    val liked = call.argument<Boolean>("liked") ?: false
                    val mode = call.argument<String>("playMode") ?: "sequential"
                    svc.updateCustomButtons(liked, mode)
                    result.success(null)
                }
                "release" -> {
                    svc.exitService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 设置回调通道（Native → Flutter）
        callbackChannel = BasicMessageChannel<String>(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.kugou.ngskg/media_callbacks",
            StringCodec.INSTANCE
        ).also { channel ->
            // 回调由 PlaybackService 的 binder lambdas 触发
        }
    }

    override fun onDestroy() {
        try {
            unbindService(serviceConnection)
        } catch (_: Exception) {}
        lastService = null
        super.onDestroy()
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
