package com.kugou.ngskg

import android.media.MediaMetadataRetriever
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.CompletableFuture

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kugou.ngskg/metadata"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
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
