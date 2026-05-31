import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:sound_mode/permission_handler.dart';

class SilentModeService {
  static Future<void> updateFromBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final silentBeforeIqama = prefs.getBool('silent_before_iqama') ?? false;
    final silentScheduleEnabled =
        prefs.getBool('silent_schedule_enabled') ?? false;
    if (!silentBeforeIqama && !silentScheduleEnabled) return;

    final iqamaMinutes = _loadIqamaFromPrefs(prefs);
    final silentScheduleStart =
        prefs.getString('silent_schedule_start') ?? '22:00';
    final silentScheduleEnd =
        prefs.getString('silent_schedule_end') ?? '05:00';

    final now = DateTime.now();
    final prayers = await _loadPrayerTimesForDate(now);

    final inWindow = _isNowInSilentWindow(
      now,
      prayers,
      iqamaMinutes,
      silentBeforeIqama,
      silentScheduleEnabled,
      silentScheduleStart,
      silentScheduleEnd,
    );

    final granted = await PermissionHandler.permissionsGranted ?? false;
    if (!granted) return;

    if (inWindow) {
      await SoundMode.setSoundMode(RingerModeStatus.silent);
    } else {
      await SoundMode.setSoundMode(RingerModeStatus.normal);
    }
  }

  static Map<String, int> _loadIqamaFromPrefs(SharedPreferences prefs) {
    final defaults = <String, int>{
      'fajr': 25,
      'duhr': 20,
      'asr': 20,
      'maghrib': 7,
      'isha': 20,
    };
    final result = <String, int>{};
    for (final k in defaults.keys) {
      result[k] = prefs.getInt('iqama_$k') ?? defaults[k]!;
    }
    return result;
  }

  static bool _isNowInSilentWindow(
    DateTime now,
    Map<String, String> prayerTimes,
    Map<String, int> iqamaMinutes,
    bool silentBeforeIqama,
    bool silentScheduleEnabled,
    String silentScheduleStart,
    String silentScheduleEnd,
  ) {
    final inSchedule = silentScheduleEnabled &&
        _isInScheduleWindow(now, silentScheduleStart, silentScheduleEnd);

    bool inIqamaWindow = false;
    if (silentBeforeIqama) {
      for (final key in ['fajr', 'duhr', 'asr', 'maghrib', 'isha']) {
        final win = _silentWindowForPrayer(now, prayerTimes, iqamaMinutes, key);
        if (win == null) continue;
        if ((now.isAtSameMomentAs(win.$1) || now.isAfter(win.$1)) &&
            now.isBefore(win.$2)) {
          inIqamaWindow = true;
          break;
        }
      }
    }

    return inSchedule || inIqamaWindow;
  }

  static bool _isInScheduleWindow(
      DateTime now, String start, String end) {
    final startDt = _parseTimeToday(now, start);
    final endDt = _parseTimeToday(now, end);
    if (startDt == null || endDt == null) return false;
    if (startDt.isBefore(endDt) || startDt.isAtSameMomentAs(endDt)) {
      return (now.isAtSameMomentAs(startDt) || now.isAfter(startDt)) &&
          now.isBefore(endDt);
    }
    // نافذة تعبر منتصف الليل
    return now.isAfter(startDt) || now.isBefore(endDt);
  }

  static (DateTime, DateTime)? _silentWindowForPrayer(
    DateTime now,
    Map<String, String> prayerTimes,
    Map<String, int> iqamaMinutes,
    String key,
  ) {
    final dt = _parseTodayTime(now, prayerTimes[key]);
    if (dt == null) return null;
    final minutes = iqamaMinutes[key] ?? 0;
    final iqamaEnd = dt.add(Duration(minutes: minutes));
    final start = iqamaEnd.subtract(const Duration(minutes: 5));
    final safeStart = start.isBefore(dt) ? dt : start;
    final end = iqamaEnd.add(const Duration(minutes: 10));
    return (safeStart, end);
  }

  static DateTime? _parseTimeToday(DateTime now, String input) {
    final parts = input.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(now.year, now.month, now.day, h, m);
  }

  static DateTime? _parseTodayTime(DateTime now, String? input) {
    if (input == null) return null;
    final s = input.trim();
    final match = RegExp(r"(\\d{1,2})[:.](\\d{1,2})").firstMatch(s);
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    int minute = int.parse(match.group(2)!);
    final lower = s.toLowerCase();
    final hasPm = lower.contains('pm') || s.contains('م');
    final hasAm = lower.contains('am') || s.contains('ص');
    if (hasPm && hour < 12) hour += 12;
    if (hasAm && hour == 12) hour = 0;
    if (minute > 59) minute = 59;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static Future<Map<String, String>> _loadPrayerTimesForDate(
      DateTime date) async {
    final monthFile = date.month;
    final path = 'assets/prayers/$monthFile.csv';

    final raw = await rootBundle.loadString(path);
    final allLines = raw
        .split(RegExp(r'\\r?\\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (allLines.isEmpty) return {};

    bool looksLikeTimeLine(String s) {
      return RegExp(r'\\d{1,2}[:.]\\d{2}').hasMatch(s);
    }

    final firstLine = allLines[0];
    final firstLineIsTime = looksLikeTimeLine(firstLine);

    List<String> headers = [];
    List<String> values = [];

    if (firstLineIsTime) {
      final dayIndex = date.day - 1;
      if (dayIndex < 0 || dayIndex >= allLines.length) return {};
      values = allLines[dayIndex].split(',').map((e) => e.trim()).toList();
      headers = ['fajr', 'sunrise', 'duhr', 'asr', 'maghrib', 'isha'];
      if (values.isNotEmpty && RegExp(r'^\\d+$').hasMatch(values[0])) {
        values.removeAt(0);
      }
    } else {
      headers = allLines[0].split(',').map((h) => h.trim()).toList();
      final dayIndex = date.day;
      if (dayIndex >= allLines.length) return {};
      values = allLines[dayIndex].split(',').map((v) => v.trim()).toList();

      final firstHeaderLower =
          headers.isNotEmpty ? headers[0].toLowerCase() : '';
      if (firstHeaderLower.contains('day') ||
          firstHeaderLower.contains('اليوم') ||
          (values.isNotEmpty && RegExp(r'^\\d+$').hasMatch(values[0]))) {
        if (headers.isNotEmpty) headers.removeAt(0);
        if (values.isNotEmpty) values.removeAt(0);
      }
    }

    final Map<String, String> map = {};
    for (int i = 0; i < values.length; i++) {
      String key;
      if (i < headers.length) {
        final h = headers[i].toLowerCase();
        if (h.contains('فجر') || h.contains('fajr')) {
          key = 'fajr';
        } else if (h.contains('شروق') || h.contains('sunrise')) {
          key = 'sunrise';
        } else if (h.contains('ظهر') ||
            h.contains('duhr') ||
            h.contains('dhuhr')) {
          key = 'duhr';
        } else if (h.contains('عصر') || h.contains('asr')) {
          key = 'asr';
        } else if (h.contains('مغرب') || h.contains('maghrib')) {
          key = 'maghrib';
        } else if (h.contains('عشاء') || h.contains('isha')) {
          key = 'isha';
        } else {
          key = headers[i].trim();
        }
      } else {
        final order = ['fajr', 'sunrise', 'duhr', 'asr', 'maghrib', 'isha'];
        key = (i < order.length) ? order[i] : 'col$i';
      }
      map[key] = values[i];
    }

    return map;
  }
}
