// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

package com.mjiutang.ngskg

import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.LayoutElementBuilders.Layout
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService as WearTileService
import com.google.common.util.concurrent.ListenableFuture
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.guava.future

/**
 * Wear OS 系统磁贴（Tile）。
 *
 * 在 Wear OS 磁贴列表中显示当前播放歌曲名和播放状态，
 * 点击磁贴直接打开应用。
 *
 * 数据来自 PlaybackService 缓存的当前元数据；
 * 无播放时显示「打开 NGS-KG+ Watch」。
 */
class PlaybackTileService : WearTileService() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onTileRequest(
        requestParams: RequestBuilders.TileRequest
    ): ListenableFuture<TileBuilders.Tile> = scope.future {
        TileBuilders.Tile.Builder()
            .setResourcesVersion("1")
            .setTileTimeline(
                TimelineBuilders.Timeline.Builder()
                    .addTimelineEntry(
                        TimelineBuilders.TimelineEntry.Builder()
                            .setLayout(buildTileContent())
                            .build()
                    )
                    .build()
            )
            .build()
    }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest
    ): ListenableFuture<ResourceBuilders.Resources> = scope.future {
        ResourceBuilders.Resources.Builder()
            .setVersion("1")
            .build()
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun buildTileContent(): Layout {
        val svc = MainActivity.lastService
        val title = svc?.tileTitle ?: "NGS-KG+ Watch"
        val subtitle = if (svc != null && svc.tileIsPlaying) {
            svc.tileArtist.ifEmpty { "正在播放" }
        } else {
            "点击开始聆听"
        }

        val root = LayoutElementBuilders.Column.Builder()
            .addContent(
                LayoutElementBuilders.Text.Builder()
                    .setText(title)
                    .setMaxLines(1)
                    .build()
            )
            .addContent(
                LayoutElementBuilders.Text.Builder()
                    .setText(subtitle)
                    .setMaxLines(1)
                    .build()
            )
            .build()

        return Layout.Builder()
            .setRoot(root)
            .build()
    }
}
