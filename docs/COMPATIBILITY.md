# Compatibility Notes

## Android 14 Namespace Overrides
**Date**: 2026-02-14
**Context**: Android 14 (AGP 8.0+) requires all modules to have a valid `namespace` declared in their `build.gradle`.

**Problem**: 
Several older Flutter plugins (e.g., `blue_thermal_printer`, `path_provider_android`) do not verify this, causing build failures with `Namespace not specified`.

**Solution**:
We have injected a dynamic namespace assignment logic in `d:\GitHub\Grocery POS\android\build.gradle.kts` within the `subprojects` block:

```kotlin
plugins.withId("com.android.library") {
    val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
    if (android != null && android.namespace == null) {
        android.namespace = "com.cosmicforge.fix.${project.name.replace(Regex("\\W"), "_")}"
    }
}
```

**Maintenance**:
If `blue_thermal_printer` or other affected plugins are updated to support Android 14 natively, this fix *should* be harmless (as it checks `if (android.namespace == null)`), but if build errors recur, check this logic first.

## Release Signing
- **Keystore**: `android/app/upload-keystore.jks` (DO NOT COMMIT)
- **Properties**: `android/key.properties` (DO NOT COMMIT)
- **CI/CD**: Inject these as GitHub Secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_PROPERTIES`).
