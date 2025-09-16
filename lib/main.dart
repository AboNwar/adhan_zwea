// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hijri/hijri_calendar.dart';

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
    _loadPrayerTimes();
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

  @override
  Widget build(BuildContext context) {
    final hijri = HijriCalendar.fromDate(_now);
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  border: Border.all(color: Colors.red.shade700, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Text(
                  dayName,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  border: Border.all(color: Colors.red.shade700, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child:
                    Text(gDate, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  border: Border.all(color: Colors.red.shade700, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child:
                    Text(hDate, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  border: Border.all(color: Colors.yellow.shade700, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                child: Text(
                  formatTime12(_now),
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              const Text('أوقات الصلاة لليوم',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

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
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.shade100,
                              border: Border.all(color: Colors.orange, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 14),
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
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.shade100,
                            border: Border.all(color: Colors.orange, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 14),
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
                    const SizedBox(height: 36),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
