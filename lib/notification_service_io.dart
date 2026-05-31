import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _adhanChannelId = 'adhan_channel_v2';
  static const String _defaultChannelId = 'default_channel';

  Future<void> init() async {
    tzdata.initializeTimeZones(); // for zonedSchedule
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (_) {
      // fallback to default timezone
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        // handle tapped notification
      },
    );

    // create channels if needed
    const adhanChannel = AndroidNotificationChannel(
      _adhanChannelId,
      'Adhan notifications',
      description: 'Channel for Adhan with custom sound',
      importance: Importance.max,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(adhanChannel);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> schedule(
    String tag,
    int id,
    String title,
    String body,
    DateTime when, {
    bool playSound = true,
    bool isAdhan = false,
  }) async {
    // convert to tz
    final scheduled = tz.TZDateTime.from(when, tz.local);

    // Android specifics: set sound if isAdhan
    AndroidNotificationDetails androidDetails;
    if (isAdhan) {
      androidDetails = const AndroidNotificationDetails(
        _adhanChannelId,
        'Adhan notifications',
        channelDescription: 'Adhan sound channel',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('adhan'),
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        _defaultChannelId,
        'General notifications',
        channelDescription: 'Default notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true, // uses default sound
      );
    }

    final iosDetails = DarwinNotificationDetails(
      presentSound: playSound,
      sound: isAdhan ? 'adhan.mp3' : null,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // only schedule at time
    );
  }
}
