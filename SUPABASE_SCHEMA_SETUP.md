# 🗄️ Supabase Database Schema Setup Guide

## 📋 **دليل إعداد Database Schema في Supabase**

هذا الدليل يشرح كيفية إعداد Database Schema للتطبيق خطوة بخطوة.

---

## ✅ **قبل البدء**

تأكد من:
- [ ] حساب Supabase تم إنشاؤه
- [ ] Project تم إنشاؤه في Supabase
- [ ] API Keys تم نسخها

---

## 🚀 **الخطوات (5 دقائق فقط!)**

### **Step 1: فتح SQL Editor**

1. اذهب إلى **Supabase Dashboard**
2. اختر **Project** الخاص بك
3. في الـ Sidebar الأيسر، اضغط على **SQL Editor**
4. اضغط **New query**

---

### **Step 2: نسخ Schema**

1. افتح ملف `supabase_schema.sql` في المشروع
2. انسخ **كل المحتوى** (Ctrl+A ثم Ctrl+C)
3. الصقه في **SQL Editor** في Supabase

---

### **Step 3: تشغيل Schema**

1. اضغط **Run** أو **Ctrl+Enter**
2. انتظر حتى تظهر رسالة **Success**
3. تأكد من عدم وجود أخطاء

---

### **Step 4: التحقق من الجداول**

1. اذهب إلى **Table Editor** في الـ Sidebar
2. يجب أن ترى 3 جداول:
   - ✅ `users`
   - ✅ `plans`
   - ✅ `reports`

---

### **Step 5: التحقق من RLS Policies**

1. اذهب إلى **Authentication** → **Policies**
2. يجب أن ترى Policies لكل جدول:
   - `users`: 4 policies
   - `plans`: 4 policies
   - `reports`: 4 policies

---

## 📊 **ما تم إنشاؤه**

### **1. Tables (3 جداول)**

#### **users**
- `id` (UUID, Primary Key)
- `name`, `username`, `email`
- `password`, `password_hash`
- `role` (dm, gm, mr)
- `status` (active, inactive)
- `created_at`, `updated_at`

#### **plans**
- `id` (UUID, Primary Key)
- `dm_id`, `dm_name`
- `date`, `mr_id`, `mr_name`
- `status` (pending, completed, cancelled)
- `created_at`, `updated_at`

#### **reports**
- `id` (UUID, Primary Key)
- `date`, `dm_id`, `dm_name`, `mr_id`, `mr_name`
- جميع حقول الكوتشينج (punctuality, dress_code, etc.)
- `strengths`, `improvements`
- `average_score`, `synced`
- `created_at`, `updated_at`

---

### **2. Indexes (10 indexes)**

للأداء السريع:
- `idx_reports_dm_id`
- `idx_reports_date`
- `idx_reports_mr_id`
- `idx_reports_dm_date` (composite)
- `idx_plans_dm_id`
- `idx_plans_date`
- `idx_plans_dm_date` (composite)
- `idx_plans_status`
- `idx_users_username`
- `idx_users_role`

---

### **3. Triggers (3 triggers)**

لتحديث `updated_at` تلقائياً:
- `update_users_updated_at`
- `update_plans_updated_at`
- `update_reports_updated_at`

---

### **4. RLS Policies (12 policies)**

#### **Users Policies:**
- ✅ Users can read own data
- ✅ GM can read all users
- ✅ GM can insert users
- ✅ GM can update users

#### **Plans Policies:**
- ✅ DM can read own plans
- ✅ GM can read all plans
- ✅ DM can insert own plans
- ✅ DM can update own plans
- ✅ DM can delete own plans

#### **Reports Policies:**
- ✅ DM can read own reports
- ✅ GM can read all reports
- ✅ DM can insert own reports
- ✅ DM can update own reports
- ✅ DM can delete own reports

---

## 🧪 **اختبار Schema**

### **1. اختبار Insert**

```sql
-- Insert test user
INSERT INTO users (name, username, email, password, role, status)
VALUES ('Test DM', 'testdm', 'testdm@biosyn.com', 'test123', 'dm', 'active');

-- Insert test plan
INSERT INTO plans (dm_id, dm_name, date, mr_id, mr_name, status)
VALUES (
    (SELECT id FROM users WHERE username = 'testdm'),
    'Test DM',
    '2025-01-15',
    'MR001',
    'Test MR',
    'pending'
);
```

### **2. اختبار Select**

```sql
-- Get all users
SELECT * FROM users;

-- Get plans for a DM
SELECT * FROM plans WHERE dm_id = (SELECT id FROM users WHERE username = 'testdm');

-- Get reports for a DM
SELECT * FROM reports WHERE dm_id = (SELECT id FROM users WHERE username = 'testdm');
```

---

## 🔐 **ملاحظات أمنية**

### **⚠️ مهم جداً:**

1. **Password Storage:**
   - في Development: يتم حفظ `password` كـ plain text (غير آمن)
   - في Production: يجب استخدام `password_hash` مع bcrypt

2. **RLS Policies:**
   - Policies تعمل فقط مع Supabase Auth
   - إذا كنت تستخدم Custom Auth (users table)، قد تحتاج لتعديل Policies

3. **API Keys:**
   - لا تشارك `service_role` key أبداً
   - استخدم `anon` key في Flutter فقط

---

## 🛠️ **استكشاف الأخطاء**

### **مشكلة: "relation already exists"**
**الحل:** الجداول موجودة بالفعل. استخدم `DROP TABLE IF EXISTS` قبل `CREATE TABLE`

### **مشكلة: "permission denied"**
**الحل:** تأكد من أنك تستخدم `service_role` key في SQL Editor

### **مشكلة: "RLS policies not working"**
**الحل:** 
1. تأكد من تفعيل RLS: `ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;`
2. تأكد من وجود Policies للجدول

### **مشكلة: "UUID extension not found"**
**الحل:** 
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

---

## 📚 **الخطوات التالية**

بعد إعداد Schema:

1. ✅ **Update SupabaseConfig:**
   - ضع `supabaseUrl` و `supabaseAnonKey` في `lib/config/supabase_config.dart`

2. ✅ **Test Connection:**
   - شغل التطبيق
   - جرب Login
   - جرب Save Report

3. ✅ **Add Sample Data:**
   - أضف مستخدمين تجريبيين
   - أضف خطط تجريبية
   - اختبر التطبيق

---

## 🎯 **Checklist**

- [ ] Schema تم تشغيله بنجاح
- [ ] Tables موجودة (3 tables)
- [ ] Indexes موجودة (10 indexes)
- [ ] Triggers موجودة (3 triggers)
- [ ] RLS Policies موجودة (12 policies)
- [ ] Sample data تم إضافتها
- [ ] Test queries تعمل
- [ ] Flutter app متصل بـ Supabase

---

## 📞 **الدعم**

إذا واجهت أي مشاكل:
1. تحقق من **Supabase Dashboard** → **Logs**
2. تحقق من **SQL Editor** → **History**
3. راجع **Documentation** في `SUPABASE_IMPLEMENTATION_GUIDE.md`

---

**تم! 🎉 Schema جاهز للاستخدام!**

