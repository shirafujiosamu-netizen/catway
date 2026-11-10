# 高德地图 SDK 混淆规则
-keep class com.amap.api.** {*;}
-keep class com.autonavi.** {*;}
-keep class com.amap.flutter.** {*;}
-keep class com.amap.api.location.** {*;}
-keep class com.amap.api.maps.** {*;}
-keep class com.amap.api.services.** {*;}

# 如果使用定位功能
-keep class com.amap.api.location.**{*;}
-keep class com.amap.api.fence.**{*;}
-keep class com.autonavi.aps.amapapi.model.**{*;}

# Flutter 通用规则
-keep class io.flutter.** {*;}
-keep class io.flutter.plugins.** {*;}