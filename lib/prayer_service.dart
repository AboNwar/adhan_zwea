import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class PrayerService {
  /// تحميل مواقيت الصلاة لليوم الحالي من ملف CSV
  static Future<Map<String, String>> loadTodayPrayers() async {
    final DateTime now = DateTime.now();
    final int month = now.month;
    final int day = now.day;

    // تحميل ملف الشهر الحالي (مثلاً 9.csv من مجلد assets/prayers/)
    final String filePath = 'assets/prayers/$month.csv';
    final String rawCsv = await rootBundle.loadString(filePath);

    final List<String> lines = LineSplitter.split(rawCsv).toList();

    if (lines.isEmpty) {
      return {};
    }

    // استخراج العناوين (Header)
    final headers = lines.first.split(',').map((h) => h.trim()).toList();

    // اختيار صف اليوم الحالي
    if (day >= lines.length) return {};
    final values = lines[day].split(',').map((v) => v.trim()).toList();

    // مطابقة القيم مع العناوين
    final Map<String, String> prayers = {};
    for (int i = 0; i < headers.length && i < values.length; i++) {
      final h = headers[i].toLowerCase();
      String? key;

      if (h.contains('فجر') || h.contains('fajr'))
        key = 'الفجر';
      else if (h.contains('شروق') || h.contains('sunrise'))
        key = 'الشروق';
      else if (h.contains('ظهر') || h.contains('duhr') || h.contains('dhuhr'))
        key = 'الظهر';
      else if (h.contains('عصر') || h.contains('asr'))
        key = 'العصر';
      else if (h.contains('مغرب') || h.contains('maghrib'))
        key = 'المغرب';
      else if (h.contains('عشاء') || h.contains('isha')) key = 'العشاء';

      if (key != null) {
        prayers[key] = values[i];
      }
    }

    return prayers;
  }
}
