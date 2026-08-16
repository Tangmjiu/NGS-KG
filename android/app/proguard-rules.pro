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
