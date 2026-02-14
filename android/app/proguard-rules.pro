# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 1. Protect Drift Database Models
# Drift uses reflection/metadata that R8 can break
-keep class * extends com.drift.Value { *; }
-keep class * extends com.drift.DriftDatabase { *; }
-keep class * extends com.drift.Table { *; }

# 2. Protect Myanmar Font Assets
# Prevents R8 from thinking fonts are unused resources
-keepclassmembers class **.R$* {
    public static <fields>;
}

# 3. Protect Google Play Core (Fix for your previous crash)
-keep class com.google.android.play.core.** { *; }

# 4. Protect Flutter & Thermal Printer Plugins
# This ensures MethodChannels for blue_thermal_printer stay intact
-keep class io.flutter.embedding.** { *; }
-keep class com.shreeshail.bluethermalprinter.** { *; }

# 5. Keep all data models for JSON serialization (Cloud Sync)
-keepclassmembers class * {
  @google.gson.annotations.SerializedName <fields>;
}

# General Safety
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.common.** { *; }
-dontwarn com.google.common.**
-dontwarn com.google.android.play.core.**

# Keep generic Flutter engine classes
-keep class io.flutter.embedding.engine.FlutterJNI { *; }
