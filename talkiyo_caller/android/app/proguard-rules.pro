# flutter_local_notifications reads cached notification models with Gson.
# R8/ProGuard can strip generic signatures that Gson TypeToken requires.
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
