// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

package com.mjiutang.ngskg

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.IBinder
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StringCodec
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    // ─── Wear OS rotary input forwarding ───
    override fun onGenericMotionEvent(event: MotionEvent?): Boolean {
        return when {
            event != null && com.samsung.wearable_rotary.WearableRotaryPlugin.onGenericMotionEvent(event) -> true
            else -> super.onGenericMotionEvent(event)
        }
    }
    companion object {
        // 供 MediaButtonReceiver 访问
        var lastService: PlaybackService? = null
    }

    private val CHANNEL_METADATA = "com.mjiutang.ngskg/metadata"
    private val CHANNEL_MEDIA = "com.mjiutang.ngskg/media_session"
    private val CHANNEL_DEVICE = "com.mjiutang.ngskg/device"
    private val CHANNEL_AUDIO_ROUTE = "com.mjiutang.ngskg/audio_route"
    private val CHANNEL_AUDIO_ROUTE_EVENTS = "com.mjiutang.ngskg/audio_route_events"
    private val CHANNEL_LOG_EXPORT = "com.mjiutang.ngskg/log_export"

    private var playbackService: PlaybackService? = null
    private var callbackChannel: BasicMessageChannel<String>? = null
    private var audioRouteManager: AudioRouteManager? = null
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
                    val durationSec = (call.argument<Number>("duration")?.toLong() ?: 0L)
                    val lyricLine = call.argument<String>("lyricLine")
                    svc.updateMetadata(title, artist, albumArtUrl, durationSec, lyricLine)
                    result.success(null)
                }
                "updatePlaybackState" -> {
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val positionSec = (call.argument<Number>("position")?.toLong() ?: 0L)
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

        // 设备信息通道（ABI 等）
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_DEVICE
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAbi" -> {
                    val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
                    result.success(abi)
                }
                else -> result.notImplemented()
            }
        }

        // 音频输出路由（设备枚举 / 切换 / 系统面板）
        val routeManager = AudioRouteManager(this).also { audioRouteManager = it }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_AUDIO_ROUTE
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAudioOutputs" -> result.success(routeManager.getAudioOutputs())
                "setAudioOutput" -> {
                    val deviceId = (call.argument<Number>("deviceId"))?.toInt() ?: -1
                    result.success(routeManager.setAudioOutput(deviceId))
                }
                "showSystemOutputSwitcher" -> {
                    routeManager.showSystemOutputSwitcher()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_AUDIO_ROUTE_EVENTS
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                routeManager.eventSink = events
                routeManager.start()
            }
            override fun onCancel(arguments: Any?) {
                routeManager.eventSink = null
                routeManager.stop()
            }
        })

        // 设置回调通道（Native → Flutter）
        callbackChannel = BasicMessageChannel<String>(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.mjiutang.ngskg/media_callbacks",
            StringCodec.INSTANCE
        ).also { channel ->
            // 回调由 PlaybackService 的 binder lambdas 触发
        }

        // 日志导出通道：dumpLogcat（尽力读取本进程 logcat）、getDeviceInfo
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_LOG_EXPORT
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "dumpLogcat" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        result.success(dumpLogcat())
                    }
                }
                "getDeviceInfo" -> result.success(getDeviceInfoMap())
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            unbindService(serviceConnection)
        } catch (_: Exception) {}
        audioRouteManager?.stop()
        audioRouteManager = null
        lastService = null
        super.onDestroy()
    }

    /// 尽力读取本进程的 logcat 日志。
    /// Android 4.1+ 普通应用无 READ_LOGS 权限，`logcat` 命令通常只能读取自身进程日志
    /// 或被拒绝；失败时返回说明字符串，而非抛异常，便于导出文件中留下痕迹。
    private fun dumpLogcat(): String {
        return try {
            val pid = android.os.Process.myPid().toString()
            val process = Runtime.getRuntime().exec(
                arrayOf("logcat", "-d", "-v", "threadtime", "--pid=$pid")
            )
            val output = process.inputStream.bufferedReader().use { it.readText() }
            process.waitFor()
            if (output.isBlank()) {
                "(logcat 返回为空：可能受系统限制无法读取，已附 Flutter 日志与错误记录)"
            } else {
                output
            }
        } catch (e: Exception) {
            "(logcat 读取失败: ${e.message}；已附 Flutter 日志与错误记录)"
        }
    }

    /// 设备信息映射（用于日志导出头）
    private fun getDeviceInfoMap(): Map<String, Any?> {
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "brand" to Build.BRAND,
            "product" to Build.PRODUCT,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "hardware" to Build.HARDWARE,
            "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"),
            "package" to packageName
        )
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
