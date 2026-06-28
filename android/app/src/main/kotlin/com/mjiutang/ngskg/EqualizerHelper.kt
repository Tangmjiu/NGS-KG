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
 * 使用示例（Flutter 侧）：
 * ```dart
 * const platform = MethodChannel('com.mjiutang.ngskg/equalizer');
 * final range = await platform.invokeMethod('getBandLevelRange');
 * final bands = await platform.invokeMethod('getNumberOfBands');
 * ```
 */
class EqualizerHelper(context: Context, audioSessionId: Int) {

    companion object {
        private const val TAG = "EqualizerHelper"
        private const val CHANNEL = "com.mjiutang.ngskg/equalizer"

        /**
         * 在指定 MethodChannel 上注册均衡器方法调用处理。
         *
         * 支持的方法：
         * - getBandLevelRange -> List<Int> [min, max] 毫贝
         * - getNumberOfBands  -> Int 频段数
         * - getCenterFreq     -> Int 中心频率（mHz），参数："band"
         * - setBandLevel      -> Unit，参数："band", "level"
         * - getBandLevel      -> Short 当前增益，参数："band"
         * - release           -> Unit 释放均衡器
         */
        fun registerWith(channel: MethodChannel, context: Context) {
            channel.setMethodCallHandler { call, result ->
                val equalizer = EqualizerHolder.getForContext(context)
                    ?: run {
                        result.error("EQ_NOT_READY", "Equalizer not initialized", null)
                        return@setMethodCallHandler
                    }

                try {
                    when (call.method) {
                        "getBandLevelRange" -> {
                            val range = equalizer.bandLevelRange
                            result.success(listOf(range[0].toInt(), range[1].toInt()))
                        }
                        "getNumberOfBands" -> {
                            result.success(equalizer.numberOfBands)
                        }
                        "getCenterFreq" -> {
                            val band = call.argument<Int>("band")
                            if (band == null) {
                                result.error("INVALID_ARG", "band required", null)
                                return@setMethodCallHandler
                            }
                            result.success(equalizer.getCenterFreq(band.toShort()))
                        }
                        "setBandLevel" -> {
                            val band = call.argument<Int>("band")
                            val level = call.argument<Int>("level")
                            if (band == null || level == null) {
                                result.error("INVALID_ARG", "band and level required", null)
                                return@setMethodCallHandler
                            }
                            equalizer.setBandLevel(band.toShort(), level.toShort())
                            result.success(null)
                        }
                        "getBandLevel" -> {
                            val band = call.argument<Int>("band")
                            if (band == null) {
                                result.error("INVALID_ARG", "band required", null)
                                return@setMethodCallHandler
                            }
                            result.success(equalizer.getBandLevel(band.toShort()).toInt())
                        }
                        "release" -> {
                            equalizer.release()
                            EqualizerHolder.clear()
                            result.success(null)
                        }
                        else -> {
                            result.notImplemented()
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Method '${call.method}' failed", e)
                    result.error("EQ_ERROR", e.message, null)
                }
            }
        }
    }

    /** 实际 Equalizer 实例（priority: 每个音频会话一个实例） */
    private val equalizer: Equalizer

    init {
        equalizer = EqualizerHolder.getOrCreate(audioSessionId)
        Log.i(TAG, "Equalizer initialized for session $audioSessionId, bands=${equalizer.numberOfBands}")
    }

    /** 获取均衡器增益范围（毫贝），返回 [min, max] */
    fun getBandLevelRange(): Pair<Short, Short> {
        val range = equalizer.bandLevelRange
        return Pair(range[0], range[1])
    }

    /** 获取频段数量 */
    fun getNumberOfBands(): Short = equalizer.numberOfBands

    /** 获取指定频段的中心频率（毫赫兹 mHz） */
    fun getCenterFreq(band: Int): Int = equalizer.getCenterFreq(band.toShort())

    /** 设置指定频段的增益（毫贝） */
    fun setBandLevel(band: Int, level: Short) {
        equalizer.setBandLevel(band.toShort(), level)
    }

    /** 获取指定频段的当前增益（毫贝） */
    fun getBandLevel(band: Int): Short = equalizer.getBandLevel(band.toShort())

    /** 释放均衡器资源 */
    fun release() {
        equalizer.release()
        EqualizerHolder.clear()
    }
}

/**
 * 均衡器实例持有者（单例）
 *
 * Android 的 Equalizer 构造需要音频会话 ID，且在同一个音频会话上
 * 重复创建多个实例可能导致音频路由异常。此持有者确保全局只有一个
 * 活跃的 Equalizer 实例，避免竞态。
 */
private object EqualizerHolder {
    private const val TAG = "EqualizerHelper.Holder"
    private var instance: Equalizer? = null
    private var sessionId: Int = -1

    /**
     * 获取或创建均衡器实例。
     * 如果 sessionId 变化，会释放旧实例并创建新的。
     */
    @Synchronized
    fun getOrCreate(audioSessionId: Int): Equalizer {
        val current = instance
        if (current != null && sessionId == audioSessionId) {
            return current
        }
        // session 变化或首次创建：释放旧的
        current?.release()
        val created = Equalizer(0, audioSessionId)
        instance = created
        sessionId = audioSessionId
        Log.i(TAG, "Created Equalizer for session $audioSessionId")
        return created
    }

    /** 获取当前实例（可能为 null） */
    @Synchronized
    fun getForContext(context: Context): Equalizer? {
        if (instance == null) {
            // 如果 registerWith 先于构造调用，使用默认音频会话 0 创建
            val created = Equalizer(0, 0)
            instance = created
            sessionId = 0
            Log.i(TAG, "Lazy-created Equalizer for MethodChannel (session 0)")
        }
        return instance
    }

    /** 释放并清除实例 */
    @Synchronized
    fun clear() {
        instance?.release()
        instance = null
        sessionId = -1
    }
}
