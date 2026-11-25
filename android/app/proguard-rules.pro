# Regras de ProGuard/R8 do CycleCursos.
#
# O Flutter liga o R8 no build release. O SDK de anúncios do Google usa o WorkManager,
# que cria o banco interno (androidx.work.impl.WorkDatabase, via Room) por reflexão; sem
# estas regras o R8 removia o construtor gerado e o app fechava ao abrir
# ("Failed to create an instance of androidx.work.impl.WorkDatabase", 01/11/2026).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
