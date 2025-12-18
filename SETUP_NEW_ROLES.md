# 🚀 Setup Guide - New Roles & Features

## ✅ **ما تم إنجازه:**

### 1. **Database Schema Updates**
- ✅ ملف Migration: `supabase_migration_add_roles_and_fields.sql`
- ✅ إضافة Roles: `ft`, `pm`, `msl`
- ✅ إضافة Profile Picture URL في Users table
- ✅ إضافة Brick Information fields في Reports table
- ✅ إضافة PM/MSL specific fields

### 2. **New Screens**
- ✅ `PMMSLCoachingFormScreen` - Form كامل لـ PM/MSL
- ✅ `PMPlanningScreen` - Planning screen للـ PM/MSL

### 3. **Updated Screens**
- ✅ `WelcomeScreen` - إضافة زر PM/MSL
- ✅ `LoginScreen` - قبول pm/msl و dm/ft من نفس الأزرار
- ✅ `UserManagementScreen` - إضافة Tabs للـ FT, PM, MSL + Profile Picture upload
- ✅ `DM/FT CoachingFormScreen` - إضافة Brick Information
- ✅ `ProfileScreen` - دعم جميع الأدوار

### 4. **Services**
- ✅ `SupabaseService` - إضافة methods للـ FT, PM, MSL
- ✅ `uploadProfilePicture()` - رفع الصور
- ✅ `getAllDMsAndFTs()` - للـ dropdowns

### 5. **Permissions**
- ✅ Android: Location permissions في `AndroidManifest.xml`
- ✅ iOS: Location permissions في `Info.plist`

---

## 📋 **الخطوات المطلوبة:**

### **Step 1: تشغيل Migration في Supabase** ⚠️ **مهم جداً**

1. افتح **Supabase Dashboard**
2. اذهب إلى **SQL Editor**
3. انسخ محتوى ملف: `supabase_migration_add_roles_and_fields.sql`
4. الصقه في SQL Editor
5. اضغط **Run**

**التحقق:**
```sql
-- تحقق من Roles
SELECT DISTINCT role FROM users;

-- تحقق من Fields الجديدة
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'reports' 
AND column_name IN ('coach_role', 'brick_name', 'brick_location_lat', 'visit_count');
```

---

### **Step 2: إنشاء Storage Bucket للصور**

1. في **Supabase Dashboard** → **Storage**
2. اضغط **New Bucket**
3. الاسم: `user-profiles`
4. اختر **Public bucket**
5. اضغط **Create**

---

### **Step 3: تثبيت Packages**

```bash
flutter pub get
```

**Packages المضافة:**
- `image_picker: ^1.0.7`
- `geolocator: ^11.0.0`

---

### **Step 4: اختبار التطبيق**

#### **4.1 اختبار Login:**
- ✅ Login كـ DM/FT
- ✅ Login كـ PM/MSL
- ✅ Login كـ GM

#### **4.2 اختبار User Management (GM):**
- ✅ إنشاء User جديد مع Profile Picture
- ✅ إنشاء FT, PM, MSL
- ✅ عرض Tabs المختلفة

#### **4.3 اختبار Coaching Forms:**
- ✅ DM/FT Form مع Brick Information
- ✅ PM/MSL Form مع جميع الأسئلة
- ✅ Location Picker
- ✅ Submit Reports

---

## 🔧 **ملاحظات مهمة:**

### **1. Location Permissions:**
- ✅ Android: تم إضافتها في `AndroidManifest.xml`
- ✅ iOS: تم إضافتها في `Info.plist`
- ⚠️ المستخدم سيحتاج إلى الموافقة على Permissions عند أول استخدام

### **2. Profile Pictures:**
- ✅ يتم رفعها إلى Supabase Storage
- ✅ Bucket name: `user-profiles`
- ⚠️ تأكد من إنشاء Bucket قبل الاستخدام

### **3. Database:**
- ✅ Migration يجب تشغيله قبل استخدام التطبيق
- ✅ Roles الجديدة: `ft`, `pm`, `msl`
- ✅ Fields الجديدة في Reports table

---

## 📱 **User Flow:**

### **DM/FT Flow:**
```
Welcome → Login (DM/FT) → Planning → Coaching Form (with Brick Info) → Submit
```

### **PM/MSL Flow:**
```
Welcome → Login (PM/MSL) → Planning → PM/MSL Coaching Form → Submit
```

### **GM Flow:**
```
Welcome → Login (GM) → Dashboard → User Management → Create Users (with Profile Picture)
```

---

## ✅ **Checklist:**

- [ ] تشغيل Migration في Supabase
- [ ] إنشاء Storage Bucket `user-profiles`
- [ ] تشغيل `flutter pub get`
- [ ] اختبار Login للأدوار الجديدة
- [ ] اختبار Profile Picture upload
- [ ] اختبار Location Picker
- [ ] اختبار Coaching Forms
- [ ] اختبار Submit Reports

---

## 🐛 **Troubleshooting:**

### **مشكلة: Location Picker لا يعمل**
- ✅ تحقق من Permissions في AndroidManifest.xml و Info.plist
- ✅ تأكد من تفعيل Location Services في الجهاز

### **مشكلة: Profile Picture لا يرفع**
- ✅ تحقق من إنشاء Storage Bucket `user-profiles`
- ✅ تحقق من أن Bucket Public

### **مشكلة: PM/MSL Form لا يظهر**
- ✅ تحقق من تشغيل Migration
- ✅ تحقق من أن User role = 'pm' أو 'msl'

---

## 📞 **Support:**

إذا واجهت أي مشاكل، تحقق من:
1. Supabase Dashboard → Logs
2. Flutter Console → Debug messages
3. Database → Tables → Reports (تحقق من البيانات)

---

**تم الإعداد بنجاح! 🎉**

