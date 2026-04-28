# kotlinx.serialization - keep all @Serializable classes and their companions/serializers
-keepattributes *Annotation*, InnerClasses, EnclosingMethod, Signature

-dontnote kotlinx.serialization.AnnotationsKt

# Keep the kotlinx.serialization runtime
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class kotlinx.serialization.** { *; }

# Keep all classes annotated with @Serializable and their members
-keep @kotlinx.serialization.Serializable class ** { *; }
-keep class **$$serializer { *; }
-keepclassmembers @kotlinx.serialization.Serializable class ** {
    static **$serializer INSTANCE;
    static kotlinx.serialization.KSerializer serializer(...);
    *** Companion;
    *** INSTANCE;
    kotlinx.serialization.descriptors.SerialDescriptor getDescriptor();
}

# Keep companion objects of @Serializable classes
-keepclasseswithmembers class ** {
    @kotlinx.serialization.Serializable <fields>;
}

# Room - keep entity and DAO classes
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class ** { *; }
-keep @androidx.room.Dao interface ** { *; }
-keepclassmembers @androidx.room.Entity class ** { *; }

# Flutter / general
-keep class io.flutter.** { *; }
-keep class com.example.blackoutapp.** { *; }
-keep class com.blackoutlink.** { *; }

# Flutter deferred components / Play Store split - not used in this app
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
