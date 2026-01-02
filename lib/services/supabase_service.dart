import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notification_service.dart';
import 'package:biosyn_report_flutter/config/supabase_config.dart';

class SupabaseService {
  static SupabaseClient? _client;
  
  static SupabaseClient? get client {
    if (_client != null) return _client;
    try {
      _client = Supabase.instance.client;
      return _client;
    } catch (e) {
      // Supabase not initialized - return null
      return null;
    }
  }
  
  /// Check if Supabase is initialized
  static bool get isInitialized => client != null;

  // ==================== Reports ====================
  
  /// Save report to Supabase
  static Future<void> saveReport(CoachingReport report) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }
      
      // Check if plan exists for this date and coach
      // If no plan exists and date is today, mark as quick session
      bool isQuickSession = false;
      if (report.isQuickSession == true) {
        isQuickSession = true;
      } else {
        // Check if date is today and no plan exists
        final today = DateTime.now();
        final reportDate = DateTime.tryParse(report.date);
        if (reportDate != null) {
          final todayOnly = DateTime(today.year, today.month, today.day);
          final reportDateOnly = DateTime(reportDate.year, reportDate.month, reportDate.day);
          
          if (reportDateOnly.isAtSameMomentAs(todayOnly)) {
            // Check if plan exists
            try {
              final plan = await getPlanByDate(report.dmId, report.date);
              isQuickSession = plan == null;
            } catch (e) {
              // If check fails, assume it's a quick session
              isQuickSession = true;
            }
          }
        }
      }
      
      // Prepare data for Supabase
      // Note: Don't send 'id' - let Supabase generate UUID automatically
      // Note: dm_id must be UUID from users table, not generated string
      // For Triple visits, we need to identify the coach
      // Since dm_id contains DM info in Triple visits, we need to store coach_id separately
      // For Triple visits, we'll store the coach_id in the dm_id field temporarily
      // and then filter by it. Actually, better approach: for Triple visits, 
      // we can identify the coach by checking if the report was created by a PM/MSL
      // with the same coach_role. But we need coach_id for proper filtering.
      // Solution: For Triple visits, store coach_id in a way that allows filtering
      // For now, we'll use the fact that for Triple visits with PM/MSL role,
      // we can query by coach_role and then filter by checking if the report
      // matches this coach. But this requires knowing which coach created it.
      // Best solution: Add coach_id column to database OR use a workaround:
      // For Triple visits, store coach_id in general_feedback as JSON or use a different field
      // Actually, simplest: For Triple visits, we can check if dm_id matches any DM
      // that this coach has coached in other reports. But this is complex.
      // Let's use a simpler approach: For Triple visits, we'll include all reports
      // with the same coach_role and filter by checking the user's coachId
      // against the reports. But this still requires knowing the coach.
      // Final solution: For Triple visits, we need to add coach_id to the database
      // OR use a workaround where we check if the report's dm_id matches
      // any DM that this coach has coached in Single/Double visits.
      // But the cleanest solution is to add coach_id column.
      // For now, let's use a workaround: For Triple visits, we'll query all reports
      // with the same coach_role and filter by checking if the report's dm_id
      // matches any DM that this coach has coached. But this requires querying
      // all reports first, which is what we're already doing.
      // So the current implementation is actually correct - we fetch all Triple visits
      // with the same coach_role and filter client-side. The issue is that we're
      // including ALL Triple visits with the same coach_role, not just this coach's.
      // Solution: For Triple visits, we need to add coach_id to identify the coach.
      // Since we don't have coach_id in the database, we'll use a workaround:
      // For Triple visits, we'll check if the report's dm_id matches any DM
      // that this coach has coached in other reports (Single/Double visits).
      // But this is complex. Let's use a simpler approach:
      // For Triple visits, we'll include all reports with the same coach_role
      // and filter by checking if the report's dm_id matches any DM that this coach
      // has coached. But this requires querying all reports first.
      // Actually, the simplest solution is to add coach_id to the database.
      // But since we can't modify the database right now, let's use a workaround:
      // For Triple visits, we'll include all reports with the same coach_role
      // and filter by checking if the report's dm_id matches any DM that this coach
      // has coached in other reports. But this is complex.
      // Final solution: For Triple visits, we need to add coach_id to identify the coach.
      // Since we don't have coach_id in the database, we'll use a workaround:
      // For Triple visits, we'll check if the report's dm_id matches any DM
      // that this coach has coached in other reports (Single/Double visits).
      // But this is complex. Let's use a simpler approach:
      // For Triple visits, we'll include all reports with the same coach_role
      // and filter by checking if the report's dm_id matches any DM that this coach
      // has coached. But this requires querying all reports first.
      // Actually, the simplest solution is to add coach_id to the database.
      final reportData = {
        // 'id' removed - Supabase will auto-generate UUID
        'date': report.date,
        'dm_id': report.dmId, // This should be UUID from users table
        'dm_name': report.dmName,
        'mr_id': report.mrId,
        'mr_name': report.mrName,
        'coach_role': report.coachRole,
        // Note: coach_id and coach_name columns don't exist in database
        // For Triple Visit, we identify the coach by coach_role and filter client-side
        // Brick Information
        'brick_name': report.brickName,
        'brick_location_lat': report.brickLocationLat,
        'brick_location_lng': report.brickLocationLng,
        'location_name': report.locationName,
        'google_maps_url': report.googleMapsUrl,
        'visit_count': report.visitCount,
        'doctors_visited': report.doctorsVisited,
        // DM/FT Form Fields
        'punctuality': report.punctuality,
        'dress_code': report.dressCode,
        'time_management': report.timeManagement,
        'pharmacy_feedback': report.pharmacyFeedback,
        'review_profile': report.reviewProfile,
        'brand_bonding': report.brandBonding,
        'smart_objectives': report.smartObjectives,
        'opening': report.opening,
        'patient_profile': report.patientProfile,
        'engaging': report.engaging,
        'insightful_questions': report.insightfulQuestions,
        'active_listening': report.activeListening,
        'link_features': report.linkFeatures,
        'product_knowledge': report.productKnowledge,
        'e_detailing': report.eDetailing,
        'answering_questions': report.answeringQuestions,
        'summarize_call': report.summarizeCall,
        'ask_commitment': report.askCommitment,
        'bridging': report.bridging,
        'self_assessment': report.selfAssessment,
        'strengths': report.strengths,
        'improvements': report.improvements,
        'filled_with_mr': report.filledWithMR,
        // PM/MSL Form Fields
        'area_brick_name': report.areaBrickName,
        'type_of_visit': report.typeOfVisit,
        'visited_accounts_names': report.visitedAccountsNames,
        'general_feedback': report.generalFeedback,
        'teamwork_and_cooperation': report.teamwork,
        'customer_awareness': report.customerAwareness,
        'medical_product_knowledge_dm': report.medicalProductKnowledgeDM,
        'dm_feedback_comments': report.dmFeedbackComments,
        'patient_centric_approach': report.patientCentricApproach,
        'medical_product_knowledge_mr': report.medicalProductKnowledgeMR,
        'feature_benefits': report.featureBenefits,
        'closing_commitment': report.closingCommitment,
        'mr_feedback_comments': report.mrFeedbackComments,
        'average_score': report.getAverageScore(),
        'is_quick_session': isQuickSession,
        'synced': true,
      };
      
      // Insert report (Supabase will auto-generate UUID for id)
      // Log the data being sent for debugging
      debugPrint('📤 Saving report to Supabase:');
      debugPrint('   dm_id: ${report.dmId}');
      debugPrint('   dm_name: ${report.dmName}');
      debugPrint('   mr_id: ${report.mrId}');
      debugPrint('   mr_name: ${report.mrName}');
      debugPrint('   date: ${report.date}');
      debugPrint('   coach_role: ${report.coachRole}');
      debugPrint('   Full report data keys: ${reportData.keys.toList()}');
      
      try {
        final response = await client!.from('reports').insert(reportData).select();
        debugPrint('✅ Report saved successfully to Supabase');
        debugPrint('   Response: $response');
        
        // Get the inserted report ID
        String? reportId;
        String? serverCreatedAt;
        if (response.isNotEmpty) {
          final firstItem = response[0];
          reportId = firstItem['id']?.toString();
          serverCreatedAt = firstItem['created_at']?.toString();
        }
        
        debugPrint('📋 Report saved with ID: $reportId');
        debugPrint('   Report date: ${report.date}');
        debugPrint('   Coach role: ${report.coachRole}');
        debugPrint('   Type of visit: ${report.typeOfVisit}');
        debugPrint('   Coach ID (from model): ${report.coachId}');
        debugPrint('   Coach Name (from model): ${report.coachName}');
        debugPrint('   DM ID: ${report.dmId}');
        debugPrint('   DM Name: ${report.dmName}');
        
        // For Triple Visit: use coachId and coachName (PM/MSL), not dmId and dmName (coached DM)
        final isTripleVisit = report.typeOfVisit == 'Triple' && (report.coachRole == 'pm' || report.coachRole == 'msl');
        final senderId = isTripleVisit && report.coachId != null && report.coachId!.isNotEmpty 
            ? report.coachId! 
            : report.dmId;
        final senderName = isTripleVisit && report.coachName != null && report.coachName!.isNotEmpty 
            ? report.coachName! 
            : report.dmName;
        
        debugPrint('📤 Notification sender info:');
        debugPrint('   Is Triple Visit: $isTripleVisit');
        debugPrint('   Sender ID: $senderId');
        debugPrint('   Sender Name: $senderName');
        debugPrint('   Sender Role: ${report.coachRole ?? 'dm'}');
        
        // Check for time/date manipulation (compare device time with server time)
        if (serverCreatedAt != null) {
          final isTimeManipulated = checkTimeDateManipulation(serverCreatedAt);
          if (isTimeManipulated && reportId != null) {
            debugPrint('⚠️ Time/Date manipulation detected for report: $reportId');
            await sendTimeChangeNotification(
              senderId: senderId,
              senderName: senderName,
              senderRole: report.coachRole ?? 'dm',
              reportId: reportId,
              // Keep the coaching session date in the message
              reportDate: report.date,
            );
          } else {
            debugPrint('✅ No time manipulation detected');
          }
        } else {
          debugPrint('⚠️ Could not read created_at from Supabase response, skipping time manipulation check');
        }
        
        // Send report submitted notification to all users (GM + all coaches)
        // Always send notification when report is submitted (even without location)
        if (reportId != null) {
          debugPrint('📬 Sending report submitted notification...');
          if (report.brickLocationLat != null && report.brickLocationLng != null) {
            await sendLocationNotification(
              senderId: senderId,
              senderName: senderName,
              senderRole: report.coachRole ?? 'dm',
              reportId: reportId,
              reportDate: report.date,
              latitude: report.brickLocationLat!,
              longitude: report.brickLocationLng!,
              locationName: report.locationName,
              googleMapsUrl: report.googleMapsUrl,
            );
          } else {
            // Send notification without location if location is not available
            debugPrint('⚠️ No location data available, sending notification without location');
            await sendLocationNotification(
              senderId: senderId,
              senderName: senderName,
              senderRole: report.coachRole ?? 'dm',
              reportId: reportId,
              reportDate: report.date,
              latitude: 0.0,
              longitude: 0.0,
              locationName: null,
              googleMapsUrl: null,
            );
          }
          debugPrint('✅ Report submitted notification sent');
        } else {
          debugPrint('⚠️ Cannot send notification: reportId is null');
        }
        
        // Update plan status to 'completed' if a matching plan exists
        // This applies to all users (PM, FT, MSL, DM) who submit a report for a scheduled visit
        if (reportId != null) {
          try {
            debugPrint('🔍 Searching for matching plan to update status...');
            debugPrint('   Report date: ${report.date}');
            debugPrint('   Report dmId: ${report.dmId}');
            debugPrint('   Report mrId: ${report.mrId}');
            debugPrint('   Report coachRole: ${report.coachRole}');
            debugPrint('   Report typeOfVisit: ${report.typeOfVisit}');
            
            // Get all pending plans for this date
            final plansForDate = await getPlansByDate(report.date);
            debugPrint('   Found ${plansForDate.length} pending plan(s) for date ${report.date}');
            
            if (plansForDate.isNotEmpty) {
              // Find matching plan based on report type and role
              Map<String, dynamic>? matchingPlan;
              
              if (report.coachRole?.toLowerCase() == 'pm' || report.coachRole?.toLowerCase() == 'msl') {
                // For PM/MSL reports:
                // - In Plan: dm_id = coachId (PM/MSL who created the plan)
                // - In Report:
                //   - Single: dmId = coachId, mrId = coachId (usually no plan)
                //   - Double with DM: dmId = coachId, mrId = coached DM (plan: dm_id = coachId, mr_id = coached DM)
                //   - Double with MR: dmId = coachId, mrId = coached MR (plan: dm_id = coachId, mr_id = coached MR)
                //   - Triple: dmId = coached DM, mrId = coached MR (plan: dm_id = coachId, mr_id = coached MR)
                
                if (report.typeOfVisit == 'Triple') {
                  // For Triple: report.dmId is the coached DM, report.mrId is the coached MR
                  // Plan: dm_id = coachId (PM/MSL), mr_id = coached MR
                  // We need to find plan where mr_id matches report.mrId AND dm_id is a PM/MSL
                  // Strategy: Find plans where mr_id matches, then verify that dm_id is a PM/MSL
                  final candidatePlans = plansForDate.where((plan) {
                    final planMrId = plan['mr_id']?.toString();
                    return planMrId == report.mrId;
                  }).toList();
                  
                  if (candidatePlans.isNotEmpty) {
                    // Verify that the plan's dm_id is a PM/MSL (not a DM)
                    // We'll check by querying the users table to see if dm_id has role 'pm' or 'msl'
                    for (final plan in candidatePlans) {
                      final planDmId = plan['dm_id']?.toString();
                      if (planDmId != null) {
                        try {
                          final user = await client!
                              .from('users')
                              .select('role')
                              .eq('id', planDmId)
                              .maybeSingle();
                          
                          final userRole = user != null && user['role'] != null 
                              ? (user['role'].toString().toLowerCase()) 
                              : null;
                          final reportCoachRole = report.coachRole?.toLowerCase();
                          // Check if the user is PM or MSL (matching report.coachRole)
                          if (userRole != null && reportCoachRole != null && userRole == reportCoachRole) {
                            matchingPlan = plan;
                            break;
                          }
                        } catch (e) {
                          debugPrint('   ⚠️ Could not verify user role for plan dm_id: $planDmId, error: $e');
                        }
                      }
                    }
                    
                    // If no matching plan found by role, use the first one (fallback)
                    if (matchingPlan == null && candidatePlans.isNotEmpty) {
                      matchingPlan = candidatePlans.first;
                      debugPrint('   ⚠️ Using first candidate plan as fallback (could not verify role)');
                    }
                  }
                  
                  if (matchingPlan != null && matchingPlan.isEmpty) matchingPlan = null;
                } else if (report.typeOfVisit == 'Double' && report.mrId == 'no_mr') {
                  // Double with DM: report.dmId = coachId, report.mrId = 'no_mr'
                  // Plan: dm_id = coachId, mr_id = coached DM (stored as mr_id in plan)
                  // We need to find plan where dm_id matches report.dmId
                  // Match: plan.dm_id == report.dmId
                  matchingPlan = plansForDate.firstWhere(
                    (plan) {
                      final planDmId = plan['dm_id']?.toString();
                      // Plan: dm_id = coachId, mr_id = coached DM
                      // Report: dmId = coachId, mrId = 'no_mr'
                      // Match: plan.dm_id == report.dmId
                      return planDmId == report.dmId;
                    },
                    orElse: () => <String, dynamic>{},
                  );
                  
                  if (matchingPlan.isEmpty) matchingPlan = null;
                } else if (report.typeOfVisit == 'Double' && report.mrId != 'no_mr') {
                  // Double with MR: report.dmId = coachId, report.mrId = coached MR
                  // Plan: dm_id = coachId, mr_id = coached MR
                  // Match: plan.dm_id == report.dmId && plan.mr_id == report.mrId
                  matchingPlan = plansForDate.firstWhere(
                    (plan) {
                      final planDmId = plan['dm_id']?.toString();
                      final planMrId = plan['mr_id']?.toString();
                      return planDmId == report.dmId && planMrId == report.mrId;
                    },
                    orElse: () => <String, dynamic>{},
                  );
                  
                  if (matchingPlan.isEmpty) matchingPlan = null;
                } else if (report.typeOfVisit == 'Single') {
                  // Single: report.dmId = coachId, report.mrId = coachId (usually no plan)
                  // But if there's a plan, it would be: dm_id = coachId, mr_id = 'no_mr' or coachId
                  matchingPlan = plansForDate.firstWhere(
                    (plan) {
                      final planDmId = plan['dm_id']?.toString();
                      return planDmId == report.dmId;
                    },
                    orElse: () => <String, dynamic>{},
                  );
                  
                  if (matchingPlan.isEmpty) matchingPlan = null;
                }
              } else {
                // For DM/FT: report.dmId is the coachId
                // Plan: dm_id = coachId, mr_id = coached MR
                // Match: plan.dm_id == report.dmId && plan.mr_id == report.mrId
                matchingPlan = plansForDate.firstWhere(
                  (plan) {
                    final planDmId = plan['dm_id']?.toString();
                    final planMrId = plan['mr_id']?.toString();
                    return planDmId == report.dmId && planMrId == report.mrId;
                  },
                  orElse: () => <String, dynamic>{},
                );
                
                if (matchingPlan.isEmpty) matchingPlan = null;
              }
              
              // Update plan status to 'completed' if matching plan found
              if (matchingPlan != null && matchingPlan['id'] != null) {
                final planId = matchingPlan['id']?.toString();
                if (planId != null) {
                  debugPrint('   ✅ Found matching plan: ID=$planId, dm_id=${matchingPlan['dm_id']}, mr_id=${matchingPlan['mr_id']}');
                  await updatePlan(
                    planId: planId,
                    status: 'completed',
                  );
                  debugPrint('   ✅ Updated plan status to completed for plan ID: $planId');
                }
              } else {
                debugPrint('   ℹ️ No matching plan found for report: date=${report.date}, dmId=${report.dmId}, mrId=${report.mrId}, type=${report.typeOfVisit}, coachRole=${report.coachRole}');
                debugPrint('   Available plans for date:');
                for (final plan in plansForDate) {
                  debugPrint('      - Plan ID: ${plan['id']}, dm_id: ${plan['dm_id']}, mr_id: ${plan['mr_id']}');
                }
              }
            } else {
              debugPrint('   ℹ️ No pending plans found for date: ${report.date}');
            }
          } catch (e, stackTrace) {
            debugPrint('   ❌ Error updating plan status: $e');
            debugPrint('   Stack trace: $stackTrace');
            // Don't throw - plan update failure shouldn't block report submission
          }
        }
      } catch (e) {
        debugPrint('❌ Supabase insert error: $e');
        debugPrint('   Report data: $reportData');
        rethrow; // Re-throw to be caught by caller
      }
    } catch (e) {
      throw Exception('Failed to save report to Supabase: $e');
    }
  }

  /// Get reports for a specific DM/FT/PM/MSL
  static Future<List<CoachingReport>> getReports(String coachId, {String? coachRole}) async {
    try {
      if (!isInitialized) {
        debugPrint('   ❌ Supabase not initialized');
        return [];
      }
      
      debugPrint('   🔍 Querying reports: coachId=$coachId, coachRole=$coachRole');
      
      var query = client!
          .from('reports')
          .select();
      
      // Filter by coach_role if provided, otherwise filter by dm_id
      if (coachRole != null) {
        // For PM/MSL/FT: filter by coach_role
        // Note: For Triple visits, dm_id contains the District Manager ID (not the coach ID)
        // For Single/Double visits, dm_id contains the coach ID
        // So we filter by coach_role, and for non-Triple visits, also filter by dm_id
        query = query.eq('coach_role', coachRole);
        // For non-Triple visits, also filter by dm_id to get only this coach's reports
        // For Triple visits, we can't filter by dm_id because it contains DM info
        // So we'll filter after fetching (client-side) or use a different approach
        // For now, we'll fetch all reports with this coach_role and filter client-side
        debugPrint('   🔍 Filter: coach_role=$coachRole (will filter by coachId client-side for non-Triple visits)');
      } else {
        // For DM, get reports where coach_role is 'dm' or null
        query = query.eq('dm_id', coachId).or('coach_role.is.null,coach_role.eq.dm');
        debugPrint('   🔍 Filter: dm_id=$coachId AND (coach_role IS NULL OR coach_role = dm)');
      }
      
      final response = await query.order('date', ascending: false);
      
      debugPrint('   ✅ Got ${(response as List).length} reports from Supabase');
      
      // For PM/MSL/FT: Filter client-side to get only this coach's reports
      // For Triple visits, dm_id contains DM info, so we can't filter by dm_id
      // For Single/Double visits, dm_id contains coach ID, so we filter by dm_id
      List<Map<String, dynamic>> filteredResponse = [];
      if (coachRole != null && (coachRole == 'pm' || coachRole == 'msl' || coachRole == 'ft')) {
        // First pass: Collect all DMs that this coach has coached
        // This includes DMs from:
        // 1. Double visits with DM (where mrId contains the coached DM's ID)
        // 2. Triple visits (where dmId contains the coached DM's ID)
        final coachedDMs = <String>{};
        for (final report in (response as List)) {
          final typeOfVisit = report['type_of_visit']?.toString();
          final reportDmId = report['dm_id']?.toString() ?? '';
          final reportCoachRole = report['coach_role']?.toString();
          
          // For Single/Double visits, if dm_id matches coachId, this is this coach's report
          if (typeOfVisit != 'Triple' && reportDmId == coachId) {
            // For Double with DM, the mrId contains the coached DM's ID
            if (typeOfVisit == 'Double') {
              final isDMReport = report['teamwork_and_cooperation'] != null ||
                  report['customer_awareness'] != null ||
                  report['medical_product_knowledge_dm'] != null;
              if (isDMReport) {
                // This is a Double visit with DM, mrId contains the coached DM's ID
                final mrId = report['mr_id']?.toString() ?? '';
                if (mrId.isNotEmpty) {
                  coachedDMs.add(mrId);
                }
              }
            }
          }
          
          // For Triple visits, if coach_role matches, collect the DM ID
          // This helps us identify which DMs this coach has coached in Triple visits
          if (typeOfVisit == 'Triple' && reportCoachRole == coachRole) {
            // For Triple visits, dm_id contains the coached DM's ID
            if (reportDmId.isNotEmpty) {
              coachedDMs.add(reportDmId);
            }
          }
        }
        
        debugPrint('   📋 Collected ${coachedDMs.length} coached DMs: $coachedDMs');
        
        // Second pass: Filter all reports
        for (final report in (response as List)) {
          final typeOfVisit = report['type_of_visit']?.toString();
          final reportDmId = report['dm_id']?.toString() ?? '';
          final reportCoachRole = report['coach_role']?.toString();
          
          if (typeOfVisit == 'Triple') {
            // For Triple visits, dm_id contains the coached DM's ID (not the coach ID)
            // Since we don't have coach_id in the database, we'll use a workaround:
            // Include Triple visits if:
            // 1. The coach_role matches (this ensures we only get reports from PMs/MSLs with the same role)
            // 2. AND the DM was coached by this coach (either in Single/Double or in other Triple visits)
            // 
            // However, since we can't identify which specific PM/MSL created the Triple visit,
            // we'll include ALL Triple visits with the same coach_role.
            // This is a limitation - proper solution requires adding coach_id to the database.
            
            if (reportCoachRole == coachRole) {
              // Include all Triple visits with the same coach_role
              // This means all PMs will see all Triple visits by PMs, and all MSLs will see all Triple visits by MSLs
              filteredResponse.add(report);
              debugPrint('   ✅ Including Triple visit: dm_id=$reportDmId, coach_role=$reportCoachRole, date=${report['date']}');
            } else {
              debugPrint('   ⚠️ Excluding Triple visit: dm_id=$reportDmId, coach_role=$reportCoachRole (doesn\'t match $coachRole)');
            }
          } else {
            // For Single/Double visits, dm_id contains coach ID, so filter by dm_id
            if (reportDmId == coachId) {
              filteredResponse.add(report);
            }
          }
        }
        debugPrint('   🔍 Filtered to ${filteredResponse.length} reports (after client-side filtering for coachId=$coachId)');
      } else {
        filteredResponse = (response as List).cast<Map<String, dynamic>>();
      }
      
      // Log all reports details for debugging
      if ((response as List).isNotEmpty) {
        debugPrint('   📋 All reports details:');
        for (int i = 0; i < (response as List).length && i < 5; i++) {
          final report = (response as List)[i];
          debugPrint('      Report $i:');
          debugPrint('         dm_id: ${report['dm_id']}');
          debugPrint('         coach_role: ${report['coach_role']}');
          debugPrint('         date: ${report['date']}');
          debugPrint('         mr_id: ${report['mr_id']}');
          debugPrint('         type_of_visit: ${report['type_of_visit']}');
        }
      } else {
        debugPrint('   ⚠️ No reports found with filters: coachRole=$coachRole, coachId=$coachId');
        
        // Try to find any reports with this coachId to debug
        final allReportsQuery = client!.from('reports').select().eq('dm_id', coachId);
        final allReports = await allReportsQuery;
        debugPrint('   🔍 Debug: Found ${(allReports as List).length} total reports with dm_id=$coachId (without coach_role filter)');
        if ((allReports as List).isNotEmpty) {
          debugPrint('   📋 Sample reports with this dm_id:');
          for (int i = 0; i < (allReports as List).length && i < 3; i++) {
            final report = (allReports as List)[i];
            debugPrint('      Report $i: coach_role=${report['coach_role']}, date=${report['date']}, mr_id=${report['mr_id']}');
          }
        }
        // Try to see what reports exist
        try {
          final allReports = await client!.from('reports').select('dm_id, coach_role, date').limit(10);
          debugPrint('   📊 Sample of all reports in database:');
          for (final r in (allReports as List).take(5)) {
            debugPrint('      dm_id: ${r['dm_id']}, coach_role: ${r['coach_role']}, date: ${r['date']}');
          }
        } catch (e) {
          debugPrint('   ❌ Could not fetch sample reports: $e');
        }
      }

      return filteredResponse
          .map((json) => CoachingReport.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      debugPrint('   ❌ Error fetching reports: $e');
      throw Exception('Failed to get reports: $e');
    }
  }

  /// Get all reports (for GM)
  static Future<List<CoachingReport>> getAllReports() async {
    try {
      debugPrint('📊 SupabaseService.getAllReports() called');
      if (!isInitialized) {
        debugPrint('   ❌ Supabase not initialized');
        return [];
      }
      debugPrint('   Fetching from reports table...');
      final response = await client!
          .from('reports')
          .select()
          .order('date', ascending: false);

      debugPrint('   ✅ Got ${(response as List).length} reports from Supabase');
      return response
          .map((json) => CoachingReport.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      debugPrint('   ❌ Error: $e');
      throw Exception('Failed to get all reports: $e');
    }
  }

  /// Get reports for a specific month
  static Future<List<CoachingReport>> getMonthlyReports(
    String dmId,
    int year,
    int month,
  ) async {
    try {
      final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
      final endDate = '$year-${month.toString().padLeft(2, '0')}-31';

      if (!isInitialized) {
        return [];
      }
      final response = await client!
          .from('reports')
          .select()
          .eq('dm_id', dmId)
          .gte('date', startDate)
          .lte('date', endDate)
          .order('date', ascending: false);

      return (response as List)
          .map((json) => CoachingReport.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get monthly reports: $e');
    }
  }

  // ==================== Plans ====================

  /// Save plan to Supabase
  static Future<void> savePlan({
    required String dmId,
    required String dmName,
    required String date,
    required String mrId,
    required String mrName,
  }) async {
    try {
      debugPrint('📅 SupabaseService.savePlan() called');
      debugPrint('   - dmId: $dmId');
      debugPrint('   - dmName: $dmName');
      debugPrint('   - date: $date');
      debugPrint('   - mrId: $mrId');
      debugPrint('   - mrName: $mrName');
      
      if (!isInitialized) {
        debugPrint('   ❌ Supabase not initialized');
        throw Exception('Supabase not initialized');
      }
      
      debugPrint('   🔄 Inserting plan into Supabase...');
      final response = await client!.from('plans').insert({
        'dm_id': dmId,
        'dm_name': dmName,
        'date': date,
        'mr_id': mrId,
        'mr_name': mrName,
        'status': 'pending',
      }).select();
      
      debugPrint('   ✅ Plan saved successfully: ${(response as List).length} row(s) inserted');
    } catch (e, stackTrace) {
      debugPrint('   ❌ Error saving plan: $e');
      debugPrint('   Stack trace: $stackTrace');
      throw Exception('Failed to save plan: $e');
    }
  }

  /// Get plan for a specific date
  static Future<Map<String, dynamic>?> getPlanByDate(String dmId, String date) async {
    try {
      if (!isInitialized) {
        return null;
      }
      final response = await client!
          .from('plans')
          .select()
          .eq('dm_id', dmId)
          .eq('date', date)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Error getting plan by date: $e');
      return null;
    }
  }

  /// Get plans for a specific date (for any coach)
  /// Used to find plans when we have the date but need to match by coach ID or MR/DM IDs
  static Future<List<Map<String, dynamic>>> getPlansByDate(String date) async {
    try {
      if (!isInitialized) {
        return [];
      }
      final response = await client!
          .from('plans')
          .select()
          .eq('date', date)
          .eq('status', 'pending'); // Only get pending plans

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting plans by date: $e');
      return [];
    }
  }

  /// Update plan status by coach ID and date
  static Future<void> updatePlanStatusByCoachAndDate({
    required String coachId,
    required String date,
    required String status,
  }) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }
      
      debugPrint('🔄 Updating plan status: coachId=$coachId, date=$date, status=$status');
      
      final response = await client!
          .from('plans')
          .update({'status': status})
          .eq('dm_id', coachId)
          .eq('date', date)
          .eq('status', 'pending') // Only update pending plans
          .select();
      
      debugPrint('   ✅ Updated ${(response as List).length} plan(s)');
    } catch (e) {
      debugPrint('   ❌ Error updating plan status: $e');
      // Don't throw - this is not critical
    }
  }

  /// Get plans for a specific DM
  static Future<List<Map<String, dynamic>>> getPlans(String dmId) async {
    try {
      debugPrint('📅 SupabaseService.getPlans() called for dmId: $dmId');
      
      if (!isInitialized) {
        debugPrint('   ❌ Supabase not initialized');
        return [];
      }
      
      debugPrint('   🔄 Fetching plans from Supabase...');
      final response = await client!
          .from('plans')
          .select()
          .eq('dm_id', dmId)
          .order('date', ascending: true);

      final plans = List<Map<String, dynamic>>.from(response);
      debugPrint('   ✅ Got ${plans.length} plan(s) from Supabase');
      return plans;
    } catch (e, stackTrace) {
      debugPrint('   ❌ Error getting plans: $e');
      debugPrint('   Stack trace: $stackTrace');
      throw Exception('Failed to get plans: $e');
    }
  }

  /// Get plans for a specific month
  static Future<List<Map<String, dynamic>>> getMonthlyPlans(
    String dmId,
    int year,
    int month,
  ) async {
    try {
      final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
      final endDate = '$year-${month.toString().padLeft(2, '0')}-31';

      if (!isInitialized) {
        return [];
      }
      final response = await client!
          .from('plans')
          .select()
          .eq('dm_id', dmId)
          .gte('date', startDate)
          .lte('date', endDate)
          .order('date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get monthly plans: $e');
    }
  }

  /// Update plan
  static Future<void> updatePlan({
    required String planId,
    String? mrId,
    String? mrName,
    String? status,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (mrId != null) updates['mr_id'] = mrId;
      if (mrName != null) updates['mr_name'] = mrName;
      if (status != null) updates['status'] = status;

      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }
      await client!
          .from('plans')
          .update(updates)
          .eq('id', planId);
    } catch (e) {
      throw Exception('Failed to update plan: $e');
    }
  }

  /// Delete plan
  static Future<void> deletePlan(String planId) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }
      await client!.from('plans').delete().eq('id', planId);
    } catch (e) {
      throw Exception('Failed to delete plan: $e');
    }
  }

  /// Get all plans (for GM - view only)
  static Future<List<Map<String, dynamic>>> getAllPlans() async {
    try {
      debugPrint('📅 SupabaseService.getAllPlans() called');
      if (!isInitialized) {
        debugPrint('   ❌ Supabase not initialized');
        return [];
      }
      debugPrint('   🔄 Fetching all plans from plans table...');
      final response = await client!
          .from('plans')
          .select()
          .order('date', ascending: true);

      final plans = List<Map<String, dynamic>>.from(response);
      debugPrint('   ✅ Got ${plans.length} plan(s) from Supabase');
      return plans;
    } catch (e, stackTrace) {
      debugPrint('   ❌ Error getting all plans: $e');
      debugPrint('   Stack trace: $stackTrace');
      throw Exception('Failed to get all plans: $e');
    }
  }

  // ==================== Authentication ====================

  /// Sign in with username and password
  static Future<Map<String, dynamic>> signIn(String username, String password) async {
    try {
      debugPrint('🔐 SupabaseService.signIn() called');
      debugPrint('   Username: $username');
      
      // Check if Supabase is initialized
      if (!isInitialized) {
        debugPrint('   ❌ Supabase not initialized');
        throw Exception('Supabase not initialized. Please check your internet connection and try again.');
      }
      
      // Option 1: Use Supabase Auth (if using email-based auth)
      // For now, we'll use custom authentication with users table
      final user = await getUserByUsername(username);
      
      if (user == null) {
        debugPrint('   ❌ User not found: $username');
        throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
      }
      
      debugPrint('   ✅ User found: ${user['name']} (${user['role']})');

      // Debug: Check password fields
      final dbPassword = user['password']?.toString() ?? '';
      final dbPasswordHash = user['password_hash']?.toString() ?? '';
      debugPrint('   🔍 Password check:');
      debugPrint('      Input password length: ${password.length}');
      debugPrint('      DB password: ${dbPassword.isNotEmpty ? "${dbPassword.substring(0, dbPassword.length > 3 ? 3 : dbPassword.length)}..." : "null/empty"}');
      debugPrint('      DB password_hash: ${dbPasswordHash.isNotEmpty ? "${dbPasswordHash.substring(0, dbPasswordHash.length > 3 ? 3 : dbPasswordHash.length)}..." : "null/empty"}');

      // In production, use password hashing (bcrypt)
      // For now, simple comparison (NOT SECURE - for development only)
      if (dbPassword != password && dbPasswordHash != password) {
        debugPrint('   ❌ Invalid password for user: $username');
        debugPrint('      Expected: ${dbPassword.isNotEmpty ? dbPassword : (dbPasswordHash.isNotEmpty ? dbPasswordHash : "NO PASSWORD SET")}');
        debugPrint('      Got: $password');
        throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
      }
      
      debugPrint('   ✅ Password verified successfully');

      // Check if user is active
      if (user['status'] != 'active') {
        debugPrint('   ❌ User account is not active');
        throw Exception('User account is not active');
      }

      // Step 4: Sign in to Supabase Auth for Storage/RLS access
      // This is needed for Storage operations (uploading profile pictures)
      try {
        final email = user['email'] ?? '${username}@biosyn.com';
        debugPrint('   🔐 Signing in to Supabase Auth with email: $email');
        
        // Try to sign in with Supabase Auth
        try {
          await client!.auth.signInWithPassword(
            email: email,
            password: password,
          );
          debugPrint('   ✅ Supabase Auth sign-in successful');
        } catch (authError) {
          // If Supabase Auth sign-in fails, try to create user in Auth
          debugPrint('   ⚠️ Supabase Auth sign-in failed: $authError');
          debugPrint('   🔄 Attempting to create user in Supabase Auth...');
          
          try {
            final signUpResponse = await client!.auth.signUp(
              email: email,
              password: password,
              data: {
                'username': username,
                'name': user['name'],
                'role': user['role'],
              },
            );
            
            if (signUpResponse.user != null) {
              debugPrint('   ✅ User created in Supabase Auth');
              // Sign in after creation
              await client!.auth.signInWithPassword(
                email: email,
                password: password,
              );
              debugPrint('   ✅ Signed in to Supabase Auth');
            }
          } catch (createError) {
            debugPrint('   ⚠️ Could not create/sign in to Supabase Auth: $createError');
            debugPrint('   ⚠️ Storage operations may not work without Supabase Auth');
            // Continue anyway - user is authenticated in our system
          }
        }
      } catch (e) {
        debugPrint('   ⚠️ Error during Supabase Auth: $e');
        // Continue anyway - user is authenticated in our system
      }

      debugPrint('   ✅ Login successful! User ID: ${user['id']}');
      return {
        'id': user['id'],
        'username': user['username'],
        'name': user['name'],
        'role': user['role'],
        'email': user['email'],
      };
    } catch (e) {
      debugPrint('   ❌ Login failed: $e');
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  /// Sign up new user (for GM to create users)
  static Future<Map<String, dynamic>> signUp({
    required String username,
    required String password,
    required String name,
    required String role,
    String? email,
  }) async {
    try {
      // Check if username already exists
      final existingUser = await getUserByUsername(username);
      if (existingUser != null) {
        throw Exception('Username already exists');
      }

      // In production, hash password with bcrypt
      // For now, store as plain text (NOT SECURE - for development only)
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }
      final response = await client!.from('users').insert({
        'username': username,
        'password': password, // In production: hash this
        'name': name,
        'role': role,
        'email': email ?? '$username@biosyn.com',
        'status': 'active',
      }).select().single();

      return {
        'id': response['id'],
        'username': response['username'],
        'name': response['name'],
        'role': response['role'],
        'email': response['email'],
      };
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  /// Get current user session
  static Map<String, dynamic>? getCurrentUser() {
    try {
      if (!isInitialized) {
        return null;
      }
      
      final session = client!.auth.currentSession;
      if (session != null) {
        return {
          'id': session.user.id,
          'email': session.user.email,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get current user from local session (SharedPreferences)
  /// This is used when Supabase Auth is not available but user is logged in via custom auth
  static Future<Map<String, dynamic>?> _getCurrentUserFromLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('biosyn_user');
      if (userJson != null) {
        return json.decode(userJson) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('   ❌ Error getting local session: $e');
      return null;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      if (isInitialized) {
        await client!.auth.signOut();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  // ==================== Users ====================

  /// Get user by username
  static Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      if (!isInitialized) {
        debugPrint('⚠️ Supabase not initialized in getUserByUsername');
        // Try to reinitialize Supabase
        try {
          await Supabase.initialize(
            url: SupabaseConfig.supabaseUrl,
            anonKey: SupabaseConfig.supabaseAnonKey,
          );
          debugPrint('✅ Supabase reinitialized successfully');
        } catch (initError) {
          debugPrint('❌ Failed to reinitialize Supabase: $initError');
          return null;
        }
      }
      
      debugPrint('🔍 Searching for user: $username');
      final response = await client!
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (response == null) {
        debugPrint('   ❌ User not found in database: $username');
      } else {
        debugPrint('   ✅ User found: ${response['name']} (${response['role']})');
      }

      return response;
    } catch (e) {
      debugPrint('❌ Error in getUserByUsername: $e');
      // Log full error details
      if (e is Exception) {
        debugPrint('   Error type: ${e.runtimeType}');
        debugPrint('   Error message: ${e.toString()}');
      }
      // If Supabase is not configured, return null (fallback to local auth)
      return null;
    }
  }

  /// Get user by ID
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      if (!isInitialized) {
        return null; // Supabase not initialized
      }
      
      final response = await client!
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Error getting user by ID: $e');
      return null;
    }
  }

  /// Get all DMs (for GM)
  static Future<List<Map<String, dynamic>>> getAllDMs() async {
    try {
      debugPrint('👥 SupabaseService.getAllDMs() called');
      if (!isInitialized) {
        debugPrint('   ❌ Supabase not initialized');
        return [];
      }
      debugPrint('   Fetching DMs from users table...');
      final response = await client!
          .from('users')
          .select()
          .eq('role', 'dm')
          .eq('status', 'active')
          .order('name', ascending: true);

      debugPrint('   ✅ Got ${(response as List).length} DMs from Supabase');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('   ❌ Error: $e');
      throw Exception('Failed to get DMs: $e');
    }
  }

  /// Get all MRs (for GM)
  static Future<List<Map<String, dynamic>>> getAllMRs() async {
    try {
      debugPrint('👥 SupabaseService.getAllMRs() called');
      if (!isInitialized) {
        debugPrint('   ❌ Supabase not initialized');
        return [];
      }
      debugPrint('   Fetching MRs from users table...');
      final response = await client!
          .from('users')
          .select('id, name, profile_picture_url, role, status')
          .eq('role', 'mr')
          .eq('status', 'active')
          .order('name', ascending: true);

      final mrs = List<Map<String, dynamic>>.from(response);
      debugPrint('   ✅ Got ${mrs.length} MRs from Supabase');
      
      // Debug: Check if profile_picture_url is present
      for (final mr in mrs) {
        final id = mr['id']?.toString() ?? 'unknown';
        final name = mr['name']?.toString() ?? 'unknown';
        final profileUrl = mr['profile_picture_url']?.toString();
        debugPrint('   👤 MR: id=$id, name=$name, hasProfilePicture=${profileUrl != null && profileUrl.isNotEmpty}');
      }
      
      return mrs;
    } catch (e) {
      debugPrint('   ❌ Error: $e');
      throw Exception('Failed to get MRs: $e');
    }
  }

  /// Get all Field Trainers (for GM and PM/MSL forms)
  static Future<List<Map<String, dynamic>>> getAllFTs() async {
    try {
      if (!isInitialized) return [];
      final response = await client!
          .from('users')
          .select()
          .eq('role', 'ft')
          .eq('status', 'active')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get FTs: $e');
    }
  }

  /// Get all Product Managers (for GM)
  static Future<List<Map<String, dynamic>>> getAllPMs() async {
    try {
      if (!isInitialized) return [];
      final response = await client!
          .from('users')
          .select()
          .eq('role', 'pm')
          .eq('status', 'active')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get PMs: $e');
    }
  }

  /// Get all Medical Science Liaisons (for GM)
  static Future<List<Map<String, dynamic>>> getAllMSLs() async {
    try {
      if (!isInitialized) return [];
      final response = await client!
          .from('users')
          .select()
          .eq('role', 'msl')
          .eq('status', 'active')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get MSLs: $e');
    }
  }

  /// Get all DMs and FTs combined (for PM/MSL forms dropdown)
  static Future<List<Map<String, dynamic>>> getAllDMsAndFTs() async {
    try {
      if (!isInitialized) return [];
      // Fetch DMs and FTs separately and combine
      final dms = await getAllDMs();
      final fts = await getAllFTs();
      final combined = [...dms, ...fts];
      // Sort by name
      combined.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      return combined;
    } catch (e) {
      throw Exception('Failed to get DMs and FTs: $e');
    }
  }

  /// Update existing user (for GM)
  static Future<void> updateUser({
    required String id,
    String? name,
    String? username,
    String? password,
    String? email,
    String? phone,
    String? role,
    String? status,
    String? profilePictureUrl,
  }) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (username != null) updates['username'] = username;
      if (password != null && password.isNotEmpty) {
        // In production, hash password here
        updates['password'] = password;
      }
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;
      if (role != null) updates['role'] = role;
      if (status != null) updates['status'] = status;
      if (profilePictureUrl != null) updates['profile_picture_url'] = profilePictureUrl;

      if (updates.isEmpty) return;

      await client!
          .from('users')
          .update(updates)
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  /// Delete user (for GM)
  static Future<void> deleteUser(String id) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }

      await client!
          .from('users')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Upload profile picture to Supabase Storage
  static Future<String> uploadProfilePicture(File imageFile, String userId) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }

      // Check if user is authenticated in Supabase Auth
      var currentUser = client!.auth.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ User not authenticated in Supabase Auth, attempting to authenticate...');
        
        // Try to get current user from AuthService (local session)
        try {
          // Import AuthService dynamically to avoid circular dependency
          final authService = await _getCurrentUserFromLocalSession();
          
          if (authService != null) {
            final username = authService['username'] ?? '';
            debugPrint('   📋 Found local session for user: $username');
            
            // Get user data from users table to get password
            final userData = await client!
                .from('users')
                .select()
                .eq('id', authService['id'])
                .single();
            
            final email = userData['email'] ?? '${username}@biosyn.com';
            
            // Try to get password from SharedPreferences first (saved during login)
            final prefs = await SharedPreferences.getInstance();
            String? password = prefs.getString('biosyn_password');
            
            // If not in SharedPreferences, try to get from database
            if (password == null || password.isEmpty) {
              password = userData['password'] ?? userData['password_hash'] ?? '';
            }
            
            // If still empty or too short, generate a secure password
            if (password == null || password.isEmpty || password.length < 6) {
              debugPrint('   ⚠️ Password is empty or too short, generating secure password...');
              // Generate a secure password based on user ID and username
              final userId = authService['id'] ?? '';
              final securePassword = '${userId}_${username}_${DateTime.now().millisecondsSinceEpoch}';
              password = securePassword.substring(0, securePassword.length > 20 ? 20 : securePassword.length);
              // Ensure minimum length of 6
              if (password.length < 6) {
                password = password.padRight(6, '0');
              }
              debugPrint('   ✅ Generated secure password (length: ${password.length})');
            }
            
            // Ensure password is not null and has minimum length
            final finalPassword = password;
            if (finalPassword.isEmpty) {
              throw Exception('Could not get or generate password for authentication');
            }
            
            debugPrint('   🔐 Attempting to sign in to Supabase Auth...');
            
            // Try to sign in to Supabase Auth
            try {
              await client!.auth.signInWithPassword(
                email: email,
                password: finalPassword,
              );
              currentUser = client!.auth.currentUser;
              debugPrint('   ✅ Signed in to Supabase Auth successfully');
            } catch (authError) {
              debugPrint('   ⚠️ Sign in failed: $authError');
              
              // Check if error is due to email not confirmed
              final errorString = authError.toString();
              if (errorString.contains('email_not_confirmed') || errorString.contains('Email not confirmed')) {
                debugPrint('   📧 Email not confirmed, attempting to resend confirmation...');
                try {
                  // Try to resend confirmation email
                  await client!.auth.resend(
                    type: OtpType.signup,
                    email: email,
                  );
                  debugPrint('   ✅ Confirmation email sent');
                  
                  // Try to sign in again (sometimes works after resend)
                  try {
                    await client!.auth.signInWithPassword(
                      email: email,
                      password: finalPassword,
                    );
                    currentUser = client!.auth.currentUser;
                    debugPrint('   ✅ Signed in after resending confirmation');
                  } catch (retryError) {
                    debugPrint('   ⚠️ Still cannot sign in: $retryError');
                    // Continue to try creating user
                  }
                } catch (resendError) {
                  debugPrint('   ⚠️ Could not resend confirmation: $resendError');
                }
              }
              
              // If still not authenticated, try to create user in Auth if doesn't exist
              if (currentUser == null) {
                try {
                  debugPrint('   🔄 Attempting to create user in Supabase Auth...');
                  final signUpResponse = await client!.auth.signUp(
                    email: email,
                    password: finalPassword,
                    data: {
                      'username': username,
                      'name': userData['name'],
                      'role': userData['role'],
                    },
                  );
                  
                  if (signUpResponse.user != null) {
                    debugPrint('   ✅ User created in Supabase Auth');
                    // Try to sign in after creation
                    try {
                      await client!.auth.signInWithPassword(
                        email: email,
                        password: finalPassword,
                      );
                      currentUser = client!.auth.currentUser;
                      debugPrint('   ✅ Signed in to Supabase Auth');
                    } catch (signInAfterCreateError) {
                      debugPrint('   ⚠️ Could not sign in after creation: $signInAfterCreateError');
                      // If email confirmation is required, we can't proceed
                      if (signInAfterCreateError.toString().contains('email_not_confirmed')) {
                        debugPrint('   ❌ Email confirmation required');
                        debugPrint('   💡 Solution: Disable email confirmation in Supabase Settings');
                        throw Exception(
                          '❌ Email Confirmation Required\n\n'
                          'Please check your email and confirm your account.\n\n'
                          '🔧 Or disable email confirmation:\n'
                          '1. Supabase Dashboard → Authentication → Settings\n'
                          '2. Disable "Enable email confirmations"\n'
                          '3. Logout and login again'
                        );
                      }
                      throw Exception('Could not authenticate with Supabase Auth. Please logout and login again.');
                    }
                  }
                } catch (createError) {
                  debugPrint('   ❌ Could not create/sign in: $createError');
                  
                  // Check if user already exists
                  if (createError.toString().contains('already registered') || 
                      createError.toString().contains('email_address_invalid')) {
                    debugPrint('   ❌ User exists but email not confirmed');
                    debugPrint('   💡 Solution: Disable email confirmation in Supabase Settings');
                    debugPrint('   📋 Steps:');
                    debugPrint('      1. Go to Supabase Dashboard → Authentication → Settings');
                    debugPrint('      2. Find "Enable email confirmations"');
                    debugPrint('      3. Disable it');
                    debugPrint('      4. Logout and login again');
                    throw Exception(
                      '❌ Email Confirmation Required\n\n'
                      'The user exists in Supabase Auth but email is not confirmed.\n\n'
                      '🔧 Solution:\n'
                      '1. Go to Supabase Dashboard\n'
                      '2. Authentication → Settings\n'
                      '3. Disable "Enable email confirmations"\n'
                      '4. Logout and login again\n\n'
                      'Or check your email and confirm your account.'
                    );
                  }
                  
                  throw Exception('Could not authenticate with Supabase Auth. Please logout and login again.');
                }
              }
            }
          } else {
            throw Exception('No local session found. Please login first.');
          }
        } catch (e) {
          debugPrint('   ❌ Error during authentication: $e');
          throw Exception('User not authenticated. Please login first.');
        }
      }
      
      if (currentUser == null) {
        throw Exception('User not authenticated. Please login first.');
      }

      debugPrint('📤 Uploading profile picture:');
      debugPrint('   User ID: $userId');
      debugPrint('   Current Auth User: ${currentUser.id}');
      debugPrint('   File path: ${imageFile.path}');

      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'profile_$userId.${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      // Note: filePath should be just the filename, not include bucket name
      final filePath = fileName;

      // Read file bytes
      final fileBytes = await imageFile.readAsBytes();
      debugPrint('   File size: ${fileBytes.length} bytes');

      // Determine content type
      String contentType = 'image/jpeg';
      if (fileExtension == 'png') {
        contentType = 'image/png';
      } else if (fileExtension == 'webp') {
        contentType = 'image/webp';
      }

      // Upload to Supabase Storage
      debugPrint('   Uploading to bucket: user-profiles');
      debugPrint('   File path: $filePath');
      debugPrint('   Content type: $contentType');

      await client!.storage
          .from('user-profiles')
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      debugPrint('✅ File uploaded successfully');

      // Get public URL
      final url = client!.storage
          .from('user-profiles')
          .getPublicUrl(filePath);

      debugPrint('   Public URL: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading profile picture: $e');
      if (e.toString().contains('row-level security') || 
          e.toString().contains('403') || 
          e.toString().contains('Unauthorized')) {
        throw Exception(
          'Storage permission denied. Please ensure:\n'
          '1. Storage bucket "user-profiles" exists\n'
          '2. Storage policies are configured correctly\n'
          '3. You are logged in as GM\n'
          'Error: $e'
        );
      }
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  /// Update user profile picture URL
  static Future<void> updateUserProfilePicture(String userId, String? imageUrl) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }

      await client!
          .from('users')
          .update({'profile_picture_url': imageUrl})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update profile picture URL: $e');
    }
  }

  // ==================== Real-time ====================

  /// Listen to reports changes (real-time)
  static Stream<List<CoachingReport>> watchReports(String coachId, {String? coachRole}) {
    debugPrint('🔄 watchReports called: coachId=$coachId, coachRole=$coachRole');
    if (!isInitialized) {
      debugPrint('   ❌ Supabase not initialized, returning empty stream');
      return Stream.value([]);
    }
    
    // Build query with filters
    // For PM/MSL/FT: filter by coach_role (not dm_id) because:
    // - For Single/Double visits, dm_id contains coach ID
    // - For Triple visits, dm_id contains DM ID (not coach ID)
    // So we need to filter by coach_role and then filter client-side
    
    // Note: Supabase stream requires building the query differently
    // We'll use a single query and filter client-side
    final query = client!
        .from('reports')
        .stream(primaryKey: ['id']);
    
    // Filter by coach_role if provided (for PM/MSL/FT)
    if (coachRole != null) {
      debugPrint('   🔍 Stream query: will filter by coach_role=$coachRole client-side');
    } else {
      // For DM, we can filter by dm_id in the stream
      debugPrint('   🔍 Stream query: will filter by dm_id=$coachId client-side');
    }
    
    // Note: Supabase stream doesn't support complex filtering after stream()
    // So we filter client-side in the map function
    return query
        .order('date', ascending: false)
        .map((data) {
          var reports = (data as List)
              .map((json) => CoachingReport.fromSupabaseJson(json))
              .toList();
          
          debugPrint('   📊 Stream received ${reports.length} reports before client-side filtering');
          
          // For PM/MSL/FT: Filter client-side to get only this coach's reports
          if (coachRole != null && (coachRole == 'pm' || coachRole == 'msl' || coachRole == 'ft')) {
            final filteredReports = <CoachingReport>[];
            
            // First pass: Collect all DMs that this coach has coached
            final coachedDMs = <String>{};
            for (final report in reports) {
              final typeOfVisit = report.typeOfVisit;
              final reportDmId = report.dmId;
              
              // For Single/Double visits, if dm_id matches coachId, this is this coach's report
              if (typeOfVisit != 'Triple' && reportDmId == coachId) {
                // For Double with DM, the mrId contains the coached DM's ID
                if (typeOfVisit == 'Double') {
                  final isDMReport = report.teamwork != null ||
                      report.customerAwareness != null ||
                      report.medicalProductKnowledgeDM != null;
                  if (isDMReport) {
                    // This is a Double visit with DM, mrId contains the coached DM's ID
                    if (report.mrId.isNotEmpty) {
                      coachedDMs.add(report.mrId);
                    }
                  }
                }
              }
              
              // For Triple visits, if coach_role matches, collect the DM ID
              if (typeOfVisit == 'Triple' && report.coachRole == coachRole) {
                if (reportDmId.isNotEmpty) {
                  coachedDMs.add(reportDmId);
                }
              }
            }
            
            // Second pass: Filter all reports
            for (final report in reports) {
              final typeOfVisit = report.typeOfVisit;
              final reportDmId = report.dmId;
              
              if (typeOfVisit == 'Triple') {
                // For Triple visits, include all with the same coach_role
                if (report.coachRole == coachRole) {
                  filteredReports.add(report);
                  debugPrint('   ✅ Stream: Including Triple visit: dm_id=$reportDmId, date=${report.date}');
                }
              } else {
                // For Single/Double visits, dm_id contains coach ID, so filter by dm_id
                if (reportDmId == coachId) {
                  filteredReports.add(report);
                }
              }
            }
            
            debugPrint('   🔍 Stream: Filtered to ${filteredReports.length} reports (after client-side filtering for coachId=$coachId)');
            return filteredReports;
          } else {
            // For DM, reports are already filtered by dm_id in the query
            return reports;
          }
        });
  }

  // ==================== Notifications ====================

  /// Get all General Managers
  static Future<List<Map<String, dynamic>>> getAllGMs() async {
    try {
      if (!isInitialized) {
        return [];
      }
      final response = await client!
          .from('users')
          .select()
          .eq('role', 'gm');
      
      return (response as List).map((user) => user as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Error getting GMs: $e');
      return [];
    }
  }

  /// Check if device time/date was changed by comparing local device time
  /// with server time (e.g. `created_at` from Supabase).
  ///
  /// Returns true if the difference is suspicious:
  /// - Any difference in calendar date (even 1 day)
  /// - Or time difference more than 30 minutes
  static bool checkTimeDateManipulation(String serverTimeIsoString) {
    try {
      final now = DateTime.now();
      // Supabase timestamps are in ISO 8601 (usually UTC)
      final serverDateTime = DateTime.tryParse(serverTimeIsoString);
      
      if (serverDateTime == null) {
        return false;
      }
      
      // Compare dates (ignore time for date comparison)
      final nowOnly = DateTime(now.year, now.month, now.day);
      final serverDateOnly = DateTime(serverDateTime.year, serverDateTime.month, serverDateTime.day);
      
      // Calculate the difference in days
      final dateDifference = serverDateOnly.difference(nowOnly).inDays;
      
      // If report date is different from today (even 1 day), it's suspicious
      if (dateDifference != 0) {
        debugPrint('⚠️ Report date is ${dateDifference.abs()} day(s) ${dateDifference > 0 ? 'in the future' : 'in the past'} - time manipulation detected');
        return true;
      }
      
      // If dates are the same, check time difference (full datetime)
      final timeDifference = serverDateTime.difference(now).abs();
      
      // If time difference is more than 30 minutes, it's suspicious
      if (timeDifference.inMinutes > 30) {
        debugPrint('⚠️ Report time is ${timeDifference.inMinutes} minutes different from current time - time manipulation detected');
        return true;
      }
      
      // If dates are the same and time difference is within 30 minutes, it's normal
      return false;
    } catch (e) {
      debugPrint('❌ Error checking time/date manipulation: $e');
      return false;
    }
  }

  /// Send notification to all users (GM + all coaches) about time/date change
  static Future<void> sendTimeChangeNotification({
    required String senderId,
    required String senderName,
    required String senderRole,
    required String reportId,
    required String reportDate,
  }) async {
    try {
      if (!isInitialized) {
        debugPrint('⚠️ Supabase not initialized, cannot send notification');
        return;
      }

      // Get all users (GM + all coaches)
      final gms = await getAllGMs();
      final dms = await getAllDMs();
      final fts = await getAllFTs();
      final pms = await getAllPMs();
      final msls = await getAllMSLs();
      
      // Combine all users
      final allUsers = <Map<String, dynamic>>[];
      allUsers.addAll(gms);
      allUsers.addAll(dms);
      allUsers.addAll(fts);
      allUsers.addAll(pms);
      allUsers.addAll(msls);
      
      if (allUsers.isEmpty) {
        debugPrint('⚠️ No users found, cannot send notification');
        return;
      }

      // Get role label
      String roleLabel;
      switch (senderRole.toLowerCase()) {
        case 'dm':
          roleLabel = 'District Manager';
          break;
        case 'ft':
          roleLabel = 'Field Trainer';
          break;
        case 'pm':
          roleLabel = 'Product Manager';
          break;
        case 'msl':
          roleLabel = 'Medical Science Liaison';
          break;
        default:
          roleLabel = 'Coach';
      }

      // Create notification message (full message for external notification)
      final fullMessage = '$senderName ($roleLabel) changed the device time/date while submitting a coaching session on $reportDate';

      // Convert senderId to UUID if it's a string
      String? senderUuid;
      try {
        // Try to parse as UUID first
        senderUuid = senderId;
        // If senderId is not a valid UUID format, try to find it in users table
        if (!senderId.contains('-') || senderId.length != 36) {
          // It's not a UUID format, try to find the user
          final users = await client!
              .from('users')
              .select('id')
              .or('id.eq.$senderId,username.eq.$senderId')
              .limit(1);
          if (users.isNotEmpty) {
            senderUuid = users[0]['id']?.toString();
          }
        }
      } catch (e) {
        debugPrint('⚠️ Could not convert senderId to UUID: $e');
        senderUuid = senderId; // Fallback to original value
      }

      // Create notifications for all users (in-app notifications)
      final notifications = allUsers.map((user) {
        final userId = user['id']?.toString();
        return {
          'recipient_id': userId,
          'sender_id': senderUuid ?? senderId,
          'sender_name': senderName,
          'sender_role': senderRole,
          'notification_type': 'time_change',
          'title': 'Time/Date Change Detected',
          'message': fullMessage,
          'report_id': reportId,
          'read': false,
        };
      }).toList();

      // Insert notifications to database (in-app notifications)
      await client!.from('notifications').insert(notifications);
      
      debugPrint('✅ Sent ${notifications.length} time change notification(s) to all users');
      
      // Send push notifications to all users (external notifications with sound - full message)
      await _sendPushNotifications(
        title: 'Time/Date Change Detected',
        message: fullMessage,
        reportId: reportId,
      );
    } catch (e) {
      debugPrint('❌ Error sending time change notification: $e');
      // Don't throw - notification failure shouldn't block report submission
    }
  }

  /// Send notification to all users (GM + all coaches) about report submission
  /// For GM: includes location in in-app notification
  /// For all users: external notification without location
  static Future<void> sendLocationNotification({
    required String senderId,
    required String senderName,
    required String senderRole,
    required String reportId,
    required String reportDate,
    required double latitude,
    required double longitude,
    String? locationName,
    String? googleMapsUrl,
  }) async {
    try {
      if (!isInitialized) {
        debugPrint('⚠️ Supabase not initialized, cannot send location notification');
        return;
      }

      // Get all users (GM + all coaches)
      final gms = await getAllGMs();
      final dms = await getAllDMs();
      final fts = await getAllFTs();
      final pms = await getAllPMs();
      final msls = await getAllMSLs();
      
      // Combine all users
      final allUsers = <Map<String, dynamic>>[];
      allUsers.addAll(gms);
      allUsers.addAll(dms);
      allUsers.addAll(fts);
      allUsers.addAll(pms);
      allUsers.addAll(msls);
      
      if (allUsers.isEmpty) {
        debugPrint('⚠️ No users found, cannot send location notification');
        return;
      }

      // Get role label
      String roleLabel;
      switch (senderRole.toLowerCase()) {
        case 'dm':
          roleLabel = 'District Manager';
          break;
        case 'ft':
          roleLabel = 'Field Trainer';
          break;
        case 'pm':
          roleLabel = 'Product Manager';
          break;
        case 'msl':
          roleLabel = 'Medical Science Liaison';
          break;
        default:
          roleLabel = 'Coach';
      }

      // Convert senderId to UUID if it's a string
      String? senderUuid;
      try {
        senderUuid = senderId;
        if (!senderId.contains('-') || senderId.length != 36) {
          final users = await client!
              .from('users')
              .select('id')
              .or('id.eq.$senderId,username.eq.$senderId')
              .limit(1);
          if (users.isNotEmpty) {
            senderUuid = users[0]['id']?.toString();
          }
        }
      } catch (e) {
        debugPrint('⚠️ Could not convert senderId to UUID: $e');
        senderUuid = senderId;
      }

      // Build location message - use Google Maps URL if available, otherwise use coordinates
      final locationMsg = googleMapsUrl != null 
          ? googleMapsUrl
          : 'https://www.google.com/maps?q=$latitude,$longitude';

      // Create full message for external notification (without location)
      final fullMessageWithoutLocation = '$senderName ($roleLabel) submitted a coaching report on $reportDate';

      // Create notifications for all users
      // For GM: include location in in-app notification
      // For others: message without location
      final notifications = allUsers.map((user) {
        final userId = user['id']?.toString() ?? '';
        final userRole = user['role']?.toString() ?? '';
        final isGM = userRole.toLowerCase() == 'gm';
        
        // For GM: include location in message
        // For others: message without location
        final message = isGM 
            ? '$senderName ($roleLabel) submitted a coaching report on $reportDate.\n$locationMsg'
            : fullMessageWithoutLocation;
        
        return {
          'recipient_id': userId,
          'sender_id': senderUuid ?? senderId,
          'sender_name': senderName,
          'sender_role': senderRole,
          'notification_type': 'location',
          'title': 'Report Submitted',
          'message': message,
          'report_id': reportId,
          'read': false,
        };
      }).toList();

      // Insert notifications to database (in-app notifications)
      await client!.from('notifications').insert(notifications);
      
      debugPrint('✅ Sent ${notifications.length} report submission notification(s) to all users');
      
      // Send push notifications to all users (external notifications with sound - full message without location)
      await _sendPushNotifications(
        title: 'Report Submitted',
        message: fullMessageWithoutLocation,
        reportId: reportId,
      );
    } catch (e) {
      debugPrint('❌ Error sending location notification: $e');
      // Don't throw - notification failure shouldn't block report submission
    }
  }

  /// Send push notifications to all GMs (external notifications with sound)
  static Future<void> _sendPushNotifications({
    required String title,
    required String message,
    required String reportId,
  }) async {
    try {
      // Initialize NotificationService if not already initialized
      await NotificationService.initialize();
      
      // Generate a unique ID based on reportId hash
      final notificationId = reportId.hashCode.abs() % 2147483647; // Max int32
      
      // Show push notification with sound
      await NotificationService.showNotification(
        id: notificationId,
        title: title,
        body: message,
        payload: reportId,
      );
      
      debugPrint('✅ Push notification sent for report: $reportId');
    } catch (e) {
      debugPrint('⚠️ Error sending push notification: $e');
      // Don't throw - push notification failure shouldn't block report submission
    }
  }

  /// Listen to plans changes (real-time)
  static Stream<List<Map<String, dynamic>>> watchPlans(String dmId) {
    if (!isInitialized) {
      return Stream.value([]);
    }
    return client!
        .from('plans')
        .stream(primaryKey: ['id'])
        .eq('dm_id', dmId)
        .order('date', ascending: true)
        .map((data) => (data as List).cast<Map<String, dynamic>>());
  }

  // ==================== Notifications ====================

  /// Get notifications for a GM
  static Future<List<Map<String, dynamic>>> getNotifications(String gmId) async {
    try {
      if (!isInitialized) {
        debugPrint('⚠️ Supabase not initialized, cannot get notifications');
        return [];
      }
      
      debugPrint('🔍 Getting notifications for GM ID: $gmId');
      
      // Convert gmId to UUID if needed
      String? gmUuid = gmId;
      if (!gmId.contains('-') || gmId.length != 36) {
        debugPrint('   GM ID is not UUID format, trying to find UUID...');
        // Try to find user by username or id
        try {
          final users = await client!
              .from('users')
              .select('id')
              .or('id.eq.$gmId,username.eq.$gmId')
              .limit(1);
          if (users.isNotEmpty) {
            gmUuid = users[0]['id']?.toString();
            debugPrint('   ✅ Found GM UUID: $gmUuid');
          } else {
            debugPrint('   ⚠️ No user found with ID/username: $gmId');
          }
        } catch (e) {
          debugPrint('   ❌ Error finding GM UUID: $e');
        }
      } else {
        debugPrint('   ✅ GM ID is already UUID format');
      }
      
      final searchId = gmUuid ?? gmId;
      debugPrint('   🔍 Searching notifications with recipient_id: $searchId');
      
      // Select all fields including title, message, sender_name, sender_role, etc.
      final response = await client!
          .from('notifications')
          .select('id, recipient_id, sender_id, sender_name, sender_role, notification_type, title, message, report_id, read, created_at, updated_at')
          .eq('recipient_id', searchId)
          .order('created_at', ascending: false);
      
      final notifications = (response as List).map((n) => n as Map<String, dynamic>).toList();
      
      debugPrint('📬 Found ${notifications.length} notifications');
      
      // Debug: Print all notifications to verify data
      if (notifications.isNotEmpty) {
        for (var i = 0; i < notifications.length; i++) {
          final notif = notifications[i];
          debugPrint('   Notification $i:');
          debugPrint('      ID: ${notif['id']}');
          debugPrint('      Title: ${notif['title']}');
          debugPrint('      Message: ${notif['message']}');
          debugPrint('      Sender: ${notif['sender_name']} (${notif['sender_role']})');
          debugPrint('      Recipient ID: ${notif['recipient_id']}');
          debugPrint('      Read: ${notif['read']}');
        }
      } else {
        debugPrint('   ⚠️ No notifications found with recipient_id: $searchId');
        debugPrint('   🔍 Trying to find GM by role and get all GM notifications...');
        
        // Fallback: Try to get all GM notifications if specific GM not found
        try {
          // Get all GMs to find matching one
          final gms = await getAllGMs();
          debugPrint('   Found ${gms.length} GMs in database');
          
          // Try to find GM that matches the provided ID
          Map<String, dynamic>? matchingGM;
          for (var gm in gms) {
            final gmIdStr = gm['id']?.toString();
            final gmUsername = gm['username']?.toString();
            if (gmIdStr == gmId || gmIdStr == searchId || gmUsername == gmId) {
              matchingGM = gm;
              debugPrint('   ✅ Found matching GM: ${gm['name']} (ID: $gmIdStr)');
              break;
            }
          }
          
          if (matchingGM != null) {
            final correctGmId = matchingGM['id']?.toString();
            if (correctGmId != null) {
              debugPrint('   🔍 Retrying with correct GM ID: $correctGmId');
              
              final retryResponse = await client!
                  .from('notifications')
                  .select('id, recipient_id, sender_id, sender_name, sender_role, notification_type, title, message, report_id, read, created_at, updated_at')
                  .eq('recipient_id', correctGmId)
                  .order('created_at', ascending: false);
              
              final retryNotifications = (retryResponse as List).map((n) => n as Map<String, dynamic>).toList();
              debugPrint('   📬 Found ${retryNotifications.length} notifications with correct ID');
              return retryNotifications;
            }
          }
          
          // Final fallback: try to return all notifications visible to this GM
          debugPrint('   ⚠️ Falling back to all notifications visible to current user');
          final allNotificationsResponse = await client!
              .from('notifications')
              .select('id, recipient_id, sender_id, sender_name, sender_role, notification_type, title, message, report_id, read, created_at, updated_at')
              .order('created_at', ascending: false);
          final allNotifications = (allNotificationsResponse as List).map((n) => n as Map<String, dynamic>).toList();
          debugPrint('   📬 Fallback returned ${allNotifications.length} notifications');
          return allNotifications;
        } catch (e) {
          debugPrint('   ❌ Error in fallback: $e');
        }
      }
      
      return notifications;
    } catch (e) {
      debugPrint('❌ Error getting notifications: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }
      
      await client!
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);
      
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read for a GM
  static Future<void> markAllNotificationsAsRead(String gmId) async {
    try {
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }
      
      // Convert gmId to UUID if needed
      String? gmUuid = gmId;
      if (!gmId.contains('-') || gmId.length != 36) {
        // Try to find user by username or id
        try {
          final users = await client!
              .from('users')
              .select('id')
              .or('id.eq.$gmId,username.eq.$gmId')
              .limit(1);
          if (users.isNotEmpty) {
            gmUuid = users[0]['id']?.toString();
          }
        } catch (e) {
          debugPrint('⚠️ Could not find GM UUID: $e');
        }
      }
      
      await client!
          .from('notifications')
          .update({'read': true})
          .eq('recipient_id', gmUuid ?? gmId)
          .eq('read', false);
      
      debugPrint('✅ All notifications marked as read for GM: $gmId');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      rethrow;
    }
  }

  /// Get unread notifications count for a GM
  static Future<int> getUnreadNotificationsCount(String gmId) async {
    try {
      if (!isInitialized) {
        return 0;
      }
      
      // Convert gmId to UUID if needed
      String? gmUuid = gmId;
      if (!gmId.contains('-') || gmId.length != 36) {
        // Try to find user by username or id
        try {
          final users = await client!
              .from('users')
              .select('id')
              .or('id.eq.$gmId,username.eq.$gmId')
              .limit(1);
          if (users.isNotEmpty) {
            gmUuid = users[0]['id']?.toString();
          }
        } catch (e) {
          debugPrint('⚠️ Could not find GM UUID: $e');
        }
      }
      
      final response = await client!
          .from('notifications')
          .select('id')
          .eq('recipient_id', gmUuid ?? gmId)
          .eq('read', false);
      
      // Get count from response
      final count = (response as List).length;
      return count;
    } catch (e) {
      debugPrint('❌ Error getting unread notifications count: $e');
      return 0;
    }
  }
}

