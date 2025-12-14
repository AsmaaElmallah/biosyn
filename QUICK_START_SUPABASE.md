# 🚀 Quick Start - Supabase Integration

## ✅ **ما تم إعداده:**

1. ✅ **Packages** تم إضافتها في `pubspec.yaml`
2. ✅ **SupabaseService** تم إنشاؤه في `lib/services/supabase_service.dart`
3. ✅ **SupabaseConfig** تم إنشاؤه في `lib/config/supabase_config.dart`
4. ✅ **CoachingReport** تم تحديثه لدعم Supabase JSON

---

## 📋 **الخطوات التالية (5 خطوات فقط!):**

### **Step 1: إنشاء Supabase Project (10 دقائق)**

1. اذهب إلى: **https://supabase.com**
2. Sign Up (مجاني)
3. Create New Project
4. احفظ:
   - Project URL
   - Database Password

### **Step 2: الحصول على API Keys (5 دقائق)**

1. Settings → API
2. انسخ:
   - **Project URL**
   - **anon public key**

### **Step 3: إضافة Keys في Flutter (5 دقائق)**

افتح `lib/config/supabase_config.dart` وعدل:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://xxxxx.supabase.co'; // ضع URL هنا
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'; // ضع Key هنا
}
```

### **Step 4: إنشاء Database Tables (20 دقيقة)**

1. في Supabase Dashboard → **SQL Editor**
2. انسخ الكود من `SUPABASE_IMPLEMENTATION_GUIDE.md` (قسم Database Schema)
3. اضغط **Run**

### **Step 5: Initialize في main.dart (10 دقائق)**

أضف في `lib/main.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:biosyn_report_flutter/config/supabase_config.dart';

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

## 🎯 **بعد الإعداد:**

### **استخدام SupabaseService:**

```dart
// Save Report
await SupabaseService.saveReport(report);

// Get Reports
final reports = await SupabaseService.getReports(dmId);

// Save Plan
await SupabaseService.savePlan(
  dmId: dmId,
  dmName: dmName,
  date: date,
  mrId: mrId,
  mrName: mrName,
);

// Get Plans
final plans = await SupabaseService.getPlans(dmId);
```

---

## 📚 **الملفات المهمة:**

- `SUPABASE_IMPLEMENTATION_GUIDE.md` - دليل شامل
- `SUPABASE_SETUP_INSTRUCTIONS.md` - تعليمات Setup
- `lib/services/supabase_service.dart` - Service للـ Supabase
- `lib/config/supabase_config.dart` - Configuration

---

## ✅ **قائمة التحقق:**

- [ ] Supabase Project تم إنشاؤه
- [ ] API Keys تم نسخها
- [ ] Keys تم وضعها في `supabase_config.dart`
- [ ] Database Tables تم إنشاؤها
- [ ] Supabase تم Initialize في `main.dart`
- [ ] `flutter pub get` تم تنفيذه
- [ ] التطبيق يعمل بدون أخطاء

---

**جاهز للبدء!** 🚀

