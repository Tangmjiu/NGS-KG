// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

package com.mjiutang.ngskg

import android.app.ActivityManager
import android.content.ComponentCallbacks2
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class MainActivity : AudioServiceActivity() {
    private val CHANNEL_METADATA = "com.mjiutang.ngskg/metadata"
    private val CHANNEL_DEVICE = "com.mjiutang.ngskg/device"
    private val CHANNEL_EQUALIZER = "com.mjiutang.ngskg/equalizer"
    private val CHANNEL_INTENT = "com.mjiutang.ngskg/intent"
    private val CHANNEL_DEVTOOLS = "com.mjiutang.ngskg/devtools"
    private val CHANNEL_MEDIASTORE = "com.mjiutang.ngskg/mediastore"

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

        // 公共 Download 目录存取（MediaStore）
        MediaStoreHelper.registerWith(
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL_MEDIASTORE
            ),
            this
        )

        // 开发者工具通道（仅 Debug 构建注册，与 Flutter 侧入口隐藏保持一致；
        // 用 FLAG_DEBUGGABLE 判定，避免依赖 BuildConfig 开关）
        // 新增功能：系统交互与触发 + 设备信息查询
        val isDebuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (isDebuggable) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL_DEVTOOLS
            ).setMethodCallHandler { call, result ->
                when (call.method) {
                "openDevSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_FAILED", e.message, null)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_FAILED", e.message, null)
                    }
                }
                "getStorageInfo" -> {
                    try {
                        val stat = StatFs(Environment.getDataDirectory().path)
                        result.success(mapOf(
                            "total" to stat.totalBytes,
                            "available" to stat.availableBytes
                        ))
                    } catch (e: Exception) {
                        result.error("STAT_FAILED", e.message, null)
                    }
                }
                "getMemoryInfo" -> {
                    try {
                        val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
                        val info = ActivityManager.MemoryInfo()
                        am.getMemoryInfo(info)
                        result.success(mapOf(
                            "totalMem" to info.totalMem,
                            "availMem" to info.availMem,
                            "lowMemory" to info.lowMemory
                        ))
                    } catch (e: Exception) {
                        result.error("MEM_FAILED", e.message, null)
                    }
                }
                "isRooted" -> CoroutineScope(Dispatchers.IO).launch {
                    result.success(isDeviceRooted())
                }
                "triggerLowMemory" -> {
                    // 模拟低内存警告：向本 Activity 派发 TRIM_MEMORY_RUNNING_LOW
                    onTrimMemory(ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW)
                    result.success(true)
                }
                else -> result.notImplemented()
                }
            }
        }

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

    /** Root 检测：常见 su 路径 + which su 命令 */
    private fun isDeviceRooted(): Boolean {
        val suPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )
        for (path in suPaths) {
            if (File(path).exists()) return true
        }
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val line = BufferedReader(InputStreamReader(process.inputStream)).readLine()
            !line.isNullOrEmpty()
        } catch (_: Exception) {
            false
        }
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

