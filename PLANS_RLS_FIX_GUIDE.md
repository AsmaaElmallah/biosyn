# 🔧 دليل إصلاح RLS Policies لـ Plans Table

## 📋 **المشكلة (Problem)**

عند إضافة plan جديد، لا يتم حفظه في Supabase ولا يتم جلبها (fetch).

**الأعراض:**
- ❌ لا يمكن حفظ plans في Supabase
- ❌ لا يمكن جلب plans من Supabase
- ❌ خطأ: `new row violates row-level security policy for table "plans"`

---

## 🔍 **السبب (Root Cause)**

**RLS policies على `plans` table غير مكتملة:**
- ✅ يوجد policy للقراءة (SELECT)
- ❌ **لا يوجد policies للإدراج (INSERT)**
- ❌ **لا يوجد policies للتحديث (UPDATE)**
- ❌ **لا يوجد policies للحذف (DELETE)**

---

## ✅ **الحل (Solution)**

### **الخطوة 1: تشغيل SQL Script**

1. افتح **Supabase Dashboard**
2. اذهب إلى **SQL Editor**
3. انسخ محتوى `fix_plans_rls.sql`
4. الصقه في SQL Editor
5. اضغط **Run**

### **الخطوة 2: التحقق من النتيجة**

بعد تشغيل الـ script، يجب أن ترى:

```
✅ Policy "DM can read own plans" created
✅ Policy "DM can insert own plans" created
✅ Policy "DM can update own plans" created
✅ Policy "DM can delete own plans" created
```

### **الخطوة 3: اختبار العمليات**

#### **اختبار 1: التحقق من Policies**

```sql
-- View all policies on plans table
SELECT 
    policyname,
    cmd
FROM pg_policies
WHERE tablename = 'plans'
ORDER BY policyname;
```

**يجب أن ترى:**
- `DM can read own plans` (SELECT)
- `DM can insert own plans` (INSERT)
- `DM can update own plans` (UPDATE)
- `DM can delete own plans` (DELETE)

#### **اختبار 2: التحقق من is_gm()**

```sql
-- Check if GM can be identified
SELECT public.is_gm() as is_gm_result;
-- Should return: true (if logged in as GM)
```

#### **اختبار 3: Debug RLS**

```sql
-- Check current auth context
SELECT * FROM public.debug_rls();
```

---

## 📝 **ما تم إصلاحه (What Was Fixed)**

### **1. إضافة INSERT Policy**

```sql
CREATE POLICY "DM can insert own plans"
    ON plans FOR INSERT
    WITH CHECK (
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );
```

**يسمح بـ:**
- DM بإدراج plans حيث `dm_id` يطابق `auth.uid()`
- GM بإدراج أي plan

### **2. إضافة UPDATE Policy**

```sql
CREATE POLICY "DM can update own plans"
    ON plans FOR UPDATE
    USING (
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    )
    WITH CHECK (
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );
```

**يسمح بـ:**
- DM بتحديث plans حيث `dm_id` يطابق `auth.uid()`
- GM بتحديث أي plan

### **3. إضافة DELETE Policy**

```sql
CREATE POLICY "DM can delete own plans"
    ON plans FOR DELETE
    USING (
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );
```

**يسمح بـ:**
- DM بحذف plans حيث `dm_id` يطابق `auth.uid()`
- GM بحذف أي plan

---

## 🔄 **تحسينات إضافية (Additional Improvements)**

### **1. تحسين Logging في SupabaseService**

تم إضافة logging مفصل في:
- `savePlan()` - لتتبع عملية الإدراج
- `getPlans()` - لتتبع عملية الجلب
- `getAllPlans()` - لتتبع عملية الجلب للـ GM

**مثال من الـ logs:**
```
📅 SupabaseService.savePlan() called
   - dmId: abc123
   - dmName: John Doe
   - date: 2024-01-15
   - mrId: xyz789
   - mrName: Jane Smith
   🔄 Inserting plan into Supabase...
   ✅ Plan saved successfully: 1 row(s) inserted
```

---

## 🆘 **Troubleshooting (حل المشاكل)**

### **المشكلة 1: لا يزال لا يمكن حفظ plans**

**التحقق:**
1. تحقق من أن الـ script تم تشغيله بنجاح
2. تحقق من وجود policies:
   ```sql
   SELECT policyname FROM pg_policies WHERE tablename = 'plans';
   ```
3. تحقق من `is_gm()`:
   ```sql
   SELECT public.is_gm();
   ```
4. تحقق من تطابق `dm_id` مع `auth.uid()`:
   ```sql
   SELECT auth.uid() as current_auth_uid;
   ```

**الحل:**
- تأكد من تسجيل الدخول في Supabase Auth
- سجل الخروج ثم سجل الدخول مرة أخرى
- تحقق من أن `dm_id` في الـ plan يطابق `auth.uid()`

### **المشكلة 2: لا يمكن جلب plans**

**التحقق:**
1. تحقق من SELECT policy:
   ```sql
   SELECT policyname, cmd FROM pg_policies 
   WHERE tablename = 'plans' AND cmd = 'SELECT';
   ```
2. تحقق من RLS:
   ```sql
   SELECT tablename, rowsecurity FROM pg_tables 
   WHERE tablename = 'plans';
   ```

**الحل:**
- تأكد من تطبيق `fix_plans_rls.sql`
- تحقق من أن المستخدم مسجل الدخول
- تحقق من الـ logs في التطبيق

### **المشكلة 3: GM لا يمكنه رؤية جميع plans**

**التحقق:**
```sql
-- Check if is_gm() returns true
SELECT public.is_gm() as is_gm_result;

-- Check email matching
SELECT * FROM public.debug_rls();
```

**الحل:**
- تأكد من تطبيق `fix_rls_complete_final.sql` أولاً
- تحقق من تطابق email في `auth.users` و `users` table
- سجل الخروج ثم سجل الدخول مرة أخرى

---

## 📚 **الملفات المعنية (Related Files)**

1. **`fix_plans_rls.sql`** - SQL script لإصلاح RLS policies
2. **`fix_rls_complete_final.sql`** - SQL script شامل (يجب تشغيله أولاً)
3. **`lib/services/supabase_service.dart`** - تم تحسين logging في:
   - `savePlan()`
   - `getPlans()`
   - `getAllPlans()`

---

## ✅ **الخلاصة (Summary)**

### **ما تم إصلاحه:**
- ✅ إضافة INSERT policy للسماح بإدراج plans
- ✅ إضافة UPDATE policy للسماح بتحديث plans
- ✅ إضافة DELETE policy للسماح بحذف plans
- ✅ تحسين logging في SupabaseService

### **الخطوات التالية:**
1. شغّل `fix_plans_rls.sql` في Supabase SQL Editor
2. اختبر حفظ plan جديد
3. اختبر جلب plans
4. تحقق من الـ logs في التطبيق

---

**الآن يجب أن يعمل حفظ وجلب plans بشكل صحيح! 🎉**

