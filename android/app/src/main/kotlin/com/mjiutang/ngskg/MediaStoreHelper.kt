// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

package com.mjiutang.ngskg

import android.content.ContentValues
import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/**
 * 公共 Download 目录存取助手。
 *
 * - Android 10+ (API 29+)：通过 MediaStore.Downloads 写入
 *   `Download/NGS-KG+MusicDownload/`，用户文件管理器可见，无需存储权限。
 * - Android 9 及以下：降级写入应用外部目录
 *   `Android/data/<pkg>/files/Download/NGS-KG+MusicDownload/`。
 */
object MediaStoreHelper {

    /** 公共下载子目录名（用户可见） */
    const val SUB_DIR = "NGS-KG+MusicDownload"

    /** MediaStore 相对路径（API 29+） */
    private const val RELATIVE_PATH =
        Environment.DIRECTORY_DOWNLOADS + "/" + SUB_DIR + "/"

    fun registerWith(channel: MethodChannel, context: Context) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToPublicDownload" -> {
                    val srcPath = call.argument<String>("srcPath")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType")
                    if (srcPath == null || fileName == null) {
                        result.error("INVALID_ARG", "srcPath/fileName required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = saveToPublicDownload(context, srcPath, fileName, mimeType)
                        result.success(uri)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }
                "deletePublicFile" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr == null) {
                        result.error("INVALID_ARG", "uri required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(deletePublicFile(context, uriStr))
                    } catch (e: Exception) {
                        result.error("DELETE_FAILED", e.message, null)
                    }
                }
                "deletePublicFilesByPrefix" -> {
                    val prefix = call.argument<String>("prefix")
                    if (prefix == null) {
                        result.error("INVALID_ARG", "prefix required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(deletePublicFilesByPrefix(context, prefix))
                    } catch (e: Exception) {
                        result.error("DELETE_FAILED", e.message, null)
                    }
                }
                "readMetadataFromUri" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr == null) {
                        result.error("INVALID_ARG", "uri required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(readMetadataFromUri(context, uriStr))
                    } catch (e: Exception) {
                        result.error("READ_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 将 [srcPath] 文件写入公共 Download 子目录，返回可访问的 URI 字符串。
     * API 29+ 返回 content:// URI；低版本返回文件绝对路径。
     */
    @Throws(Exception::class)
    fun saveToPublicDownload(
        context: Context,
        srcPath: String,
        fileName: String,
        mimeType: String?
    ): String {
        val srcFile = File(srcPath)
        if (!srcFile.exists()) throw Exception("source file not found: $srcPath")
        // 校验文件名，防止路径穿越（通道为公共入口点）
        if (fileName.isEmpty() ||
            fileName.contains('/') ||
            fileName.contains('\\') ||
            fileName.contains('\u0000') ||
            fileName == "." ||
            fileName == ".."
        ) {
            throw Exception("invalid fileName: $fileName")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType ?: "audio/mpeg")
                put(MediaStore.Downloads.RELATIVE_PATH, RELATIVE_PATH)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = context.contentResolver
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = resolver.insert(collection, values)
                ?: throw Exception("MediaStore insert failed")

            try {
                resolver.openOutputStream(uri)?.use { out ->
                    FileInputStream(srcFile).use { input ->
                        input.copyTo(out, bufferSize = 64 * 1024)
                    }
                } ?: throw Exception("openOutputStream failed")
                // 写入完成，标记可见
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return uri.toString()
            } catch (e: Exception) {
                // 失败清理条目
                runCatching { resolver.delete(uri, null, null) }
                throw e
            }
        } else {
            // Android 9 及以下：应用外部目录（无公共写权限时仍可用）
            val dir = File(
                context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
                SUB_DIR
            )
            if (!dir.exists()) dir.mkdirs()
            val dest = File(dir, fileName)
            srcFile.copyTo(dest, overwrite = true)
            return dest.absolutePath
        }
    }

    /** 删除公共目录文件（content URI 或文件路径均可） */
    @Throws(Exception::class)
    fun deletePublicFile(context: Context, uriStr: String): Boolean {
        if (uriStr.startsWith("content://")) {
            val uri = Uri.parse(uriStr)
            return context.contentResolver.delete(uri, null, null) > 0
        }
        val f = File(uriStr)
        return f.exists() && f.delete()
    }

    /** 按文件名前缀删除公共目录文件，返回删除数量。
     *  仅限本应用子目录（RELATIVE_PATH 过滤），前缀 LIKE 转义防止误删。 */
    @Throws(Exception::class)
    fun deletePublicFilesByPrefix(context: Context, prefix: String): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // LIKE 转义 % _ \ 通配符；追加 '.' 防止同名前缀歌曲的 sidecar 过删
            val escaped = prefix
                .replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_")
            val collection =
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            return context.contentResolver.delete(
                collection,
                "${MediaStore.Downloads.RELATIVE_PATH} = ? AND " +
                    "${MediaStore.Downloads.DISPLAY_NAME} LIKE ? ESCAPE '\\'",
                arrayOf(RELATIVE_PATH, "$escaped.%")
            )
        }
        // Android 9 及以下：应用外部目录
        val dir = File(
            context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
            SUB_DIR
        )
        if (!dir.exists()) return 0
        var count = 0
        dir.listFiles()?.forEach { f ->
            if (f.name.startsWith(prefix)) {
                if (f.delete()) count++
            }
        }
        return count
    }

    /** 读取歌曲元数据（content URI 或文件路径均可） */
    @Throws(Exception::class)
    fun readMetadataFromUri(context: Context, uriStr: String): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        try {
            if (uriStr.startsWith("content://")) {
                retriever.setDataSource(context, Uri.parse(uriStr))
            } else {
                retriever.setDataSource(uriStr)
            }
            val title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
            val artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
            val album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val bitrateStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
            val embeddedPicture = retriever.embeddedPicture

            // content URI 额外查询文件大小与显示名（MediaStore 列）
            var size: Long? = null
            var displayName: String? = null
            if (uriStr.startsWith("content://")) {
                try {
                    val cursor = context.contentResolver.query(
                        Uri.parse(uriStr),
                        arrayOf(
                            MediaStore.Downloads.SIZE,
                            MediaStore.Downloads.DISPLAY_NAME
                        ),
                        null, null, null
                    )
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val sizeCol = it.getColumnIndex(MediaStore.Downloads.SIZE)
                            if (sizeCol >= 0) size = it.getLong(sizeCol)
                            val nameCol = it.getColumnIndex(MediaStore.Downloads.DISPLAY_NAME)
                            if (nameCol >= 0) displayName = it.getString(nameCol)
                        }
                    }
                } catch (_: Exception) {}
            }

            return mapOf(
                "title" to (title?.takeIf { it.isNotEmpty() }),
                "artist" to (artist?.takeIf { it.isNotEmpty() }),
                "album" to (album?.takeIf { it.isNotEmpty() }),
                "duration" to (durationStr?.toIntOrNull() ?: 0),
                "bitrate" to bitrateStr?.toIntOrNull(),
                "albumArt" to (embeddedPicture?.toList()),
                "size" to size,
                "displayName" to displayName
            )
        } finally {
            retriever.release()
        }
    }
}
