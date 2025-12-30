# 🔧 تعليمات الإعداد - Biosyn Coaching App
## Setup Instructions for Client

---

## 📋 **المتطلبات (Requirements)**

### **للعميل (Client Side):**
- ✅ حساب Supabase (مجاني أو مدفوع)
- ✅ Android Device (للتثبيت المباشر)
- ✅ أو Google Play Developer Account (لرفع على Play Store)

### **للمطور (Developer Side):**
- ✅ Flutter SDK
- ✅ Android Studio / Xcode
- ✅ Supabase Project

---

## 🗄️ **الخطوة 1: إعداد Supabase (Supabase Setup)**

### **1.1 إنشاء Project جديد:**

1. اذهب إلى: https://supabase.com
2. Sign In / Sign Up
3. اضغط **"New Project"**
4. أدخل:
   - **Project Name**: `biosyn-coaching-app`
   - **Database Password**: (اختر كلمة مرور قوية واحفظها)
   - **Region**: اختر الأقرب لموقعك
5. اضغط **"Create new project"**
6. انتظر حتى يكتمل Setup (2-3 دقائق)

### **1.2 الحصول على API Credentials:**

1. بعد اكتمال Setup، اذهب إلى **Settings** → **API**
2. انسخ المعلومات التالية:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon public key**: `eyJhbGc...`
   - **service_role key**: `eyJhbGc...` (احتفظ به آمن - لا تشاركه)

### **1.3 تشغيل Database Schema:**

1. اذهب إلى **SQL Editor** في Supabase Dashboard
2. افتح ملف `supabase_schema.sql` من المشروع
3. انسخ **كل** محتوى الملف
4. الصقه في SQL Editor
5. اضغط **"Run"** أو **F5**
6. انتظر حتى يكتمل (يجب أن ترى "Success")

### **1.4 التحقق من الجداول:**

1. اذهب إلى **Table Editor**
2. تحقق من وجود الجداول التالية:
   - ✅ `users`
   - ✅ `reports`
   - ✅ `plans`
   - ✅ `notifications`

### **1.5 إعداد Storage:**

1. اذهب إلى **Storage**
2. تحقق من وجود Bucket: `user-profiles`
3. إن لم يكن موجوداً:
   - اضغط **"New bucket"**
   - Name: `user-profiles`
   - Public: ✅ (مفعل)
   - اضغط **"Create bucket"**

### **1.6 إعداد Authentication:**

1. اذهب إلى **Authentication** → **Settings**
2. ابحث عن **"Enable email confirmations"**
3. **عطّل** هذا الخيار (Toggle OFF)
4. احفظ التغييرات

---

## 📱 **الخطوة 2: إعداد التطبيق (App Configuration)**

### **2.1 تحديث Supabase Credentials:**

1. افتح المشروع في Flutter
2. اذهب إلى `lib/config/supabase_config.dart`
3. حدث القيم التالية:
   ```dart
   static const String supabaseUrl = 'YOUR_PROJECT_URL';
   static const String supabaseAnonKey = 'YOUR_ANON_KEY';
   ```

### **2.2 اختبار الاتصال:**

1. شغّل التطبيق
2. جرب تسجيل الدخول
3. تحقق من أن البيانات تظهر في Supabase Dashboard

---

## 🏗️ **الخطوة 3: بناء التطبيق (Build Application)**

### **3.1 لـ Android (APK):**

```bash
# في Terminal
cd "path/to/project"
flutter clean
flutter pub get
flutter build apk --release
```

**الملف الناتج:**
- `build/app/outputs/flutter-apk/app-release.apk`

### **3.2 لـ Android (AAB - لـ Play Store):**

```bash
flutter build appbundle --release
```

**الملف الناتج:**
- `build/app/outputs/bundle/release/app-release.aab`

### **3.3 لـ iOS:**

```bash
flutter build ios --release
```

ثم في Xcode:
1. افتح `ios/Runner.xcworkspace`
2. Product → Archive
3. Distribute App

---

## 📦 **الخطوة 4: التثبيت (Installation)**

### **لـ Android (APK):**

1. **على الهاتف:**
   - اذهب إلى Settings → Security
   - فعّل **"Unknown Sources"** أو **"Install from Unknown Sources"**

2. **نقل APK:**
   - انسخ `app-release.apk` إلى الهاتف
   - أو أرسله عبر Email/WhatsApp

3. **التثبيت:**
   - اضغط على APK
   - اضغط **"Install"**
   - انتظر حتى يكتمل التثبيت

4. **الفتح:**
   - اضغط **"Open"** أو ابحث عن "Biosyn Coaching App"

### **لـ Google Play Store:**

1. **إنشاء حساب Developer:**
   - اذهب إلى https://play.google.com/console
   - ادفع $25 (رسوم لمرة واحدة)
   - أكمل التسجيل

2. **رفع التطبيق:**
   - Create App
   - ارفع `app-release.aab`
   - أكمل Store Listing
   - Submit for Review

---

## 👤 **الخطوة 5: إنشاء المستخدمين (Create Users)**

### **5.1 إنشاء GM (General Manager):**

1. افتح التطبيق
2. اختر **"General Manager"**
3. سجل دخول (أو أنشئ حساب جديد)
4. اذهب إلى **User Management**
5. اضغط **"Add User"**
6. اختر Role: **GM**
7. أدخل البيانات:
   - Name: `Admin`
   - Username: `admin`
   - Password: `[اختر كلمة مرور قوية]`
8. احفظ

### **5.2 إنشاء DMs, PMs, MSLs:**

1. من GM Dashboard
2. اذهب إلى **User Management**
3. اضغط **"Add User"**
4. اختر Role المناسب
5. أدخل البيانات
6. احفظ

---

## ✅ **التحقق من الإعداد (Verification)**

### **اختبارات أساسية:**

1. ✅ **Login Test:**
   - جرب تسجيل الدخول بجميع الأدوار
   - تحقق من Navigation الصحيح

2. ✅ **Create Report Test:**
   - أنشئ تقرير جديد
   - تحقق من ظهوره في Dashboard

3. ✅ **Create Plan Test:**
   - أنشئ خطة جديدة
   - تحقق من ظهورها في View Plans

4. ✅ **Dashboard Test:**
   - تحقق من ظهور الإحصائيات
   - تحقق من Charts

5. ✅ **Export Test:**
   - جرب Export Report
   - تحقق من إنشاء الملف

---

## 🔐 **الأمان (Security)**

### **⚠️ مهم جداً:**

1. **غير جميع Passwords الافتراضية**
2. **احتفظ بـ service_role key آمن** (لا تشاركه)
3. **فعّل RLS Policies** في Supabase
4. **راجع Permissions** في AndroidManifest.xml

---

## 📞 **الدعم (Support)**

### **في حالة وجود مشاكل:**

1. **تحقق من Logs:**
   - في Flutter: `flutter logs`
   - في Supabase: Dashboard → Logs

2. **تحقق من الاتصال:**
   - تحقق من Internet Connection
   - تحقق من Supabase Status

3. **تحقق من Credentials:**
   - تأكد من صحة Supabase URL و Key
   - تأكد من تشغيل Database Schema

---

## 🎉 **الخلاصة**

بعد إكمال جميع الخطوات:
- ✅ Supabase جاهز
- ✅ Database Schema جاهز
- ✅ التطبيق مبني
- ✅ التطبيق مثبت
- ✅ المستخدمون جاهزون

**التطبيق جاهز للاستخدام!** 🚀

