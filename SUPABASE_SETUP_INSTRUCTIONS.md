# 📋 تعليمات إعداد Supabase - خطوة بخطوة

## 🚀 الخطوات السريعة

### **Step 1: إنشاء حساب Supabase (10 دقائق)**

1. اذهب إلى: **https://supabase.com**
2. اضغط **"Start your project"** أو **"Sign Up"**
3. سجل بحساب GitHub أو Email
4. اضغط **"New Project"**
5. املأ البيانات:
   - **Organization**: اختر أو أنشئ جديد
   - **Project Name**: `biosyn-coaching`
   - **Database Password**: (احفظها في مكان آمن!)
   - **Region**: اختر الأقرب (مثلاً: `West US` أو `Europe West`)
6. اضغط **"Create new project"**
7. انتظر 2-3 دقائق حتى يتم Setup

---

### **Step 2: الحصول على API Keys (5 دقائق)**

1. في Project Dashboard
2. اذهب إلى **Settings** (في الـ sidebar الأيسر)
3. اضغط **API**
4. ستجد:
   - **Project URL**: مثل `https://xxxxx.supabase.co`
   - **anon public key**: مثل `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
5. **انسخهم** واحفظهم

---

### **Step 3: إضافة Keys في Flutter (5 دقائق)**

1. افتح `lib/config/supabase_config.dart`
2. ضع الـ URL والـ Key:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://xxxxx.supabase.co'; // ضع URL هنا
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'; // ضع Key هنا
}
```

---

### **Step 4: إنشاء Database Tables (20 دقيقة)**

1. في Supabase Dashboard
2. اذهب إلى **SQL Editor** (في الـ sidebar)
3. اضغط **"New query"**
4. انسخ الكود من `SUPABASE_IMPLEMENTATION_GUIDE.md` (قسم Database Schema)
5. اضغط **"Run"** أو **Ctrl+Enter**
6. تأكد من نجاح العملية (ستظهر رسالة success)

---

### **Step 5: تثبيت Packages (5 دقائق)**

في Terminal:
```bash
flutter pub get
```

---

### **Step 6: Initialize Supabase (10 دقائق)**

1. افتح `lib/main.dart`
2. أضف في بداية الملف:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:biosyn_report_flutter/config/supabase_config.dart';
```

3. عدل `main()` function:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  runApp(const MyApp());
}
```

---

### **Step 7: Test Connection (5 دقائق)**

1. شغل التطبيق
2. إذا لم تظهر أخطاء = نجح الإعداد! ✅

---

## ✅ **قائمة التحقق (Checklist)**

- [ ] حساب Supabase تم إنشاؤه
- [ ] Project تم إنشاؤه
- [ ] API Keys تم نسخها
- [ ] Keys تم وضعها في `supabase_config.dart`
- [ ] Packages تم تثبيتها (`flutter pub get`)
- [ ] Supabase تم Initialize في `main.dart`
- [ ] Database Tables تم إنشاؤها
- [ ] التطبيق يعمل بدون أخطاء

---

## 🆘 **مشاكل شائعة وحلولها**

### **مشكلة: "Invalid API key"**
**الحل:** تأكد من نسخ الـ anon key كاملاً (طويل جداً)

### **مشكلة: "Connection refused"**
**الحل:** تأكد من الـ URL صحيح

### **مشكلة: "Table does not exist"**
**الحل:** تأكد من إنشاء Tables في SQL Editor

### **مشكلة: "Permission denied"**
**الحل:** اذهب إلى Settings → API → Row Level Security (RLS) وعدل الـ Policies

---

## 📚 **الخطوات التالية**

بعد إكمال Setup:
1. ✅ Test Save Report
2. ✅ Test Get Reports
3. ✅ Test Save Plan
4. ✅ Test Get Plans
5. ✅ Integration مع الكود الموجود

---

**هل تحتاج مساعدة في أي خطوة؟** 🚀

