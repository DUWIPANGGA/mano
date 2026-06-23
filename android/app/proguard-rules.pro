# Keep sherpa_onnx classes
-keep class com.k2fsa.sherpa.onnx.** { *; }
-keep class com.k2fsa.sherpa_onnx.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep native libraries
-keep class **.so { *; }