# 🔧 إصلاح مشكلة Update و Delete للمستخدمين

## ⚠️ **المشكلة:**

عند محاولة تعديل أو حذف أي مستخدم (DM, FT, PM, MSL)، يحدث خطأ:
```
Connection reset by peer
Failed to delete user
Failed to update user
```

### **السبب:**
- RLS policies تمنع UPDATE و DELETE على جدول `users`
- لا توجد policy للـ DELETE
- UPDATE policy قد لا تعمل بشكل صحيح

---

## ✅ **الحل:**

تم إضافة policies للـ UPDATE و DELETE في `fix_rls_recursion.sql`:

### **1. Policy للـ UPDATE:**
```sql
-- Policy: GM can update users
CREATE POLICY "GM can update users"
    ON users FOR UPDATE
    USING (public.is_gm())
    WITH CHECK (public.is_gm());
```

### **2. Policy للـ DELETE:**
```sql
-- Policy: GM can delete users
CREATE POLICY "GM can delete users"
    ON users FOR DELETE
    USING (public.is_gm());
```

---

## 🔧 **التنفيذ:**

### **الخطوة 1: فتح Supabase SQL Editor**

1. اذهب إلى Supabase Dashboard
2. اختر **SQL Editor** من القائمة الجانبية
3. اضغط **New Query**

### **الخطوة 2: تشغيل SQL Script**

انسخ والصق الكود التالي:

```sql
-- Policy: GM can update users (using helper function)
DROP POLICY IF EXISTS "GM can update users" ON users;
CREATE POLICY "GM can update users"
    ON users FOR UPDATE
    USING (public.is_gm())
    WITH CHECK (public.is_gm());

-- Policy: GM can delete users (using helper function)
DROP POLICY IF EXISTS "GM can delete users" ON users;
CREATE POLICY "GM can delete users"
    ON users FOR DELETE
    USING (public.is_gm());
```

**أو شغّل الكود المحدث من `fix_rls_recursion.sql`** (تم تحديثه ليشمل هذه الـ policies)

---

## 🔍 **التحقق من الإصلاح:**

### **1. اختبار التعديل:**

1. سجل دخول كـ **GM**
2. اذهب إلى **User Management**
3. اضغط **Edit** على أي مستخدم
4. عدّل البيانات واضغط **Save**
5. يجب أن يعمل بدون أخطاء ✅

### **2. اختبار الحذف:**

1. سجل دخول كـ **GM**
2. اذهب إلى **User Management**
3. اضغط **Delete** على أي مستخدم
4. أكد الحذف
5. يجب أن يعمل بدون أخطاء ✅

### **3. التحقق من Policies:**

```sql
-- View all policies on users table
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'users'
ORDER BY policyname;
```

**يجب أن ترى:**
- ✅ `GM can read all users` (SELECT)
- ✅ `GM can insert users` (INSERT)
- ✅ `GM can update users` (UPDATE) ← **محدث**
- ✅ `GM can delete users` (DELETE) ← **جديد**
- ✅ `Users can read own data` (SELECT)
- ✅ `Users can update own data` (UPDATE)
- ✅ `Allow username lookup for login` (SELECT)

---

## ⚠️ **ملاحظات مهمة:**

### **1. UPDATE Policy:**

**`USING` clause:**
- يحدد الصفوف التي يمكن تحديثها
- `public.is_gm()` يتحقق من أن المستخدم الحالي هو GM

**`WITH CHECK` clause:**
- يحدد القيم الجديدة المسموح بها بعد التحديث
- `public.is_gm()` يضمن أن GM فقط يمكنه التحديث

### **2. DELETE Policy:**

**`USING` clause:**
- يحدد الصفوف التي يمكن حذفها
- `public.is_gm()` يتحقق من أن المستخدم الحالي هو GM

---

## 🆘 **إذا استمرت المشكلة:**

### **1. تحقق من RLS:**

```sql
-- Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' 
    AND tablename = 'users';
```

**يجب أن ترى:** `rls_enabled = true`

### **2. تحقق من Function `is_gm()`:**

```sql
-- Test the helper function
SELECT 
    auth.uid() as current_user_id,
    public.is_gm() as is_gm_user;
```

**يجب أن ترى:**
- `current_user_id`: ID المستخدم الحالي
- `is_gm_user`: `true` إذا كان GM، `false` إذا لم يكن

### **3. تحقق من Policies:**

```sql
-- View all policies
SELECT * FROM pg_policies WHERE tablename = 'users';
```

**يجب أن ترى على الأقل:**
- `GM can update users`
- `GM can delete users`

### **4. تحقق من تسجيل الدخول:**

- تأكد من تسجيل الدخول كـ **GM**
- تأكد من أن `auth.uid()` يعيد ID المستخدم الصحيح

---

## ✅ **بعد الإصلاح:**

1. **اختبر التطبيق:**
   - تعديل مستخدم ✅
   - حذف مستخدم ✅
   - إنشاء مستخدم ✅
   - قراءة المستخدمين ✅

2. **تحقق من Logs:**
   - لا يجب أن ترى `Connection reset by peer`
   - لا يجب أن ترى `Failed to update user`
   - لا يجب أن ترى `Failed to delete user`

3. **راجع Security Advisor:**
   - يجب أن تختفي أخطاء RLS
   - يجب أن تبقى فقط التحذيرات (Warnings)

---

## 📞 **الدعم:**

إذا واجهت مشاكل:
- راجع [Supabase RLS Documentation](https://supabase.com/docs/guides/database/postgres/row-level-security)
- راجع [Supabase UPDATE/DELETE Policies](https://supabase.com/docs/guides/database/postgres/row-level-security#using-vs-with-check)

