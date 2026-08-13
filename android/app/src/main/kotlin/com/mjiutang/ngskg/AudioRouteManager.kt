// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

package com.mjiutang.ngskg

import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 音频输出路由管理（Wear OS）。
 *
 * - 枚举可用媒体输出设备（手表喇叭 / 已连接 A2DP 蓝牙 / 有线）
 * - 监听 A2DP 连接状态与设备插拔，向 Flutter 推送变化事件
 * - Android 11+ 支持通过 [AudioManager.setPreferredDevice] 切换输出；
 *   更低版本回退为打开系统媒体输出面板
 * - 读取已连接蓝牙设备电量（API 可用时）
 */
class AudioRouteManager(private val context: Context) {

    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val bluetoothAdapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)
            ?.adapter

    private var a2dpProxy: BluetoothA2dp? = null
    private val batteryByAddress = mutableMapOf<String, Int>()

    var eventSink: EventChannel.EventSink? = null

    // ─── 设备枚举 ───

    fun getAudioOutputs(): List<Map<String, Any?>> {
        val active = activeOutputDevice()
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return devices
            .filter { isMediaOutput(it) }
            .map { d ->
                val type = typeLabel(d.type)
                val battery = if (type == "bluetooth") batteryFor(d) else null
                mapOf(
                    "id" to d.id,
                    "name" to deviceName(d),
                    "type" to type,
                    "isActive" to (active != null && active.id == d.id),
                    "batteryLevel" to battery,
                )
            }
    }

    /** 当前媒体输出设备（播放中路由；未播放时按系统默认）。 */
    private fun activeOutputDevice(): AudioDeviceInfo? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // 返回 null 表示由系统自动路由
            return audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                .firstOrNull { it.isSink && isMediaOutput(it) && it.type == preferredType() }
        }
        return null
    }

    private fun preferredType(): Int {
        // 粗略推断当前路由：A2DP 连接中 → 蓝牙；否则扬声器
        val a2dpConnected = bluetoothAdapter
            ?.getProfileConnectionState(BluetoothProfile.A2DP) ==
            BluetoothProfile.STATE_CONNECTED
        return if (a2dpConnected) AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
        else AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
    }

    private fun isMediaOutput(d: AudioDeviceInfo): Boolean {
        if (!d.isSink) return false
        return when (d.type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER -> true
            else -> false
        }
    }

    private fun typeLabel(type: Int): String = when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLE_HEADSET,
        AudioDeviceInfo.TYPE_BLE_SPEAKER -> "bluetooth"
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wired"
        else -> "other"
    }

    private fun deviceName(d: AudioDeviceInfo): String {
        if (d.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) return "手表扬声器"
        val product = d.productName?.toString()?.trim()
        return if (!product.isNullOrEmpty()) product else "蓝牙设备"
    }

    private fun batteryFor(d: AudioDeviceInfo): Int? {
        val addr = d.address ?: return null
        return batteryByAddress[addr]
    }

    // ─── 输出切换 ───

    /**
     * 请求切换媒体输出。返回 true 表示系统已接受。
     *
     * Android 11+（Wear 4+）无公开的 preferredDevice API 给普通应用，
     * 因此这里通过打开系统媒体输出面板引导用户完成切换，
     * 返回值表示「系统已弹出选择器」。
     */
    fun setAudioOutput(@Suppress("UNUSED_PARAMETER") deviceId: Int): Boolean {
        // 程序化切换需要系统签名权限，普通应用不可用。
        // 统一回退：返回 false，由 Dart 侧调用 showSystemOutputSwitcher。
        return false
    }

    fun showSystemOutputSwitcher() {
        try {
            // Android 12+ 系统媒体输出切换面板
            val intent = android.content.Intent(
                "com.android.systemui.action.LAUNCH_MEDIA_OUTPUT_DIALOG"
            ).apply {
                putExtra("android.intent.extra.PACKAGE_NAME", context.packageName)
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        } catch (_: Exception) {
            // 系统面板不可用时静默降级（UI 层展示设备列表即可）
        }
    }

    // ─── 监听 ───

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
            notifyChanged()
        }
        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
            notifyChanged()
        }
    }

    private val a2dpListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
            a2dpProxy = proxy as? BluetoothA2dp
            refreshBatteryCache()
            notifyChanged()
        }
        override fun onServiceDisconnected(profile: Int) {
            a2dpProxy = null
            notifyChanged()
        }
    }

    @Suppress("MissingPermission") // BLUETOOTH_CONNECT 已在 Manifest 声明；旧版本无需
    private fun refreshBatteryCache() {
        val proxy = a2dpProxy ?: return
        try {
            for (device in proxy.connectedDevices) {
                val battery = readBatteryLevel(device)
                if (battery != null && device.address != null) {
                    batteryByAddress[device.address] = battery
                }
            }
        } catch (_: SecurityException) {
            // 未授予蓝牙权限时忽略电量
        }
    }

    @Suppress("MissingPermission")
    private fun readBatteryLevel(device: BluetoothDevice): Int? {
        // BluetoothDevice#getBatteryLevel: API 33+ 公开但需要 BLUETOOTH_CONNECT；
        // 更早版本为隐藏 API，统一用反射避免编译期 SDK 差异。
        return try {
            val m = device.javaClass.getMethod("getBatteryLevel")
            (m.invoke(device) as? Int)?.takeIf { it in 0..100 }
        } catch (_: Exception) {
            null
        }
    }

    fun start() {
        audioManager.registerAudioDeviceCallback(deviceCallback, null)
        bluetoothAdapter?.getProfileProxy(context, a2dpListener, BluetoothProfile.A2DP)
    }

    fun stop() {
        audioManager.unregisterAudioDeviceCallback(deviceCallback)
        bluetoothAdapter?.closeProfileProxy(BluetoothProfile.A2DP, a2dpProxy)
        a2dpProxy = null
    }

    private fun notifyChanged() {
        eventSink?.success("changed")
    }
}
