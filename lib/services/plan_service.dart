import 'package:biosyn_report_flutter/models/plan.dart';
import 'package:biosyn_report_flutter/services/database_service.dart';
import 'package:biosyn_report_flutter/services/connectivity_service.dart';
import 'package:biosyn_report_flutter/services/sync_service.dart';

/// Service لإدارة Plans (يستخدم Local Database مع Auto-sync)
class PlanService {
  /// Get all plans
  static Future<List<Plan>> getPlans() async {
    try {
      return await DatabaseService.getPlans();
    } catch (e) {
      return [];
    }
  }

  /// Get plans for a specific DM
  static Future<List<Plan>> getPlansByDM(String dmId) async {
    try {
      return await DatabaseService.getPlans(dmId: dmId);
    } catch (e) {
      return [];
    }
  }

  /// Get plans for a specific month
  static Future<List<Plan>> getMonthlyPlans(
    String dmId,
    int year,
    int month,
  ) async {
    try {
      final allPlans = await getPlansByDM(dmId);
      return allPlans.where((plan) {
        final planDate = DateTime.parse(plan.date);
        return planDate.year == year && planDate.month == month;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get plan for a specific date
  static Future<Plan?> getPlanByDate(String dmId, String date) async {
    try {
      return await DatabaseService.getPlanByDate(dmId, date);
    } catch (e) {
      return null;
    }
  }

  /// Save plan (saves locally and syncs if online)
  static Future<void> savePlan(Plan plan) async {
    try {
      // Check if online
      final isConnected = await ConnectivityService.isConnected();
      
      // Save to local database
      await DatabaseService.savePlan(plan, synced: isConnected);
      
      // If online, try to sync immediately
      if (isConnected) {
        try {
          await SyncService.syncIfNeeded();
        } catch (e) {
          // Sync failed, will retry later
        }
      }
    } catch (e) {
      throw Exception('Failed to save plan: $e');
    }
  }

  /// Delete plan
  static Future<void> deletePlan(String planId) async {
    try {
      await DatabaseService.deletePlan(planId);
      
      // Try to sync if online
      final isConnected = await ConnectivityService.isConnected();
      if (isConnected) {
        try {
          await SyncService.syncIfNeeded();
        } catch (e) {
          // Sync failed, will retry later
        }
      }
    } catch (e) {
      throw Exception('Failed to delete plan: $e');
    }
  }

  /// Update plan status
  static Future<void> updatePlanStatus(String planId, String status) async {
    try {
      final plan = await DatabaseService.getPlans();
      final existingPlan = plan.firstWhere(
        (p) => p.id == planId,
        orElse: () => throw Exception('Plan not found'),
      );
      
      final updatedPlan = existingPlan.copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      
      await savePlan(updatedPlan);
    } catch (e) {
      throw Exception('Failed to update plan status: $e');
    }
  }

  /// Check if date has a plan
  static Future<bool> hasPlanForDate(String dmId, String date) async {
    try {
      final plan = await getPlanByDate(dmId, date);
      return plan != null;
    } catch (e) {
      return false;
    }
  }
}
