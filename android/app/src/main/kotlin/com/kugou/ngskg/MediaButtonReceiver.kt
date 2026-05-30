package com.kugou.ngskg

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 接收通知栏媒体按钮的广播事件
 *
 * 由 MediaSessionManager 发布的 Notification Action 触发，
 * 转发到 MainActivity 的 MethodChannel 回调处理。
 */
class MediaButtonReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            MediaSessionManager.ACTION_PREV -> {
                MainActivity.lastMediaSessionManager?.onPrev?.invoke()
            }
            MediaSessionManager.ACTION_PLAY_PAUSE -> {
                MainActivity.lastMediaSessionManager?.onPlayPause?.invoke()
            }
            MediaSessionManager.ACTION_NEXT -> {
                MainActivity.lastMediaSessionManager?.onNext?.invoke()
            }
            MediaSessionManager.ACTION_STOP -> {
                MainActivity.lastMediaSessionManager?.apply {
                    onPrev?.invoke()
                    release()
                }
            }
        }
    }
}
