# 🔐 دليل تفعيل Row Level Security (RLS)

## ⚠️ **المشكلة الحالية:**

Supabase Security Advisor يظهر أن:
- **6 أخطاء (Errors)**: RLS غير مفعل على الجداول رغم وجود Policies
- **3 تحذيرات (Warnings)**: RLS غير مفعل في Public Schema

### **الخطر:**
- بدون RLS، أي شخص يعرف الـ `anon key` يمكنه الوصول لجميع البيانات
- البيانات غير محمية من الوصول غير المصرح به
- قد يتمكن المستخدمون من قراءة/تعديل/حذف بيانات غيرهم

---

## ✅ **الحل: تفعيل RLS**

### **الخطوة 1: فتح Supabase SQL Editor**

1. اذهب إلى Supabase Dashboard
2. اختر **SQL Editor** من القائمة الجانبية
3. اضغط **New Query**

### **الخطوة 2: تشغيل SQL Script**

انسخ والصق الكود من ملف `enable_rls.sql`:

```sql
-- Enable RLS on users table
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Enable RLS on reports table
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Enable RLS on plans table
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
```

### **الخطوة 3: التحقق من التفعيل**

بعد تشغيل الـ script، تحقق من أن RLS مفعل:

```sql
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' 
    AND tablename IN ('users', 'reports', 'plans')
ORDER BY tablename;
```

يجب أن ترى `rls_enabled = true` لجميع الجداول.

---

## 🔍 **التحقق من Policies**

بعد تفعيل RLS، تأكد من وجود Policies صحيحة:

### **1. Users Table Policies:**

```sql
-- View existing policies
SELECT * FROM pg_policies WHERE tablename = 'users';
```

يجب أن يكون لديك policies مثل:
- `Users can read their own data`
- `Users can update their own data`

### **2. Reports Table Policies:**

```sql
SELECT * FROM pg_policies WHERE tablename = 'reports';
```

يجب أن يكون لديك policies مثل:
- `Users can read reports they created`
- `Users can create reports`
- `GM can read all reports`

### **3. Plans Table Policies:**

```sql
SELECT * FROM pg_policies WHERE tablename = 'plans';
```

يجب أن يكون لديك policies مثل:
- `Users can read their own plans`
- `Users can create plans`
- `Users can update their own plans`

---

## ⚠️ **ملاحظات مهمة:**

### **1. بعد تفعيل RLS:**
- **جميع** العمليات على الجداول ستخضع للـ Policies
- إذا لم يكن لديك Policies صحيحة، قد يتوقف التطبيق عن العمل
- تأكد من اختبار التطبيق بعد التفعيل

### **2. إذا كان التطبيق لا يعمل بعد التفعيل:**

**الحل المؤقت (للتطوير فقط):**
```sql
-- ⚠️ WARNING: Only for development/testing
-- Disable RLS temporarily
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.plans DISABLE ROW LEVEL SECURITY;
```

**الحل الصحيح:**
- أضف Policies صحيحة لكل جدول
- تأكد من أن Policies تسمح بالعمليات المطلوبة

---

## 📋 **Policies الموصى بها:**

### **Users Table:**
```sql
-- Policy: Users can read their own data
CREATE POLICY "Users can read own data"
ON public.users
FOR SELECT
USING (auth.uid()::text = id);

-- Policy: Users can update their own data
CREATE POLICY "Users can update own data"
ON public.users
FOR UPDATE
USING (auth.uid()::text = id);
```

### **Reports Table:**
```sql
-- Policy: Users can read reports they created
CREATE POLICY "Users can read own reports"
ON public.reports
FOR SELECT
USING (dm_id = auth.uid()::text OR mr_id = auth.uid()::text);

-- Policy: Users can create reports
CREATE POLICY "Users can create reports"
ON public.reports
FOR INSERT
WITH CHECK (true); -- Adjust based on your needs

-- Policy: GM can read all reports
CREATE POLICY "GM can read all reports"
ON public.reports
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()::text
        AND role = 'gm'
    )
);
```

### **Plans Table:**
```sql
-- Policy: Users can read their own plans
CREATE POLICY "Users can read own plans"
ON public.plans
FOR SELECT
USING (dm_id = auth.uid()::text OR mr_id = auth.uid()::text);

-- Policy: Users can create plans
CREATE POLICY "Users can create plans"
ON public.plans
FOR INSERT
WITH CHECK (true); -- Adjust based on your needs
```

---

## ✅ **بعد التفعيل:**

1. **اختبر التطبيق:**
   - تسجيل الدخول
   - إنشاء report
   - قراءة reports
   - تحديث بيانات المستخدم

2. **تحقق من Security Advisor:**
   - اذهب إلى **Security Advisor** في Supabase
   - يجب أن تختفي الأخطاء والتحذيرات

3. **راقب الأخطاء:**
   - إذا ظهرت أخطاء في التطبيق، تحقق من Policies
   - قد تحتاج لتعديل Policies حسب احتياجاتك

---

## 🆘 **إذا واجهت مشاكل:**

1. **التطبيق لا يعمل بعد التفعيل:**
   - تحقق من Policies
   - تأكد من أن المستخدم مسجل دخول في Supabase Auth
   - راجع logs في Supabase Dashboard

2. **لا يمكن قراءة البيانات:**
   - أضف Policy للـ SELECT
   - تأكد من أن Policy صحيحة

3. **لا يمكن إدراج البيانات:**
   - أضف Policy للـ INSERT
   - تأكد من أن Policy تسمح بالعملية

---

## 📞 **الدعم:**

إذا واجهت مشاكل، راجع:
- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [Supabase Policies Guide](https://supabase.com/docs/guides/auth/row-level-security#policies)

