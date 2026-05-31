# تشغيل Flutter من المشروع / Run Flutter from project

## مهم: لا تكتب `flutter clean` أو `flutter pub get` وحدها
Flutter غير مضاف إلى PATH، لذلك يجب أولاً تشغيل أحد الأمرين التاليين.

## الأسهل: تشغيل الملف .bat
من **PowerShell** (وأنت في مجلد المشروع `C:\src\dev\adhan_zwea`):

```powershell
.\scripts\flutter_here.bat
```

هذا يشغّل تلقائياً `flutter clean` ثم `flutter pub get`. لا حاجة لكتابة `flutter` بنفسك.

إذا أردت لاحقاً استخدام أوامر `flutter` يدوياً في نفس النافذة، فعّل المسار أولاً ثم استخدم flutter:

```powershell
$env:Path = "C:\src\dev\flutter\bin;" + $env:Path
flutter clean
flutter pub get
```

إذا كان مسار Flutter عندك مختلف، مرّر المسار للـ .bat:

```cmd
.\scripts\flutter_here.bat C:\path\to\flutter
```

---

## إذا ظهر خطأ "running scripts is disabled" أو "powershell is not recognized"
**استخدم الملف .bat** (لا يحتاج PowerShell):

```cmd
cd c:\src\dev\adhan_zwea
scripts\flutter_here.bat C:\flutter
```

أو من داخل PowerShell نفسها غيّر السياسة لمرة واحدة ثم شغّل السكربت:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\scripts\flutter_here.ps1 -FlutterPath "C:\flutter"
```

---

## إذا كان Flutter غير معروف في الطرفية (flutter: command not found)

### الطريقة 1: استخدام .bat مع مسار Flutter
```cmd
scripts\flutter_here.bat C:\flutter
```
غيّر `C:\flutter` إلى **مجلد Flutter** عندك (المجلد الذي بداخله مجلد `bin` وفيه الملف `flutter.bat`). إذا لا تعرف أين: ابحث في الجهاز عن الملف `flutter.bat` ثم استخدم اسم المجلد الأب لمجلد `bin`.

### الطريقة 2: تعيين FLUTTER_ROOT ثم تشغيل .bat
```cmd
set FLUTTER_ROOT=C:\flutter
scripts\flutter_here.bat
```

### الطريقة 3: إضافة Flutter إلى PATH بشكل دائم (مرة واحدة)
1. ابحث في Windows عن **"تعديل متغيرات البيئة"** أو **Environment Variables**.
2. في **متغيرات المستخدم** اختر **Path** ثم **تحرير**.
3. أضف سطراً جديداً: مسار مجلد **bin** الخاص بـ Flutter، مثلاً: `C:\flutter\bin`.
4. موافق وحفظ، ثم افتح طرفية جديدة ونفّذ:
   ```powershell
   cd c:\src\dev\adhan_zwea
   flutter clean
   flutter pub get
   ```

---

السكربت `flutter_here.ps1` يبحث تلقائياً عن Flutter في مسارات شائعة، ثم يشغّل `flutter clean` و `flutter pub get`. إذا لم يجده، استخدم الطريقة 1 أو 2 أعلاه.
