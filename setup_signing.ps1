# إعداد توقيع أندرويد باستخدام my-release-key.jks المحلي
param(
    [string]$KeyStore = "my-release-key.jks",
    [string]$OutFile = "android/key.properties"
)

$keytool = "C:\Program Files\Java\jdk-21.0.10\bin\keytool.exe"
if (-not (Test-Path $keytool)) {
    $found = Get-ChildItem -Path "C:\Program Files\Java","C:\Program Files\Android\Android Studio\jbr" -Recurse -Filter keytool.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $keytool = $found.FullName } else { throw "لم يتم العثور على keytool. ثبّت Java JDK أولاً." }
}

if (-not (Test-Path $KeyStore)) { throw "ملف المفتاح غير موجود: $KeyStore" }

Write-Host "إعداد توقيع أندرويد" -ForegroundColor Cyan
Write-Host "ملف المفتاح: $KeyStore" -ForegroundColor Gray

$storePassword = Read-Host "كلمة مرور المفتاح (storePassword)" -AsSecureString
$storePasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword))

$keyAlias = Read-Host "اسم المفتاح (keyAlias)"
$keyPasswordInput = Read-Host "كلمة مرور المفتاح الفرعي (keyPassword) — اضغط Enter لاستخدام نفس storePassword" -AsSecureString
$keyPasswordPlain = if ($keyPasswordInput.Length -eq 0) {
    $storePasswordPlain
} else {
    [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPasswordInput))
}

Write-Host "التحقق من المفتاح..." -ForegroundColor Yellow
& $keytool -list -keystore $KeyStore -alias $keyAlias -storepass $storePasswordPlain -keypass $keyPasswordPlain 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "فشل التحقق من المفتاح. تأكد من كلمات المرور واسم المفتاح (keyAlias)."
}

$content = @"
storePassword=$storePasswordPlain
keyPassword=$keyPasswordPlain
keyAlias=$keyAlias
storeFile=../../my-release-key.jks
"@

Set-Content -Path $OutFile -Value $content -Encoding UTF8
Write-Host ""
Write-Host "تم إنشاء $OutFile بنجاح." -ForegroundColor Green
Write-Host "الملف محمي ولن يُرفع إلى Git." -ForegroundColor Green
