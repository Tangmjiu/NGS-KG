# Flutter specific
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Dio/OkHttp
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep Flutter 插件原生类（release 混淆会剥离未显式 keep 的插件，导致 NoClassDefFoundError）
-keep class dev.rexios.wear_plus.** { *; }
-keep class com.samsung.wearable_rotary.** { *; }
-keep class com.pmorales.wear_os_scrollbar.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.lucasjosino.on_audio_query.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Wear OS Tiles / Protolayout
-keep class androidx.wear.tiles.** { *; }
-keep class androidx.wear.protolayout.** { *; }
-keep class com.google.common.util.concurrent.** { *; }

# Keep Kotlin 协程
-keepclassmembers class kotlinx.coroutines.** { *; }

# Keep 自有服务/接收器
-keep class com.mjiutang.ngskg.** { *; }

# Play Core：已移除 com.google.android.play:core 依赖，但 Flutter 引擎内部
# 仍引用 Play Core 类（FlutterPlayStoreSplitApplication / PlayStoreDeferredComponentManager）。
# 本应用不使用延迟组件（deferred components），忽略这些缺失类即可。
-dontwarn com.google.android.play.core.**
