import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'silent_mode_service.dart';

class BackgroundServiceManager {
  static const String _enabledKey = 'background_service_enabled';

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'adhan_background_service',
        initialNotificationTitle: 'أذان الزوية',
        initialNotificationContent: 'خدمة الخلفية تعمل',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    final service = FlutterBackgroundService();
    if (enabled) {
      await service.startService();
    } else {
      service.invoke('stopService');
    }
  }

  static Future<void> ensureRunningIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    if (enabled) {
      final service = FlutterBackgroundService();
      await service.startService();
    }
  }
}

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.on('stopService').listen((_) {
      service.stopSelf();
    });
  }

  Timer.periodic(const Duration(minutes: 1), (_) async {
    await SilentModeService.updateFromBackground();
  });
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
