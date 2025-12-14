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
import 'package:biosyn_report_flutter/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/utils/export_utils.dart';

void main() {
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
  }

  Future<void> _loadReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getString('biosyn_reports');
      if (reportsJson != null) {
        final List<dynamic> decoded = json.decode(reportsJson);
        setState(() {
          _reports = decoded.map((r) => CoachingReport.fromJson(r)).toList();
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveReport(CoachingReport report) async {
    setState(() {
      _reports = [..._reports, report];
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = json.encode(_reports.map((r) => r.toJson()).toList());
      await prefs.setString('biosyn_reports', reportsJson);
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

  void _handleLogin(String username, String password) {
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
        );
      case 'dm-coaching':
        return CoachingFormScreen(
          date: _coachingDate!,
          mrId: _coachingMrId!,
          mrName: _coachingMrName!,
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
