// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

package com.mjiutang.ngskg

import android.content.Context
import android.media.audiofx.Equalizer
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * 系统均衡器（Equalizer）封装
 *
 * 包装 android.media.audiofx.Equalizer，通过 MethodChannel 向 Flutter 暴露
 * 频段增益查询与设置能力。
 *
 * 均衡器必须挂在播放器自己的音频会话上（just_audio 的 androidAudioSessionId），
 * 由 Flutter 侧通过 attachSession 传入；全局会话 0 已被弃用，多数设备上无效。
 *
 * 使用示例（Flutter 侧）：
 * ```dart
 * const platform = MethodChannel('com.mjiutang.ngskg/equalizer');
 * await platform.invokeMethod('attachSession', {'sessionId': id});
 * final range = await platform.invokeMethod('getBandLevelRange');
 * ```
 */
object EqualizerHelper {
    private const val TAG = "EqualizerHelper"

    /**
     * 在指定 MethodChannel 上注册均衡器方法调用处理。
     *
     * 支持的方法：
     * - attachSession     -> Bool 绑定播放器音频会话，参数："sessionId"
     * - getBandLevelRange -> List<Int> [min, max] 毫贝
     * - getNumberOfBands  -> Int 频段数
     * - getCenterFreq     -> Int 中心频率（mHz），参数："band"
     * - setBandLevel      -> Unit，参数："band", "level"
     * - getBandLevel      -> Int 当前增益，参数："band"
     * - release           -> Unit 释放均衡器
     */
    fun registerWith(channel: MethodChannel, @Suppress("UNUSED_PARAMETER") context: Context) {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "attachSession" -> {
                        val id = call.argument<Int>("sessionId")
                        if (id == null || id <= 0) {
                            result.error("INVALID_ARG", "valid sessionId required", null)
                        } else {
                            result.success(EqualizerHolder.attach(id) != null)
                        }
                    }
                    "release" -> {
                        EqualizerHolder.clear()
                        result.success(null)
                    }
                    else -> {
                        val equalizer = EqualizerHolder.current()
                        if (equalizer == null) {
                            result.error("EQ_NOT_READY", "Equalizer not attached to a session", null)
                            return@setMethodCallHandler
                        }
                        handle(call.method, call, equalizer, result)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Method '${call.method}' failed", e)
                result.error("EQ_ERROR", e.message, null)
            }
        }
    }

    private fun handle(
        method: String,
        call: io.flutter.plugin.common.MethodCall,
        equalizer: Equalizer,
        result: MethodChannel.Result,
    ) {
        when (method) {
            "getBandLevelRange" -> {
                val range = equalizer.bandLevelRange
                result.success(listOf(range[0].toInt(), range[1].toInt()))
            }
            "getNumberOfBands" -> result.success(equalizer.numberOfBands.toInt())
            "getCenterFreq" -> {
                val band = call.argument<Int>("band")
                    ?: return result.error("INVALID_ARG", "band required", null)
                result.success(equalizer.getCenterFreq(band.toShort()))
            }
            "setBandLevel" -> {
                val band = call.argument<Int>("band")
                val level = call.argument<Int>("level")
                if (band == null || level == null) {
                    return result.error("INVALID_ARG", "band and level required", null)
                }
                EqualizerHolder.setBandLevel(band.toShort(), level.toShort())
                result.success(null)
            }
            "getBandLevel" -> {
                val band = call.argument<Int>("band")
                    ?: return result.error("INVALID_ARG", "band required", null)
                result.success(equalizer.getBandLevel(band.toShort()).toInt())
            }
            else -> result.notImplemented()
        }
    }
}

/**
 * 均衡器实例持有者（单例）
 *
 * 同一音频会话上重复创建多个 Equalizer 可能导致音频路由异常，
 * 因此全局只保留一个实例。会话变化（播放器重建）时释放旧实例并
 * 把用户设置过的增益恢复到新实例上。
 */
private object EqualizerHolder {
    private const val TAG = "EqualizerHelper.Holder"
    private var instance: Equalizer? = null
    private var sessionId: Int = -1

    /** 用户设置过的频段增益，会话切换时恢复 */
    private val savedLevels = mutableMapOf<Short, Short>()

    @Synchronized
    fun attach(audioSessionId: Int): Equalizer? {
        val existing = instance
        if (existing != null && sessionId == audioSessionId) return existing
        existing?.release()
        instance = null
        return try {
            val created = Equalizer(0, audioSessionId)
            for ((band, level) in savedLevels) {
                created.setBandLevel(band, level)
            }
            // 新建的 Equalizer 默认是禁用状态，不启用则调节没有任何效果
            created.enabled = true
            instance = created
            sessionId = audioSessionId
            Log.i(TAG, "Equalizer attached to session $audioSessionId, bands=${created.numberOfBands}")
            created
        } catch (e: Exception) {
            Log.e(TAG, "Equalizer unsupported for session $audioSessionId", e)
            sessionId = -1
            null
        }
    }

    @Synchronized
    fun current(): Equalizer? = instance

    @Synchronized
    fun setBandLevel(band: Short, level: Short) {
        savedLevels[band] = level
        instance?.setBandLevel(band, level)
    }

    @Synchronized
    fun clear() {
        instance?.release()
        instance = null
        sessionId = -1
    }
}
