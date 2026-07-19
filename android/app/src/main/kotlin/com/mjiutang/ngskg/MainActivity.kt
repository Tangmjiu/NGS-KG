// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

package com.mjiutang.ngskg

import android.media.MediaMetadataRetriever
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : AudioServiceActivity() {
    private val CHANNEL_METADATA = "com.mjiutang.ngskg/metadata"
    private val CHANNEL_DEVICE = "com.mjiutang.ngskg/device"
    private val CHANNEL_EQUALIZER = "com.mjiutang.ngskg/equalizer"

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
