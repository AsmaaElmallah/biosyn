# 🔧 حل مشكلة تسجيل الدخول - "المحتوى المطلوب غير موجود"
## Login Troubleshooting Guide

---

## ❌ **المشكلة:**
عند محاولة تسجيل الدخول، تظهر رسالة الخطأ:
**"المحتوى المطلوب غير موجود"**

---

## 🔍 **الأسباب المحتملة:**

### **1. المستخدم غير موجود في قاعدة البيانات**
- المستخدم "gm" غير موجود في جدول `users` في Supabase
- أو اسم المستخدم مختلف (مثلاً: "GM" بدلاً من "gm")

### **2. مشكلة في الاتصال بـ Supabase**
- لا يوجد اتصال بالإنترنت
- Supabase Project غير متاح أو تم إيقافه
- إعدادات Supabase غير صحيحة

### **3. مشكلة في قاعدة البيانات**
- جدول `users` غير موجود
- الصلاحيات (RLS) تمنع الوصول

---

## ✅ **الحلول:**

### **الحل 1: التحقق من وجود المستخدم في Supabase**

1. افتح Supabase Dashboard
2. اذهب إلى **Table Editor** → **users**
3. تحقق من وجود المستخدم:
   - Username: `gm`
   - Password: `admin123`
   - Status: `active`

**إذا لم يكن المستخدم موجوداً:**
- أنشئ المستخدم يدوياً في Supabase
- أو استخدم شاشة "User Management" في التطبيق (تتطلب تسجيل دخول GM)

---

### **الحل 2: التحقق من إعدادات Supabase**

1. افتح `lib/config/supabase_config.dart`
2. تحقق من:
   ```dart
   static const String supabaseUrl = 'https://noiuxsaajphioculuvhx.supabase.co';
   static const String supabaseAnonKey = '...';
   ```

3. تأكد من أن:
   - URL صحيح
   - Anon Key صحيح
   - Supabase Project نشط

---

### **الحل 3: إنشاء المستخدم يدوياً في Supabase**

**في Supabase Dashboard:**

1. اذهب إلى **Table Editor** → **users**
2. اضغط **Insert** → **Insert row**
3. أدخل البيانات:
   ```json
   {
     "username": "gm",
     "password": "admin123",
     "name": "General Manager",
     "role": "gm",
     "email": "gm@biosyn.com",
     "status": "active"
   }
   ```
4. احفظ

---

### **الحل 4: التحقق من الصلاحيات (RLS)**

1. في Supabase Dashboard
2. اذهب إلى **Authentication** → **Policies**
3. تحقق من أن جدول `users` لديه:
   - **Policy للقراءة (SELECT)** للجميع (anon)
   - أو على الأقل للقراءة بدون قيود

**مثال Policy:**
```sql
CREATE POLICY "Allow anonymous read access to users"
ON users FOR SELECT
TO anon
USING (true);
```

---

### **الحل 5: اختبار الاتصال**

**في التطبيق:**
1. تأكد من وجود اتصال بالإنترنت
2. حاول تسجيل الدخول مرة أخرى
3. راجع Console Logs (في Debug Mode) لرؤية الأخطاء التفصيلية

---

## 📋 **قائمة التحقق (Checklist):**

- [ ] المستخدم موجود في جدول `users` في Supabase
- [ ] اسم المستخدم صحيح (case-sensitive)
- [ ] كلمة المرور صحيحة
- [ ] Status = `active`
- [ ] Supabase URL صحيح
- [ ] Supabase Anon Key صحيح
- [ ] اتصال الإنترنت يعمل
- [ ] RLS Policies تسمح بالقراءة

---

## 🐛 **Debug Mode:**

لرؤية الأخطاء التفصيلية:

1. افتح التطبيق في Debug Mode
2. شاهد Console Logs
3. ابحث عن:
   - `🔐 SupabaseService.signIn() called`
   - `🔍 Searching for user: ...`
   - `❌ User not found` أو `✅ User found`

---

## 📞 **إذا استمرت المشكلة:**

1. تحقق من Console Logs
2. تحقق من Supabase Dashboard → Logs
3. تأكد من أن Supabase Project نشط
4. جرب إنشاء مستخدم جديد في Supabase

---

## ✅ **بعد إصلاح المشكلة:**

1. أعد بناء APK:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

2. اختبر تسجيل الدخول مرة أخرى

---

## 📝 **ملاحظات:**

- **اسم المستخدم حساس لحالة الأحرف (case-sensitive)**
- **كلمة المرور يجب أن تطابق تماماً**
- **Status يجب أن يكون `active`**
- **يجب أن يكون هناك اتصال بالإنترنت**

---

**جاهز!** 🚀

