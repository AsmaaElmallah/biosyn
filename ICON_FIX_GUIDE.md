# 🔧 حل مشكلة قطع النص في أيقونة التطبيق
## Icon Text Cutoff Fix Guide

---

## ❌ **المشكلة:**
عند تحويل `blue-logo.png` إلى أيقونة تطبيق، النص الصغير "PHARMACEUTICALS" يُقطع أو يختفي.

---

## 🔍 **السبب:**
- الأيقونات في Android صغيرة (48x48 إلى 192x192 بكسل)
- النص "PHARMACEUTICALS" صغير جداً في الصورة الأصلية
- عند التصغير، النص الصغير يصبح غير قابل للقراءة

---

## ✅ **الحلول:**

### **الحل 1: استخدام أيقونة مبسطة (موصى به)**

**إنشاء أيقونة تحتوي فقط على:**
- الشعار (الرمز الأزرق)
- كلمة "Biosyn" فقط
- بدون "PHARMACEUTICALS"

**الخطوات:**
1. افتح `assets/blue-logo.png` في محرر صور
2. أنشئ نسخة مبسطة:
   - احذف أو أخفِ "PHARMACEUTICALS"
   - اترك فقط الشعار و "Biosyn"
   - احفظ كـ `assets/icon-simple.png`
3. عدّل `pubspec.yaml`:
   ```yaml
   flutter_launcher_icons:
     android: true
     image_path: "assets/icon-simple.png"
     adaptive_icon_background: "#FFFFFF"
     adaptive_icon_foreground: "assets/icon-simple.png"
   ```
4. شغّل:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

---

### **الحل 2: استخدام الشعار فقط (بدون نص)**

**إنشاء أيقونة تحتوي فقط على:**
- الشعار (الرمز الأزرق) فقط
- بدون أي نص

**الخطوات:**
1. افتح `assets/blue-logo.png` في محرر صور
2. قص الشعار فقط (الجزء الأيسر)
3. احفظ كـ `assets/icon-logo-only.png`
4. عدّل `pubspec.yaml`:
   ```yaml
   flutter_launcher_icons:
     android: true
     image_path: "assets/icon-logo-only.png"
     adaptive_icon_background: "#0175C2"
     adaptive_icon_foreground: "assets/icon-logo-only.png"
   ```
5. شغّل:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

---

### **الحل 3: تعديل الصورة الحالية**

**إضافة padding حول الصورة:**
1. افتح `assets/blue-logo.png` في محرر صور
2. أضف مساحة بيضاء حول الصورة (padding)
3. تأكد أن النص بعيد عن الحواف
4. احفظ
5. شغّل:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

---

## 📋 **الخطوات السريعة:**

### **بعد تعديل الأيقونة:**

1. **تحديث pubspec.yaml:**
   ```yaml
   flutter_launcher_icons:
     android: true
     image_path: "assets/your-icon.png"
     adaptive_icon_background: "#FFFFFF"
     adaptive_icon_foreground: "assets/your-icon.png"
   ```

2. **توليد الأيقونات:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

3. **بناء APK:**
   ```bash
   flutter clean
   flutter build apk --release
   ```

---

## 💡 **نصائح:**

1. **الحجم المثالي للأيقونة:**
   - 1024x1024 بكسل (للجودة العالية)
   - أو 512x512 بكسل (للحجم الأصغر)

2. **التصميم:**
   - تجنب النص الصغير
   - استخدم ألوان واضحة
   - تأكد من وجود padding كافٍ

3. **الخلفية:**
   - استخدم خلفية بيضاء أو زرقاء
   - تجنب الخلفيات المعقدة

---

## ✅ **بعد الإصلاح:**

1. اختبر الأيقونة على هاتف Android
2. تحقق من ظهور النص بشكل صحيح
3. إذا استمرت المشكلة، استخدم أيقونة مبسطة

---

**جاهز!** 🚀

