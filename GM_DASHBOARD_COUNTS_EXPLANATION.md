# 📊 شرح كيفية حساب Coaches و Medical Reps في GM Dashboard

## 🎯 **كيف يعمل النظام الآن (How It Works Now)**

### **1. Medical Reps (Total in system)**

**المصدر:** جدول `users` في Supabase

**الكود:**
```dart
final mrs = await SupabaseService.getAllMRs();
final totalMRs = mrs.length;
```

**ما يحدث:**
1. يتم استدعاء `SupabaseService.getAllMRs()`
2. يتم جلب جميع المستخدمين من جدول `users` حيث:
   - `role = 'mr'`
   - `status = 'active'`
3. يتم حساب العدد الإجمالي: `mrs.length`
4. يتم عرض العدد في الـ card: `'$totalMRs'`

**الاستعلام SQL (داخل SupabaseService):**
```sql
SELECT id, name, profile_picture_url, role, status
FROM users
WHERE role = 'mr' AND status = 'active'
ORDER BY name ASC;
```

---

### **2. Coaches (DM/FT/PM/MSL)**

**المصدر:** جدول `users` في Supabase

**الكود:**
```dart
final dms = await SupabaseService.getAllDMs();
final fts = await SupabaseService.getAllFTs();
final pms = await SupabaseService.getAllPMs();
final msls = await SupabaseService.getAllMSLs();

final totalCoaches = dms.length + fts.length + pms.length + msls.length;
```

**ما يحدث:**
1. يتم استدعاء 4 functions:
   - `getAllDMs()` - جلب جميع DMs
   - `getAllFTs()` - جلب جميع FTs
   - `getAllPMs()` - جلب جميع PMs
   - `getAllMSLs()` - جلب جميع MSLs
2. كل function تجلب المستخدمين من جدول `users` حيث:
   - `role = 'dm'/'ft'/'pm'/'msl'` (حسب الـ function)
   - `status = 'active'`
3. يتم جمع الأعداد: `dms.length + fts.length + pms.length + msls.length`
4. يتم عرض العدد في الـ card: `'$totalCoaches'`

**الاستعلامات SQL (داخل SupabaseService):**
```sql
-- For DMs:
SELECT * FROM users WHERE role = 'dm' AND status = 'active' ORDER BY name ASC;

-- For FTs:
SELECT * FROM users WHERE role = 'ft' AND status = 'active' ORDER BY name ASC;

-- For PMs:
SELECT * FROM users WHERE role = 'pm' AND status = 'active' ORDER BY name ASC;

-- For MSLs:
SELECT * FROM users WHERE role = 'msl' AND status = 'active' ORDER BY name ASC;
```

---

## 🔄 **متى يتم تحديث البيانات (When Data is Updated)**

### **1. عند تحميل Dashboard (initState):**
```dart
@override
void initState() {
  super.initState();
  _loadUsersCount(); // يتم استدعاؤها هنا
  // ...
}
```

### **2. عند تحديث التقارير (didUpdateWidget):**
```dart
@override
void didUpdateWidget(GMDashboardScreen oldWidget) {
  super.didUpdateWidget(oldWidget);
  // يتم تحديث البيانات عند تغيير التقارير
  if (oldWidget.allReports.length != widget.allReports.length) {
    _loadUsersCount();
  }
}
```

---

## 📝 **الملفات المعنية (Related Files)**

### **1. `lib/screens/gm/gm_dashboard_screen.dart`:**
- `_loadUsersCount()` - function لتحميل الأعداد من users table
- `_totalCoaches` - متغير لحفظ عدد Coaches
- `_totalMRs` - متغير لحفظ عدد MRs
- `build()` method - يستخدم `_totalCoaches` و `_totalMRs` لعرض الأرقام

### **2. `lib/services/supabase_service.dart`:**
- `getAllDMs()` - جلب جميع DMs من users table
- `getAllFTs()` - جلب جميع FTs من users table
- `getAllPMs()` - جلب جميع PMs من users table
- `getAllMSLs()` - جلب جميع MSLs من users table
- `getAllMRs()` - جلب جميع MRs من users table

---

## ✅ **التحقق من النجاح (Verification)**

### **اختبار 1: التحقق من الـ Logs**

عند فتح GM Dashboard، يجب أن ترى في الـ logs:

```
📊 Loading users count from users table...
   🔍 Fetching all coaches and MRs from users table...
👥 SupabaseService.getAllDMs() called
   Fetching DMs from users table...
   ✅ Got X DMs from Supabase
👥 SupabaseService.getAllFTs() called
   ✅ Got X FTs from Supabase
👥 SupabaseService.getAllPMs() called
   ✅ Got X PMs from Supabase
👥 SupabaseService.getAllMSLs() called
   ✅ Got X MSLs from Supabase
👥 SupabaseService.getAllMRs() called
   Fetching MRs from users table...
   ✅ Got X MRs from Supabase
   📊 Users count from users table:
      - DMs: X
      - FTs: X
      - PMs: X
      - MSLs: X
      - Total Coaches: X
      - Total MRs: X
   ✅ Updated state: _totalCoaches=X, _totalMRs=X
```

### **اختبار 2: التحقق من الـ UI**

1. افتح GM Dashboard
2. تحقق من الـ cards:
   - **Coaches**: يجب أن يعرض العدد الصحيح من users table
   - **Medical Reps**: يجب أن يعرض العدد الصحيح من users table

---

## 🔍 **Troubleshooting (حل المشاكل)**

### **المشكلة 1: الأرقام لا تتغير**

**التحقق:**
1. تحقق من الـ logs - هل `_loadUsersCount()` يتم استدعاؤها؟
2. تحقق من الـ logs - هل الـ functions تجلب البيانات بشكل صحيح؟
3. تحقق من RLS - هل GM يمكنه قراءة users table؟

**الحل:**
```sql
-- تحقق من RLS policies
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'users';

-- تحقق من أن GM يمكنه قراءة users
SELECT public.is_gm() as is_gm_result;
-- Should return: true
```

### **المشكلة 2: الأرقام = 0**

**التحقق:**
1. تحقق من وجود مستخدمين في users table:
   ```sql
   SELECT role, COUNT(*) FROM users WHERE status = 'active' GROUP BY role;
   ```
2. تحقق من أن RLS يسمح بقراءة users table
3. تحقق من الـ logs - هل هناك أخطاء؟

**الحل:**
- تأكد من تطبيق `fix_rls_complete_final.sql`
- تأكد من أن GM مسجل الدخول في Supabase Auth
- تحقق من الـ logs للبحث عن أخطاء

---

## 📚 **الخلاصة (Summary)**

### **Medical Reps:**
- ✅ يُحسب من `users` table مباشرة
- ✅ يجلب جميع المستخدمين بـ `role = 'mr'` و `status = 'active'`
- ✅ يعرض العدد الصحيح دائماً

### **Coaches:**
- ✅ يُحسب من `users` table مباشرة
- ✅ يجلب جميع المستخدمين بـ `role` في `['dm', 'ft', 'pm', 'msl']` و `status = 'active'`
- ✅ يجمع الأعداد: `DMs + FTs + PMs + MSLs`
- ✅ يعرض العدد الصحيح دائماً

---

**النظام الآن يعمل بشكل صحيح! 🎉**

