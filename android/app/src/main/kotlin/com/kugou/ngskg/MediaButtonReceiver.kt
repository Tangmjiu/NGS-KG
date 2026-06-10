package com.kugou.ngskg

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 接收通知栏 + 蓝牙/耳机媒体按钮的广播事件
 *
 * 在 AndroidManifest.xml 中静态注册（不依赖 Activity 生命周期），
 * 确保 App 被杀死后仍能接收蓝牙媒体按键。
 */
class MediaButtonReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val svc = MainActivity.lastService ?: return

        when (intent.action) {
            PlaybackService.ACTION_PREV -> {
                svc.onPrev?.invoke()
            }
            PlaybackService.ACTION_PLAY_PAUSE -> {
                // 检查是否为收藏命令（通过 extra 区分）
                if (intent.hasExtra("command") && intent.getStringExtra("command") == "like") {
                    svc.onLike?.invoke()
                } else {
                    svc.onPlayPause?.invoke()
                }
            }
            PlaybackService.ACTION_NEXT -> {
                svc.onNext?.invoke()
            }
            PlaybackService.ACTION_STOP -> {
                svc.exitService()
            }
            android.media.session.MediaSession.ACTION_MEDIA_BUTTON -> {
                // 处理蓝牙/耳机实体按键
                val keyEvent = intent.getParcelableExtra<android.view.KeyEvent>(
                    Intent.EXTRA_KEY_EVENT
                )
                if (keyEvent?.action == android.view.KeyEvent.ACTION_DOWN) {
                    when (keyEvent.keyCode) {
                        android.view.KeyEvent.KEYCODE_MEDIA_PLAY -> svc.onPlayPause?.invoke()
                        android.view.KeyEvent.KEYCODE_MEDIA_PAUSE -> svc.onPlayPause?.invoke()
                        android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> svc.onPlayPause?.invoke()
                        android.view.KeyEvent.KEYCODE_MEDIA_NEXT -> svc.onNext?.invoke()
                        android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS -> svc.onPrev?.invoke()
                        android.view.KeyEvent.KEYCODE_MEDIA_STOP -> svc.exitService()
                    }
                }
            }
        }
    }
}
