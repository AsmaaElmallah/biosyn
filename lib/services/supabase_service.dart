import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:flutter/foundation.dart';

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
        'average_score': report.getAverageScore(),
        'synced': true,
      };
      
      // Insert report (Supabase will auto-generate UUID for id)
      // Log the data being sent for debugging
      debugPrint('📤 Saving report to Supabase:');
      debugPrint('   dm_id: ${report.dmId}');
      debugPrint('   mr_id: ${report.mrId}');
      debugPrint('   date: ${report.date}');
      
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

  /// Get reports for a specific DM
  static Future<List<CoachingReport>> getReports(String dmId) async {
    try {
      if (!isInitialized) {
        return [];
      }
      final response = await client!
          .from('reports')
          .select()
          .eq('dm_id', dmId)
          .order('date', ascending: false);

      return (response as List)
          .map((json) => CoachingReport.fromSupabaseJson(json))
          .toList();
    } catch (e) {
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
          .select()
          .eq('role', 'mr')
          .eq('status', 'active')
          .order('name', ascending: true);

      debugPrint('   ✅ Got ${(response as List).length} MRs from Supabase');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('   ❌ Error: $e');
      throw Exception('Failed to get MRs: $e');
    }
  }

  /// Update existing user (for GM)
  static Future<void> updateUser({
    required String id,
    String? name,
    String? username,
    String? password,
    String? email,
    String? role,
    String? status,
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
      if (role != null) updates['role'] = role;
      if (status != null) updates['status'] = status;

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

  // ==================== Real-time ====================

  /// Listen to reports changes (real-time)
  static Stream<List<CoachingReport>> watchReports(String dmId) {
    if (!isInitialized) {
      return Stream.value([]);
    }
    return client!
        .from('reports')
        .stream(primaryKey: ['id'])
        .eq('dm_id', dmId)
        .order('date', ascending: false)
        .map((data) => (data as List)
            .map((json) => CoachingReport.fromSupabaseJson(json))
            .toList());
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

