import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'privacy_policy_page.dart';

class SettingsPage extends StatefulWidget {
  final bool initialBefore10;
  final bool initialAtTime;
  final bool initialSilentBeforeIqama;
  final Map<String, int> initialIqamaMinutes;
  const SettingsPage({
    super.key,
    required this.initialBefore10,
    required this.initialAtTime,
    required this.initialSilentBeforeIqama,
    required this.initialIqamaMinutes,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool notifyBefore10;
  late bool notifyAtTime;
  late bool silentBeforeIqama;
  late Map<String, int> iqamaMinutes;
  static const String _hijriOffsetKey = 'hijri_offset';

  @override
  void initState() {
    super.initState();
    notifyBefore10 = widget.initialBefore10;
    notifyAtTime = widget.initialAtTime;
    silentBeforeIqama = widget.initialSilentBeforeIqama;
    iqamaMinutes = Map<String, int>.from(widget.initialIqamaMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات التنبيهات'),
          backgroundColor: Colors.teal,
          actions: [
            TextButton(
              onPressed: () {
                final ret = <String, dynamic>{
                  'before10': notifyBefore10,
                  'atTime': notifyAtTime,
                  'silentBeforeIqama': silentBeforeIqama,
                };
                for (final k in iqamaMinutes.keys) {
                  ret['iqama_$k'] = iqamaMinutes[k];
                }
                Navigator.of(context).pop(ret);
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: SwitchListTile(
                title: const Text('تنبيه قبل 10 دقائق'),
                subtitle: const Text('إشعار عادي قبل 10 دقائق من وقت الصلاة'),
                value: notifyBefore10,
                onChanged: (v) => setState(() => notifyBefore10 = v),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.blue.shade50,
              child: SwitchListTile(
                title: const Text('تفعيل الصامت قبل نهاية الإقامة بـ5 دقائق'),
                subtitle: const Text(
                    'يعيد الصوت بعد الصلاة بـ10 دقائق (يتطلب إذن عدم الإزعاج)'),
                value: silentBeforeIqama,
                onChanged: (v) => setState(() => silentBeforeIqama = v),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ExpansionTile(
                initiallyExpanded: true,
                title: const Text('إعدادات إقامة الصلاة'),
                subtitle: const Text('اختر عدد دقائق الإقامة لكل صلاة'),
                children: [
                  for (final k in ['fajr', 'duhr', 'asr', 'maghrib', 'isha'])
                    ListTile(
                      title: Text(_labelFor(k)),
                      subtitle: Text('دقائق: ${iqamaMinutes[k] ?? 0}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final newVal = await _askForMinutes(
                              context, k, iqamaMinutes[k] ?? 0);
                          if (newVal != null) {
                            setState(() => iqamaMinutes[k] = newVal);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            Card(
              color: Colors.orange.shade50,
              child: SwitchListTile(
                title: const Text('تنبيه عند الأذان 🔊'),
                subtitle: const Text('إشعار مع صوت الأذان عند وقت الصلاة'),
                value: notifyAtTime,
                onChanged: (v) => setState(() => notifyAtTime = v),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.refresh, color: Colors.teal),
                title: const Text('إعادة ضبط التاريخ الهجري'),
                subtitle: const Text('إرجاع التعويض إلى صفر (تاريخ افتراضي)'),
                onTap: () async {
                  // حفظ التعويض بقيمة صفر
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt(_hijriOffsetKey, 0);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('تمت إعادة ضبط التاريخ الهجري إلى الافتراضي')),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.contact_mail, color: Colors.teal),
                title: const Text('اتصل بنا'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                        title: const Text('اتصل بنا'),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('مطور البرنامج: فارس النجرس ابو نوار'),
                            SizedBox(height: 6),
                            Text('البريد الإلكتروني: fares.85naa@gmail.com'),
                            SizedBox(height: 6),
                            Text('واتساب: 07801865105'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('إغلاق'),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.privacy_tip, color: Colors.teal),
                title: const Text('سياسة الخصوصية'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(String k) {
    switch (k) {
      case 'fajr':
        return 'الفجر';
      case 'duhr':
        return 'الظهر';
      case 'asr':
        return 'العصر';
      case 'maghrib':
        return 'المغرب';
      case 'isha':
        return 'العشاء';
      default:
        return k;
    }
  }

  Future<int?> _askForMinutes(
      BuildContext context, String key, int current) async {
    int val = current;
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('دقائق إقامة ${_labelFor(key)}'),
            content: StatefulBuilder(
              builder: (ctx2, setState) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() {
                      if (val > 0) val -= 1;
                    }),
                  ),
                  Text(val.toString(), style: const TextStyle(fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() {
                      val += 1;
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء')),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(val),
                  child: const Text('موافق')),
            ],
          ),
        );
      },
    );
  }
}
