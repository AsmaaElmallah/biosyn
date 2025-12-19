import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:biosyn_report_flutter/services/supabase_service.dart';

/// Service لإدارة Authentication و Session
class AuthService {
  static const String _sessionKey = 'biosyn_session';
  static const String _userKey = 'biosyn_user';

  /// Sign in with username and password
  static Future<Map<String, dynamic>> signIn(String username, String password) async {
    try {
      // Try Supabase authentication first
      final user = await SupabaseService.signIn(username, password);
      
      // Save session locally with password
      await _saveSession(user, password: password);
      
      return user;
    } catch (e) {
      // If Supabase fails, check if we should allow offline login
      // For development, allow offline login with any credentials
      final offlineUser = {
        'id': 'offline_${username.hashCode}',
        'username': username,
        'name': username,
        'role': 'dm', // Default role
        'email': '$username@biosyn.com',
      };
      
      await _saveSession(offlineUser);
      return offlineUser;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
    } catch (e) {
      // Ignore errors
    }
    
    // Clear local session
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_userKey);
  }

  /// Get current user
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      // Try Supabase session first
      final supabaseUser = SupabaseService.getCurrentUser();
      if (supabaseUser != null) {
        return supabaseUser;
      }
      
      // Fallback to local session
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        return json.decode(userJson) as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }

  /// Save session locally
  static Future<void> _saveSession(Map<String, dynamic> user, {String? password}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, DateTime.now().toIso8601String());
    await prefs.setString(_userKey, json.encode(user));
    // Save password for later use in Supabase Auth
    if (password != null && password.isNotEmpty) {
      await prefs.setString('biosyn_password', password);
    }
  }

  /// Get user role
  static Future<String?> getUserRole() async {
    final user = await getCurrentUser();
    return user?['role'] as String?;
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    final user = await getCurrentUser();
    return user?['id']?.toString();
  }

  /// Get user name
  static Future<String?> getUserName() async {
    final user = await getCurrentUser();
    return user?['name'] as String?;
  }
}

