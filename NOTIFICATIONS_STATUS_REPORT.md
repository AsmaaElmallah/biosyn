# 📬 تقرير حالة الإشعارات (Notifications Status Report)

## 📋 **الملخص التنفيذي (Executive Summary)**

### ✅ **الإشعارات تُرسل لجميع المستخدمين:**
- ✅ GM (General Manager)
- ✅ DM (District Manager)
- ✅ FT (Field Trainer)
- ✅ PM (Product Manager)
- ✅ MSL (Medical Science Liaison)

### ⚠️ **من يستطيع رؤية الإشعارات:**

| الدور | إرسال الإشعارات | RLS Policy | Screen لعرض الإشعارات | الحالة |
|------|----------------|------------|---------------------|--------|
| **GM** | ✅ يُرسل له | ✅ يمكنه قراءة جميع الإشعارات | ✅ `GMNotificationsScreen` | ✅ **يعمل بشكل كامل** |
| **DM** | ✅ يُرسل له | ✅ يمكنه قراءة إشعاراته فقط | ❌ لا يوجد screen | ⚠️ **RLS يعمل لكن لا يوجد UI** |
| **FT** | ✅ يُرسل له | ✅ يمكنه قراءة إشعاراته فقط | ❌ لا يوجد screen | ⚠️ **RLS يعمل لكن لا يوجد UI** |
| **PM** | ✅ يُرسل له | ✅ يمكنه قراءة إشعاراته فقط | ❌ لا يوجد screen | ⚠️ **RLS يعمل لكن لا يوجد UI** |
| **MSL** | ✅ يُرسل له | ✅ يمكنه قراءة إشعاراته فقط | ❌ لا يوجد screen | ⚠️ **RLS يعمل لكن لا يوجد UI** |

---

## 🔍 **التفاصيل (Details)**

### **1. إرسال الإشعارات (Sending Notifications)**

#### **أ. Time Change Notification:**
```dart
// في SupabaseService.sendTimeChangeNotification()
// تُرسل إشعارات لجميع المستخدمين:
final gms = await getAllGMs();
final dms = await getAllDMs();
final fts = await getAllFTs();
final pms = await getAllPMs();
final msls = await getAllMSLs();

// جميع المستخدمين يتلقون الإشعار
```

#### **ب. Location Notification (Report Submitted):**
```dart
// في SupabaseService.sendLocationNotification()
// تُرسل إشعارات لجميع المستخدمين:
// - GM: يتلقى إشعار مع location
// - DM/FT/PM/MSL: يتلقون إشعار بدون location
```

**الخلاصة:** ✅ جميع المستخدمين يتلقون الإشعارات عند:
- تغيير الوقت/التاريخ أثناء إرسال التقرير
- إرسال تقرير جديد

---

### **2. RLS Policies (Row Level Security)**

#### **أ. SELECT Policy (قراءة الإشعارات):**
```sql
CREATE POLICY "Users can read their own notifications"
    ON notifications FOR SELECT
    USING (
        -- User can read notifications where recipient_id matches their auth.uid()
        recipient_id::text = auth.uid()::text
        -- OR GM can read all notifications (for GM dashboard)
        OR public.is_gm()
    );
```

**ما يعنيه هذا:**
- ✅ **GM**: يمكنه قراءة جميع الإشعارات (`is_gm() = true`)
- ✅ **DM/FT/PM/MSL**: يمكنهم قراءة إشعاراتهم فقط (`recipient_id = auth.uid()`)

#### **ب. INSERT Policy (إدراج الإشعارات):**
```sql
CREATE POLICY "Authenticated users can insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL
        OR public.is_gm()
    );
```

**ما يعنيه هذا:**
- ✅ أي مستخدم مسجل دخول يمكنه إدراج إشعارات (يتم من التطبيق)

#### **ج. UPDATE Policy (تحديث الإشعارات - mark as read):**
```sql
CREATE POLICY "Users can update their own notifications"
    ON notifications FOR UPDATE
    USING (
        recipient_id::text = auth.uid()::text
        OR public.is_gm()
    );
```

**ما يعنيه هذا:**
- ✅ **GM**: يمكنه تحديث جميع الإشعارات
- ✅ **DM/FT/PM/MSL**: يمكنهم تحديث إشعاراتهم فقط

---

### **3. UI Screens (واجهات المستخدم)**

#### **أ. GM Notifications Screen:**
```dart
// lib/screens/gm/gm_notifications_screen.dart
class GMNotificationsScreen extends StatefulWidget {
  // GM لديه screen كامل لعرض الإشعارات
  // - عرض جميع الإشعارات
  // - Mark as read
  // - Mark all as read
  // - عرض تفاصيل الإشعار
}
```

**الحالة:** ✅ **يعمل بشكل كامل**

#### **ب. DM/FT/PM/MSL Notifications Screen:**
```dart
// ❌ لا يوجد screen لعرض الإشعارات لـ DM/FT/PM/MSL
// الإشعارات تُرسل لهم لكن لا يمكنهم عرضها في التطبيق
```

**الحالة:** ❌ **لا يوجد UI لعرض الإشعارات**

---

## 📊 **الخلاصة (Summary)**

### ✅ **ما يعمل:**

1. **إرسال الإشعارات:**
   - ✅ جميع المستخدمين يتلقون إشعارات عند تغيير الوقت/التاريخ
   - ✅ جميع المستخدمين يتلقون إشعارات عند إرسال تقرير جديد

2. **RLS Policies:**
   - ✅ GM يمكنه قراءة جميع الإشعارات
   - ✅ DM/FT/PM/MSL يمكنهم قراءة إشعاراتهم (من ناحية RLS)

3. **GM UI:**
   - ✅ GM لديه screen كامل لعرض الإشعارات

### ⚠️ **ما لا يعمل:**

1. **DM/FT/PM/MSL UI:**
   - ❌ لا يوجد screen لعرض الإشعارات
   - ❌ لا يمكنهم رؤية الإشعارات في التطبيق (رغم أن RLS يسمح)

---

## 🔧 **التوصيات (Recommendations)**

### **الخيار 1: إضافة Notifications Screen لجميع الأدوار**

**الإجراء:**
1. إنشاء `NotificationsScreen` مشترك لجميع الأدوار
2. إضافة button/icon في header لعرض الإشعارات
3. استخدام `SupabaseService.getNotifications(userId)` لجلب الإشعارات

**المزايا:**
- ✅ جميع المستخدمين يمكنهم رؤية إشعاراتهم
- ✅ استفادة كاملة من نظام الإشعارات

**العيوب:**
- ⚠️ يحتاج تطوير UI جديد

### **الخيار 2: إزالة إرسال الإشعارات لـ DM/FT/PM/MSL**

**الإجراء:**
1. تعديل `sendTimeChangeNotification` و `sendLocationNotification`
2. إرسال الإشعارات لـ GM فقط

**المزايا:**
- ✅ لا يحتاج تطوير UI
- ✅ يقلل من عدد الإشعارات في قاعدة البيانات

**العيوب:**
- ❌ DM/FT/PM/MSL لن يتلقوا إشعارات

### **الخيار 3: إبقاء الوضع الحالي**

**الإجراء:**
- لا شيء (الوضع الحالي)

**المزايا:**
- ✅ لا يحتاج تطوير
- ✅ GM يستفيد من الإشعارات

**العيوب:**
- ⚠️ DM/FT/PM/MSL يتلقون إشعارات لكن لا يمكنهم رؤيتها

---

## 📝 **الملفات المعنية (Related Files)**

1. **`fix_reports_notifications_rls.sql`** - RLS policies للإشعارات
2. **`lib/services/supabase_service.dart`**:
   - `sendTimeChangeNotification()` - إرسال إشعارات تغيير الوقت
   - `sendLocationNotification()` - إرسال إشعارات إرسال التقرير
   - `getNotifications()` - جلب الإشعارات (لـ GM فقط حالياً)
3. **`lib/screens/gm/gm_notifications_screen.dart`** - Screen لعرض الإشعارات (GM فقط)

---

## ✅ **الخلاصة النهائية**

### **الإشعارات تعمل عند:**
- ✅ **GM**: يعمل بشكل كامل (إرسال + قراءة + UI)
- ⚠️ **DM/FT/PM/MSL**: الإشعارات تُرسل لهم وRLS يسمح بقراءتها، لكن لا يوجد UI لعرضها

### **التوصية:**
- **للآن:** الوضع الحالي يعمل لـ GM
- **للمستقبل:** إضافة Notifications Screen لجميع الأدوار (الخيار 1)

---

**تم إنشاء هذا التقرير في:** `NOTIFICATIONS_STATUS_REPORT.md`

