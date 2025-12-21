import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
      final reportData = {
        // 'id' removed - Supabase will auto-generate UUID
        'date': report.date,
        'dm_id': report.dmId, // This should be UUID from users table
        'dm_name': report.dmName,
        'mr_id': report.mrId,
        'mr_name': report.mrName,
        'coach_role': report.coachRole,
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
        // For PM/MSL/FT: filter by coach_role AND dm_id (where dm_id is the coach ID)
        query = query.eq('coach_role', coachRole).eq('dm_id', coachId);
        debugPrint('   🔍 Filter: coach_role=$coachRole AND dm_id=$coachId');
      } else {
        // For DM, get reports where coach_role is 'dm' or null
        query = query.eq('dm_id', coachId).or('coach_role.is.null,coach_role.eq.dm');
        debugPrint('   🔍 Filter: dm_id=$coachId AND (coach_role IS NULL OR coach_role = dm)');
      }
      
      final response = await query.order('date', ascending: false);
      
      debugPrint('   ✅ Got ${(response as List).length} reports from Supabase');
      
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

      return (response as List)
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
      if (!isInitialized) {
        throw Exception('Supabase not initialized');
      }
      await client!.from('plans').insert({
        'dm_id': dmId,
        'dm_name': dmName,
        'date': date,
        'mr_id': mrId,
        'mr_name': mrName,
        'status': 'pending',
      });
    } catch (e) {
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

  /// Get plans for a specific DM
  static Future<List<Map<String, dynamic>>> getPlans(String dmId) async {
    try {
      if (!isInitialized) {
        return [];
      }
      final response = await client!
          .from('plans')
          .select()
          .eq('dm_id', dmId)
          .order('date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
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
      debugPrint('   Fetching from plans table...');
      final response = await client!
          .from('plans')
          .select()
          .order('date', ascending: true);

      debugPrint('   ✅ Got ${(response as List).length} plans from Supabase');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('   ❌ Error: $e');
      throw Exception('Failed to get all plans: $e');
    }
  }

  // ==================== Authentication ====================

  /// Sign in with username and password
  static Future<Map<String, dynamic>> signIn(String username, String password) async {
    try {
      debugPrint('🔐 SupabaseService.signIn() called');
      debugPrint('   Username: $username');
      
      // Option 1: Use Supabase Auth (if using email-based auth)
      // For now, we'll use custom authentication with users table
      final user = await getUserByUsername(username);
      
      if (user == null) {
        debugPrint('   ❌ User not found');
        throw Exception('User not found');
      }
      
      debugPrint('   ✅ User found: ${user['name']} (${user['role']})');

      // In production, use password hashing (bcrypt)
      // For now, simple comparison (NOT SECURE - for development only)
      if (user['password'] != password && user['password_hash'] != password) {
        debugPrint('   ❌ Invalid password');
        throw Exception('Invalid password');
      }

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
        return null; // Supabase not initialized
      }
      
      final response = await client!
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      return response;
    } catch (e) {
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
    var query = client!
        .from('reports')
        .stream(primaryKey: ['id'])
        .eq('dm_id', coachId);
    
    debugPrint('   🔍 Stream query: dm_id=$coachId');
    
    // Note: Supabase stream doesn't support chaining multiple eq() after stream()
    // So we filter by coach_role in the map function instead
    return query
        .order('date', ascending: false)
        .map((data) {
          var reports = (data as List)
              .map((json) => CoachingReport.fromSupabaseJson(json))
              .toList();
          
          debugPrint('   📊 Stream received ${reports.length} reports before coach_role filter');
          
          // Filter by coach_role if provided
          if (coachRole != null) {
            final beforeCount = reports.length;
            reports = reports.where((r) => r.coachRole == coachRole).toList();
            debugPrint('   🔍 Filtered by coach_role=$coachRole: ${beforeCount} -> ${reports.length} reports');
            
            // Debug: Log coach_role values
            if (beforeCount > 0 && reports.length == 0) {
              debugPrint('   ⚠️ No reports match coach_role=$coachRole. Available coach_roles:');
              final allReports = (data as List).map((json) => CoachingReport.fromSupabaseJson(json)).toList();
              for (var r in allReports) {
                debugPrint('      - Report: dm_id=${r.dmId}, coach_role=${r.coachRole}, mr_id=${r.mrId}, date=${r.date}');
              }
            }
          }
          
          return reports;
        });
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
}

