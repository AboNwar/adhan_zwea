import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hijri/hijri_calendar.dart';
import 'notification_service.dart';
import 'settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PrayerTimesScreen(),
      ),
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});
  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  DateTime _now = DateTime.now();
  late Timer _timer;
  Map<String, String> prayerTimes = {}; // key -> value (as in CSV)
  String errorMessage = '';
  bool notifyBefore10 = false;
  bool notifyAtTime = false;
  int _hijriOffset = 0; // تعويض أيام للهجري

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
    });
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notifyBefore10 = prefs.getBool('notify_before10') ?? false;
      notifyAtTime = prefs.getBool('notify_at_time') ?? false;
      _hijriOffset = prefs.getInt('hijri_offset') ?? 0;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notify_before10', notifyBefore10);
    await prefs.setBool('notify_at_time', notifyAtTime);
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

      final firstHeaderLower = headers.isNotEmpty ? headers[0].toLowerCase() : '';
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
        } else if (h.contains('ظهر') || h.contains('duhr') || h.contains('dhuhr')) {
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
                Widget body;
                if (snap.connectionState == ConnectionState.waiting) {
                  body = const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snap.hasError) {
                  body = Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(snap.error.toString(), style: const TextStyle(color: Colors.red)),
                  );
                } else {
                  final map = snap.data ?? {};
                  final order = ['fajr', 'sunrise', 'duhr', 'asr', 'maghrib', 'isha'];
                  body = SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final key in order)
                          if (map.containsKey(key))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.shade100,
                                  border: Border.all(color: Colors.orange, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(arabicLabels[key] ?? key, style: const TextStyle(fontSize: 16)),
                                    Text(map[key] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  );
                }

                return Container(
                  width: 360,
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade100,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              tooltip: 'إغلاق',
                            )
                          ],
                        ),
                      ),
                      body,
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
    final fajrTomorrow = _parseTodayTime(prayerTimes['fajr'])?.add(const Duration(days: 1));
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
          );
        }
      }
    }
  }

  String _formatDuration(Duration d) {
    final total = d.inMinutes;
    final h = total ~/ 60;
    final m = total % 60;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final scale = (screenHeight / 800).clamp(0.8, 1.0);
    // تطبيق تعويض التاريخ الهجري (إن وُجد)
    final hijri = HijriCalendar.fromDate(_now.add(Duration(days: _hijriOffset)));
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
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.of(context).push<Map<String, bool>>(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    initialBefore10: notifyBefore10,
                    initialAtTime: notifyAtTime,
                  ),
                ),
              );
              if (result != null) {
                setState(() {
                  notifyBefore10 = result['before10'] ?? notifyBefore10;
                  notifyAtTime = result['atTime'] ?? notifyAtTime;
                });
                await _savePrefs();
                // إعادة قراءة تعويض الهجري في حال تم الضغط على زر إعادة الضبط
                await _restorePrefs();
                await _scheduleNotificationsForToday();
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
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    border: Border.all(color: Colors.yellow.shade700, width: 1.5),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  padding: EdgeInsets.symmetric(
                      vertical: 10 * scale, horizontal: 24 * scale),
                  child: Text(
                    formatTime12(_now),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22 * scale,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  border: Border.all(color: Colors.red.shade700, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.symmetric(
                    vertical: 5 * scale, horizontal: 10 * scale),
                child:
                    Text(gDate, style: TextStyle(fontSize: 16 * scale)),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  border: Border.all(color: Colors.red.shade700, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.symmetric(
                    vertical: 5 * scale, horizontal: 10 * scale),
                child:
                    Text(hDate, style: TextStyle(fontSize: 16 * scale)),
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 8),
              const Divider(),
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
                        color: Colors.yellow.shade100,
                        border: Border.all(color: Colors.red.shade700, width: 1.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      child: Text(
                        'أوقات الصلاة ليوم $dayName',
                        style: TextStyle(fontSize: dayName == 'الجمعة' ? 18 : 20, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 4),

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
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.shade100,
                              border: Border.all(color: Colors.orange, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // يمين: اسم الصلاة (لأن اتجاه النص RTL)
                                Text(
                                  arabicLabels[key] ?? key,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                // يسار: الوقت
                                Text(
                                  prayerTimes[key] ?? '',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
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
                            color: Colors.greenAccent.shade100,
                            border: Border.all(color: Colors.orange, width: 2),
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
                    const SizedBox(height: 12),
                  // بطاقة العدّ التنازلي بسطر واحد: اسم الصلاة + الوقت
                  Builder(builder: (context) {
                    final nextInfo = _nextPrayerAndRemaining();
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade100,
                        border: Border.all(color: Colors.orange, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      child: nextInfo == null
                          ? const Text('...')
                          : Text(
                              'الوقت المتبقي للصلاة القادمة ${nextInfo.$1} ${_formatDuration(nextInfo.$2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                    );
                  }),
                  ],
                ),
                // بعد تحميل الأوقات لأول مرة، جدولة الإشعارات حسب الحالة
                FutureBuilder(
                  future: _scheduleNotificationsForToday(),
                  builder: (context, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}