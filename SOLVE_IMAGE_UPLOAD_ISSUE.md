# 🔧 حل مشكلة رفع الصور - دليل شامل

## ❌ **المشكلة:**
```
Failed to save user: Exception: Failed to upload profile picture: 
StorageException(message: new row violates row-level security policy, 
statusCode: 403, error: Unauthorized)
```

---

## ✅ **الحل خطوة بخطوة:**

### **الخطوة 1: تشغيل SQL Script في Supabase**

1. افتح **Supabase Dashboard**
2. اذهب إلى **SQL Editor**
3. انسخ محتوى ملف: **`fix_storage_policies_final.sql`**
4. الصقه في SQL Editor
5. اضغط **Run** (أو F5)

**التحقق من النجاح:**
- يجب أن ترى رسالة "Success. No rows returned" أو رسالة نجاح
- إذا رأيت أخطاء، تأكد من أن Bucket موجود أولاً

---

### **الخطوة 2: التحقق من Storage Bucket**

1. في **Supabase Dashboard** → **Storage**
2. تأكد من وجود Bucket باسم **`user-profiles`**
3. إذا لم يكن موجوداً:
   - اضغط **New Bucket**
   - الاسم: `user-profiles`
   - اختر **Public bucket** ✅
   - اضغط **Create**

---

### **الخطوة 3: التحقق من Storage Policies**

1. في **Supabase Dashboard** → **Storage** → **Policies**
2. اختر Bucket: **`user-profiles`**
3. تأكد من وجود Policies التالية:
   - ✅ "GM can manage all profile pictures" (ALL operations)
   - ✅ "Anyone can read profile pictures" (SELECT)
   - ✅ "Authenticated users can upload profile pictures" (INSERT)
   - ✅ "Authenticated users can update profile pictures" (UPDATE)
   - ✅ "Authenticated users can delete profile pictures" (DELETE)

**إذا لم تكن موجودة:**
- قم بتشغيل `fix_storage_policies_final.sql` مرة أخرى

---

### **الخطوة 4: التحقق من تسجيل الدخول**

⚠️ **مهم جداً:** يجب أن تكون مسجل دخول كـ **GM** قبل محاولة رفع الصور!

1. تأكد من تسجيل الدخول في التطبيق
2. تأكد من أن المستخدم الحالي هو **GM**
3. إذا لم تكن مسجل دخول، سجل دخول أولاً

---

### **الخطوة 5: اختبار رفع الصور**

1. سجل دخول كـ **GM**
2. اذهب إلى **User Management**
3. اضغط **Add New**
4. اختر صورة Profile Picture
5. املأ باقي البيانات
6. اضغط **Save**

**يجب أن يعمل الآن! ✅**

---

## 🔍 **إذا استمرت المشكلة:**

### **Option 1: التحقق من Authentication**

قم بتشغيل هذا الاستعلام في Supabase SQL Editor:
```sql
-- تحقق من المستخدم الحالي
SELECT 
    auth.uid() as current_user_id,
    (SELECT role FROM users WHERE id::text = auth.uid()::text) as user_role;
```

**يجب أن ترى:**
- `current_user_id`: ID المستخدم الحالي
- `user_role`: `gm`

---

### **Option 2: التحقق من Bucket Configuration**

قم بتشغيل هذا الاستعلام:
```sql
SELECT id, name, public, file_size_limit, allowed_mime_types 
FROM storage.buckets 
WHERE id = 'user-profiles';
```

**يجب أن ترى:**
- `id`: `user-profiles`
- `public`: `true` ✅
- `file_size_limit`: `5242880` (5MB)
- `allowed_mime_types`: `{image/jpeg,image/jpg,image/png,image/webp}`

---

### **Option 3: التحقق من Policies**

قم بتشغيل هذا الاستعلام:
```sql
SELECT policyname, cmd, qual, with_check
FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects'
AND policyname LIKE '%profile%'
ORDER BY policyname;
```

**يجب أن ترى 5 policies على الأقل**

---

### **Option 4: تعطيل RLS مؤقتاً (للتجربة فقط)**

⚠️ **تحذير:** هذا غير آمن للإنتاج! استخدمه فقط للتجربة.

1. في **Supabase Dashboard** → **Storage** → **Settings**
2. عطّل **Row Level Security** مؤقتاً
3. اختبر رفع الصور
4. إذا عمل، المشكلة في Policies
5. أعد تفعيل RLS وأصلح Policies

---

## 📝 **ملاحظات مهمة:**

1. ✅ **تأكد من تسجيل الدخول:** يجب أن تكون مسجل دخول كـ GM
2. ✅ **تأكد من Bucket:** يجب أن يكون `user-profiles` موجود و public
3. ✅ **تأكد من Policies:** يجب أن تكون جميع Policies موجودة
4. ✅ **حجم الصورة:** يجب أن يكون أقل من 5MB
5. ✅ **نوع الصورة:** يجب أن يكون jpeg, jpg, png, أو webp

---

## 🎯 **ملخص الخطوات:**

1. ✅ تشغيل `fix_storage_policies_final.sql` في Supabase
2. ✅ التحقق من وجود Bucket `user-profiles`
3. ✅ التحقق من وجود Policies
4. ✅ تسجيل الدخول كـ GM
5. ✅ اختبار رفع الصور

---

## ✅ **بعد الحل:**

- [x] Migration تم تشغيله
- [x] Storage Bucket موجود و public
- [x] Storage Policies نشطة
- [x] المستخدم مسجل دخول
- [x] رفع الصور يعمل

🎉 **جاهز للاستخدام!**

---

## 📞 **إذا استمرت المشكلة:**

1. تحقق من **Console Logs** في التطبيق (ستجد تفاصيل أكثر)
2. تحقق من **Supabase Logs** في Dashboard
3. تأكد من أن جميع الخطوات أعلاه تم تنفيذها بشكل صحيح

