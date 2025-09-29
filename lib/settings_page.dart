import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'privacy_policy_page.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final bool initialBefore10;
  final bool initialAtTime;
  const SettingsPage({super.key, required this.initialBefore10, required this.initialAtTime});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool notifyBefore10;
  late bool notifyAtTime;
  static const String _hijriOffsetKey = 'hijri_offset';

  @override
  void initState() {
    super.initState();
    notifyBefore10 = widget.initialBefore10;
    notifyAtTime = widget.initialAtTime;
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
                Navigator.of(context).pop(<String, bool>{
                  'before10': notifyBefore10,
                  'atTime': notifyAtTime,
                });
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
                    const SnackBar(content: Text('تمت إعادة ضبط التاريخ الهجري إلى الافتراضي')),
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
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.teal),
                title: const Text('سياسة الخصوصية (رابط خارجي)'),
                subtitle: const Text('فتح الصفحة عبر GitHub'),
                onTap: () async {
                  const url = 'https://raw.githubusercontent.com/USERNAME/REPO/BRANCH/PRIVACY_POLICY.md';
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تعذر فتح الرابط')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


