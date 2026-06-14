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

# Keep Google Play Core (needed by Flutter engine for deferred components)
-keep class com.google.android.play.core.** { *; }

# Keep models
-keep class com.mjiutang.ngskg.model.** { *; }
