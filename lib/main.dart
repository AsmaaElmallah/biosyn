import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/theme.dart';
import 'package:biosyn_report_flutter/screens/splash_screen.dart';
import 'package:biosyn_report_flutter/screens/welcome_screen.dart';
import 'package:biosyn_report_flutter/screens/login_screen.dart';
import 'package:biosyn_report_flutter/screens/dm/dm_planning_screen.dart';
import 'package:biosyn_report_flutter/screens/dm/dm_dashboard_screen.dart';
import 'package:biosyn_report_flutter/screens/dm/coaching_form_screen.dart';
import 'package:biosyn_report_flutter/screens/gm/gm_dashboard_screen.dart';
import 'package:biosyn_report_flutter/screens/gm/gm_reports_screen.dart';
import 'package:biosyn_report_flutter/screens/gm/user_management_screen.dart';
import 'package:biosyn_report_flutter/screens/gm/gm_view_plans_screen.dart';
import 'package:biosyn_report_flutter/screens/profile_screen.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/utils/export_utils.dart';
import 'package:biosyn_report_flutter/services/database_service.dart';
import 'package:biosyn_report_flutter/services/connectivity_service.dart';
import 'package:biosyn_report_flutter/services/sync_service.dart';
import 'package:biosyn_report_flutter/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:biosyn_report_flutter/config/supabase_config.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (only if configured)
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      debugPrint('✅ Supabase initialized successfully');
    } catch (e) {
      // Supabase not configured or connection failed - continue with local only
      debugPrint('❌ Supabase initialization failed: $e');
    }
  } else {
    debugPrint('⚠️ Supabase not configured - running in offline mode');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biosyn Coaching App',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AppNavigator(),
    );
  }
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  String _currentScreen = 'splash';
  String? _selectedRole;
  String _userName = '';
  String _activeTab = 'planning';
  List<CoachingReport> _reports = [];
  String? _coachingDate;
  String? _coachingMrId;
  String? _coachingMrName;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Check if user is already logged in
    final isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        final userRole = user['role'] as String?;
        setState(() {
          _userName = user['name'] as String? ?? '';
          _selectedRole = userRole ?? 'dm';
          if (userRole == 'dm') {
            _currentScreen = 'dm-planning';
            _activeTab = 'planning';
          } else if (userRole == 'gm') {
            _currentScreen = 'gm-dashboard';
            _activeTab = 'dashboard';
          }
        });
      }
    }
  }

  Future<void> _loadReports() async {
    try {
      final reports = await DatabaseService.getReports();
      setState(() {
        _reports = reports;
      });
      
      // Try to sync if online
      final isConnected = await ConnectivityService.isConnected();
      if (isConnected) {
        SyncService.syncIfNeeded();
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveReport(CoachingReport report) async {
    try {
      // Check if online
      final isConnected = await ConnectivityService.isConnected();
      
      // Save to local database
      await DatabaseService.saveReport(report, synced: isConnected);
      
      // Update UI
      setState(() {
        _reports = [..._reports, report];
      });
      
      // If online, try to sync immediately
      if (isConnected) {
        try {
          await SyncService.syncIfNeeded();
        } catch (e) {
          // Sync failed, will retry later
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  void _handleSplashComplete() {
    setState(() {
      _currentScreen = 'welcome';
    });
  }

  void _handleRoleSelect(String role) {
    setState(() {
      _selectedRole = role;
      _currentScreen = 'login';
    });
  }

  Future<void> _handleLogin(String username, String password) async {
    try {
      // Use AuthService for authentication
      final user = await AuthService.signIn(username, password);
      
      setState(() {
        _userName = user['name'] as String? ?? username;
        final userRole = user['role'] as String?;
        
        // Determine screen based on role or selected role
        if (userRole == 'dm' || _selectedRole == 'dm') {
          _currentScreen = 'dm-planning';
          _activeTab = 'planning';
        } else if (userRole == 'gm' || _selectedRole == 'gm') {
          _currentScreen = 'gm-dashboard';
          _activeTab = 'dashboard';
        } else {
          // Default based on selected role
          if (_selectedRole == 'dm') {
            _currentScreen = 'dm-planning';
            _activeTab = 'planning';
          } else {
            _currentScreen = 'gm-dashboard';
            _activeTab = 'dashboard';
          }
        }
      });
    } catch (e) {
      // Fallback to local authentication if Supabase fails
      // This allows the app to work even without Supabase configured
      setState(() {
        _userName = username;
        if (_selectedRole == 'dm') {
          _currentScreen = 'dm-planning';
          _activeTab = 'planning';
        } else {
          _currentScreen = 'gm-dashboard';
          _activeTab = 'dashboard';
        }
      });
    }
  }

  void _handleBackToWelcome() {
    setState(() {
      _currentScreen = 'welcome';
      _selectedRole = null;
    });
  }

  void _handleTabChange(String tab) {
    setState(() {
      _activeTab = tab;
      if (_selectedRole == 'dm') {
        switch (tab) {
          case 'planning':
            _currentScreen = 'dm-planning';
            break;
          case 'dashboard':
            _currentScreen = 'dm-dashboard';
            break;
          case 'profile':
            _currentScreen = 'profile';
            break;
        }
      } else if (_selectedRole == 'gm') {
        switch (tab) {
          case 'dashboard':
            _currentScreen = 'gm-dashboard';
            break;
          case 'users':
            _currentScreen = 'gm-users';
            break;
          case 'reports':
            _currentScreen = 'gm-reports';
            break;
          case 'plans':
            _currentScreen = 'gm-view-plans';
            break;
          case 'profile':
            _currentScreen = 'profile';
            break;
        }
      }
    });
  }

  void _handleLogout() {
    setState(() {
      _currentScreen = 'welcome';
      _selectedRole = null;
      _userName = '';
      _activeTab = 'planning';
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentScreen) {
      case 'splash':
        return SplashScreen(onComplete: _handleSplashComplete);
      case 'welcome':
        return WelcomeScreen(onSelectRole: _handleRoleSelect);
      case 'login':
        return LoginScreen(
          role: _selectedRole!,
          onLogin: _handleLogin,
          onBack: _handleBackToWelcome,
        );
      case 'dm-planning':
        return DMPlanningScreen(
          onStartCoaching: (date, mrId, mrName) {
            setState(() {
              _coachingDate = date;
              _coachingMrId = mrId;
              _coachingMrName = mrName;
              _currentScreen = 'dm-coaching';
            });
          },
          activeTab: _activeTab,
          onTabChange: _handleTabChange,
          dmId: _userName.isNotEmpty ? 'dm_${_userName.hashCode}' : 'dm_001',
          dmName: _userName.isNotEmpty ? _userName : 'District Manager',
        );
      case 'dm-coaching':
        return CoachingFormScreen(
          date: _coachingDate!,
          mrId: _coachingMrId!,
          mrName: _coachingMrName!,
          dmId: _userName.isNotEmpty ? 'dm_${_userName.hashCode}' : 'dm_001',
          dmName: _userName,
          onSubmit: (report) {
            // Time Restriction: Cannot submit after 12:00 AM (midnight)
            final hour = DateTime.now().hour;
            if (hour >= 0 && hour < 6) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cannot submit coaching reports after 12:00 AM (midnight)')),
              );
              return;
            }
            
            _saveReport(report);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coaching report submitted successfully!')),
            );
            setState(() {
              _currentScreen = 'dm-planning';
              _coachingDate = null;
              _coachingMrId = null;
              _coachingMrName = null;
            });
          },
          onBack: () {
            setState(() {
              _currentScreen = 'dm-planning';
              _coachingDate = null;
              _coachingMrId = null;
              _coachingMrName = null;
            });
          },
        );
      case 'dm-dashboard':
        return DMDashboardScreen(
          reports: _reports,
          onExport: (reportId) async {
            try {
              if (reportId != null) {
                // Export single report
                final report = _reports.firstWhere(
                  (r) => (r.mrId + r.date) == reportId,
                  orElse: () => _reports.first,
                );
                await ExportUtils.exportSingleReportToText(report);
              } else {
                // Export monthly report
                await ExportUtils.exportMonthlyReport(_reports, _userName);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report exported successfully!')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: ${e.toString()}')),
                );
              }
            }
          },
          activeTab: _activeTab,
          onTabChange: _handleTabChange,
        );
      case 'gm-dashboard':
        return GMDashboardScreen(
          allReports: _reports,
          onExport: () async {
            try {
              await ExportUtils.exportToCSV(_reports, 'all_coaching_reports.csv');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reports exported successfully!')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: ${e.toString()}')),
                );
              }
            }
          },
          activeTab: _activeTab,
          onTabChange: _handleTabChange,
        );
      case 'gm-users':
        return UserManagementScreen(
          activeTab: _activeTab,
          onTabChange: _handleTabChange,
        );
      case 'gm-reports':
        return GMReportsScreen(
          reports: _reports,
          onExport: (reportId) async {
            try {
              if (reportId != null) {
                // Export single report
                final report = _reports.firstWhere(
                  (r) => (r.mrId + r.date) == reportId,
                  orElse: () => _reports.first,
                );
                await ExportUtils.exportSingleReportToText(report);
              } else {
                // Export all reports
                await ExportUtils.exportToCSV(_reports, 'all_coaching_reports.csv');
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report exported successfully!')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: ${e.toString()}')),
                );
              }
            }
          },
          activeTab: _activeTab,
          onTabChange: _handleTabChange,
        );
      case 'gm-view-plans':
        return GMViewPlansScreen(
          activeTab: _activeTab,
          onTabChange: _handleTabChange,
        );
      case 'profile':
        return ProfileScreen(
          role: _selectedRole!,
          userName: _userName,
          onLogout: _handleLogout,
          activeTab: _activeTab,
          onTabChange: _handleTabChange,
        );
      default:
        return Scaffold(
          body: Center(
            child: Text('Screen: $_currentScreen\nComing soon...'),
          ),
        );
    }
  }
}
