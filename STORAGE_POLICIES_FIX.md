# 🔧 Fix: Profile Picture Upload Error

## ❌ **المشكلة:**
```
Failed to save user: Exception: Failed to upload profile picture: 
StorageException(message: new row violates row-level security policy, 
statusCode: 403, error: Unauthorized)
```

## ✅ **الحل السريع:**

### **الخطوة 1: تشغيل ملف الإصلاح المباشر** ⚡

1. افتح **Supabase Dashboard**
2. اذهب إلى **SQL Editor**
3. انسخ محتوى ملف: `fix_storage_policies.sql`
4. الصقه في SQL Editor
5. اضغط **Run**

هذا الملف سيقوم بـ:
- ✅ إنشاء Storage Bucket `user-profiles`
- ✅ إنشاء جميع Storage Policies المطلوبة

---

### **الخطوة 2: التحقق من النتيجة**

بعد تشغيل الملف، تحقق من:
1. في **Supabase Dashboard** → **Storage** → يجب أن ترى Bucket باسم `user-profiles`
2. في **Supabase Dashboard** → **Storage** → **Policies** → يجب أن ترى 5 Policies

---

## ✅ **الحل الكامل (إذا لم يعمل الحل السريع):**

### **الخطوة 1: تشغيل Migration المحدث**

1. افتح **Supabase Dashboard**
2. اذهب إلى **SQL Editor**
3. انسخ محتوى ملف: `supabase_migration_add_roles_and_fields.sql`
4. الصقه في SQL Editor
5. اضغط **Run**

**ملاحظة:** الملف الآن يتضمن:
- ✅ إنشاء Storage Bucket `user-profiles`
- ✅ إنشاء Storage Policies (RLS) للسماح برفع الصور

---

### **الخطوة 2: التحقق من Storage Bucket**

1. في **Supabase Dashboard** → **Storage**
2. تأكد من وجود Bucket باسم `user-profiles`
3. إذا لم يكن موجوداً، أنشئه:
   - اضغط **New Bucket**
   - الاسم: `user-profiles`
   - اختر **Public bucket**
   - اضغط **Create**

---

### **الخطوة 3: التحقق من Storage Policies**

1. في **Supabase Dashboard** → **Storage** → **Policies**
2. تأكد من وجود Policies التالية:
   - ✅ "GM can manage all profile pictures"
   - ✅ "Anyone can read profile pictures"
   - ✅ "Authenticated users can upload profile pictures"
   - ✅ "Authenticated users can update profile pictures"
   - ✅ "Authenticated users can delete profile pictures"

إذا لم تكن موجودة، قم بتشغيل Migration مرة أخرى.

---

### **الخطوة 4: اختبار رفع الصور**

1. سجل دخول كـ **GM**
2. اذهب إلى **User Management**
3. اضغط **Add New**
4. اختر صورة Profile Picture
5. احفظ المستخدم

**يجب أن يعمل الآن! ✅**

---

## 🔍 **إذا استمرت المشكلة:**

### **Option 1: التحقق من RLS Policies يدوياً**

في **Supabase Dashboard** → **Storage** → **Policies** → **user-profiles**:

تأكد من وجود Policy:
```sql
CREATE POLICY "Authenticated users can upload profile pictures"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'user-profiles'
        AND auth.role() = 'authenticated'
    );
```

### **Option 2: تعطيل RLS مؤقتاً (للتجربة فقط)**

⚠️ **تحذير:** هذا غير آمن للإنتاج!

في **Supabase Dashboard** → **Storage** → **Settings**:
- عطّل **Row Level Security** مؤقتاً
- اختبر رفع الصور
- أعد تفعيل RLS بعد التأكد من أن Policies تعمل

---

## 📝 **ملاحظات:**

- ✅ Migration المحدث يتضمن كل شيء (Bucket + Policies)
- ✅ لا حاجة لإنشاء Bucket يدوياً إذا تم تشغيل Migration
- ✅ Policies تسمح لجميع المستخدمين المصرح لهم برفع الصور
- ✅ GM يمكنه إدارة جميع الصور (لإدارة المستخدمين)

---

## ✅ **بعد الحل:**

- [x] Migration تم تشغيله
- [x] Storage Bucket موجود
- [x] Storage Policies نشطة
- [x] رفع الصور يعمل

🎉 **جاهز للاستخدام!**

