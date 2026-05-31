import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hijri/hijri_calendar.dart';
import 'notification_service.dart';
import 'settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:sound_mode/permission_handler.dart';
import 'app_theme.dart';
import 'background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundServiceManager.initialize();
  await BackgroundServiceManager.ensureRunningIfEnabled();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _themeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadThemeIndex();
  }

  Future<void> _loadThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeIndex = prefs.getInt('theme_index') ?? 0;
    });
  }

  Future<void> _setThemeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_index', index);
    setState(() {
      _themeIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemes.themes[_themeIndex.clamp(0, AppThemes.themes.length - 1)];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.data,
        home: PrayerTimesScreen(
          themeIndex: _themeIndex,
          onThemeChanged: _setThemeIndex,
        ),
      ),
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({
    super.key,
    required this.themeIndex,
    required this.onThemeChanged,
  });

  final int themeIndex;
  final ValueChanged<int> onThemeChanged;
  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  DateTime _now = DateTime.now();
  late Timer _timer;
  Map<String, String> prayerTimes = {}; // key -> value (as in CSV)
  // دقائق الإقامة لكل صلاة
  Map<String, int> iqamaMinutes = {
    'fajr': 25,
    'duhr': 20,
    'asr': 20,
    'maghrib': 7,
    'isha': 20,
  };
  String errorMessage = '';
  // فعّل الإشعارات افتراضياً (بصوت)
  bool notifyBefore10 = true;
  bool notifyAtTime = true;
  bool silentBeforeIqama = false;
  bool silentScheduleEnabled = false;
  String silentScheduleStart = '22:00';
  String silentScheduleEnd = '05:00';
  bool backgroundServiceEnabled = false;
  double uiScale = 1.0;
  int _hijriOffset = 0; // تعويض أيام للهجري
  bool _silentActive = false;
  bool _silentUpdateInProgress = false;

  // تسميات لعرض جميلة
  final Map<String, String> arabicLabels = {
    'fajr': 'الفجر',
    'sunrise': 'الشروق',
    'duhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  final List<String> gregorianMonths = [
    "كانون الثاني",
    "شباط",
    "آذار",
    "نيسان",
    "أيار",
    "حزيران",
    "تموز",
    "آب",
    "أيلول",
    "تشرين الأول",
    "تشرين الثاني",
    "كانون الأول",
  ];

  final List<String> hijriMonths = [
    "محرم",
    "صفر",
    "ربيع الأول",
    "ربيع الآخر",
    "جمادى الأولى",
    "جمادى الآخرة",
    "رجب",
    "شعبان",
    "رمضان",
    "شوال",
    "ذو القعدة",
    "ذو الحجة"
  ];

  final List<String> weekDays = [
    "الاثنين",
    "الثلاثاء",
    "الأربعاء",
    "الخميس",
    "الجمعة",
    "السبت",
    "الأحد"
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    _restorePrefs().then((_) => _loadPrayerTimes());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      // إذا تغير اليوم أو الشهر - أعيد تحميل الملف
      if (now.day != _now.day ||
          now.month != _now.month ||
          now.year != _now.year) {
        _now = now;
        _loadPrayerTimes();
      } else {
        setState(() {
          _now = now;
        });
      }
      _updateSilentMode();
    });
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultsInitialized =
        prefs.getBool('iqama_defaults_initialized') ?? false;
    setState(() {
      notifyBefore10 = prefs.getBool('notify_before10') ?? false;
      notifyAtTime = prefs.getBool('notify_at_time') ?? false;
      silentBeforeIqama = prefs.getBool('silent_before_iqama') ?? false;
      silentScheduleEnabled =
          prefs.getBool('silent_schedule_enabled') ?? false;
      silentScheduleStart =
          prefs.getString('silent_schedule_start') ?? '22:00';
      silentScheduleEnd =
          prefs.getString('silent_schedule_end') ?? '05:00';
      backgroundServiceEnabled =
          prefs.getBool('background_service_enabled') ?? false;
      uiScale = prefs.getDouble('ui_scale') ?? 1.0;
      _hijriOffset = prefs.getInt('hijri_offset') ?? 0;
      // Restore iqama minutes
      if (!defaultsInitialized) {
        iqamaMinutes['fajr'] = 25;
        iqamaMinutes['duhr'] = 20;
        iqamaMinutes['asr'] = 20;
        iqamaMinutes['maghrib'] = 7;
        iqamaMinutes['isha'] = 20;
      } else {
        for (final k in iqamaMinutes.keys) {
          final v = prefs.getInt('iqama_$k');
          if (v != null) iqamaMinutes[k] = v;
        }
      }
    });
    if (!defaultsInitialized) {
      await prefs.setBool('iqama_defaults_initialized', true);
    }
    // حفظ الافتراضيات الجديدة إن لم تكن موجودة سابقاً
    await _savePrefs();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notify_before10', notifyBefore10);
    await prefs.setBool('notify_at_time', notifyAtTime);
    await prefs.setBool('silent_before_iqama', silentBeforeIqama);
    await prefs.setBool('silent_schedule_enabled', silentScheduleEnabled);
    await prefs.setString('silent_schedule_start', silentScheduleStart);
    await prefs.setString('silent_schedule_end', silentScheduleEnd);
    await prefs.setBool(
        'background_service_enabled', backgroundServiceEnabled);
    await prefs.setDouble('ui_scale', uiScale);
    // save iqama minutes
    for (final k in iqamaMinutes.keys) {
      await prefs.setInt('iqama_$k', iqamaMinutes[k] ?? 0);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// تحميل ملف الشهر الحالي (1.csv .. 12.csv)
  Future<void> _loadPrayerTimes() async {
    setState(() {
      errorMessage = '';
      prayerTimes.clear();
    });

    final monthFile = _now.month; // 1..12
    final path = 'assets/prayers/$monthFile.csv';

    try {
      final raw = await rootBundle.loadString(path);
      // تقسيم الأسطر مع تجاهل الأسطر الفارغة
      final allLines = raw
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (allLines.isEmpty) {
        setState(() => errorMessage = 'الملف فارغ: $path');
        return;
      }

      // دالة للمطابقة إن كان النص يحتوي زمن مثل 04:15 أو 4:5
      bool looksLikeTimeLine(String s) {
        // نبحث عن رمز الساعة: رقم+(:|.)+دقيقتين
        return RegExp(r'\d{1,2}[:.]\d{2}').hasMatch(s);
      }

      // نتحقق إن السطر الأول هو header أم صف بيانات
      final firstLine = allLines[0];
      final firstLineIsTime = looksLikeTimeLine(firstLine);

      List<String> headers = [];
      List<String> values = [];

      if (firstLineIsTime) {
        // لا يوجد header: اعتبر أن كل سطر هو بيانات يوم (1-> index0)
        // يومنا الحالي يجب أن يكون index = day-1
        final dayIndex = _now.day - 1;
        if (dayIndex < 0 || dayIndex >= allLines.length) {
          setState(() => errorMessage = 'الملف لا يحتوي صف لليوم ${_now.day}');
          return;
        }
        values = allLines[dayIndex].split(',').map((e) => e.trim()).toList();
        // افتراض أسماء الأعمدة القياسية
        headers = ['fajr', 'sunrise', 'duhr', 'asr', 'maghrib', 'isha'];
        // إذا كان هناك عمود إضافي أولاً (مثلاً رقم اليوم) و values أطول
        if (values.isNotEmpty && RegExp(r'^\d+$').hasMatch(values[0])) {
          // حذف أول عمود (رقم اليوم)
          values.removeAt(0);
        }
      } else {
        // يوجد header في السطر الأول
        headers = allLines[0].split(',').map((h) => h.trim()).toList();
        final dayIndex = _now.day; // لأن السطر 0 header، سطر 1 -> يوم1
        if (dayIndex >= allLines.length) {
          setState(() => errorMessage = 'الملف لا يحتوي صف لليوم ${_now.day}');
          return;
        }
        values = allLines[dayIndex].split(',').map((v) => v.trim()).toList();

        // إذا كان header يحتوي عمود 'day' أو 'day' بالعربية، واحتمال أول قيمة هو رقم اليوم -> نتجاهل العمود الأول
        final firstHeaderLower =
            headers.isNotEmpty ? headers[0].toLowerCase() : '';
        if (firstHeaderLower.contains('day') ||
            firstHeaderLower.contains('اليوم') ||
            (values.isNotEmpty && RegExp(r'^\d+$').hasMatch(values[0]))) {
          if (headers.isNotEmpty) headers.removeAt(0);
          if (values.isNotEmpty) values.removeAt(0);
        }
      }

      // الآن نملك headers و values (قد يكون headers اسماء عربية أو انجليزية)
      // نريد ماب key->value; إذا header يساعد نستخدمه، وإلا نستخدم الافتراضي.
      Map<String, String> map = {};

      // normalize header names to lower-case latin if possible (fajr, sunrise, duhr, asr, maghrib, isha)
      for (int i = 0; i < values.length; i++) {
        String key;
        if (i < headers.length) {
          final h = headers[i].toLowerCase();
          // إذا header عربي شائع استخدم كلمات انجليزية
          if (h.contains('فجر') || h.contains('fajr')) {
            key = 'fajr';
          } else if (h.contains('شروق') || h.contains('sunrise'))
            key = 'sunrise';
          else if (h.contains('ظهر') ||
              h.contains('duhr') ||
              h.contains('dhuhr'))
            key = 'duhr';
          else if (h.contains('عصر') || h.contains('asr'))
            key = 'asr';
          else if (h.contains('مغرب') || h.contains('maghrib'))
            key = 'maghrib';
          else if (h.contains('عشاء') || h.contains('isha'))
            key = 'isha';
          else {
            // غير معروف: خذ النص كما هو (بعد تنظيف)
            key = headers[i].trim();
          }
        } else {
          // header غير كافٍ: نستخدم ترتيب افتراضي
          final order = ['fajr', 'sunrise', 'duhr', 'asr', 'maghrib', 'isha'];
          key = (i < order.length) ? order[i] : 'col$i';
        }

        map[key] = values[i];
      }

      setState(() {
        prayerTimes = map;
        errorMessage = '';
      });
      try {
        await _scheduleNotificationsForToday();
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('invalid_sound') || msg.contains('adhan')) {
          setState(() {
            errorMessage =
                'خطأ في صوت الأذان: تأكد أن الملف adhan.mp3 موجود داخل res/raw';
          });
        } else {
          setState(() {
            errorMessage = 'فشل جدولة الإشعارات: $e';
          });
        }
      }
      _updateSilentMode();
    } catch (e) {
      setState(() {
        errorMessage = 'فشل تحميل الملف: $path\n$e';
      });
    }
  }

  String formatTime12(DateTime dt) {
    int hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    String minute = dt.minute.toString().padLeft(2, '0');
    String second = dt.second.toString().padLeft(2, '0');
    String suffix = dt.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute:$second $suffix';
  }

  /// تحويل نص وقت إلى DateTime لليوم (يدعم ص/م ووجود مسافات)
  DateTime? _parseTodayTime(String? input) {
    if (input == null) return null;
    final s = input.trim();
    // التقط أول وقت بالشكل H:MM أو HH:MM أو H.MM
    final match = RegExp(r"(\d{1,2})[:.](\d{1,2})").firstMatch(s);
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    int minute = int.parse(match.group(2)!);
    // دعم ص/م (عربي) أو AM/PM (لاتيني)
    final lower = s.toLowerCase();
    final hasPm = lower.contains('pm') || s.contains('م');
    final hasAm = lower.contains('am') || s.contains('ص');
    if (hasPm && hour < 12) hour += 12;
    if (hasAm && hour == 12) hour = 0;
    if (minute > 59) minute = 59;
    return DateTime(_now.year, _now.month, _now.day, hour, minute);
  }

  // --- حوار عرض يوم أمس/الغد: توابع مساعدة مضافة في الأسفل ---

  /// تحميل أوقات يوم محدد بدون التأثير على الحالة الحالية
  Future<Map<String, String>> _loadPrayerTimesForDate(DateTime date) async {
    final monthFile = date.month; // 1..12
    final path = 'assets/prayers/$monthFile.csv';

    final raw = await rootBundle.loadString(path);
    final allLines = raw
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (allLines.isEmpty) {
      throw 'الملف فارغ: $path';
    }

    bool looksLikeTimeLine(String s) {
      return RegExp(r'\d{1,2}[:.]\d{2}').hasMatch(s);
    }

    final firstLine = allLines[0];
    final firstLineIsTime = looksLikeTimeLine(firstLine);

    List<String> headers = [];
    List<String> values = [];

    if (firstLineIsTime) {
      final dayIndex = date.day - 1;
      if (dayIndex < 0 || dayIndex >= allLines.length) {
        throw 'الملف لا يحتوي صف لليوم ${date.day}';
      }
      values = allLines[dayIndex].split(',').map((e) => e.trim()).toList();
      headers = ['fajr', 'sunrise', 'duhr', 'asr', 'maghrib', 'isha'];
      if (values.isNotEmpty && RegExp(r'^\d+$').hasMatch(values[0])) {
        values.removeAt(0);
      }
    } else {
      headers = allLines[0].split(',').map((h) => h.trim()).toList();
      final dayIndex = date.day; // سطر 0 header
      if (dayIndex >= allLines.length) {
        throw 'الملف لا يحتوي صف لليوم ${date.day}';
      }
      values = allLines[dayIndex].split(',').map((v) => v.trim()).toList();

      final firstHeaderLower =
          headers.isNotEmpty ? headers[0].toLowerCase() : '';
      if (firstHeaderLower.contains('day') ||
          firstHeaderLower.contains('اليوم') ||
          (values.isNotEmpty && RegExp(r'^\d+$').hasMatch(values[0]))) {
        if (headers.isNotEmpty) headers.removeAt(0);
        if (values.isNotEmpty) values.removeAt(0);
      }
    }

    Map<String, String> map = {};
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

  Future<void> _openDayDialog(DateTime date, {required String title}) async {
    if (!mounted) return;
    final palette = AppThemes
        .themes[widget.themeIndex.clamp(0, AppThemes.themes.length - 1)]
        .palette;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: FutureBuilder<Map<String, String>>(
              future: _loadPrayerTimesForDate(date),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(snap.error.toString(),
                        style: const TextStyle(color: Colors.red)),
                  );
                }
                final map = snap.data ?? {};
                final order = [
                  'fajr',
                  'sunrise',
                  'duhr',
                  'asr',
                  'maghrib',
                  'isha'
                ];

                return Container(
                  width: 360,
                  decoration: BoxDecoration(
                    color: palette.dialogBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // header with close button
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: palette.dialogHeaderBg,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              tooltip: 'إغلاق',
                            ),
                          ],
                        ),
                      ),

                      // body
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final key in order)
                              if (map.containsKey(key))
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: palette.cardBg,
                                      border: Border.all(
                                          color: palette.cardBorder, width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(arabicLabels[key] ?? key,
                                            style:
                                                const TextStyle(fontSize: 16)),
                                        Text(map[key] ?? '',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// حساب الصلاة القادمة والمدة المتبقية
  (String, Duration)? _nextPrayerAndRemaining() {
    if (prayerTimes.isEmpty) return null;
    // ترتيب الصلوات (استثناء الشروق من العدّ التنازلي)
    final order = ['fajr', 'duhr', 'asr', 'maghrib', 'isha'];
    final now = _now;
    for (final key in order) {
      final t = _parseTodayTime(prayerTimes[key]);
      if (t != null && t.isAfter(now)) {
        return (arabicLabels[key] ?? key, t.difference(now));
      }
    }
    // لا يوجد وقت لاحق اليوم: نعتبر فجر الغد
    final fajrTomorrow =
        _parseTodayTime(prayerTimes['fajr'])?.add(const Duration(days: 1));
    if (fajrTomorrow != null) {
      return (arabicLabels['fajr'] ?? 'الفجر', fajrTomorrow.difference(now));
    }
    return null;
  }

  // جدولة الإشعارات حسب التبديلات الحالية
  Future<void> _scheduleNotificationsForToday() async {
    if (prayerTimes.isEmpty) return;
    await NotificationService.instance.cancelAll();

    if (!notifyBefore10 && !notifyAtTime) return;

    final keys = ['fajr', 'duhr', 'asr', 'maghrib', 'isha'];
    int id = 100; // base id
    for (final k in keys) {
      final dt = _parseTodayTime(prayerTimes[k]);
      if (dt == null) continue;

      if (notifyBefore10) {
        final when = dt.subtract(const Duration(minutes: 10));
        if (when.isAfter(DateTime.now())) {
          await NotificationService.instance.schedule(
            'before10',
            id++,
            'تذكير قبل الصلاة',
            'تبقَّ 10 دقائق لصلاة ${arabicLabels[k] ?? k}',
            when,
            playSound: true, // تشغيل صوت للتذكير قبل 10 دقائق
            isAdhan: false, // تذكير عادي (ليس آذان)
          );
        }
      }
      if (notifyAtTime) {
        if (dt.isAfter(DateTime.now())) {
          await NotificationService.instance.schedule(
            'ontime',
            id++,
            'حان وقت الصلاة',
            'حان الآن وقت ${arabicLabels[k] ?? k}',
            dt,
            playSound: true, // تشغيل صوت
            isAdhan: true, // آذان عند الوقت
          );
        }
      }
    }
  }

  // حساب نافذة الصامت لصلاة محددة
  (DateTime, DateTime)? _silentWindowForPrayer(String key) {
    final dt = _parseTodayTime(prayerTimes[key]);
    if (dt == null) return null;
    final minutes = iqamaMinutes[key] ?? 0;
    final iqamaEnd = dt.add(Duration(minutes: minutes));
    final start = iqamaEnd.subtract(const Duration(minutes: 5));
    final safeStart = start.isBefore(dt) ? dt : start;
    final end = iqamaEnd.add(const Duration(minutes: 10));
    return (safeStart, end);
  }

  // هل الآن ضمن نافذة الصامت لأي صلاة؟
  bool _isNowInSilentWindow() {
    if (prayerTimes.isEmpty) return false;
    final now = _now;
    bool inSchedule = false;
    if (silentScheduleEnabled) {
      final start = _parseTimeToday(silentScheduleStart);
      final end = _parseTimeToday(silentScheduleEnd);
      if (start != null && end != null) {
        if (start.isBefore(end) || start.isAtSameMomentAs(end)) {
          inSchedule = (now.isAtSameMomentAs(start) || now.isAfter(start)) &&
              now.isBefore(end);
        } else {
          // نافذة تعبر منتصف الليل
          inSchedule = now.isAfter(start) || now.isBefore(end);
        }
      }
    }

    bool inIqamaWindow = false;
    if (silentBeforeIqama) {
      for (final key in ['fajr', 'duhr', 'asr', 'maghrib', 'isha']) {
        final win = _silentWindowForPrayer(key);
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

  DateTime? _parseTimeToday(String input) {
    final parts = input.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(_now.year, _now.month, _now.day, h, m);
  }

  Future<void> _enterSilentModeIfPossible() async {
    if (!Platform.isAndroid) return;
    final granted = await PermissionHandler.permissionsGranted ?? false;
    if (!granted) return;
    await SoundMode.setSoundMode(RingerModeStatus.silent);
    _silentActive = true;
  }

  Future<void> _restoreRingerMode() async {
    if (!Platform.isAndroid) return;
    await SoundMode.setSoundMode(RingerModeStatus.normal);
    _silentActive = false;
  }
  Future<void> _updateSilentMode() async {
    if (_silentUpdateInProgress) return;
    _silentUpdateInProgress = true;
    try {
      if (!silentBeforeIqama && !silentScheduleEnabled) {
        if (_silentActive) {
          await _restoreRingerMode();
        }
        return;
      }

      final inWindow = _isNowInSilentWindow();
      if (inWindow && !_silentActive) {
        await _enterSilentModeIfPossible();
      } else if (!inWindow && _silentActive) {
        await _restoreRingerMode();
      }
    } catch (_) {
      // تجاهل الأخطاء لتفادي إيقاف المؤقت
    } finally {
      _silentUpdateInProgress = false;
    }
  }

  String _formatDuration(Duration d) {
    final total = d.inMinutes;
    final h = total ~/ 60;
    final m = total % 60;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}';
  }

  /// Format mm:ss for small countdowns
  String _formatMinutesSeconds(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(m)}:${two(s)}';
  }

  // helper: format time HH:mm
  String _formatTimeHM(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildScaleButton({
    required String label,
    required double fontSize,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    final size = (fontSize * 1.8).clamp(28.0, 46.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.4),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // فتح حوار لتعديل دقائق الإقامة لكل صلاة (تجاهل الشروق)
  Future<void> _openEditIqamaDialog(String key) async {
    if (key == 'sunrise') return; // تجاهل الشروق
    final controller =
        TextEditingController(text: (iqamaMinutes[key] ?? 0).toString());
    await showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('ضبط وقت الإقامة - ${arabicLabels[key] ?? key}'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المدة (دقائق)'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final minutes = int.tryParse(controller.text.trim()) ?? 0;
                  if (!mounted) return;
                  setState(() => iqamaMinutes[key] = minutes);
                  await _savePrefs(); // حفظ الإعدادات
                  await _scheduleNotificationsForToday(); // إعادة جدولة الإشعارات فوراً
                  Navigator.of(ctx).pop();
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final scale =
        ((screenHeight / 800).clamp(0.8, 1.0) * uiScale).clamp(0.7, 1.4);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme =
        AppThemes.themes[widget.themeIndex.clamp(0, AppThemes.themes.length - 1)];
    final palette = theme.palette;

    // المساحة الداخلية في الـ body padding (SingleChildScrollView has padding 18)
    const double bodyPadding = 18.0;
    final double availableWidth =
        (screenWidth - bodyPadding * 2).clamp(0.0, double.infinity).toDouble();
    // عرض السطر: لا يتجاوز المساحة المتاحة
    final double preferredRowWidth =
        screenWidth > 600 ? 560.0 : availableWidth * 0.92;
    final double rowWidth =
        preferredRowWidth.clamp(0.0, availableWidth).toDouble();
    final double safeRowWidth = rowWidth <= 0 ? 0.0 : rowWidth;
    // ثوابت التحكم بالأبعاد
    const double tileGap = 6.0; // المسافة بين مستطيلي الاسم والوقت
    const double containerHorizontalPadding = 10.0;
    const double tileMinWidth = 100.0; // عرض أدنى أوسع
    const double tileMaxWidth = 160.0; // أكبر عرض للمربعين (طويلة لاحقًا)
    const double tileHeight = 44.0; // ارتفاع أصغر قليلاً
    // احتسب عرض المربعات بناءً على عرض الحاوية الفعلي لضمان عدم overflow
    final tileWidthCandidate =
        ((safeRowWidth - containerHorizontalPadding * 2 - tileGap) / 2);
    final double tileWidth =
        tileWidthCandidate.clamp(tileMinWidth, tileMaxWidth).toDouble();
    // تصغير مستطيل اسم الصلاة قليلاً بالنسبة لعرض المربعات
    final double nameTileWidth =
        (tileWidth * 0.90).clamp(70.0, tileWidth).toDouble();
    final contentWidth =
        tileWidth * 2 + tileGap + containerHorizontalPadding * 2;
    final double containerWidth = safeRowWidth == 0
        ? 0.0
        : contentWidth.clamp(0.0, safeRowWidth).toDouble();

    // حساب عرض بطاقة العدّ التنازلي (موسع أكثر قليلاً)
    final double countdownWidth = safeRowWidth == 0
        ? 0.0
        : (containerWidth * 1.25)
            .clamp(containerWidth, safeRowWidth)
            .toDouble();

    // تطبيق تعويض التاريخ الهجري (إن وُجد)
    final hijri =
        HijriCalendar.fromDate(_now.add(Duration(days: _hijriOffset)));
    final gDate =
        '${_now.year}/${_now.month}/${_now.day} - ${gregorianMonths[_now.month - 1]}';
    final hDate =
        '${hijri.hYear}/${hijri.hMonth}/${hijri.hDay} هـ - ${hijriMonths[hijri.hMonth - 1]}';
    final dayName = weekDays[_now.weekday - 1];

    // ترتيب عرض الصلوات بالترتيب المعروف
    final order = ['fajr', 'sunrise', 'duhr', 'asr', 'maghrib', 'isha'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('أوقات الصلاة - الزوية'),
        centerTitle: true,
        backgroundColor: palette.appBar,
        actions: [
          IconButton(
            icon: const Icon(Icons.brush),
            tooltip: 'الثيمات',
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text('اختر الثيم'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < AppThemes.themes.length; i++)
                          ListTile(
                            title: Text(AppThemes.themes[i].name),
                            leading: Icon(
                              widget.themeIndex == i
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                            ),
                            onTap: () {
                              widget.onThemeChanged(i);
                              Navigator.of(ctx).pop();
                            },
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result =
                  await Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    initialBefore10: notifyBefore10,
                    initialAtTime: notifyAtTime,
                    initialSilentBeforeIqama: silentBeforeIqama,
                    initialSilentScheduleEnabled: silentScheduleEnabled,
                    initialSilentScheduleStart: silentScheduleStart,
                    initialSilentScheduleEnd: silentScheduleEnd,
                    initialBackgroundServiceEnabled: backgroundServiceEnabled,
                    initialIqamaMinutes: iqamaMinutes,
                  ),
                ),
              );
              if (result != null) {
                setState(() {
                  notifyBefore10 = result['before10'] ?? notifyBefore10;
                  notifyAtTime = result['atTime'] ?? notifyAtTime;
                  silentBeforeIqama =
                      result['silentBeforeIqama'] ?? silentBeforeIqama;
                  silentScheduleEnabled = result['silentScheduleEnabled'] ??
                      silentScheduleEnabled;
                  silentScheduleStart =
                      result['silentScheduleStart'] ?? silentScheduleStart;
                  silentScheduleEnd =
                      result['silentScheduleEnd'] ?? silentScheduleEnd;
                  backgroundServiceEnabled =
                      result['backgroundServiceEnabled'] ??
                          backgroundServiceEnabled;
                  for (final k in iqamaMinutes.keys) {
                    final keyName = 'iqama_$k';
                    if (result.containsKey(keyName) && result[keyName] is int) {
                      iqamaMinutes[k] = result[keyName] as int;
                    }
                  }
                });
                await _savePrefs();
                // إعادة قراءة تعويض الهجري في حال تم الضغط على زر إعادة الضبط
                await _restorePrefs();
                await _scheduleNotificationsForToday();
                _updateSilentMode();
                await BackgroundServiceManager.setEnabled(
                    backgroundServiceEnabled);
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Column(
            children: [
              // الوقت أعلى الشاشة في الوسط وبشكل بيضوي
              Row(
                children: [
                  // زر التصغير (يسار)
                  _buildScaleButton(
                    label: 'ظ',
                    fontSize: 14 * scale,
                    bgColor: palette.dateBg,
                    borderColor: palette.dateBorder,
                    onTap: () async {
                      setState(() {
                        uiScale = (uiScale - 0.05).clamp(0.8, 1.4);
                      });
                      await _savePrefs();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          color: palette.timeBg,
                          border:
                              Border.all(color: palette.timeBorder, width: 1.5),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        padding: EdgeInsets.symmetric(
                            vertical: 10 * scale, horizontal: 24 * scale),
                        child: Text(
                          formatTime12(_now),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22 * scale,
                              color: palette.timeText,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // زر التكبير (يمين)
                  _buildScaleButton(
                    label: 'ظ',
                    fontSize: 22 * scale,
                    bgColor: palette.dateBg,
                    borderColor: palette.dateBorder,
                    onTap: () async {
                      setState(() {
                        uiScale = (uiScale + 0.05).clamp(0.8, 1.4);
                      });
                      await _savePrefs();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: palette.dateBg,
                  border: Border.all(color: palette.dateBorder, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.symmetric(
                    vertical: 5 * scale, horizontal: 10 * scale),
                child: Text(gDate, style: TextStyle(fontSize: 16 * scale)),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: palette.dateBg,
                  border: Border.all(color: palette.dateBorder, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.symmetric(
                    vertical: 5 * scale, horizontal: 10 * scale),
                child: Text(hDate, style: TextStyle(fontSize: 16 * scale)),
              ),
              // تقليل المسافات لجعل مستطيلات الصلاة أعلى قليلاً
              const SizedBox(height: 2), // أقل مسافة لأعلى
              const SizedBox(height: 2),
              const SizedBox(height: 2),
              const SizedBox(height: 4),
              // بطاقة اليوم مع مثلثين لعرض يوم أمس والغد بنافذة مستقلة
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // يسار: مثلث لليوم التالي
                  IconButton(
                    onPressed: () {
                      final d = _now.add(const Duration(days: 1));
                      _openDayDialog(d, title: 'أوقات الصلاة ليوم الغد');
                    },
                    icon: Transform.rotate(
                      angle: 3.14159,
                      child: const Icon(Icons.play_arrow, color: Colors.teal),
                    ),
                    iconSize: 34,
                    tooltip: 'اليوم التالي',
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.dateBg,
                        border: Border.all(color: palette.dateBorder, width: 1.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      child: Text(
                        'أوقات الصلاة ليوم $dayName',
                        style: TextStyle(
                            fontSize:
                                dayName == 'الجمعة' ? 15 : 17, // أصغر قليلاً
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // يمين: مثلث لليوم الماضي
                  IconButton(
                    onPressed: () {
                      final d = _now.subtract(const Duration(days: 1));
                      _openDayDialog(d, title: 'أوقات الصلاة لليوم الماضي');
                    },
                    icon: const Icon(Icons.play_arrow, color: Colors.teal),
                    iconSize: 34,
                    tooltip: 'اليوم الماضي',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const SizedBox(
                  height:
                      4), // تم إزالة Divider بين التاريخ الهجري وبطاقة أوقات الصلاة

              if (errorMessage.isNotEmpty)
                Text(errorMessage, style: const TextStyle(color: Colors.red)),
              if (prayerTimes.isEmpty && errorMessage.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('جاري تحميل أوقات الصلاة...'),
                ),

              // قائمة منسدلة أو عمود للأوقات
              if (prayerTimes.isNotEmpty)
                Column(
                  children: [
                    for (final key in order)
                      if (prayerTimes.containsKey(key))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Center(
                            child: Container(
                              width: containerWidth,
                              decoration: BoxDecoration(
                                color: palette.cardBg,
                                border: Border.all(
                                    color: palette.cardBorder, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 10),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  // يمين: مستطيل اسم الصلاة (مصغر ومتوسّط)
                                  Container(
                                    width: nameTileWidth,
                                    height: tileHeight,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: palette.tileNameBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: palette.tileNameBorder,
                                          width: 1.2),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: Center(
                                      child: Text(
                                        arabicLabels[key] ?? key,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 15, // حجم مناسب للتوسيط
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 6),

                                  // الوسط: مربع الوقت (يعرض وقت الصلاة أو عدّاد الإقامة mm:ss)
                                  Builder(builder: (ctx) {
                                    final dt =
                                        _parseTodayTime(prayerTimes[key]);
                                    final now = _now;
                                    final minutes = (key == 'sunrise')
                                        ? 0
                                        : (iqamaMinutes[key] ?? 0);

                                    // حساب نهاية الإقامة إن وُجدت
                                    final DateTime? iqamaEndDt =
                                        (dt != null && minutes > 0)
                                            ? dt.add(Duration(minutes: minutes))
                                            : null;

                                    final bool inIqama = dt != null &&
                                        iqamaEndDt != null &&
                                        (now.isAtSameMomentAs(dt) ||
                                            now.isAfter(dt)) &&
                                        now.isBefore(iqamaEndDt);

                                    final String displayTime =
                                        inIqama
                                            ? _formatMinutesSeconds(
                                                iqamaEndDt.difference(now))
                                            : (prayerTimes[key] ?? '');

                                    // وميض (blink): نغيّر اللون كل ثانية أثناء الإقامة
                                    final bool blink =
                                        inIqama && (now.second % 2 == 0);
                                    final Color timeBgColor = inIqama
                                        ? (blink
                                            ? Colors.red.shade100
                                            : Colors.red.shade50)
                                        : palette.tileTimeBg;
                                    final Color timeTextColor = inIqama
                                        ? (blink
                                            ? Colors.red.shade900
                                            : Colors.red.shade700)
                                        : Colors.black87;

                                    return Container(
                                      width: tileWidth,
                                      height: tileHeight,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: timeBgColor,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: palette.tileTimeBorder,
                                            width: 1.2),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      child: Center(
                                        child: Text(
                                          displayTime,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15, // نفس حجم اسم الصلاة
                                            fontWeight: FontWeight.w600,
                                            color: timeTextColor,
                                          ),
                                        ),
                                      ),
                                    );
                                  }), // end Builder

                                  // تمت ازالة مربع "الإقامة" بالكامل لأن الوقت يظهر داخل مربع الوقت
                                  // لذلك لا توجد مساحة إضافية على اليسار هنا
                                ],
                              ),
                            ),
                          ),
                        ),

                    // عرض أي أعمدة إضافية لم تُعرَف
                    ...prayerTimes.entries
                        .where((e) => !order.contains(e.key))
                        .map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Container(
                          decoration: BoxDecoration(
                            color: palette.cardBg,
                            border: Border.all(
                                color: palette.cardBorder, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key.toString(),
                                  style: const TextStyle(fontSize: 16)),
                              Text(e.value.toString(),
                                  style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    // بطاقة العدّ التنازلي بسطر واحد: اسم الصلاة + الوقت
                    Builder(builder: (context) {
                      final nextInfo = _nextPrayerAndRemaining();
                      return Center(
                        child: Container(
                          width: countdownWidth,
                          decoration: BoxDecoration(
                            color: palette.countdownBg,
                            border: Border.all(
                                color: palette.countdownBorder, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 12),
                          child: nextInfo == null
                              ? const Text('...')
                              : Text(
                                  'الوقت المتبقي للصلاة القادمة ${nextInfo.$1} ${_formatDuration(nextInfo.$2)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 13, // تم تصغير الخط قليلاً
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      );
                    }),

                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
