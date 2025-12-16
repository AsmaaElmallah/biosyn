# أمثلة عملية - Real-time, Conflict Resolution, Offline Queue

## 📱 مثال 1: Real-time Updates

### السيناريو:
- **DM 1** (Device A) عمل Report جديد في 2:00 PM
- **GM** (Device B) فاتح Dashboard في 1:55 PM

### بدون Real-time:
```
1:55 PM - GM يشوف Dashboard (5 reports)
2:00 PM - DM 1 يعمل Report جديد
2:05 PM - GM لازم يعمل Pull-to-Refresh يدوياً
2:05 PM - GM يشوف Report جديد (6 reports)
```

### مع Real-time:
```
1:55 PM - GM يشوف Dashboard (5 reports)
2:00 PM - DM 1 يعمل Report جديد
2:00 PM - Supabase بيبعت Notification للـ GM
2:00 PM - GM Dashboard بيتحدث تلقائياً (6 reports) ✨
```

### الكود المطلوب:
```dart
// في DMDashboardScreen
class _DMDashboardScreenState extends State<DMDashboardScreen> {
  StreamSubscription? _reportsSubscription;
  
  @override
  void initState() {
    super.initState();
    // Start listening to real-time updates
    _startListening();
  }
  
  void _startListening() {
    final dmId = widget.dmId; // Get from AuthService
    _reportsSubscription = SupabaseService.watchReports(dmId).listen(
      (reports) {
        // Reports updated! Update UI
        setState(() {
          // Update reports list
        });
      },
      onError: (error) {
        // Handle error
      },
    );
  }
  
  @override
  void dispose() {
    _reportsSubscription?.cancel();
    super.dispose();
  }
}
```

---

## ⚔️ مثال 2: Conflict Resolution

### السيناريو:
- **DM 1** عمل Report للـ MR "Ahmed" في 10:00 AM (Local, Offline)
- **DM 2** عمل Report لنفس الـ MR "Ahmed" في 10:05 AM (Supabase, Online)
- **DM 1** اتصله Internet في 10:10 AM

### بدون Conflict Resolution:
```
10:00 AM - DM 1: Report محلي (Score: 4.5)
10:05 AM - DM 2: Report على Supabase (Score: 5.0)
10:10 AM - DM 1: Sync → ❌ Error! Report موجود
10:10 AM - DM 1: Report مفقود أو مكرر
```

### مع Conflict Resolution (Last Write Wins):
```
10:00 AM - DM 1: Report محلي (updated_at: 10:00)
10:05 AM - DM 2: Report على Supabase (updated_at: 10:05)
10:10 AM - DM 1: Sync → Check timestamps
10:10 AM - Supabase timestamp (10:05) > Local (10:00)
10:10 AM - ✅ Use Supabase version (Score: 5.0)
10:10 AM - Update local database
```

### الكود المطلوب:
```dart
// في SyncService
static Future<bool> _resolveConflict(
  String tableName,
  Map<String, dynamic> localData,
) async {
  // 1. Fetch remote data
  final remoteData = await SupabaseService.getReport(localData['id']);
  
  // 2. Compare timestamps
  final localTime = DateTime.parse(localData['updated_at']);
  final remoteTime = DateTime.parse(remoteData['updated_at']);
  
  // 3. Decision
  if (localTime.isAfter(remoteTime)) {
    // Local is newer - sync it
    return true;
  } else {
    // Remote is newer - update local
    await DatabaseService.updateReport(remoteData);
    return false; // Don't sync local
  }
}
```

---

## 📦 مثال 3: Offline Queue

### السيناريو:
- **DM** عمل 5 Reports وهو Offline
- بعدين اتصله Internet

### بدون Offline Queue:
```
Offline:
- Report 1: ✅ Saved locally
- Report 2: ✅ Saved locally
- Report 3: ✅ Saved locally
- Report 4: ✅ Saved locally
- Report 5: ✅ Saved locally

Online:
- Report 1: ❌ Lost (no sync mechanism)
- Report 2: ❌ Lost
- Report 3: ❌ Lost
- Report 4: ❌ Lost
- Report 5: ❌ Lost
```

### مع Offline Queue:
```
Offline:
- Report 1: ✅ Saved locally (synced = false)
- Report 2: ✅ Saved locally (synced = false)
- Report 3: ✅ Saved locally (synced = false)
- Report 4: ✅ Saved locally (synced = false)
- Report 5: ✅ Saved locally (synced = false)
- All added to sync_queue

Online:
- Auto-sync triggered
- Report 1: ✅ Synced to Supabase
- Report 2: ✅ Synced to Supabase
- Report 3: ❌ Failed (Network error) → Added to queue (retry_count = 1)
- Report 4: ✅ Synced to Supabase
- Report 5: ✅ Synced to Supabase

After 5 minutes (Retry):
- Report 3: ✅ Synced to Supabase (retry_count = 2)
- All reports synced! ✅
```

### الكود الموجود:
```dart
// في _saveReport() - main.dart
Future<void> _saveReport(CoachingReport report) async {
  final isConnected = await ConnectivityService.isConnected();
  
  if (isConnected) {
    // Online: Save directly
    try {
      await SupabaseService.saveReport(report);
      await DatabaseService.saveReport(report, synced: true);
    } catch (e) {
      // Failed - save locally and add to queue
      await DatabaseService.saveReport(report, synced: false);
      await DatabaseService.addToSyncQueue('reports', reportId, 'insert', data);
    }
  } else {
    // Offline: Save locally only
    await DatabaseService.saveReport(report, synced: false);
    await DatabaseService.addToSyncQueue('reports', reportId, 'insert', data);
  }
}
```

---

## 🔄 مثال 4: Complete Flow

### السيناريو الكامل:
1. **DM** فتح App (Offline)
2. عمل Report جديد
3. عمل Plan جديد
4. اتصله Internet
5. GM عمل Report لنفس الـ MR

### Flow:

```
[1. DM Opens App - Offline]
   ↓
[2. DM Creates Report]
   ↓
[Save Locally (synced = false)]
[Add to sync_queue]
   ↓
[3. DM Creates Plan]
   ↓
[Save Locally (synced = false)]
[Add to sync_queue]
   ↓
[4. Internet Connected]
   ↓
[Auto-sync Triggered]
   ↓
[Sync Reports]
   ├─ Report 1: ✅ Synced
   └─ Report 2: ❌ Failed → Queue (retry)
   ↓
[Sync Plans]
   └─ Plan 1: ✅ Synced
   ↓
[Process Queue]
   └─ Report 2: ✅ Synced (retry)
   ↓
[5. GM Creates Report]
   ↓
[Supabase Realtime Notification]
   ↓
[DM Dashboard Updates Automatically] ✨
```

---

## 📊 Comparison Table

| Feature | بدون | مع |
|---------|------|-----|
| **Real-time** | Manual Refresh | Auto Update ✨ |
| **Conflict** | Data Loss | Smart Resolution ✅ |
| **Offline** | Data Lost | Queue & Retry 🔄 |

---

## 🎯 الخلاصة:

### Real-time Updates:
- **الفوائد:** Auto-update, No manual refresh, Multi-device sync
- **التكلفة:** استهلاك Battery أكثر شوية (minimal)
- **التوصية:** ✅ إضافتها للـ Dashboard

### Conflict Resolution:
- **الفوائد:** No data loss, Smart merging
- **التكلفة:** Logic معقدة شوية
- **التوصية:** ✅ تحسين Last Write Wins strategy

### Offline Queue:
- **الفوائد:** Data never lost, Auto-retry
- **التكلفة:** Storage space (minimal)
- **التوصية:** ✅ موجود ويعمل - ممكن تحسين Background sync

