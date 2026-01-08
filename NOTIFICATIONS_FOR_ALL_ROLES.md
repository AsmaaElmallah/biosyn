# 🔔 إضافة الإشعارات لجميع الأدوار (Notifications for All Roles)

## 📋 **المشكلة (Problem)**

الإشعارات الخارجية (local notifications) كانت تظهر لـ DM, FT, PM, MSL عند تغيير الوقت/التاريخ، لكن لم يكن لديهم:
- ❌ زر إشعارات في Dashboard
- ❌ صفحة لعرض الإشعارات
- ❌ طريقة لرؤية الإشعارات الداخلية (in-app notifications)

فقط GM كان لديه هذه الميزات.

---

## ✅ **الحل (Solution)**

تم إضافة:
1. ✅ **NotificationsScreen مشترك** لجميع الأدوار (DM, FT, PM, MSL, GM)
2. ✅ **زر إشعارات** في DM Dashboard مع عداد غير مقروء
3. ✅ **زر إشعارات** في PM/MSL Dashboard مع عداد غير مقروء
4. ✅ **عرض الإشعارات الداخلية** من Supabase بجانب الإشعارات الخارجية

---

## 📁 **الملفات المضافة/المعدلة**

### **1. ملف جديد: `lib/screens/shared/notifications_screen.dart`**

شاشة مشتركة لعرض الإشعارات لجميع الأدوار:
- عرض جميع الإشعارات من Supabase
- Mark as read / Mark all as read
- عرض تفاصيل الإشعار (sender, role, time, message)
- دعم الروابط القابلة للنقر في الرسائل

### **2. تعديل: `lib/screens/dm/dm_dashboard_screen.dart`**

**التغييرات:**
- ✅ إضافة import لـ `NotificationsScreen`
- ✅ إضافة state variables:
  - `_unreadNotificationsCount`: عدد الإشعارات غير المقروءة
  - `_notificationsTimer`: Timer لتحديث العدد كل 30 ثانية
- ✅ إضافة functions:
  - `_loadUnreadNotificationsCount()`: تحميل عدد الإشعارات غير المقروءة
  - `_openNotifications()`: فتح صفحة الإشعارات
- ✅ إضافة زر إشعارات في `AppHeader` مع:
  - أيقونة إشعارات
  - عداد أحمر يظهر عدد الإشعارات غير المقروءة
  - Badge يظهر "9+" إذا كان العدد أكبر من 9

### **3. تعديل: `lib/screens/pm_msl/pm_msl_dashboard_screen.dart`**

**نفس التغييرات كما في DM Dashboard:**
- ✅ إضافة import لـ `NotificationsScreen`
- ✅ إضافة state variables للإشعارات
- ✅ إضافة functions لتحميل وفتح الإشعارات
- ✅ إضافة زر إشعارات في `AppHeader`

---

## 🎯 **كيف يعمل النظام**

### **1. الإشعارات الخارجية (Local Notifications)**

عند تغيير الوقت/التاريخ أثناء submit التقرير:
- ✅ يتم إرسال إشعار خارجي (local notification) لجميع المستخدمين
- ✅ يظهر في notification tray للجهاز
- ✅ يصدر صوت/اهتزاز

### **2. الإشعارات الداخلية (In-App Notifications)**

في نفس الوقت:
- ✅ يتم حفظ إشعار في Supabase `notifications` table
- ✅ يتم إرسال إشعار لكل مستخدم (GM, DM, FT, PM, MSL)
- ✅ يمكن رؤيتها في صفحة الإشعارات داخل التطبيق

### **3. عرض الإشعارات**

**في Dashboard:**
- ✅ زر إشعارات في header
- ✅ عداد أحمر يظهر عدد الإشعارات غير المقروءة
- ✅ يتم تحديث العدد كل 30 ثانية تلقائياً

**في صفحة الإشعارات:**
- ✅ عرض جميع الإشعارات من Supabase
- ✅ تمييز الإشعارات غير المقروءة بخلفية زرقاء فاتحة
- ✅ Mark as read عند الضغط على إشعار
- ✅ Mark all as read button
- ✅ عرض تفاصيل الإشعار:
  - Title
  - Message (مع دعم الروابط)
  - Sender name + role
  - Time (Just now, 5m ago, 2h ago, etc.)

---

## 🔄 **التدفق (Flow)**

### **عند تغيير الوقت/التاريخ:**

1. **User (DM/FT/PM/MSL) يغير الوقت/التاريخ أثناء submit تقرير**
   ↓
2. **System يكتشف التغيير**
   ↓
3. **System يرسل:**
   - ✅ Local notification (خارجي) لجميع المستخدمين
   - ✅ In-app notification (داخلي) في Supabase لجميع المستخدمين
   ↓
4. **جميع المستخدمين (GM, DM, FT, PM, MSL) يتلقون:**
   - ✅ إشعار خارجي في notification tray
   - ✅ إشعار داخلي في التطبيق
   ↓
5. **User يفتح التطبيق**
   ↓
6. **User يرى:**
   - ✅ عداد أحمر على زر الإشعارات في Dashboard
   - ✅ يمكنه فتح صفحة الإشعارات لرؤية التفاصيل

---

## 📱 **الاستخدام (Usage)**

### **للمستخدم (DM/FT/PM/MSL):**

1. **فتح Dashboard:**
   - يرى زر إشعارات في header
   - يرى عداد أحمر إذا كان هناك إشعارات غير مقروءة

2. **الضغط على زر الإشعارات:**
   - يفتح صفحة الإشعارات
   - يرى جميع الإشعارات (مقروءة وغير مقروءة)

3. **الضغط على إشعار:**
   - يتم mark as read تلقائياً
   - يرى تفاصيل الإشعار

4. **Mark all as read:**
   - يمكنه الضغط على "Mark all as read" لتعليم جميع الإشعارات كمقروءة

---

## 🔍 **التفاصيل التقنية (Technical Details)**

### **RLS Policies:**

الإشعارات محمية بـ RLS policies:
- ✅ **SELECT**: User يمكنه قراءة إشعاراته فقط (`recipient_id = auth.uid()`)
- ✅ **INSERT**: Authenticated users يمكنهم إدراج إشعارات
- ✅ **UPDATE**: User يمكنه تحديث إشعاراته فقط (mark as read)

### **API Methods:**

```dart
// جلب الإشعارات
SupabaseService.getNotifications(userId)

// جلب عدد الإشعارات غير المقروءة
SupabaseService.getUnreadNotificationsCount(userId)

// Mark as read
SupabaseService.markNotificationAsRead(notificationId)

// Mark all as read
SupabaseService.markAllNotificationsAsRead(userId)
```

---

## ✅ **الخلاصة**

### **قبل التعديل:**
- ❌ DM/FT/PM/MSL لا يملكون صفحة إشعارات
- ❌ DM/FT/PM/MSL لا يملكون زر إشعارات في Dashboard
- ❌ الإشعارات الخارجية فقط (لا يمكن رؤيتها داخل التطبيق)

### **بعد التعديل:**
- ✅ جميع الأدوار (DM, FT, PM, MSL, GM) لديهم صفحة إشعارات
- ✅ جميع الأدوار لديهم زر إشعارات في Dashboard
- ✅ عرض الإشعارات الداخلية (من Supabase) بجانب الخارجية
- ✅ عداد غير مقروء يظهر عدد الإشعارات
- ✅ Mark as read / Mark all as read

---

**الآن جميع المستخدمين يمكنهم رؤية الإشعارات داخل التطبيق! 🎉**

