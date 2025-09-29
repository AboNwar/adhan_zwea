import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سياسة الخصوصية'),
          backgroundColor: Colors.teal,
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سياسة الخصوصية - أذان الزوية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'آخر تحديث: 2025-09-29',
                style: TextStyle(color: Colors.black54),
              ),
              SizedBox(height: 16),
              Text(
                'نحن نحترم خصوصيتك. يوضح هذا المستند كيفية تعامل تطبيق "أذان الزوية" مع البيانات والأذونات.',
              ),
              SizedBox(height: 16),
              Text('1) البيانات التي نجمعها', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('''
- لا نقوم بجمع أو تخزين أي بيانات شخصية حساسة عنك.
- لا نقوم بإنشاء حسابات أو تتبّع المستخدمين.
- لا نشارك أي بيانات مع أطراف خارجية لأغراض التسويق.
'''),
              SizedBox(height: 16),
              Text('2) البيانات المخزنة محليًا على جهازك', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('''
- إعدادات الإشعارات (تشغيل/تعطيل).
- تفضيل تشغيل صوت الأذان عند وقت الصلاة.
- تعويض التاريخ الهجري (إن تم تغييره).

هذه البيانات تبقى محليًا على جهازك عبر SharedPreferences، ويمكنك حذفها بإزالة التطبيق أو مسح بياناته.
'''),
              SizedBox(height: 16),
              Text('3) الأذونات المستخدمة ولماذا', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('''
- POST_NOTIFICATIONS: لإظهار الإشعارات.
- SCHEDULE_EXACT_ALARM (أندرويد): لجدولة الأذان في وقت دقيق.
- VIBRATE و WAKE_LOCK و USE_FULL_SCREEN_INTENT (أندرويد): لتحسين موثوقية الإشعار والصوت.
- لا نستخدم الموقع أو جهات الاتصال أو الميكروفون أو الكاميرا.
'''),
              SizedBox(height: 16),
              Text('4) خدمات وأطراف خارجية', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'لا يتضمن التطبيق حزمًا تجمع بيانات شخصية بغرض التحليل أو الإعلانات. يتم تشغيل الصوت محليًا، وأوقات الصلاة تُحمّل من ملفات داخلية ضمن التطبيق.',
              ),
              SizedBox(height: 16),
              Text('5) الأطفال', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'التطبيق مناسب للعائلة ولا يجمع بيانات تعريفية عن الأطفال.',
              ),
              SizedBox(height: 16),
              Text('6) الاحتفاظ بالبيانات', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('لا نحتفظ ببيانات على خوادم. الإعدادات تُخزن محليًا ويمكن حذفها بمسح بيانات التطبيق.'),
              SizedBox(height: 16),
              Text('7) الأمان', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('لا توجد عمليات نقل بيانات إلى خادم. نعتمد على طبقات الأمان الأساسية للنظام.'),
              SizedBox(height: 16),
              Text('8) التغييرات على هذه السياسة', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('قد نقوم بتحديث هذه السياسة. سيظهر تاريخ آخر تحديث أعلاه.'),
              SizedBox(height: 16),
              Text('9) معلومات المطوّر والتواصل', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'مطور البرنامج: فارس النجرس ابو نوار\nالبريد الإلكتروني: fares.85naa@gmail.com\nواتساب: 07801865105',
              ),
              SizedBox(height: 24),
              Text(
                'ملخص نموذج خصوصية المتاجر (للمستخدم):\n- جمع البيانات: لا نجمع بيانات شخصية.\n- مشاركة البيانات: لا نشارك بيانات.\n- معالجة على الجهاز: نعم، الإعدادات على الجهاز فقط.\n- البيانات الحساسة: غير مطلوبة.',
                style: TextStyle(color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


