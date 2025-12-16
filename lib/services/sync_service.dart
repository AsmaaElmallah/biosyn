import 'package:biosyn_report_flutter/services/database_service.dart';
import 'package:biosyn_report_flutter/services/connectivity_service.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'dart:convert';

/// Conflict Resolution Strategy
enum ConflictStrategy {
  lastWriteWins, // Use the most recent version
  localWins,     // Always use local version
  remoteWins,    // Always use remote version
}

/// Service لإدارة Sync بين Local Database و Supabase
class SyncService {
  static const int maxRetries = 3;
  static ConflictStrategy _conflictStrategy = ConflictStrategy.lastWriteWins;

  /// Check if sync is needed and perform sync
  static Future<bool> syncIfNeeded() async {
    final isConnected = await ConnectivityService.isConnected();
    if (!isConnected) {
      return false;
    }

    try {
      await syncReports();
      await syncPlans();
      await processSyncQueue();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sync reports
  static Future<void> syncReports() async {
    final unsyncedReports = await DatabaseService.getUnsyncedReports();
    
    for (final reportData in unsyncedReports) {
      try {
        final data = json.decode(reportData['data'] as String) as Map<String, dynamic>;
        final report = CoachingReport.fromJson(data);
        
        // Check for conflicts (if report exists in Supabase)
        final conflict = await _checkConflict('reports', reportData['id'] as String, reportData);
        
        if (conflict) {
          // Handle conflict based on strategy
          final shouldSync = await _resolveConflict('reports', reportData, report);
          if (!shouldSync) {
            continue; // Skip this report
          }
        }
        
        // Try to save to Supabase
        await SupabaseService.saveReport(report);
        
        // Mark as synced
        await DatabaseService.markReportAsSynced(reportData['id'] as String);
      } catch (e) {
        // If sync fails, add to queue for retry
        await DatabaseService.addToSyncQueue(
          'reports',
          reportData['id'] as String,
          'insert',
          reportData,
        );
      }
    }
  }

  /// Sync plans
  static Future<void> syncPlans() async {
    final unsyncedPlans = await DatabaseService.getUnsyncedPlans();
    
    for (final planData in unsyncedPlans) {
      try {
        final planId = planData['id'] as String;
        
        // Try to save to Supabase
        await SupabaseService.savePlan(
          dmId: planData['dm_id'] as String,
          dmName: planData['dm_name'] as String,
          date: planData['date'] as String,
          mrId: planData['mr_id'] as String,
          mrName: planData['mr_name'] as String,
        );
        
        // Mark as synced
        await DatabaseService.markPlanAsSynced(planId);
      } catch (e) {
        // If sync fails, add to queue for retry
        await DatabaseService.addToSyncQueue(
          'plans',
          planData['id'] as String,
          'insert',
          planData,
        );
      }
    }
  }

  /// Process sync queue
  static Future<void> processSyncQueue() async {
    final queueItems = await DatabaseService.getSyncQueue();
    
    for (final item in queueItems) {
      final retryCount = item['retry_count'] as int;
      if (retryCount >= maxRetries) {
        // Max retries reached, remove from queue
        await DatabaseService.removeFromSyncQueue(item['id'] as int);
        continue;
      }

      try {
        final tableName = item['table_name'] as String;
        final operation = item['operation'] as String;
        final data = json.decode(item['data'] as String) as Map<String, dynamic>;

        if (tableName == 'reports' && operation == 'insert') {
          final report = CoachingReport.fromJson(data);
          await SupabaseService.saveReport(report);
          await DatabaseService.markReportAsSynced(item['record_id'] as String);
          await DatabaseService.removeFromSyncQueue(item['id'] as int);
        } else if (tableName == 'plans' && operation == 'insert') {
          await SupabaseService.savePlan(
            dmId: data['dm_id'] as String,
            dmName: data['dm_name'] as String,
            date: data['date'] as String,
            mrId: data['mr_id'] as String,
            mrName: data['mr_name'] as String,
          );
          await DatabaseService.markPlanAsSynced(data['id'] as String);
          await DatabaseService.removeFromSyncQueue(item['id'] as int);
        }
      } catch (e) {
        // Increment retry count
        await DatabaseService.incrementRetryCount(item['id'] as int);
      }
    }
  }

  /// Manual sync trigger
  static Future<bool> manualSync() async {
    final isConnected = await ConnectivityService.isConnected();
    if (!isConnected) {
      throw Exception('No internet connection');
    }

    try {
      await syncReports();
      await syncPlans();
      await processSyncQueue();
      return true;
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  /// Get sync status
  static Future<Map<String, int>> getSyncStatus() async {
    final unsyncedReports = await DatabaseService.getUnsyncedReports();
    final unsyncedPlans = await DatabaseService.getUnsyncedPlans();
    final queueItems = await DatabaseService.getSyncQueue();

    return {
      'unsynced_reports': unsyncedReports.length,
      'unsynced_plans': unsyncedPlans.length,
      'queue_items': queueItems.length,
    };
  }

  // ==================== Conflict Resolution ====================

  /// Check if there's a conflict (record exists in remote but not synced locally)
  static Future<bool> _checkConflict(
    String tableName,
    String recordId,
    Map<String, dynamic> localData,
  ) async {
    try {
      if (!SupabaseService.isInitialized) return false;
      
      // Check if record exists in Supabase
      if (tableName == 'reports') {
        final reports = await SupabaseService.getReports(localData['dm_id'] as String);
        return reports.any((r) => '${r.mrId}_${r.date}' == recordId);
      } else if (tableName == 'plans') {
        final plans = await SupabaseService.getPlans(localData['dm_id'] as String);
        return plans.any((p) => p['id'] == recordId);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Resolve conflict based on strategy
  static Future<bool> _resolveConflict(
    String tableName,
    Map<String, dynamic> localData,
    dynamic localObject,
  ) async {
    switch (_conflictStrategy) {
      case ConflictStrategy.lastWriteWins:
        // Fetch remote data and compare timestamps
        try {
          if (!SupabaseService.isInitialized) return true;
          
          Map<String, dynamic>? remoteData;
          if (tableName == 'reports') {
            final reports = await SupabaseService.getReports(localData['dm_id'] as String);
            final reportId = '${localData['mr_id']}_${localData['date']}';
            final remoteReport = reports.firstWhere(
              (r) => '${r.mrId}_${r.date}' == reportId,
              orElse: () => throw Exception('Not found'),
            );
            // Convert to map for comparison
            remoteData = {
              'updated_at': remoteReport.date, // Use date as timestamp proxy
            };
          } else if (tableName == 'plans') {
            final plans = await SupabaseService.getPlans(localData['dm_id'] as String);
            remoteData = plans.firstWhere(
              (p) => p['id'] == localData['id'],
              orElse: () => throw Exception('Not found'),
            );
          }
          
          if (remoteData != null) {
            // Compare timestamps
            final localTime = DateTime.tryParse(localData['updated_at'] as String? ?? '') ?? DateTime.now();
            final remoteTime = DateTime.tryParse(remoteData['updated_at']?.toString() ?? '') ?? DateTime.now();
            
            // Use most recent version
            return localTime.isAfter(remoteTime);
          }
        } catch (e) {
          // If we can't fetch remote, proceed with local
          return true;
        }
        return true; // Default: proceed with local
      
      case ConflictStrategy.localWins:
        // Always use local version
        return true;
      
      case ConflictStrategy.remoteWins:
        // Skip local version, will be overwritten by remote
        return false;
    }
  }

  /// Set conflict resolution strategy
  static void setConflictStrategy(ConflictStrategy strategy) {
    _conflictStrategy = strategy;
  }

  /// Get current conflict resolution strategy
  static ConflictStrategy getConflictStrategy() {
    return _conflictStrategy;
  }
}

