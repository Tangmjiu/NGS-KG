// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

package com.mjiutang.ngskg

import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.dp
import androidx.wear.protolayout.DimensionBuilders.expand
import androidx.wear.protolayout.DimensionBuilders.sp
import androidx.wear.protolayout.LayoutElementBuilders as Elements
import androidx.wear.protolayout.ModifiersBuilders as Modifiers
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/** 系统磁贴只读取已绑定服务的曲目信息，点按按钮后打开应用。 */
class PlaybackTileService : TileService() {
    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val service = MainActivity.lastService
        val screenWidth = requestParams.deviceConfiguration?.screenWidthDp?.takeIf { it > 0 } ?: 192
        val content = Elements.Column.Builder()
            .setWidth(dp(screenWidth * 0.76f))
            .setHorizontalAlignment(Elements.HORIZONTAL_ALIGN_CENTER)
            .addContent(text(service?.tileTitle?.takeIf { it.isNotBlank() } ?: "NGS-KG+ Watch", 18f, 0xFFFFFFFF.toInt()))
        service?.tileArtist?.takeIf { it.isNotBlank() }?.let {
            content.addContent(text(it, 14f, 0xFFBFC8D4.toInt()))
        }
        content.addContent(Elements.Spacer.Builder().setHeight(dp(8f)).build())
            .addContent(openAppButton())
        val root = Elements.Box.Builder()
            .setWidth(expand())
            .setHeight(expand())
            .setHorizontalAlignment(Elements.HORIZONTAL_ALIGN_CENTER)
            .setVerticalAlignment(Elements.VERTICAL_ALIGN_CENTER)
            .addContent(content.build())
            .build()
        val timeline = TimelineBuilders.Timeline.Builder()
            .addTimelineEntry(TimelineBuilders.TimelineEntry.Builder()
                .setLayout(Elements.Layout.Builder().setRoot(root).build()).build())
            .build()
        return Futures.immediateFuture(TileBuilders.Tile.Builder().setResourcesVersion("1").setTileTimeline(timeline).build())
    }

    override fun onTileResourcesRequest(requestParams: RequestBuilders.ResourcesRequest): ListenableFuture<ResourceBuilders.Resources> =
        Futures.immediateFuture(ResourceBuilders.Resources.Builder().setVersion("1").build())

    private fun text(value: String, size: Float, color: Int) = Elements.Text.Builder()
        .setText(value)
        .setFontStyle(Elements.FontStyle.Builder().setSize(sp(size)).setColor(argb(color)).build())
        .setMaxLines(1)
        .setOverflow(Elements.TEXT_OVERFLOW_ELLIPSIZE_END)
        .setMultilineAlignment(Elements.TEXT_ALIGN_CENTER)
        .build()

    private fun openAppButton(): Elements.Box {
        val label = "打开应用"
        val activity = ActionBuilders.AndroidActivity.Builder()
            .setPackageName(packageName)
            .setClassName(MainActivity::class.java.name)
            .build()
        val clickable = Modifiers.Clickable.Builder()
            .setId("open_app")
            .setOnClick(ActionBuilders.LaunchAction.Builder().setAndroidActivity(activity).build())
            .build()
        val background = Modifiers.Background.Builder()
            .setColor(argb(0xFFB3D2FF.toInt()))
            .setCorner(Modifiers.Corner.Builder().setRadius(dp(24f)).build())
            .build()
        return Elements.Box.Builder()
            .setWidth(dp(104f))
            .setHeight(dp(48f))
            .setModifiers(Modifiers.Modifiers.Builder()
                .setClickable(clickable)
                .setBackground(background)
                .setSemantics(Modifiers.Semantics.Builder().setContentDescription(label)
                    .setRole(Modifiers.SEMANTICS_ROLE_BUTTON).build())
                .build())
            .addContent(text(label, 15f, 0xFF14283F.toInt()))
            .build()
    }
}
