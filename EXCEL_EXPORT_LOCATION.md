# 📁 موقع حفظ ملفات Excel - Excel Export Location Guide

## 📍 أين يتم حفظ ملفات Excel بعد التصدير؟

### على Android:

#### **الموقع الأساسي (Primary Location):**
```
/storage/emulated/0/Download/
```
أو
```
/storage/emulated/0/Download/اسم_الملف.xlsx
```

#### **المواقع البديلة (Fallback Locations):**

1. **إذا فشل الوصول إلى Downloads:**
   ```
   /storage/emulated/0/Android/data/com.example.biosyn_report_flutter/files/Download/
   ```

2. **إذا فشل كل شيء:**
   ```
   /data/data/com.example.biosyn_report_flutter/app_flutter/
   ```

---

## 🔍 كيفية الوصول إلى الملفات:

### **الطريقة 1: استخدام File Manager (مدير الملفات)**

1. افتح تطبيق **"Files"** أو **"File Manager"** على هاتفك
2. اذهب إلى **"Internal Storage"** أو **"Storage"**
3. افتح مجلد **"Download"** أو **"Downloads"**
4. ابحث عن الملف الذي تم تصديره (عادة يبدأ بـ `coaching_report_` أو `monthly_report_` أو `all_coaching_reports_`)

### **الطريقة 2: استخدام تطبيق Downloads (التنزيلات)**

1. افتح تطبيق **"Downloads"** على هاتفك
2. ابحث عن الملف الذي تم تصديره
3. اضغط على الملف لفتحه

### **الطريقة 3: استخدام Google Files**

1. افتح تطبيق **"Google Files"**
2. اذهب إلى **"Downloads"**
3. ابحث عن الملف

---

## 📱 رسالة النجاح في التطبيق:

بعد تصدير أي تقرير، ستظهر رسالة نجاح تحتوي على:
- ✅ **رسالة النجاح**: "Report exported successfully!"
- 📁 **المسار الكامل**: المسار الكامل للملف المحفوظ

**مثال:**
```
✅ Report exported successfully!
📁 Location:
/storage/emulated/0/Download/coaching_report_MR_Name_2024-01-15.xlsx
```

---

## ⚠️ ملاحظات مهمة:

### **1. الصلاحيات (Permissions):**
- التطبيق يطلب صلاحيات الوصول إلى التخزين تلقائياً
- إذا لم تمنح الصلاحيات، قد يتم حفظ الملف في موقع بديل

### **2. Android 11+ (Android 11 وأحدث):**
- قد تحتاج إلى منح صلاحية **"Manage All Files"** للوصول الكامل
- يمكنك منح الصلاحية من: **Settings > Apps > Biosyn Report > Permissions > Files and Media > All files**

### **3. إذا لم تجد الملف:**

#### **الخطوة 1: تحقق من رسالة النجاح**
- انظر إلى المسار الكامل الذي يظهر في رسالة النجاح
- استخدم هذا المسار للوصول إلى الملف

#### **الخطوة 2: استخدم البحث**
- افتح File Manager
- استخدم وظيفة البحث
- ابحث عن اسم الملف (مثلاً: `coaching_report_`)

#### **الخطوة 3: تحقق من الموقع البديل**
- اذهب إلى: `/storage/emulated/0/Android/data/com.example.biosyn_report_flutter/files/Download/`

---

## 🔧 استكشاف الأخطاء (Troubleshooting):

### **المشكلة: الملف لا يظهر في Downloads**

**الحل:**
1. تحقق من رسالة النجاح في التطبيق (تحتوي على المسار الكامل)
2. استخدم File Manager للوصول إلى المسار المحدد
3. تأكد من منح جميع الصلاحيات المطلوبة

### **المشكلة: رسالة خطأ عند التصدير**

**الحل:**
1. تحقق من وجود مساحة كافية في التخزين
2. تأكد من منح صلاحيات التخزين
3. حاول إعادة التصدير

### **المشكلة: الملف محفوظ لكن لا يمكن فتحه**

**الحل:**
1. تأكد من تثبيت تطبيق Excel (Microsoft Excel أو Google Sheets)
2. اضغط على الملف واختر "Open with Excel"
3. إذا لم يعمل، جرب فتحه من تطبيق Files

---

## 📝 أسماء الملفات:

### **تقرير واحد (Single Report):**
```
coaching_report_MR_Name_2024-01-15.xlsx
```

### **تقرير شهري (Monthly Report):**
```
monthly_report_January_2024.xlsx
```

### **جميع التقارير (All Reports):**
```
all_coaching_reports_2024-01-15.xlsx
```

---

## 💡 نصيحة:

**للعثور السريع على الملفات:**
1. افتح File Manager
2. استخدم البحث
3. ابحث عن: `coaching_report` أو `monthly_report` أو `all_coaching_reports`

---

## 📞 للمساعدة:

إذا استمرت المشكلة:
1. تحقق من رسالة النجاح في التطبيق (تحتوي على المسار الكامل)
2. التقط screenshot للرسالة
3. استخدم File Manager للوصول إلى المسار المحدد

---

**آخر تحديث:** 2024-01-15

