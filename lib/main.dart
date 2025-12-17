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
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
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
      // Force English locale and LTR direction
      locale: const Locale('en', 'US'),
      supportedLocales: const [Locale('en', 'US')],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: child!,
          ),
        );
      },
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
  String? _userId;
  String _activeTab = 'planning';
  List<CoachingReport> _reports = [];
  String? _coachingDate;
  String? _coachingMrId;
  String? _coachingMrName;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _checkSession();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    // Listen to connectivity changes and auto-sync when connected
    _connectivitySubscription = ConnectivityService.connectivityStream.listen(
      (ConnectivityResult result) {
        if (result != ConnectivityResult.none) {
          // Internet connected - trigger sync
          SyncService.syncIfNeeded().then((success) {
            if (success && mounted) {
              // Reload reports after successful sync
              _loadReports();
            }
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkSession() async {
    // Check if user is already logged in
    final isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        final userRole = user['role'] as String?;
        final userId = user['id']?.toString();
        setState(() {
          _userName = user['name'] as String? ?? '';
          _userId = userId;
          _selectedRole = userRole ?? 'dm';
          if (userRole == 'dm') {
            _currentScreen = 'dm-planning';
            _activeTab = 'planning';
          } else if (userRole == 'gm') {
            _currentScreen = 'gm-dashboard';
            _activeTab = 'dashboard';
          }
        });
        // Reload reports after session check
        await _loadReports();
      }
    }
  }

  Future<void> _loadReports() async {
    try {
      debugPrint('📊 Loading reports...');
      debugPrint('   Role: $_selectedRole');
      debugPrint('   User ID: $_userId');
      
      // First, load from local database
      List<CoachingReport> reports = await DatabaseService.getReports();
      debugPrint('   Local reports: ${reports.length}');
      
      // If online, fetch from Supabase and merge
      final isConnected = await ConnectivityService.isConnected();
      debugPrint('   Is connected: $isConnected');
      debugPrint('   Supabase initialized: ${SupabaseService.isInitialized}');
      
      if (isConnected && SupabaseService.isInitialized) {
        try {
          List<CoachingReport> supabaseReports;
          
          // For GM, fetch ALL reports. For DM, fetch only their reports.
          if (_selectedRole == 'gm') {
            debugPrint('   Fetching ALL reports for GM...');
            supabaseReports = await SupabaseService.getAllReports();
          } else if (_userId != null) {
            debugPrint('   Fetching reports for DM: $_userId');
            supabaseReports = await SupabaseService.getReports(_userId!);
          } else {
            debugPrint('   No user ID, skipping Supabase fetch');
            supabaseReports = [];
          }
          
          debugPrint('   Supabase reports: ${supabaseReports.length}');
          
          // Merge: Add Supabase reports that don't exist locally
          final localReportIds = reports.map((r) => '${r.mrId}_${r.date}').toSet();
          int newReportsAdded = 0;
          for (final supabaseReport in supabaseReports) {
            final reportId = '${supabaseReport.mrId}_${supabaseReport.date}';
            if (!localReportIds.contains(reportId)) {
              // Save to local database
              await DatabaseService.saveReport(supabaseReport, synced: true);
              reports.add(supabaseReport);
              newReportsAdded++;
            }
          }
          debugPrint('   New reports added from Supabase: $newReportsAdded');
          
          // If GM and local is empty but Supabase has data, use Supabase data directly
          if (_selectedRole == 'gm' && reports.isEmpty && supabaseReports.isNotEmpty) {
            reports = supabaseReports;
            debugPrint('   Using Supabase reports directly for GM');
          }
          
          // Sort by date (newest first)
          reports.sort((a, b) => b.date.compareTo(a.date));
        } catch (e) {
          // Supabase fetch failed, continue with local data
          debugPrint('❌ Failed to fetch reports from Supabase: $e');
        }
      }
      
      debugPrint('   Total reports loaded: ${reports.length}');
      
      setState(() {
        _reports = reports;
      });
      
      // Try to sync unsynced items if online
      if (isConnected) {
        SyncService.syncIfNeeded();
      }
    } catch (e) {
      // Handle error
      debugPrint('❌ Error loading reports: $e');
    }
  }

  Future<void> _saveReport(CoachingReport report) async {
    try {
      // Check if online
      final isConnected = await ConnectivityService.isConnected();
      
      // If online, try to save to Supabase first
      bool synced = false;
      if (isConnected && SupabaseService.isInitialized) {
        try {
          await SupabaseService.saveReport(report);
          synced = true;
          debugPrint('✅ Report saved to Supabase successfully');
        } catch (e) {
          // Supabase save failed, will sync later
          synced = false;
          debugPrint('❌ Failed to save report to Supabase: $e');
          debugPrint('Report will be synced later when connection is stable');
        }
      } else {
        debugPrint('⚠️ Not connected or Supabase not initialized - saving locally only');
      }
      
      // Save to local database
      await DatabaseService.saveReport(report, synced: synced);
      
      // Update UI
      setState(() {
        _reports = [..._reports, report];
      });
      
      // If not synced and online, try to sync unsynced items
      if (isConnected && !synced) {
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
        _userId = user['id']?.toString();
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
      
      // After login, reload reports (will fetch from Supabase if online)
      await _loadReports();
    } catch (e) {
      // Fallback to local authentication if Supabase fails
      // This allows the app to work even without Supabase configured
      setState(() {
        _userName = username;
        _userId = null; // No user ID for offline mode
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
      _userId = null;
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
          dmId: _userId ?? (_userName.isNotEmpty ? 'dm_${_userName.hashCode}' : 'dm_001'),
          dmName: _userName.isNotEmpty ? _userName : 'District Manager',
        );
      case 'dm-coaching':
        return CoachingFormScreen(
          date: _coachingDate!,
          mrId: _coachingMrId!,
          mrName: _coachingMrName!,
          dmId: _userId ?? (_userName.isNotEmpty ? 'dm_${_userName.hashCode}' : 'dm_001'), // Use UUID from Supabase
          dmName: _userName,
          onSubmit: (report) async {
            // Time Restriction: Cannot submit after 12:00 AM (midnight)
            final hour = DateTime.now().hour;
            if (hour >= 0 && hour < 6) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cannot submit coaching reports after 12:00 AM (midnight)')),
              );
              return;
            }
            
            await _saveReport(report);
            // Reload reports to include the new one
            await _loadReports();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coaching report submitted successfully!')),
              );
              setState(() {
                _currentScreen = 'dm-planning';
                _coachingDate = null;
                _coachingMrId = null;
                _coachingMrName = null;
              });
            }
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
          dmId: _userId,
          onRefresh: () async {
            await _loadReports();
          },
          onExport: (reportId) async {
            try {
              if (reportId != null && _reports.isNotEmpty) {
                // Export single report
                final report = _reports.firstWhere(
                  (r) => (r.mrId + r.date) == reportId,
                  orElse: () => _reports.first,
                );
                await ExportUtils.exportSingleReportToText(report);
              } else if (_reports.isNotEmpty) {
                // Export monthly report
                await ExportUtils.exportMonthlyReport(_reports, _userName);
              } else {
                throw Exception('No reports to export');
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
              await ExportUtils.exportAllReportsToText(_reports);
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
              if (reportId != null && _reports.isNotEmpty) {
                // Export single report
                final report = _reports.firstWhere(
                  (r) => (r.mrId + r.date) == reportId,
                  orElse: () => _reports.first,
                );
                await ExportUtils.exportSingleReportToText(report);
              } else if (_reports.isNotEmpty) {
                // Export all reports
                await ExportUtils.exportAllReportsToText(_reports);
              } else {
                throw Exception('No reports to export');
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
