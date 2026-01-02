# 🔧 إصلاح خطأ RLS Recursion

## ⚠️ **المشكلة:**

```
infinite recursion detected in policy for relation "users"
```

### **السبب:**
Policies على جدول `users` تحاول قراءة من جدول `users` نفسه:

```sql
CREATE POLICY "GM can read all users"
    ON users FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users  -- ❌ هنا المشكلة!
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    );
```

**ما يحدث:**
1. Policy تحاول قراءة `users` للتحقق من role
2. لكن قراءة `users` تحتاج للتحقق من Policy
3. Policy تحاول قراءة `users` مرة أخرى...
4. **Recursion لا نهائي!** ♾️

---

## ✅ **الحل:**

### **الخطوة 1: فتح Supabase SQL Editor**

1. اذهب إلى Supabase Dashboard
2. اختر **SQL Editor** من القائمة الجانبية
3. اضغط **New Query**

### **الخطوة 2: تشغيل Script الإصلاح**

انسخ والصق الكود من ملف `fix_rls_recursion.sql`:

```sql
-- Step 1: Drop problematic policies
DROP POLICY IF EXISTS "GM can read all users" ON users;
DROP POLICY IF EXISTS "GM can insert users" ON users;
DROP POLICY IF EXISTS "GM can update users" ON users;
DROP POLICY IF EXISTS "DM can read own plans" ON plans;
DROP POLICY IF EXISTS "DM can read own reports" ON reports;

-- Step 2: Create helper function
CREATE OR REPLACE FUNCTION public.is_gm()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role
    FROM public.users
    WHERE id::text = auth.uid()::text
    LIMIT 1;
    
    RETURN COALESCE(user_role = 'gm', false);
END;
$$;

-- Step 3: Create fixed policies
CREATE POLICY "GM can read all users"
    ON users FOR SELECT
    USING (public.is_gm());
```

### **الخطوة 3: التحقق من الإصلاح**

بعد تشغيل الـ script، اختبر:

```sql
-- Test the helper function
SELECT 
    auth.uid() as current_user_id,
    public.is_gm() as is_gm_user;
```

**يجب أن ترى:**
- `current_user_id`: ID المستخدم الحالي
- `is_gm_user`: `true` إذا كان GM، `false` إذا لم يكن

---

## 🔍 **كيف يعمل الحل:**

### **1. Helper Function `is_gm()`:**

```sql
CREATE OR REPLACE FUNCTION public.is_gm()
RETURNS BOOLEAN
SECURITY DEFINER  -- ✅ يسمح بتجاوز RLS
SET search_path = public  -- ✅ يمنع SQL Injection
```

**المميزات:**
- ✅ **`SECURITY DEFINER`**: Function تعمل بصلاحيات منشئها، تسمح بتجاوز RLS
- ✅ **`SET search_path`**: يحدد مسار البحث، يمنع SQL Injection
- ✅ **`STABLE`**: Function لا تغير البيانات، يمكن تحسينها

**كيف يمنع Recursion:**
- Function تستخدم `SECURITY DEFINER`، لذلك لا تخضع لـ RLS
- يمكنها قراءة `users` مباشرة بدون التحقق من Policies
- لا يوجد recursion!

### **2. Fixed Policies:**

```sql
CREATE POLICY "GM can read all users"
    ON users FOR SELECT
    USING (public.is_gm());  -- ✅ استخدام function بدلاً من SELECT مباشر
```

**بدلاً من:**
```sql
-- ❌ يسبب recursion
EXISTS (SELECT 1 FROM users WHERE ...)
```

**نستخدم:**
```sql
-- ✅ لا يسبب recursion
public.is_gm()
```

---

## 📋 **Policies المحدثة:**

### **Users Table:**
- ✅ `Users can read own data` - المستخدم يقرأ بياناته
- ✅ `GM can read all users` - GM يقرأ جميع المستخدمين
- ✅ `GM can insert users` - GM يضيف مستخدمين
- ✅ `GM can update users` - GM يحدث مستخدمين
- ✅ `Users can update own data` - المستخدم يحدث بياناته

### **Plans Table:**
- ✅ `DM can read own plans` - DM يقرأ خططه أو GM يقرأ الجميع

### **Reports Table:**
- ✅ `DM can read own reports` - DM يقرأ تقاريره أو GM يقرأ الجميع

---

## 🧪 **اختبار الإصلاح:**

### **1. اختبار تسجيل الدخول:**

1. شغّل التطبيق
2. سجل دخول كـ **GM**
3. يجب أن يعمل بدون أخطاء ✅

### **2. اختبار قراءة البيانات:**

```sql
-- يجب أن يعمل بدون recursion error
SELECT * FROM users;
```

### **3. اختبار إنشاء Report:**

1. سجل دخول كـ **DM**
2. أنشئ report جديد
3. يجب أن يعمل بدون أخطاء ✅

---

## ⚠️ **ملاحظات مهمة:**

### **1. Function `is_gm()`:**
- Function تستخدم `SECURITY DEFINER`، لذلك يجب التأكد من أمانها
- Function تستخدم `SET search_path = public` لمنع SQL Injection
- Function `STABLE`، لذلك يمكن تحسينها

### **2. إذا استمرت المشكلة:**

**تحقق من:**
```sql
-- تحقق من وجود function
SELECT * FROM pg_proc WHERE proname = 'is_gm';

-- تحقق من policies
SELECT * FROM pg_policies WHERE tablename = 'users';
```

**إذا لم تعمل:**
- تأكد من تشغيل الـ script بالكامل
- تحقق من وجود أخطاء في SQL Editor
- راجع logs في Supabase Dashboard

---

## 🆘 **إذا واجهت مشاكل:**

### **1. Function لا تعمل:**

```sql
-- أعد إنشاء function
DROP FUNCTION IF EXISTS public.is_gm();
-- ثم شغّل الكود من fix_rls_recursion.sql مرة أخرى
```

### **2. Policies لا تعمل:**

```sql
-- تحقق من وجود policies
SELECT * FROM pg_policies WHERE tablename = 'users';

-- إذا لم توجد، شغّل الكود مرة أخرى
```

### **3. لا يزال هناك recursion:**

- تأكد من حذف جميع الـ policies القديمة
- تحقق من عدم وجود policies أخرى تستخدم `SELECT FROM users` داخل policy على `users`

---

## ✅ **بعد الإصلاح:**

1. **اختبر التطبيق:**
   - تسجيل الدخول ✅
   - قراءة البيانات ✅
   - إنشاء reports ✅
   - تحديث البيانات ✅

2. **تحقق من Logs:**
   - لا يجب أن ترى `infinite recursion` error
   - التطبيق يجب أن يعمل بشكل طبيعي

3. **راجع Security Advisor:**
   - يجب أن تختفي أخطاء RLS
   - يجب أن تبقى فقط التحذيرات (Warnings) التي يمكن إصلاحها لاحقاً

---

## 📞 **الدعم:**

إذا واجهت مشاكل:
- راجع [Supabase RLS Documentation](https://supabase.com/docs/guides/database/postgres/row-level-security)
- راجع [Supabase Functions Documentation](https://supabase.com/docs/guides/database/postgres/functions)

