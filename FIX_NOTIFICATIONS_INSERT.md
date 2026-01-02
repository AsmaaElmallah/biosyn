# 🔧 إصلاح مشكلة إدراج الإشعارات (Fix Notifications INSERT Issue)

## 📋 **المشكلة (Problem)**

عند عمل submit للتقرير، لا تظهر إشعارات رغم عمل submit أكثر من مرة.

**السبب:** في `fix_rls_complete_final.sql`، يتم حذف policies على notifications table لكن **لا يتم إعادة إنشائها**.

---

## ✅ **الحل (Solution)**

تم إضافة policies على notifications table مباشرة في `fix_rls_complete_final.sql`.

### **السياسات المضافة:**

#### **1. SELECT Policy (قراءة الإشعارات):**
```sql
CREATE POLICY "Users can read their own notifications"
    ON notifications FOR SELECT
    USING (
        recipient_id::text = auth.uid()::text
        OR public.is_gm()
    );
```

#### **2. INSERT Policy (إدراج الإشعارات) - ⚠️ هذا هو الأهم:**
```sql
CREATE POLICY "Authenticated users can insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL
        OR public.is_gm()
    );
```

**هذه الـ policy هي التي تسمح بإدراج الإشعارات عند submit التقرير.**

#### **3. UPDATE Policy (تحديث الإشعارات):**
```sql
CREATE POLICY "Users can update their own notifications"
    ON notifications FOR UPDATE
    USING (
        recipient_id::text = auth.uid()::text
        OR public.is_gm()
    )
    WITH CHECK (
        recipient_id::text = auth.uid()::text
        OR public.is_gm()
    );
```

---

## 🔄 **الخطوات المطلوبة (Required Steps)**

### **الخطوة 1: تشغيل SQL Script المحدث**

1. افتح **Supabase Dashboard**
2. اذهب إلى **SQL Editor**
3. انسخ محتوى `fix_rls_complete_final.sql` (المحدث)
4. الصقه في SQL Editor
5. اضغط **Run**

### **الخطوة 2: التحقق من Policies**

بعد تشغيل الـ script، تحقق من وجود policies على notifications:

```sql
SELECT 
    policyname,
    cmd
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY policyname;
```

**يجب أن ترى:**
- ✅ `Users can read their own notifications` (SELECT)
- ✅ `Authenticated users can insert notifications` (INSERT) - **هذا هو الأهم**
- ✅ `Users can update their own notifications` (UPDATE)

### **الخطوة 3: اختبار الإشعارات**

1. سجل الخروج تماماً من التطبيق
2. سجل الدخول مرة أخرى
3. أنشئ تقرير جديد واعمل submit
4. تحقق من:
   - ✅ التقرير يُحفظ في Supabase
   - ✅ الإشعارات تُدرج في notifications table
   - ✅ GM يرى الإشعارات في Dashboard

---

## 🔍 **Troubleshooting (حل المشاكل)**

### **المشكلة 1: لا تزال الإشعارات لا تُدرج**

**التحقق:**
```sql
-- 1. تحقق من وجود INSERT policy
SELECT policyname, cmd FROM pg_policies 
WHERE tablename = 'notifications' AND cmd = 'INSERT';

-- 2. تحقق من auth.uid()
SELECT auth.uid() as current_auth_uid;

-- 3. تحقق من is_gm()
SELECT public.is_gm() as is_gm_result;
```

**الحل:**
- تأكد من تشغيل `fix_rls_complete_final.sql` المحدث
- تأكد من تسجيل الدخول في Supabase Auth
- سجل الخروج ثم سجل الدخول مرة أخرى

### **المشكلة 2: خطأ "new row violates row-level security policy"**

**السبب:** لا توجد INSERT policy على notifications table.

**الحل:**
- شغّل `fix_rls_complete_final.sql` المحدث
- أو شغّل `fix_reports_notifications_rls.sql` (يحتوي على نفس policies)

### **المشكلة 3: الإشعارات تُدرج لكن لا تظهر**

**التحقق:**
```sql
-- تحقق من وجود إشعارات في notifications table
SELECT COUNT(*) FROM notifications;

-- تحقق من recipient_id
SELECT recipient_id, sender_name, title, created_at 
FROM notifications 
ORDER BY created_at DESC 
LIMIT 10;
```

**الحل:**
- تحقق من أن `recipient_id` يطابق `auth.uid()` للمستخدم
- تحقق من SELECT policy

---

## 📝 **الملفات المحدثة**

1. **`fix_rls_complete_final.sql`** - تم إضافة policies على notifications table
2. **`FIX_NOTIFICATIONS_INSERT.md`** - هذا الملف (توثيق)

---

## ✅ **الخلاصة**

### **المشكلة:**
- ❌ `fix_rls_complete_final.sql` كان يحذف policies على notifications لكن لا يعيد إنشائها

### **الحل:**
- ✅ تم إضافة policies على notifications مباشرة في `fix_rls_complete_final.sql`
- ✅ INSERT policy تسمح بإدراج الإشعارات عند submit التقرير

### **الخطوات التالية:**
1. شغّل `fix_rls_complete_final.sql` المحدث
2. اختبر submit تقرير جديد
3. تحقق من ظهور الإشعارات

---

**الآن يجب أن تعمل الإشعارات بشكل صحيح! 🎉**

