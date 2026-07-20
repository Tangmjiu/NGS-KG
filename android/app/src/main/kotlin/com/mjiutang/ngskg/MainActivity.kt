// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

package com.mjiutang.ngskg

import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : AudioServiceActivity() {
    private val CHANNEL_METADATA = "com.mjiutang.ngskg/metadata"
    private val CHANNEL_DEVICE = "com.mjiutang.ngskg/device"
    private val CHANNEL_EQUALIZER = "com.mjiutang.ngskg/equalizer"
    private val CHANNEL_INTENT = "com.mjiutang.ngskg/intent"

    // EventChannel 用于推送 Intent 文件 URI 到 Flutter
    private var intentEventSink: EventChannel.EventSink? = null

    // 若 Flutter 引擎尚未就绪，暂存冷启动时的 URI
    private var pendingFileUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        // 系统均衡器
        val equalizerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_EQUALIZER
        )
        EqualizerHelper.registerWith(equalizerChannel, this)

        // Intent EventChannel：用于推送音频文件 URI 到 Flutter
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_INTENT
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                intentEventSink = sink
                // Flutter 已就绪，发送冷启动时暂存的 URI
                pendingFileUri?.let { uri ->
                    sink?.success(uri)
                    pendingFileUri = null
                }
            }
            override fun onCancel(arguments: Any?) {
                intentEventSink = null
            }
        })

        // 处理冷启动时的 Intent（应用被文件打开请求直接启动）
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        val uriStr = resolveFileUri(uri)
        if (uriStr.isNullOrEmpty()) return

        if (intentEventSink != null) {
            intentEventSink?.success(uriStr)
        } else {
            // Flutter 引擎还没准备好，暂存
            pendingFileUri = uriStr
        }
    }

    /** 将 content:// URI 解析为可用路径，优先尝试转换为文件路径 */
    private fun resolveFileUri(uri: Uri): String? {
        return when (uri.scheme) {
            "file" -> uri.path
            "content" -> {
                // 尝试通过 ContentResolver 获取真实路径
                try {
                    val cursor = contentResolver.query(uri, arrayOf("_data"), null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val col = it.getColumnIndex("_data")
                            if (col >= 0) return it.getString(col)
                        }
                    }
                } catch (_: Exception) {}
                // 无法解析真实路径时，直接返回 content URI 字符串
                uri.toString()
            }
            else -> uri.toString()
        }
    }

    override fun onDestroy() {
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

