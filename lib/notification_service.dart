import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
// تم إزالة الاعتماد على حزم المنطقة الزمنية لوجود تعارضات بناء على أندرويد

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      // افتراضي مناسب لليبيا في حال عدم توفر حزمة المنطقة الزمنية
      final tz.Location location = tz.getLocation('Africa/Tripoli');
      tz.setLocalLocation(location);
    } catch (_) {
      // في حال فشل جلب المنطقة الزمنية، نكتفي بالافتراضي tz.local
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(initSettings);

    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();

      // إنشاء القنوات مع الصوت المخصص للأذان
      // ملاحظة: تغيير المعرّف إلى adhan_channel_v2 لضمان تفعيل الصوت حتى لو كانت القناة القديمة بلا صوت
      const adhanChannel = AndroidNotificationChannel(
        'adhan_channel_v2',
        'Adhan Notifications',
        description: 'Adhan notifications with sound',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('adhan'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
      );
      const reminderChannel = AndroidNotificationChannel(
        'reminder_channel',
        'Prayer Reminders',
        description: 'Prayer time reminders',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      await androidImpl?.createNotificationChannel(adhanChannel);
      await androidImpl?.createNotificationChannel(reminderChannel);
    }
    if (Platform.isIOS) {
      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true,
      );
    }

    _initialized = true;
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> schedule(String idTag, int id, String title, String body,
      DateTime whenLocal) async {
    final tzTime = tz.TZDateTime.from(whenLocal, tz.local);
    
    // تحديد نوع الإشعار حسب idTag
    final bool isAdhanTime = idTag == 'ontime';
    
    // إعدادات Android - صوت الأذان للتنبيه عند الأذان فقط
    final androidDetails = AndroidNotificationDetails(
      isAdhanTime ? 'adhan_channel_v2' : 'reminder_channel',
      isAdhanTime ? 'Adhan Notifications' : 'Prayer Reminders',
      channelDescription: isAdhanTime 
          ? 'Adhan notifications with sound' 
          : 'Prayer time reminders',
      importance: isAdhanTime ? Importance.max : Importance.high,
      priority: isAdhanTime ? Priority.high : Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
      vibrationPattern: isAdhanTime 
          ? Int64List.fromList([0, 2000, 1000, 2000]) // اهتزاز أقوى للأذان
          : Int64List.fromList([0, 500, 200, 500]), // اهتزاز خفيف للتذكير
      sound: isAdhanTime 
          ? RawResourceAndroidNotificationSound('adhan') // صوت الأذان
          : null, // صوت افتراضي للتذكير
      enableLights: true,
      ledColor: isAdhanTime ? Color(0xFFFF5722) : Color(0xFF2196F3), // برتقالي للأذان، أزرق للتذكير
      ledOnMs: 1000,
      ledOffMs: 500,
      showWhen: true,
      when: null,
      usesChronometer: false,
      autoCancel: isAdhanTime ? false : true, // الأذان لا يختفي تلقائياً
      ongoing: isAdhanTime,
      silent: false,
      fullScreenIntent: isAdhanTime, // إشعار ملء الشاشة للأذان فقط
      category: isAdhanTime 
          ? AndroidNotificationCategory.alarm 
          : AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );
    
    // إعدادات iOS - صوت الأذان للتنبيه عند الأذان فقط
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: isAdhanTime ? 'adhan.caf' : null, // صوت الأذان أو افتراضي
      interruptionLevel: isAdhanTime 
          ? InterruptionLevel.critical 
          : InterruptionLevel.active,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }
}


