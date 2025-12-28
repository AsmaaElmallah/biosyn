import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/theme.dart';
import 'package:biosyn_report_flutter/screens/splash_screen.dart';
import 'package:biosyn_report_flutter/screens/login_screen.dart';
import 'package:biosyn_report_flutter/screens/dm/dm_planning_screen.dart';
import 'package:biosyn_report_flutter/screens/dm/dm_dashboard_screen.dart';
import 'package:biosyn_report_flutter/screens/dm/coaching_form_screen.dart';
import 'package:biosyn_report_flutter/screens/pm_msl/pm_planning_screen.dart';
import 'package:biosyn_report_flutter/screens/pm_msl/pm_msl_dashboard_screen.dart';
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
import 'package:biosyn_report_flutter/services/notification_service.dart';
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
  
  // Initialize Notification Service
  await NotificationService.initialize();
  
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
            data: MediaQuery.of(context).copyWith(
              // Ensure text scaling for accessibility (iOS and Android)
              textScaler: MediaQuery.of(context).textScaler.clamp(
                minScaleFactor: 0.8,
                maxScaleFactor: 1.2,
              ),
            ),
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
  bool _isQuickSession = false;
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
          if (userRole == 'dm' || userRole == 'ft') {
            _currentScreen = 'dm-planning';
            _activeTab = 'planning';
          } else if (userRole == 'pm' || userRole == 'msl') {
            _currentScreen = 'pm-planning';
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
      
      bool supabaseFetchSucceeded = false;
      if (isConnected && SupabaseService.isInitialized) {
        try {
          List<CoachingReport> supabaseReports;
          
          // For GM, fetch ALL reports. For DM/FT/PM/MSL, fetch only their reports.
          if (_selectedRole == 'gm') {
            debugPrint('   Fetching ALL reports for GM...');
            supabaseReports = await SupabaseService.getAllReports();
            supabaseFetchSucceeded = true;
          } else if (_userId != null) {
            debugPrint('   Fetching reports for $_selectedRole: $_userId');
            // For PM/MSL/FT, filter by coach_role
            if (_selectedRole == 'pm' || _selectedRole == 'msl' || _selectedRole == 'ft') {
              supabaseReports = await SupabaseService.getReports(_userId!, coachRole: _selectedRole);
            } else {
              // For DM, use default filtering (coach_role = 'dm' or null)
              supabaseReports = await SupabaseService.getReports(_userId!);
            }
            supabaseFetchSucceeded = true;
          } else {
            debugPrint('   No user ID, skipping Supabase fetch');
            supabaseReports = [];
            supabaseFetchSucceeded = true; // Not an error, just no user ID
          }
          
          debugPrint('   Supabase reports: ${supabaseReports.length}');
          
          // Merge: Add Supabase reports that don't exist locally
          // Use coachRole in the ID to differentiate between DM and FT reports with same MR and date
          debugPrint('   📋 Building local report IDs set...');
          debugPrint('   📋 Analyzing ${reports.length} local reports...');
          for (int i = 0; i < reports.length && i < 3; i++) {
            final r = reports[i];
            debugPrint('      Local[$i]: MR=${r.mrId}, Date=${r.date}, CoachRole=${r.coachRole ?? 'null'}, DmId=${r.dmId}');
          }
          
          final localReportIds = reports.map((r) => '${r.mrId}_${r.date}_${r.coachRole ?? 'null'}').toSet();
          debugPrint('   📋 Local report IDs (${localReportIds.length}): ${localReportIds.take(5).join(', ')}${localReportIds.length > 5 ? '...' : ''}');
          
          int newReportsAdded = 0;
          debugPrint('   🔍 Processing ${supabaseReports.length} Supabase reports...');
          for (final supabaseReport in supabaseReports) {
            final reportId = '${supabaseReport.mrId}_${supabaseReport.date}_${supabaseReport.coachRole ?? 'null'}';
            debugPrint('   🔍 Checking Supabase report:');
            debugPrint('      ReportId: $reportId');
            debugPrint('      MR: ${supabaseReport.mrId}');
            debugPrint('      Date: ${supabaseReport.date}');
            debugPrint('      CoachRole: ${supabaseReport.coachRole ?? 'null'}');
            debugPrint('      DmId: ${supabaseReport.dmId}');
            
            // Check if exists with same MR and date but different coachRole
            final sameMrDate = reports.where((r) => r.mrId == supabaseReport.mrId && r.date == supabaseReport.date).toList();
            if (sameMrDate.isNotEmpty) {
              debugPrint('      ⚠️ Found ${sameMrDate.length} local report(s) with same MR and date:');
              for (final r in sameMrDate) {
                debugPrint('         Local: CoachRole=${r.coachRole ?? 'null'}, DmId=${r.dmId}');
              }
            }
            
            final exists = localReportIds.contains(reportId);
            debugPrint('      Local IDs contains this report: $exists');
            
            if (!exists) {
              debugPrint('   ✅ Adding new report from Supabase: $reportId');
              // Save to local database
              await DatabaseService.saveReport(supabaseReport, synced: true);
              reports.add(supabaseReport);
              newReportsAdded++;
            } else {
              debugPrint('   ⏭️ Report already exists locally: $reportId');
            }
          }
          debugPrint('   ✅ New reports added from Supabase: $newReportsAdded');
          
          // For GM: Remove local reports that no longer exist in Supabase
          if (_selectedRole == 'gm' && supabaseFetchSucceeded) {
            debugPrint('   🗑️ Checking for deleted reports in Supabase...');
            final supabaseReportIds = supabaseReports.map((r) => '${r.mrId}_${r.date}_${r.coachRole ?? 'null'}').toSet();
            final reportsToDelete = <String>[];
            
            for (final localReport in reports) {
              final reportId = '${localReport.mrId}_${localReport.date}_${localReport.coachRole ?? 'null'}';
              if (!supabaseReportIds.contains(reportId)) {
                reportsToDelete.add(reportId);
                debugPrint('   🗑️ Report to delete (not in Supabase): $reportId');
              }
            }
            
            if (reportsToDelete.isNotEmpty) {
              debugPrint('   🗑️ Deleting ${reportsToDelete.length} reports from local database...');
              for (final reportId in reportsToDelete) {
                await DatabaseService.deleteReport(reportId);
              }
              // Remove from reports list
              reports = reports.where((r) {
                final reportId = '${r.mrId}_${r.date}_${r.coachRole ?? 'null'}';
                return !reportsToDelete.contains(reportId);
              }).toList();
              debugPrint('   ✅ Deleted ${reportsToDelete.length} reports from local database');
            }
            
            // If local is empty but Supabase has data, use Supabase data directly
            if (reports.isEmpty && supabaseReports.isNotEmpty) {
              reports = supabaseReports;
              debugPrint('   Using Supabase reports directly for GM');
            }
          }
          
          // Sort by date (newest first)
          reports.sort((a, b) => b.date.compareTo(a.date));
        } catch (e) {
          // Supabase fetch failed, continue with local data
          debugPrint('❌ Failed to fetch reports from Supabase: $e');
          supabaseFetchSucceeded = false;
        }
      }
      
      // Filter reports based on role (for FT, only show reports with coach_role = 'ft')
      // IMPORTANT: If Supabase fetch failed, be more lenient with filtering to avoid empty dashboard
      debugPrint('   🔍 Filtering reports for role: $_selectedRole, userId: $_userId');
      debugPrint('   📊 Reports before filtering: ${reports.length}');
      debugPrint('   📊 Supabase fetch succeeded: $supabaseFetchSucceeded');
      
      if (_selectedRole == 'ft' && _userId != null) {
        final beforeFilter = reports.length;
        debugPrint('   📊 Before filtering: $beforeFilter reports');
        
        // Filter: Only show reports with coachRole = 'ft' AND dmId = userId
        final filtered = reports.where((r) {
          final matches = r.coachRole == 'ft' && r.dmId == _userId;
          if (!matches) {
            debugPrint('   ⏭️ Filtered out: MR=${r.mrId}, Date=${r.date}, CoachRole=${r.coachRole ?? 'null'}, DmId=${r.dmId} (expected: ft, $_userId)');
          }
          return matches;
        }).toList();
        
        // Apply filter, but if it results in empty list and Supabase fetch failed,
        // show a message or keep some reports to indicate the issue
        if (filtered.isNotEmpty) {
          reports = filtered;
          debugPrint('   ✅ Filtered reports for FT: $beforeFilter -> ${reports.length}');
        } else if (supabaseFetchSucceeded) {
          // Supabase fetch succeeded but no FT reports found - this is correct, show empty
          reports = filtered;
          debugPrint('   ✅ Filtered reports for FT: $beforeFilter -> ${reports.length} (no FT reports found)');
        } else {
          // Supabase fetch failed - don't filter aggressively to avoid empty dashboard
          // This indicates a connection issue, so we'll show filtered results but log a warning
          reports = filtered;
          debugPrint('   ⚠️ Filtered reports for FT: $beforeFilter -> ${reports.length} (Supabase fetch failed, may be connection issue)');
        }
      } else if (_selectedRole == 'dm' && _userId != null) {
        // For DM, show reports with coach_role = 'dm' or null/empty (for backward compatibility)
        final beforeFilter = reports.length;
        debugPrint('   📊 Before filtering: $beforeFilter reports');
        reports = reports.where((r) => (r.coachRole == 'dm' || r.coachRole == null || (r.coachRole?.isEmpty ?? true)) && r.dmId == _userId).toList();
        debugPrint('   ✅ Filtered reports for DM: $beforeFilter -> ${reports.length}');
      }
      
      debugPrint('   Total reports loaded: ${reports.length}');
      
      if (mounted) {
        setState(() {
          _reports = reports;
        });
      }
      
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
      _currentScreen = 'login';
    });
  }

  Future<void> _handleLogin(String username, String password) async {
    try {
      // Use SupabaseService for authentication
      final user = await SupabaseService.signIn(username, password);
      
      setState(() {
        _userName = user['name'] as String? ?? username;
        _userId = user['id']?.toString();
        final userRole = user['role'] as String?;
        
        // Update selected role based on actual user role from database
        if (userRole != null) {
          _selectedRole = userRole;
        }
        
        // Determine screen based on role automatically
        if (userRole == 'dm' || userRole == 'ft') {
          _currentScreen = 'dm-planning';
          _activeTab = 'planning';
        } else if (userRole == 'pm' || userRole == 'msl') {
          _currentScreen = 'pm-planning';
          _activeTab = 'planning';
        } else if (userRole == 'gm') {
          _currentScreen = 'gm-dashboard';
          _activeTab = 'dashboard';
        } else {
          // Default fallback (should not happen if database is correct)
          _currentScreen = 'login';
        }
      });
      
      // After login, reload reports (will fetch from Supabase if online)
      await _loadReports();
    } catch (e) {
      // Authentication failed - stay on login screen
      // Error will be shown by LoginScreen
      debugPrint('Login failed: $e');
    }
  }

  void _handleTabChange(String tab) {
    setState(() {
      _activeTab = tab;
      if (_selectedRole == 'dm' || _selectedRole == 'ft') {
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
      } else if (_selectedRole == 'pm' || _selectedRole == 'msl') {
        switch (tab) {
          case 'planning':
            _currentScreen = 'pm-planning';
            break;
          case 'dashboard':
            _currentScreen = 'pm-dashboard';
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
      _currentScreen = 'login';
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
      case 'login':
        return LoginScreen(
          onLogin: _handleLogin,
        );
      case 'dm-planning':
        return DMPlanningScreen(
          onStartCoaching: (date, mrId, mrName, isQuickSession) {
            setState(() {
              _coachingDate = date;
              _coachingMrId = mrId;
              _coachingMrName = mrName;
              _isQuickSession = isQuickSession;
              _currentScreen = 'dm-coaching';
            });
          },
          activeTab: _activeTab,
          onTabChange: _handleTabChange,
          dmId: _userId ?? (_userName.isNotEmpty ? 'dm_${_userName.hashCode}' : 'dm_001'),
          dmName: _userName.isNotEmpty ? _userName : 'District Manager',
          coachRole: _selectedRole == 'ft' ? 'ft' : 'dm',
        );
      case 'dm-coaching':
        return CoachingFormScreen(
          date: _coachingDate!,
          mrId: _coachingMrId!,
          mrName: _coachingMrName!,
          dmId: _userId ?? (_userName.isNotEmpty ? 'dm_${_userName.hashCode}' : 'dm_001'), // Use UUID from Supabase
          dmName: _userName,
          coachRole: _selectedRole == 'ft' ? 'ft' : 'dm', // Pass the actual role
          isQuickSession: _isQuickSession,
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
                _isQuickSession = false;
              });
            }
          },
          onBack: () {
            setState(() {
              _currentScreen = 'dm-planning';
              _coachingDate = null;
              _coachingMrId = null;
              _coachingMrName = null;
              _isQuickSession = false;
            });
          },
        );
      case 'dm-dashboard':
        // Filter reports based on role: FT should only see reports with coach_role = 'ft'
        final filteredReports = _selectedRole == 'ft'
            ? _reports.where((r) => r.coachRole == 'ft' && r.dmId == _userId).toList()
            : _selectedRole == 'dm'
                ? _reports.where((r) => (r.coachRole == 'dm' || r.coachRole == null || (r.coachRole?.isEmpty ?? true)) && r.dmId == _userId).toList()
                : _reports.where((r) => r.dmId == _userId).toList();
        return DMDashboardScreen(
          reports: filteredReports,
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
          gmId: _userId,
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
      case 'pm-planning':
        return PMPlanningScreen(
          activeTab: _activeTab,
          onTabChange: _handleTabChange,
          coachId: _userId,
          coachName: _userName,
          coachRole: _selectedRole == 'pm' ? 'pm' : 'msl',
          onReportSubmit: (report) async {
            await _saveReport(report);
            await _loadReports();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coaching report submitted successfully!')),
              );
            }
          },
        );
      case 'pm-dashboard':
        return PMMSLDashboardScreen(
          reports: _reports.where((r) => 
            r.coachRole == _selectedRole && r.dmId == _userId
          ).toList(),
          coachId: _userId,
          coachRole: _selectedRole == 'pm' ? 'pm' : 'msl',
          onRefresh: () async {
            await _loadReports();
          },
          onExport: (reportId) async {
            try {
              final pmReports = _reports.where((r) => 
                r.coachRole == _selectedRole || 
                (r.coachRole == null && (r.dmId == _userId || r.dmId == '${_selectedRole}_001'))
              ).toList();
              
              if (reportId != null && pmReports.isNotEmpty) {
                final report = pmReports.firstWhere(
                  (r) => (r.mrId + r.date) == reportId,
                  orElse: () => pmReports.first,
                );
                await ExportUtils.exportSingleReportToText(report);
              } else if (pmReports.isNotEmpty) {
                await ExportUtils.exportAllReportsToText(pmReports);
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
      case 'profile':
        return ProfileScreen(
          role: _selectedRole!,
          userName: _userName,
          userId: _userId,
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
