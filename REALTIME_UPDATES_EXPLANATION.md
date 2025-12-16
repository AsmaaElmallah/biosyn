# Real-time Updates - شرح تفصيلي

## 🔴 المشكلة الحالية:
- لو DM عمل Report على Device 1
- GM على Device 2 مش هيشوف الـ Report إلا لو عمل Refresh يدوي
- أو لو DM عمل Plan، DM تاني مش هيشوفه إلا لو عمل Refresh

## ✅ الحل: Supabase Realtime Subscriptions

### كيف بيشتغل؟
Supabase بيوفر **Realtime Subscriptions** - يعني:
- App بيستمع (Listen) للتغييرات في Supabase
- أي تغيير يحصل في Database، Supabase بيبعت Notification للـ App
- App بيحدث الـ UI تلقائياً بدون Refresh

### مثال عملي:

```dart
// في SupabaseService - الكود موجود لكن مش مستخدم
static Stream<List<CoachingReport>> watchReports(String dmId) {
  return client!
      .from('reports')
      .stream(primaryKey: ['id'])
      .eq('dm_id', dmId)
      .order('date', ascending: false)
      .map((data) => (data as List)
          .map((json) => CoachingReport.fromSupabaseJson(json))
          .toList());
}
```

### السيناريو:
1. **DM 1** يعمل Report جديد → بيحفظ على Supabase
2. **Supabase** بيبعت Notification لجميع الـ Apps المستمعين
3. **DM 2** و **GM** يشوفوا الـ Report الجديد **تلقائياً** بدون Refresh

### كيف نستخدمه في Dashboard؟

```dart
// في DMDashboardScreen
StreamBuilder<List<CoachingReport>>(
  stream: SupabaseService.watchReports(dmId),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      // البيانات اتحدثت تلقائياً!
      final reports = snapshot.data!;
      return _buildReportsList(reports);
    }
    return CircularProgressIndicator();
  },
)
```

### الفوائد:
✅ **No Manual Refresh** - البيانات بتتحدث تلقائياً
✅ **Multi-device Sync** - لو فتحت App على device تاني، هتشوف التحديثات
✅ **Real-time Collaboration** - GM يشوف Reports DMs فوراً

---

## 2️⃣ Conflict Resolution - شرح تفصيلي

## 🔴 المشكلة:
لو:
- **DM 1** عمل Report في 10:00 AM (Local)
- **DM 2** عمل Report لنفس الـ MR في 10:05 AM (Supabase)
- **DM 1** اتصله Internet في 10:10 AM

**إيه اللي يحصل؟**
- DM 1 عنده Report محلي
- Supabase عنده Report من DM 2
- **Conflict!** - إيه اللي يتخزن؟

## ✅ الحل: Conflict Resolution Strategies

### الاستراتيجيات المتاحة:

#### 1. **Last Write Wins** (الحالي) ⚠️
```dart
// الكود الحالي في sync_service.dart
case ConflictStrategy.lastWriteWins:
  // بيستخدم آخر نسخة (مش دقيق حالياً)
  return true; // Proceed with local version
```

**المشكلة:**
- مش بيقارن Timestamps صح
- ممكن يخسر بيانات مهمة

**الحل الأفضل:**
```dart
case ConflictStrategy.lastWriteWins:
  // Fetch remote timestamp
  final remoteReport = await SupabaseService.getReport(reportId);
  final localTime = DateTime.parse(localData['updated_at']);
  final remoteTime = DateTime.parse(remoteReport['updated_at']);
  
  // Use most recent
  return localTime.isAfter(remoteTime);
```

#### 2. **Local Wins** (Local دائماً يفوز)
```dart
case ConflictStrategy.localWins:
  // دائماً نستخدم النسخة المحلية
  return true; // Always use local
```

**متى نستخدمه:**
- لو البيانات المحلية أهم (مثلاً: بيانات حساسة)
- لو عايزين نمنع Overwrite للبيانات المحلية

#### 3. **Remote Wins** (Supabase دائماً يفوز)
```dart
case ConflictStrategy.remoteWins:
  // دائماً نستخدم نسخة Supabase
  return false; // Skip local, use remote
```

**متى نستخدمه:**
- لو Supabase هو Source of Truth
- لو عايزين نمنع Conflicts تماماً

### مثال عملي محسّن:

```dart
static Future<bool> _resolveConflict(
  String tableName,
  Map<String, dynamic> localData,
  dynamic localObject,
) async {
  switch (_conflictStrategy) {
    case ConflictStrategy.lastWriteWins:
      // 1. Fetch remote data
      final remoteData = await _fetchRemoteData(tableName, localData['id']);
      
      // 2. Compare timestamps
      final localTime = DateTime.parse(localData['updated_at']);
      final remoteTime = DateTime.parse(remoteData['updated_at']);
      
      // 3. Use most recent
      if (localTime.isAfter(remoteTime)) {
        // Local is newer - use it
        return true;
      } else {
        // Remote is newer - update local
        await DatabaseService.updateFromRemote(tableName, remoteData);
        return false; // Don't sync local
      }
    
    case ConflictStrategy.localWins:
      return true; // Always use local
    
    case ConflictStrategy.remoteWins:
      // Update local from remote
      await DatabaseService.updateFromRemote(tableName, remoteData);
      return false; // Don't sync local
  }
}
```

---

## 3️⃣ Offline Queue - شرح تفصيلي

## 🔴 المشكلة:
لو:
- **DM** عمل Report وهو **Offline**
- Report اتحفظ **محلياً فقط**
- بعدين اتصله Internet

**إيه اللي يحصل؟**
- Report لازم يتسنجر على Supabase
- لكن لو فشل الـ Sync، إيه اللي يحصل؟

## ✅ الحل: Offline Queue System

### كيف بيشتغل؟

#### 1. **عند الحفظ Offline:**
```dart
// في _saveReport() في main.dart
Future<void> _saveReport(CoachingReport report) async {
  final isConnected = await ConnectivityService.isConnected();
  
  if (isConnected) {
    // Online: Save directly to Supabase
    await SupabaseService.saveReport(report);
    await DatabaseService.saveReport(report, synced: true);
  } else {
    // Offline: Save locally only
    await DatabaseService.saveReport(report, synced: false);
    // Report is now in local DB with synced = false
  }
}
```

#### 2. **Sync Queue Table:**
```sql
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY,
  table_name TEXT,        -- 'reports' or 'plans'
  record_id TEXT,          -- ID of the record
  operation TEXT,          -- 'insert', 'update', 'delete'
  data TEXT,               -- JSON data
  retry_count INTEGER,     -- How many times we tried
  created_at TEXT
);
```

#### 3. **عند الاتصال:**
```dart
// في SyncService.syncIfNeeded()
static Future<bool> syncIfNeeded() async {
  final isConnected = await ConnectivityService.isConnected();
  if (!isConnected) return false;
  
  // 1. Sync unsynced reports
  await syncReports();
  
  // 2. Sync unsynced plans
  await syncPlans();
  
  // 3. Process sync queue (retry failed syncs)
  await processSyncQueue();
  
  return true;
}
```

#### 4. **Retry Mechanism:**
```dart
// في processSyncQueue()
for (final item in queueItems) {
  final retryCount = item['retry_count'] as int;
  
  if (retryCount >= maxRetries) {
    // Max retries reached (3 times)
    // Remove from queue (or mark as failed)
    await DatabaseService.removeFromSyncQueue(item['id']);
    continue;
  }
  
  try {
    // Try to sync
    await SupabaseService.saveReport(report);
    // Success! Remove from queue
    await DatabaseService.removeFromSyncQueue(item['id']);
  } catch (e) {
    // Failed - increment retry count
    await DatabaseService.incrementRetryCount(item['id']);
  }
}
```

### Flow Diagram:

```
[DM Creates Report Offline]
         ↓
[Save to Local DB (synced = false)]
         ↓
[Add to Sync Queue]
         ↓
[Internet Connected?]
    ↙        ↘
  NO         YES
   ↓          ↓
[Wait]   [Try Sync]
              ↓
        [Success?]
        ↙        ↘
      YES         NO
       ↓           ↓
[Mark as Synced] [Increment Retry]
[Remove from Queue] [Retry Later]
```

### متى بيحصل Auto-sync؟

1. **عند فتح App:**
   ```dart
   // في initState()
   await SyncService.syncIfNeeded();
   ```

2. **عند الاتصال بالإنترنت:**
   ```dart
   // في ConnectivityService
   connectivityStream.listen((result) {
     if (result != ConnectivityResult.none) {
       SyncService.syncIfNeeded();
     }
   });
   ```

3. **عند Manual Sync:**
   ```dart
   // في SyncStatusIndicator
   onTap: () async {
     await SyncService.manualSync();
   }
   ```

### مثال عملي:

**السيناريو:**
1. DM عمل 3 Reports وهو Offline
2. Reports اتحفظت محلياً (synced = false)
3. DM اتصله Internet
4. App بيحاول Sync تلقائياً:
   - Report 1: ✅ Success → Mark as synced
   - Report 2: ❌ Failed (Network error) → Add to queue
   - Report 3: ✅ Success → Mark as synced
5. بعد 5 دقائق، App بيحاول تاني:
   - Report 2: ✅ Success → Remove from queue

---

## 📊 Summary

| Feature | الوضع الحالي | ممكن تحسينه |
|---------|--------------|--------------|
| **Real-time Updates** | ❌ مش مستخدم | ✅ إضافة StreamBuilder في Dashboard |
| **Conflict Resolution** | ⚠️ Last Write Wins (مش دقيق) | ✅ تحسين Timestamp Comparison |
| **Offline Queue** | ✅ موجود ويعمل | ✅ إضافة Background Sync |

---

## 🚀 التوصيات:

### Priority 1: Real-time Updates
- إضافة StreamBuilder في Dashboard
- GM يشوف Reports DMs تلقائياً

### Priority 2: Conflict Resolution
- تحسين Last Write Wins strategy
- إضافة Timestamp comparison

### Priority 3: Background Sync
- Sync في Background حتى لو App مقفول
- Notifications عند Sync success/failure

