import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/theme/text_styles.dart';
import 'package:biosyn_report_flutter/theme/spacing.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/widgets/app_card.dart';
import 'package:biosyn_report_flutter/widgets/sync_status_indicator.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:biosyn_report_flutter/utils/export_utils.dart';
import 'package:biosyn_report_flutter/screens/shared/notifications_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class PMMSLDashboardScreen extends StatefulWidget {
  final List<CoachingReport> reports;
  final Function(String?) onExport;
  final String activeTab;
  final Function(String) onTabChange;
  final Future<void> Function()? onRefresh;
  final String? coachId;
  final String coachRole; // 'pm' or 'msl'

  const PMMSLDashboardScreen({
    super.key,
    required this.reports,
    required this.onExport,
    required this.activeTab,
    required this.onTabChange,
    this.onRefresh,
    this.coachId,
    required this.coachRole,
  });

  @override
  State<PMMSLDashboardScreen> createState() => _PMMSLDashboardScreenState();
}

class _PMMSLDashboardScreenState extends State<PMMSLDashboardScreen> {
  StreamSubscription<List<CoachingReport>>? _reportsSubscription;
  List<CoachingReport> _currentReports = [];
  CoachingReport? _selectedReport;
  Map<String, String?> _mrProfilePictures = {}; // Map of MR ID -> profile_picture_url
  Map<String, String?> _mrNamesToIds = {}; // Map of MR name -> MR ID for lookup
  Map<String, String?> _dmRoles = {}; // Map of DM ID -> role
  Set<String> _mrIds = {}; // Set of MR IDs from users table
  Set<String> _dmIds = {}; // Set of DM IDs from users table
  Map<String, String> _personRoles = {}; // Map of person ID -> role from Supabase (mr, dm, ft, etc.)
  Map<String, String?> _coachNames = {}; // Map of coach ID -> coach name from users table
  
  // Loading and error states
  bool _isLoadingProfiles = true;
  int _profileRetryCount = 0;
  int _rolesRetryCount = 0;
  static const int _maxRetries = 3;
  int _unreadNotificationsCount = 0;
  Timer? _notificationsTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('📊 PM/MSL Dashboard initialized');
    debugPrint('   Initial reports count: ${widget.reports.length}');
    debugPrint('   coachId: ${widget.coachId}');
    debugPrint('   coachRole: ${widget.coachRole}');
    _currentReports = List.from(widget.reports);
    _initializeData();
    _startRealtimeUpdates();
    if (widget.coachId != null) {
      _loadUnreadNotificationsCount();
      // Refresh notifications count every 30 seconds
      _notificationsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _loadUnreadNotificationsCount();
      });
    }
  }

  @override
  void dispose() {
    _notificationsTimer?.cancel();
    _reportsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadNotificationsCount() async {
    if (widget.coachId == null) return;
    
    try {
      final count = await SupabaseService.getUnreadNotificationsCount(widget.coachId!);
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading unread notifications count: $e');
    }
  }

  void _openNotifications() {
    if (widget.coachId == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          userId: widget.coachId!,
          activeTab: widget.activeTab,
          onTabChange: widget.onTabChange,
        ),
      ),
    ).then((_) {
      // Refresh count when returning from notifications screen
      _loadUnreadNotificationsCount();
    });
  }

  /// Initialize all data loading operations with proper error handling
  Future<void> _initializeData() async {
    // Load profiles and roles in parallel, but handle errors gracefully
    try {
      await Future.wait([
        _loadMRProfiles(),
        _loadDMRoles(),
        _loadCoachNames(),
      ], eagerError: false); // Don't stop on first error
    } catch (e) {
      debugPrint('❌ Error initializing data: $e');
      // Errors are handled individually in each function
    }
  }

  /// Load coach names from users table
  Future<void> _loadCoachNames() async {
    try {
      debugPrint('👤 Loading coach names...');
      debugPrint('   coachRole: ${widget.coachRole}');
      debugPrint('   coachId: ${widget.coachId}');
      
      // Load coaches based on role
      List<Map<String, dynamic>> coaches = [];
      if (widget.coachRole == 'pm') {
        coaches = await SupabaseService.getAllPMs();
      } else if (widget.coachRole == 'msl') {
        coaches = await SupabaseService.getAllMSLs();
      }
      
      final coachNamesMap = <String, String?>{};
      for (final coach in coaches) {
        final id = (coach['id'] ?? '').toString();
        final name = (coach['name'] ?? '').toString();
        if (id.isNotEmpty && name.isNotEmpty) {
          coachNamesMap[id] = name;
          debugPrint('   📝 Loaded coach: id=$id, name=$name');
        }
      }
      
      // Also load the current coach's name if coachId is provided
      if (widget.coachId != null && widget.coachId!.isNotEmpty) {
        try {
          final user = await SupabaseService.getUserById(widget.coachId!);
          if (user != null) {
            final id = (user['id'] ?? '').toString();
            final name = (user['name'] ?? '').toString();
            final role = (user['role'] ?? '').toString();
            if (id.isNotEmpty && name.isNotEmpty) {
              coachNamesMap[id] = name;
              debugPrint('   ✅ Loaded current coach: id=$id, name=$name, role=$role');
            }
          }
        } catch (e) {
          debugPrint('   ⚠️ Error loading current coach name: $e');
        }
      }
      
      debugPrint('   ✅ Loaded ${coachNamesMap.length} coach names total');
      if (mounted) {
        setState(() {
          _coachNames = coachNamesMap;
        });
      }
    } catch (e) {
      debugPrint('   ❌ Error loading coach names: $e');
    }
  }

  Future<void> _loadMRProfiles({bool isRetry = false}) async {
    if (!isRetry && _profileRetryCount >= _maxRetries) {
      debugPrint('   ⚠️ Max retries reached for MR profiles');
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingProfiles = true;
      });
    }

    try {
      debugPrint('🖼️ Loading MR and DM profile pictures... (attempt ${_profileRetryCount + 1})');
      // Load both MRs and DMs to support Triple Visit reports
      final mrs = await SupabaseService.getAllMRs();
      final dms = await SupabaseService.getAllDMs();
      
      final profileMap = <String, String?>{};
      final nameToIdMap = <String, String?>{};
      final personRolesMap = <String, String>{};
      
      final mrIdsSet = <String>{};
      final dmIdsSet = <String>{};
      
      // Load MR profiles and roles
      for (final mr in mrs) {
        final id = (mr['id'] ?? '').toString();
        final name = (mr['name'] ?? '').toString();
        final profileUrl = mr['profile_picture_url']?.toString();
        final role = (mr['role'] ?? 'mr').toString().toLowerCase();
        
        if (id.isNotEmpty) {
          profileMap[id] = profileUrl;
          mrIdsSet.add(id);
          personRolesMap[id] = role;
        }
        if (name.isNotEmpty && id.isNotEmpty) {
          nameToIdMap[name] = id;
        }
      }
      
      // Load DM profiles and roles (for Triple Visit DM reports)
      for (final dm in dms) {
        final id = (dm['id'] ?? '').toString();
        final name = (dm['name'] ?? '').toString();
        final profileUrl = dm['profile_picture_url']?.toString();
        final role = (dm['role'] ?? 'dm').toString().toLowerCase();
        
        if (id.isNotEmpty) {
          if (!profileMap.containsKey(id)) {
            profileMap[id] = profileUrl;
          }
          dmIdsSet.add(id);
          personRolesMap[id] = role;
        }
        if (name.isNotEmpty && id.isNotEmpty && !nameToIdMap.containsKey(name)) {
          nameToIdMap[name] = id;
        }
      }
      
      debugPrint('   ✅ Loaded ${profileMap.length} profiles (MRs + DMs)');
      debugPrint('   📋 MR IDs: ${mrIdsSet.length}, DM IDs: ${dmIdsSet.length}');
      debugPrint('   📋 Person Roles: ${personRolesMap.length}');
      if (mounted) {
        setState(() {
          _mrProfilePictures = profileMap;
          _mrNamesToIds = nameToIdMap;
          _mrIds = mrIdsSet;
          _dmIds = dmIdsSet;
          _personRoles = personRolesMap;
          _isLoadingProfiles = false;
          _profileRetryCount = 0; // Reset on success
        });
      }
    } catch (e) {
      debugPrint('   ❌ Error loading MR profiles: $e');
      _profileRetryCount++;
      
      if (mounted) {
        setState(() {
          _isLoadingProfiles = false;
        });
        
        // Auto-retry with exponential backoff
        if (_profileRetryCount < _maxRetries) {
          final delay = Duration(seconds: _profileRetryCount * 2);
          debugPrint('   🔄 Retrying in ${delay.inSeconds} seconds...');
          Future.delayed(delay, () {
            if (mounted) {
              _loadMRProfiles(isRetry: true);
            }
          });
        } else {
          // Show error to user after max retries
          if (mounted && _profileRetryCount == _maxRetries) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to load profile pictures. Using default avatars.'),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    _profileRetryCount = 0;
                    _loadMRProfiles();
                  },
                ),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _loadDMRoles({bool isRetry = false}) async {
    if (!isRetry && _rolesRetryCount >= _maxRetries) {
      debugPrint('   ⚠️ Max retries reached for DM roles');
      return;
    }

    // Loading state handled internally, no UI indicator needed for roles

    try {
      debugPrint('👥 Loading DM roles... (attempt ${_rolesRetryCount + 1})');
      // Get all DMs and FTs to get their roles
      final dms = await SupabaseService.getAllDMs();
      final fts = await SupabaseService.getAllFTs();
      
      final roleMap = <String, String?>{};
      
      // Add DMs
      for (final dm in dms) {
        final id = (dm['id'] ?? '').toString();
        final role = (dm['role'] ?? 'dm').toString().toLowerCase();
        if (id.isNotEmpty) {
          roleMap[id] = role;
        }
      }
      
      // Add FTs
      for (final ft in fts) {
        final id = (ft['id'] ?? '').toString();
        final role = (ft['role'] ?? 'ft').toString().toLowerCase();
        if (id.isNotEmpty) {
          roleMap[id] = role;
        }
      }
      
      debugPrint('   ✅ Loaded ${roleMap.length} DM/FT roles');
      if (mounted) {
        setState(() {
          _dmRoles = roleMap;
          // Also update _personRoles to include DM/FT roles
          _personRoles.addAll(roleMap.map((key, value) => MapEntry(key, value ?? 'dm')));
          _rolesRetryCount = 0; // Reset on success
        });
      }
    } catch (e) {
      debugPrint('   ❌ Error loading DM roles: $e');
      _rolesRetryCount++;
      
      if (mounted) {
        // Error state handled, continue with empty roles map
        
        // Auto-retry with exponential backoff
        if (_rolesRetryCount < _maxRetries) {
          final delay = Duration(seconds: _rolesRetryCount * 2);
          debugPrint('   🔄 Retrying in ${delay.inSeconds} seconds...');
          Future.delayed(delay, () {
            if (mounted) {
              _loadDMRoles(isRetry: true);
            }
          });
        } else {
          // Show error to user after max retries
          if (mounted && _rolesRetryCount == _maxRetries) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to load roles. Some role labels may be incorrect.'),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    _rolesRetryCount = 0;
                    _loadDMRoles();
                  },
                ),
              ),
            );
          }
        }
      }
    }
  }

  String _getRoleLabel(String? role) {
    switch (role?.toLowerCase()) {
      case 'dm':
        return 'District Manager';
      case 'ft':
        return 'Field Trainer';
      case 'pm':
        return 'Product Manager';
      case 'msl':
        return 'Medical Science Liaison';
      case 'mr':
        return 'Medical Rep';
      default:
        return 'Coach';
    }
  }

  /// Determine if a report is a DM report or MR report based on mr_id in users table
  bool _isDMReport(CoachingReport report) {
    // First, check if mr_id is in DM IDs set (most reliable)
    if (_dmIds.contains(report.mrId)) {
      return true;
    }
    // If not in DM IDs, check if it's in MR IDs
    if (_mrIds.contains(report.mrId)) {
      return false;
    }
    // Fallback: use field-based detection (for old reports or if IDs not loaded yet)
    return report.customerAwareness != null || report.medicalProductKnowledgeDM != null;
  }

  String? _getMRProfilePictureUrl(String mrId, String? mrName) {
    // Try by ID first
    if (_mrProfilePictures.containsKey(mrId)) {
      return _mrProfilePictures[mrId];
    }
    // Try by name if ID not found
    if (mrName != null && _mrNamesToIds.containsKey(mrName)) {
      final id = _mrNamesToIds[mrName];
      if (id != null && _mrProfilePictures.containsKey(id)) {
        return _mrProfilePictures[id];
      }
    }
    return null;
  }

  Map<String, dynamic> _calculateStatsFromReports(List<CoachingReport> reports) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final thisMonthReports = reports.where((r) {
      if (r.date.isEmpty) return false;
      try {
        final reportDate = DateTime.parse(r.date);
        return reportDate.month == currentMonth && reportDate.year == currentYear;
      } catch (e) {
        return false;
      }
    }).toList();

    // 1. Total Coaching Sessions: Count all reports (Single + Double + Triple)
    // Each report = 1 session, regardless of type
    final totalVisits = thisMonthReports.length;

    // 2. Average Score: Calculate only from MR reports (Double with MR or Triple)
    // Exclude Single visits and DM reports from Double visits
    final mrReports = thisMonthReports.where((r) {
      // Include MR reports from Double (with MR) or Triple visits
      // Exclude Single visits and DM reports from Double visits
      if (r.typeOfVisit == 'Single') return false;
      if (r.typeOfVisit == 'Double' && _isDMReport(r)) return false; // Exclude DM reports from Double
      if (r.typeOfVisit == 'Triple' && _isDMReport(r)) return false; // Exclude DM reports from Triple
      return !_isDMReport(r); // Include only MR reports
    }).toList();

    final allScores = mrReports
        .map((r) => r.getAverageScore())
        .where((s) => s > 0)
        .toList();
    final avgScore = allScores.isEmpty
        ? 0.0
        : allScores.reduce((a, b) => a + b) / allScores.length;

    // 3. Total MRs Coached: Count unique MRs from Double (with MR) or Triple visits
    final uniqueMRs = mrReports.map((r) => r.mrId).where((id) => id.isNotEmpty).toSet().length;
    
    // 4. Total DMs Coached: Count unique DMs from Double (with DM) or Triple visits
    // For Triple visits, use dmId (which contains the coached DM's ID)
    // For Double visits with DM, use mrId (which contains the coached DM's ID in this case)
    final uniqueDMs = <String>{};
    for (final report in thisMonthReports) {
      if (report.typeOfVisit == 'Single') continue;
      
      if (report.typeOfVisit == 'Triple') {
        // For Triple visits, dmId contains the coached DM's ID
        if (report.dmId.isNotEmpty) {
          uniqueDMs.add(report.dmId);
        }
      } else if (_isDMReport(report)) {
        // For Double visits with DM, mrId contains the coached DM's ID
        if (report.mrId.isNotEmpty) {
          uniqueDMs.add(report.mrId);
        }
      }
    }

    return {
      'totalVisitsThisMonth': totalVisits, // Sum of MRs Coached + DMs Coached
      'averageScore': avgScore,
      'totalMRsCoached': uniqueMRs,
      'totalDMsCoached': uniqueDMs.length, // Return the count, not the set
    };
  }

  List<Map<String, dynamic>> _calculateMonthlyVisitsFromReports(List<CoachingReport> reports) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final monthlyData = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final month = months[date.month - 1];
      
      final visitsCount = reports.where((r) {
        if (r.date.isEmpty) return false;
        // Exclude Single visits - only count visits with actual MR or DM
        if (r.typeOfVisit == 'Single') return false;
        try {
          final reportDate = DateTime.parse(r.date);
          return reportDate.month == date.month && reportDate.year == date.year;
        } catch (e) {
          return false;
        }
      }).length;

      monthlyData.add({'month': month, 'visits': visitsCount});
    }

    return monthlyData;
  }

  // Use getDMScore() from CoachingReport model instead of local function
  // This method is kept for backward compatibility but now delegates to the model
  double _calculateDMScore(CoachingReport report) {
    return report.getDMScore();
  }

  List<Map<String, dynamic>> _calculateMRPerformanceFromReports(List<CoachingReport> reports) {
    final performanceStats = <String, Map<String, dynamic>>{};

    for (final report in reports) {
      // Exclude Single visits (they don't have actual MR or DM)
      if (report.typeOfVisit == 'Single') continue;
      
      // For Triple visits: process both MR and DM separately
      if (report.typeOfVisit == 'Triple') {
        // Process MR from Triple visit
        if (report.mrId.isNotEmpty && report.mrName.isNotEmpty) {
          final mrKey = 'mr_${report.mrId}';
          if (!performanceStats.containsKey(mrKey)) {
            performanceStats[mrKey] = {
              'id': report.mrId,
              'name': report.mrName,
              'role': 'MR',
              'visitCount': 0,
              'totalScore': 0.0,
              'reports': <CoachingReport>[],
            };
          }
          performanceStats[mrKey]!['visitCount'] = (performanceStats[mrKey]!['visitCount'] as int) + 1;
          performanceStats[mrKey]!['reports'].add(report);
        }
        
        // Process DM from Triple visit
        if (report.dmId.isNotEmpty && report.dmName.isNotEmpty) {
          final dmKey = 'dm_${report.dmId}';
          if (!performanceStats.containsKey(dmKey)) {
            performanceStats[dmKey] = {
              'id': report.dmId,
              'name': report.dmName,
              'role': 'DM',
              'visitCount': 0,
              'totalScore': 0.0,
              'reports': <CoachingReport>[],
            };
          }
          performanceStats[dmKey]!['visitCount'] = (performanceStats[dmKey]!['visitCount'] as int) + 1;
          performanceStats[dmKey]!['reports'].add(report);
        }
      } else {
        // For Double visits: process MR or DM reports
        if (report.mrId.isNotEmpty && report.mrName.isNotEmpty) {
          final isDMReport = _isDMReport(report);
          final role = isDMReport ? 'DM' : 'MR';
          final key = '${role.toLowerCase()}_${report.mrId}';
          
          if (!performanceStats.containsKey(key)) {
            performanceStats[key] = {
              'id': report.mrId,
              'name': report.mrName,
              'role': role,
              'visitCount': 0,
              'totalScore': 0.0,
              'reports': <CoachingReport>[],
            };
          }
          performanceStats[key]!['visitCount'] = (performanceStats[key]!['visitCount'] as int) + 1;
          performanceStats[key]!['reports'].add(report);
        }
      }
    }

    return performanceStats.values.map((stats) {
      final reports = stats['reports'] as List<CoachingReport>;
      final personRole = stats['role'] as String;
      final isDM = personRole == 'DM';
      
      // Calculate score - use getDMScore() for DM reports, getAverageScore() for MR reports
      final scores = reports.map((r) {
        return isDM ? r.getDMScore() : r.getAverageScore();
      }).where((s) => s > 0).toList();
      
      final avgScore = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;

      return {
        'id': stats['id'],
        'name': stats['name'],
        'role': stats['role'],
        'visitCount': stats['visitCount'],
        'averageScore': avgScore,
      };
    }).toList()
      ..sort((a, b) {
        final visitDiff = (b['visitCount'] as int) - (a['visitCount'] as int);
        if (visitDiff != 0) return visitDiff;
        return (b['averageScore'] as double).compareTo(a['averageScore'] as double);
      });
  }

  List<Map<String, dynamic>> _calculateMonthlyMRVisitsFromReports(List<CoachingReport> reports) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final thisMonthReports = reports.where((r) {
      if (r.date.isEmpty) return false;
      try {
        final reportDate = DateTime.parse(r.date);
        return reportDate.month == currentMonth && reportDate.year == currentYear;
      } catch (e) {
        return false;
      }
    }).toList();

    final personReports = <String, Map<String, dynamic>>{};
    
    for (final report in thisMonthReports) {
      // Exclude Single visits (they don't have actual MR or DM)
      if (report.typeOfVisit == 'Single') continue;
      
      // For Triple visits: process both MR and DM separately
      if (report.typeOfVisit == 'Triple') {
        // Process MR from Triple visit
        if (report.mrId.isNotEmpty && report.mrName.isNotEmpty) {
          final mrKey = 'mr_${report.mrId}';
          if (!personReports.containsKey(mrKey)) {
            personReports[mrKey] = {
              'id': report.mrId,
              'name': report.mrName,
              'role': 'MR',
              'reports': <CoachingReport>[],
            };
          }
          personReports[mrKey]!['reports'].add(report);
        }
        
        // Process DM from Triple visit
        if (report.dmId.isNotEmpty && report.dmName.isNotEmpty) {
          final dmKey = 'dm_${report.dmId}';
          if (!personReports.containsKey(dmKey)) {
            personReports[dmKey] = {
              'id': report.dmId,
              'name': report.dmName,
              'role': 'DM',
              'reports': <CoachingReport>[],
            };
          }
          personReports[dmKey]!['reports'].add(report);
        }
      } else {
        // For Double visits: process MR or DM reports
        if (report.mrId.isNotEmpty && report.mrName.isNotEmpty) {
          final isDMReport = _isDMReport(report);
          final role = isDMReport ? 'DM' : 'MR';
          final key = '${role.toLowerCase()}_${report.mrId}';
          
          if (!personReports.containsKey(key)) {
            personReports[key] = {
              'id': report.mrId,
              'name': report.mrName,
              'role': role,
              'reports': <CoachingReport>[],
            };
          }
          personReports[key]!['reports'].add(report);
        }
      }
    }

    return personReports.values.map((person) {
      final reports = person['reports'] as List<CoachingReport>;
      final sortedReports = List<CoachingReport>.from(reports)
        ..sort((a, b) => a.date.compareTo(b.date));

      // Calculate scores - use getDMScore() for DM reports, getAverageScore() for MR reports
      final personRole = person['role'] as String;
      final isDM = personRole == 'DM';
      final visitScores = sortedReports.map((r) {
        final score = isDM ? r.getDMScore() : r.getAverageScore();
        return <String, dynamic>{
          'date': r.date,
          'score': double.parse(score.toStringAsFixed(2)),
        };
      }).toList();

      final totalScore = visitScores.fold<double>(0.0, (sum, v) => sum + (v['score'] as double));
      final averageScore = visitScores.isEmpty
          ? 0.0
          : double.parse((totalScore / visitScores.length).toStringAsFixed(2));

      return {
        'id': person['id'],
        'name': person['name'],
        'role': person['role'],
        'visitCount': visitScores.length,
        'visits': visitScores,
        'averageScore': averageScore,
      };
    }).toList()
      ..sort((a, b) {
        final visitDiff = (b['visitCount'] as int) - (a['visitCount'] as int);
        if (visitDiff != 0) return visitDiff;
        return (b['averageScore'] as double).compareTo(a['averageScore'] as double);
      });
  }


  void _startRealtimeUpdates() {
    debugPrint('🔄 Starting real-time updates for PM/MSL Dashboard...');
    debugPrint('   coachId: ${widget.coachId}');
    debugPrint('   coachRole: ${widget.coachRole}');
    debugPrint('   Supabase initialized: ${SupabaseService.isInitialized}');
    
    if (widget.coachId != null && SupabaseService.isInitialized) {
      debugPrint('   ✅ Setting up real-time subscription...');
      _reportsSubscription = SupabaseService.watchReports(widget.coachId!, coachRole: widget.coachRole).listen(
        (reports) {
          debugPrint('   📊 Real-time update: Received ${reports.length} reports');
          if (mounted) {
            setState(() {
              _currentReports = reports;
            });
            if (widget.onRefresh != null) {
              widget.onRefresh!();
            }
          }
        },
        onError: (error) {
          debugPrint('   ❌ Real-time subscription error: $error');
          if (mounted) {
            setState(() {
              _currentReports = List.from(widget.reports);
            });
          }
          // Try to fetch reports directly as fallback
          _fetchReportsDirectly();
        },
      );
    } else {
      debugPrint('   ⚠️ Cannot start real-time updates: coachId=${widget.coachId}, Supabase initialized=${SupabaseService.isInitialized}');
      // Try to fetch reports directly as fallback
      _fetchReportsDirectly();
    }
  }

  /// Fallback method to fetch reports directly from Supabase
  Future<void> _fetchReportsDirectly() async {
    if (widget.coachId != null && SupabaseService.isInitialized) {
      try {
        debugPrint('   🔄 Fetching reports directly from Supabase...');
        final reports = await SupabaseService.getReports(widget.coachId!, coachRole: widget.coachRole);
        debugPrint('   ✅ Fetched ${reports.length} reports directly');
        if (mounted) {
          setState(() {
            _currentReports = reports;
          });
        }
      } catch (e) {
        debugPrint('   ❌ Error fetching reports directly: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = _currentReports.isNotEmpty ? _currentReports : widget.reports;
    debugPrint('📊 Dashboard build: Using ${reports.length} reports (current: ${_currentReports.length}, widget: ${widget.reports.length})');
    
    // Debug: Log all reports to verify Triple Visit reports are included
    final tripleVisitReports = reports.where((r) => r.typeOfVisit == 'Triple').toList();
    debugPrint('   🔍 Triple Visit reports: ${tripleVisitReports.length}');
    for (var report in tripleVisitReports) {
      final isDMReport = _isDMReport(report);
      debugPrint('      - ${isDMReport ? "DM" : "MR"} Report: mr_id=${report.mrId}, mr_name=${report.mrName}, date=${report.date}');
    }
    
    final stats = _calculateStatsFromReports(reports);
    final monthlyVisits = _calculateMonthlyVisitsFromReports(reports);
    final mrPerformance = _calculateMRPerformanceFromReports(reports);
    final monthlyMRVisits = _calculateMonthlyMRVisitsFromReports(reports);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                AppHeader(
                  title: 'Dashboard',
                  subtitle: widget.coachRole == 'pm' 
                      ? 'Product Manager performance overview'
                      : 'Medical Science Liaison performance overview',
                  trailing: widget.coachId != null
                      ? Stack(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: _openNotifications,
                            ),
                            if (_unreadNotificationsCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : null,
                ),
                // Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: widget.onRefresh ?? () async {},
                    child: SingleChildScrollView(
                      padding: AppSpacing.screenPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sync Status Indicator
                          const SyncStatusIndicator(),
                          AppSpacing.vertical(AppSpacing.lg),
                          // Stats Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'This Month',
                                  '${stats['totalVisitsThisMonth']}',
                                  'Coaching sessions',
                                  Icons.calendar_today,
                                  AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Avg Score',
                                  (stats['averageScore'] as double).toStringAsFixed(2),
                                  'Out of 6.0',
                                  Icons.trending_up,
                                  AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'MRs Coached',
                                  '${stats['totalMRsCoached']}',
                                  'Medical reps trained',
                                  Icons.people,
                                  Colors.purple,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'DMs Coached',
                                  '${stats['totalDMsCoached']}',
                                  'District managers',
                                  Icons.business,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Monthly Visits Chart
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Monthly Visits Trend',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 200,
                                  child: LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        horizontalInterval: 1,
                                        getDrawingHorizontalLine: (value) {
                                          return FlLine(
                                            color: AppColors.gray200,
                                            strokeWidth: 1,
                                            dashArray: [3, 3],
                                          );
                                        },
                                      ),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            getTitlesWidget: (value, meta) {
                                              return Text(
                                                value.toInt().toString(),
                                                style: const TextStyle(
                                                  color: AppColors.gray600,
                                                  fontSize: 12,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              if (value.toInt() >= 0 && value.toInt() < monthlyVisits.length) {
                                                return Text(
                                                  monthlyVisits[value.toInt()]['month'],
                                                  style: const TextStyle(
                                                    color: AppColors.gray600,
                                                    fontSize: 12,
                                                  ),
                                                );
                                              }
                                              return const Text('');
                                            },
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: monthlyVisits.asMap().entries.map((entry) {
                                            return FlSpot(entry.key.toDouble(), (entry.value['visits'] as int).toDouble());
                                          }).toList(),
                                          isCurved: false,
                                          color: AppColors.primaryBlue,
                                          barWidth: 3,
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter: (spot, percent, barData, index) {
                                              return FlDotCirclePainter(
                                                radius: 5,
                                                color: AppColors.primaryCyan,
                                                strokeWidth: 0,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // MR Performance Overview
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Medical Rep & District Manager Performance',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 250,
                                  child: mrPerformance.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No performance data available',
                                            style: TextStyle(color: AppColors.gray600),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: SizedBox(
                                            width: (mrPerformance.length * 90.0).clamp(400.0, double.infinity),
                                            child: BarChart(
                                              BarChartData(
                                                alignment: BarChartAlignment.spaceAround,
                                                maxY: 6.0,
                                                gridData: FlGridData(
                                                  show: true,
                                                  drawVerticalLine: false,
                                                  getDrawingHorizontalLine: (value) {
                                                    return FlLine(
                                                      color: AppColors.gray200,
                                                      strokeWidth: 1,
                                                      dashArray: [3, 3],
                                                    );
                                                  },
                                                ),
                                                titlesData: FlTitlesData(
                                                  leftTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: true,
                                                      reservedSize: 40,
                                                      getTitlesWidget: (value, meta) {
                                                        return Text(
                                                          value.toInt().toString(),
                                                          style: const TextStyle(
                                                            color: AppColors.gray600,
                                                            fontSize: 12,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  bottomTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: true,
                                                      reservedSize: 100,
                                                      getTitlesWidget: (value, meta) {
                                                        if (value.toInt() >= 0 && value.toInt() < mrPerformance.length) {
                                                          final person = mrPerformance[value.toInt()];
                                                          final name = person['name'] as String? ?? person['mrName'] as String? ?? '';
                                                          final role = person['role'] as String? ?? 'MR';
                                                          return Padding(
                                                            padding: const EdgeInsets.only(top: 8),
                                                            child: SizedBox(
                                                              width: 80,
                                                              child: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  Text(
                                                                    name,
                                                                    style: const TextStyle(
                                                                      color: AppColors.gray600,
                                                                      fontSize: 9,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    textAlign: TextAlign.center,
                                                                  ),
                                                                  const SizedBox(height: 2),
                                                                  Text(
                                                                    '($role)',
                                                                    style: const TextStyle(
                                                                      color: AppColors.gray600,
                                                                      fontSize: 8,
                                                                    ),
                                                                    textAlign: TextAlign.center,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                        return const Text('');
                                                      },
                                                    ),
                                                  ),
                                                  rightTitles: const AxisTitles(
                                                    sideTitles: SideTitles(showTitles: false),
                                                  ),
                                                  topTitles: const AxisTitles(
                                                    sideTitles: SideTitles(showTitles: false),
                                                  ),
                                                ),
                                                borderData: FlBorderData(show: false),
                                                barGroups: mrPerformance.asMap().entries.map((entry) {
                                                  return BarChartGroupData(
                                                    x: entry.key,
                                                    barRods: [
                                                      BarChartRodData(
                                                        toY: entry.value['averageScore'] as double,
                                                        color: AppColors.primaryCyan,
                                                        width: 30,
                                                        borderRadius: const BorderRadius.vertical(
                                                          top: Radius.circular(8),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Monthly Report
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Monthly Report',
                                      style: TextStyle(
                                        color: AppColors.primaryBlue,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${monthlyMRVisits.length} ${monthlyMRVisits.length != 1 ? 'People' : 'Person'}',
                                        style: const TextStyle(
                                          color: AppColors.primaryBlue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'All people (DMs and MRs) you visited this month with visit counts and scores',
                                  style: TextStyle(
                                    color: AppColors.gray600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                monthlyMRVisits.isEmpty
                                    ? Center(
                                        child: Column(
                                          children: [
                                            Icon(Icons.people, size: 48, color: AppColors.gray300),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'No visits this month',
                                              style: TextStyle(color: AppColors.gray600),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Start coaching sessions to see your monthly report',
                                              style: TextStyle(
                                                color: AppColors.gray600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        children: monthlyMRVisits.map((person) {
                                          final visitCount = person['visitCount'] as int;
                                          final personName = person['name'] as String;
                                          final personId = person['id'] as String;
                                          final personRole = person['role'] as String? ?? 'MR';
                                          final avgScore = person['averageScore'] as double;
                                          // Get initials from name
                                          final initials = personName.split(' ')
                                              .take(2)
                                              .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
                                              .join();
                                          // Score color based on value
                                          final scoreColor = avgScore >= 5.0 ? AppColors.success 
                                              : avgScore >= 4.0 ? AppColors.warning 
                                              : AppColors.error;
                                          
                                          // Get role label
                                          final roleLabel = personRole == 'MR' ? 'Medical Rep' 
                                              : personRole == 'DM' ? 'District Manager'
                                              : personRole == 'FT' ? 'Field Trainer'
                                              : personRole;
                                          
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primaryBlue.withOpacity(0.08),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              children: [
                                                // Header with gradient
                                                Container(
                                                  padding: const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        AppColors.primaryBlue.withOpacity(0.05),
                                                        AppColors.primaryCyan.withOpacity(0.1),
                                                      ],
                                                    ),
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // Avatar - Show profile picture if available
                                                      Builder(
                                                        builder: (context) {
                                                          final profileUrl = _getMRProfilePictureUrl(personId, personName);
                                                          
                                                          return Container(
                                                            width: 50,
                                                            height: 50,
                                                            decoration: BoxDecoration(
                                                              gradient: profileUrl == null ? AppColors.primaryGradient : null,
                                                              shape: BoxShape.circle,
                                                              border: profileUrl != null ? Border.all(color: AppColors.gray200, width: 2) : null,
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: AppColors.primaryBlue.withOpacity(0.3),
                                                                  blurRadius: 8,
                                                                  offset: const Offset(0, 3),
                                                                ),
                                                              ],
                                                            ),
                                                            child: profileUrl != null && profileUrl.isNotEmpty
                                                                ? ClipOval(
                                                                    child: Image.network(
                                                                      profileUrl,
                                                                      width: 50,
                                                                      height: 50,
                                                                      fit: BoxFit.cover,
                                                                      errorBuilder: (context, error, stackTrace) {
                                                                        return Container(
                                                                          decoration: BoxDecoration(
                                                                            gradient: AppColors.primaryGradient,
                                                                            shape: BoxShape.circle,
                                                                          ),
                                                                          child: Center(
                                                                            child: Text(
                                                                              initials.isNotEmpty ? initials : personRole,
                                                                              style: const TextStyle(
                                                                                color: Colors.white,
                                                                                fontSize: 18,
                                                                                fontWeight: FontWeight.bold,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      },
                                                                      loadingBuilder: (context, child, loadingProgress) {
                                                                        if (loadingProgress == null) return child;
                                                                        return Container(
                                                                          decoration: BoxDecoration(
                                                                            gradient: AppColors.primaryGradient,
                                                                            shape: BoxShape.circle,
                                                                          ),
                                                                          child: Center(
                                                                            child: CircularProgressIndicator(
                                                                              value: loadingProgress.expectedTotalBytes != null
                                                                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                                                  : null,
                                                                              strokeWidth: 2,
                                                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      },
                                                                    ),
                                                                  )
                                                                : Center(
                                                                    child: Text(
                                                                      initials.isNotEmpty ? initials : personRole,
                                                                      style: const TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 18,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ),
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(width: 10),
                                                      // Name and role
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              personName,
                                                              style: const TextStyle(
                                                                fontSize: 15,
                                                                fontWeight: FontWeight.bold,
                                                                color: AppColors.gray900,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                              maxLines: 1,
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Row(
                                                              children: [
                                                                Icon(Icons.business, 
                                                                    size: 11, color: AppColors.gray600),
                                                                const SizedBox(width: 3),
                                                                Flexible(
                                                                  child: Text(
                                                                    roleLabel,
                                                                    style: const TextStyle(
                                                                      color: AppColors.gray600,
                                                                      fontSize: 11,
                                                                    ),
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // Score badge
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                        decoration: BoxDecoration(
                                                          color: scoreColor.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(16),
                                                          border: Border.all(color: scoreColor.withOpacity(0.3)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.star, size: 12, color: scoreColor),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              '${avgScore.toStringAsFixed(1)}',
                                                              style: TextStyle(
                                                                color: scoreColor,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Stats row
                                                Padding(
                                                  padding: const EdgeInsets.all(16),
                                                  child: Row(
                                                    children: [
                                                      // Visits count
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.primaryBlue.withOpacity(0.05),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Column(
                                                            children: [
                                                              Text(
                                                                '$visitCount',
                                                                style: const TextStyle(
                                                                  fontSize: 24,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: AppColors.primaryBlue,
                                                                ),
                                                              ),
                                                              const Text(
                                                                'Coaching Visits',
                                                                style: TextStyle(
                                                                  color: AppColors.gray600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      // Average score
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                          decoration: BoxDecoration(
                                                            color: scoreColor.withOpacity(0.05),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Column(
                                                            children: [
                                                              Text(
                                                                avgScore.toStringAsFixed(1),
                                                                style: TextStyle(
                                                                  fontSize: 24,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: scoreColor,
                                                                ),
                                                              ),
                                                              const Text(
                                                                'Avg Score',
                                                                style: TextStyle(
                                                                  color: AppColors.gray600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Visit details - show first visit and more if available
                                                if (person['visits'] != null && (person['visits'] as List).isNotEmpty) ...[
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const SizedBox(height: 16),
                                                        // Trend Chart (only if more than 1 visit)
                                                        if (visitCount > 1) ...[
                                                          Container(
                                                            height: 120,
                                                            padding: const EdgeInsets.all(12),
                                                            decoration: BoxDecoration(
                                                              color: Colors.white,
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(color: AppColors.gray200),
                                                            ),
                                                            child: LineChart(
                                                              LineChartData(
                                                                gridData: FlGridData(
                                                                  show: true,
                                                                  drawVerticalLine: false,
                                                                  getDrawingHorizontalLine: (value) {
                                                                    return FlLine(
                                                                      color: AppColors.gray200,
                                                                      strokeWidth: 1,
                                                                      dashArray: [3, 3],
                                                                    );
                                                                  },
                                                                ),
                                                                titlesData: FlTitlesData(
                                                                  leftTitles: AxisTitles(
                                                                    sideTitles: SideTitles(
                                                                      showTitles: true,
                                                                      reservedSize: 35,
                                                                      getTitlesWidget: (value, meta) {
                                                                        return Text(
                                                                          value.toStringAsFixed(1),
                                                                          style: const TextStyle(
                                                                            color: AppColors.gray600,
                                                                            fontSize: 10,
                                                                          ),
                                                                        );
                                                                      },
                                                                    ),
                                                                  ),
                                                                  bottomTitles: AxisTitles(
                                                                    sideTitles: SideTitles(
                                                                      showTitles: true,
                                                                      reservedSize: 30,
                                                                      getTitlesWidget: (value, meta) {
                                                                        final visits = person['visits'] as List;
                                                                        if (value.toInt() >= 0 && value.toInt() < visits.length) {
                                                                          return Padding(
                                                                            padding: const EdgeInsets.only(top: 4),
                                                                            child: Text(
                                                                              'V${value.toInt() + 1}',
                                                                              style: const TextStyle(
                                                                                color: AppColors.gray600,
                                                                                fontSize: 10,
                                                                              ),
                                                                            ),
                                                                          );
                                                                        }
                                                                        return const Text('');
                                                                      },
                                                                    ),
                                                                  ),
                                                                  rightTitles: const AxisTitles(
                                                                    sideTitles: SideTitles(showTitles: false),
                                                                  ),
                                                                  topTitles: const AxisTitles(
                                                                    sideTitles: SideTitles(showTitles: false),
                                                                  ),
                                                                ),
                                                                borderData: FlBorderData(
                                                                  show: true,
                                                                  border: Border.all(color: AppColors.gray200),
                                                                ),
                                                                lineBarsData: [
                                                                  LineChartBarData(
                                                                    spots: (person['visits'] as List).asMap().entries.map((entry) {
                                                                      return FlSpot(
                                                                        entry.key.toDouble(),
                                                                        entry.value['score'] as double,
                                                                      );
                                                                    }).toList(),
                                                                    isCurved: true,
                                                                    color: AppColors.primaryCyan,
                                                                    barWidth: 3,
                                                                    dotData: FlDotData(
                                                                      show: true,
                                                                      getDotPainter: (spot, percent, barData, index) {
                                                                        return FlDotCirclePainter(
                                                                          radius: 4,
                                                                          color: AppColors.primaryBlue,
                                                                          strokeWidth: 2,
                                                                          strokeColor: Colors.white,
                                                                        );
                                                                      },
                                                                    ),
                                                                    belowBarData: BarAreaData(
                                                                      show: true,
                                                                      color: AppColors.primaryCyan.withOpacity(0.1),
                                                                    ),
                                                                  ),
                                                                ],
                                                                minY: 0,
                                                                maxY: 6,
                                                                lineTouchData: LineTouchData(
                                                                  touchTooltipData: LineTouchTooltipData(
                                                                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                                                      return touchedSpots.map((LineBarSpot touchedSpot) {
                                                                        final visits = person['visits'] as List;
                                                                        final visit = visits[touchedSpot.x.toInt()];
                                                                        return LineTooltipItem(
                                                                          '${DateFormat('MMM dd').format(DateTime.parse(visit['date']))}\n${touchedSpot.y.toStringAsFixed(2)}/6',
                                                                          const TextStyle(
                                                                            color: Colors.white,
                                                                            fontWeight: FontWeight.bold,
                                                                          ),
                                                                        );
                                                                      }).toList();
                                                                    },
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 16),
                                                        ],
                                                        // Visits - Compact horizontal list
                                                        SizedBox(
                                                          height: 80,
                                                          child: ListView.builder(
                                                            scrollDirection: Axis.horizontal,
                                                            itemCount: (person['visits'] as List).length,
                                                            itemBuilder: (context, index) {
                                                              final visit = (person['visits'] as List)[index];
                                                              final vScore = visit['score'] as double;
                                                              final vScoreColor = vScore >= 5.0 ? AppColors.success 
                                                                  : vScore >= 4.0 ? AppColors.warning 
                                                                  : AppColors.error;
                                                              return Container(
                                                                width: 100,
                                                                margin: EdgeInsets.only(right: index < (person['visits'] as List).length - 1 ? 10 : 0),
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    begin: Alignment.topLeft,
                                                                    end: Alignment.bottomRight,
                                                                    colors: [
                                                                      vScoreColor.withOpacity(0.08),
                                                                      vScoreColor.withOpacity(0.15),
                                                                    ],
                                                                  ),
                                                                  borderRadius: BorderRadius.circular(12),
                                                                  border: Border.all(color: vScoreColor.withOpacity(0.3)),
                                                                ),
                                                                child: Column(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    // Visit number badge
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                      decoration: BoxDecoration(
                                                                        color: vScoreColor.withOpacity(0.2),
                                                                        borderRadius: BorderRadius.circular(8),
                                                                      ),
                                                                      child: Text(
                                                                        'Coaching Visit ${index + 1}',
                                                                        style: TextStyle(
                                                                          color: vScoreColor,
                                                                          fontSize: 10,
                                                                          fontWeight: FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 4),
                                                                    // Date
                                                                    Text(
                                                                      DateFormat('MMM dd').format(DateTime.parse(visit['date'])),
                                                                      style: const TextStyle(
                                                                        color: AppColors.gray600,
                                                                        fontSize: 10,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 2),
                                                                    // Score
                                                                    Row(
                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                                                      textBaseline: TextBaseline.alphabetic,
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                        Text(
                                                                          vScore.toStringAsFixed(1),
                                                                          style: TextStyle(
                                                                            fontSize: 18,
                                                                            fontWeight: FontWeight.bold,
                                                                            color: vScoreColor,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          '/6',
                                                                          style: TextStyle(
                                                                            color: AppColors.gray600,
                                                                            fontSize: 10,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(height: 12),
                                                        const Divider(),
                                                        const SizedBox(height: 8),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            const Text(
                                                              'Total Coaching Visits',
                                                              style: TextStyle(
                                                                color: AppColors.gray600,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            Text(
                                                              '$visitCount visit${visitCount != 1 ? 's' : ''} completed',
                                                              style: const TextStyle(
                                                                color: AppColors.primaryBlue,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Recent Reports
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recent Reports',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                reports.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32),
                                          child: Text(
                                            'No reports available',
                                            style: TextStyle(color: AppColors.gray600),
                                          ),
                                        ),
                                      )
                                    : _buildRecentReportsList(reports),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Export Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradientHorizontal,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => widget.onExport(null),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.file_download, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Export Monthly Report',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Bottom padding to account for BottomNav
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom Navigation
                BottomNav(
                  role: widget.coachRole,
                  activeTab: widget.activeTab,
                  onTabChange: widget.onTabChange,
                ),
              ],
            ),
            // Report Modal
            if (_selectedReport != null)
              _buildReportModal(context, _selectedReport!),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: AppSpacing.paddingSM,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          AppSpacing.vertical(AppSpacing.md),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(color: color),
          ),
          AppSpacing.vertical(AppSpacing.xs),
          Text(
            title,
            style: AppTextStyles.labelLarge,
          ),
          AppSpacing.vertical(AppSpacing.xs / 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.gray600,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateAvgScore(CoachingReport report) {
    // For Triple Visit, use combined average of DM and MR scores
    if (report.typeOfVisit == 'Triple') {
      return report.getTripleVisitScore();
    }
    // For DM reports, use DM score calculation
    if (_isDMReport(report)) {
      return _calculateDMScore(report);
    }
    // For MR reports, use standard getAverageScore
    return report.getAverageScore();
  }


  Widget _buildRecentReportsList(List<CoachingReport> reports) {
    // Show both MR and DM reports from Triple Visit
    // Sort by date (newest first) and take first 10 (to show both MR and DM from Triple Visits)
    final sortedReports = List<CoachingReport>.from(reports)
      ..sort((a, b) => b.date.compareTo(a.date));
    final recentReports = sortedReports.take(10).toList();
    
    if (recentReports.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No reports available',
            style: TextStyle(color: AppColors.gray600),
          ),
        ),
      );
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: recentReports.map((report) {
        // Determine if this is a DM report or MR report based on mr_id in users table
        final isDMReport = _isDMReport(report);
        final personName = report.mrName;
        final personId = report.mrId;
        
        // Get role from Supabase (most reliable)
        final personRoleFromSupabase = _personRoles[personId] ?? (isDMReport ? 'dm' : 'mr');
        final personRole = personRoleFromSupabase.toUpperCase(); // 'dm' -> 'DM', 'mr' -> 'MR'
        
        debugPrint('   📋 Recent Report: name=$personName, id=$personId, roleFromSupabase=$personRoleFromSupabase, isDMReport=$isDMReport');
        
        final avgScore = isDMReport ? report.getDMScore() : report.getAverageScore();
        final profileUrl = _getMRProfilePictureUrl(personId, personName);
        final initials = personName.split(' ')
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gray200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar with loading state
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: profileUrl == null ? AppColors.primaryGradient : null,
                            shape: BoxShape.circle,
                            border: profileUrl != null ? Border.all(color: AppColors.gray200, width: 2) : null,
                          ),
                          child: _isLoadingProfiles
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                )
                              : profileUrl != null && profileUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        profileUrl,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient: AppColors.primaryGradient,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                    : null,
                                                strokeWidth: 2,
                                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient: AppColors.primaryGradient,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                initials.isNotEmpty ? initials : personRole,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        initials.isNotEmpty ? initials : personRole,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // For Triple visits, show first name of DM + dash + first name of MR
                              if (report.typeOfVisit == 'Triple' && report.dmName.isNotEmpty && report.mrName.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      () {
                                        // Get first name only (first word) from DM and MR names
                                        final dmParts = report.dmName.trim().split(' ');
                                        final mrParts = report.mrName.trim().split(' ');
                                        final dmFirstName = dmParts.isNotEmpty ? dmParts[0] : '';
                                        final mrFirstName = mrParts.isNotEmpty ? mrParts[0] : '';
                                        return '$dmFirstName - $mrFirstName';
                                      }(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Triple Visit',
                                      style: const TextStyle(
                                        color: AppColors.gray600,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                )
                              // For Single visits, show "Single Visit" instead of role label
                              else if (report.typeOfVisit == 'Single')
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      personName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Single Visit',
                                      style: const TextStyle(
                                        color: AppColors.gray600,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      personName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getRoleLabel(personRoleFromSupabase),
                                      style: const TextStyle(
                                        color: AppColors.gray600,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    report.date,
                    style: const TextStyle(
                      color: AppColors.gray600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: AppColors.primaryBlue, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${avgScore.toStringAsFixed(1)}/6',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedReport = report;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility, color: AppColors.primaryBlue, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'View Details',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Get coach name from users table
  Future<String?> _getCoachName(String coachId) async {
    debugPrint('   🔍 Getting coach name for coachId: $coachId');
    
    // First check cache
    if (_coachNames.containsKey(coachId)) {
      final cachedName = _coachNames[coachId];
      debugPrint('   ✅ Found in cache: $cachedName');
      return cachedName;
    }
    
    // If not in cache, fetch from Supabase
    try {
      debugPrint('   🔄 Fetching from Supabase...');
      final user = await SupabaseService.getUserById(coachId);
      if (user != null) {
        final id = (user['id'] ?? '').toString();
        final name = (user['name'] ?? '').toString();
        final role = (user['role'] ?? '').toString();
        debugPrint('   📋 User data: id=$id, name=$name, role=$role');
        
        if (name.isNotEmpty) {
          if (mounted) {
            setState(() {
              _coachNames[coachId] = name;
            });
          }
          debugPrint('   ✅ Returning coach name: $name');
          return name;
        } else {
          debugPrint('   ⚠️ User name is empty');
        }
      } else {
        debugPrint('   ⚠️ User not found in Supabase');
      }
    } catch (e) {
      debugPrint('   ❌ Error fetching coach name: $e');
    }
    
    debugPrint('   ⚠️ Returning null for coach name');
    return null;
  }

  Widget _buildModalSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildModalInfoItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.gray600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.gray900,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalYesNoItem(String label, String? value) {
    final isYes = value == 'Yes';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.gray600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isYes
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                color: isYes ? AppColors.success : AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalScoreItem(String label, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.gray600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 1,
            child: Text(
              value != null ? '$value/6' : 'N/A',
              style: const TextStyle(
                color: AppColors.gray900,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportModal(BuildContext context, CoachingReport report) {
    // Determine if this is a DM report or MR report based on mr_id in users table
    final isDMReport = _isDMReport(report);
    final personName = report.mrName;
    final personId = report.mrId;
    
    // Get role from Supabase (most reliable)
    final personRoleFromSupabase = _personRoles[personId] ?? (isDMReport ? 'dm' : 'mr');
    
    final avgScore = _calculateAvgScore(report);
    final scorePercent = (avgScore / 6.0 * 100).clamp(0, 100);
    final scoreColor = avgScore >= 5.0 ? AppColors.success 
        : avgScore >= 4.0 ? AppColors.warning 
        : AppColors.error;
    // Get initials from name
    final initials = personName.split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();
    
    // Check if this is a PM/MSL report (has PM/MSL specific fields)
    final isPMMSLReport = report.visitedAccountsNames != null || report.generalFeedback != null ||
                         report.dmFeedbackComments != null || report.mrFeedbackComments != null ||
                         report.customerAwareness != null || report.medicalProductKnowledgeDM != null;
    
    return Container(
      color: Colors.black54,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            maxWidth: MediaQuery.of(context).size.width * 0.95,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modal Header - Enhanced with Score
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradientHorizontal,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Avatar - Show profile picture if available
                            Builder(
                              builder: (context) {
                                final profileUrl = _getMRProfilePictureUrl(report.mrId, personName);
                                
                                return Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: profileUrl == null ? Colors.white : null,
                                    shape: BoxShape.circle,
                                    border: profileUrl != null ? Border.all(color: Colors.white, width: 2) : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: profileUrl != null && profileUrl.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            profileUrl,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.white,
                                                child: Center(
                                                  child: Text(
                                                    initials.isNotEmpty ? initials : 'MR',
                                                    style: const TextStyle(
                                                      color: AppColors.primaryBlue,
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(
                                                color: Colors.white,
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                        : null,
                                                    strokeWidth: 2,
                                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            initials.isNotEmpty ? initials : 'MR',
                                            style: const TextStyle(
                                              color: AppColors.primaryBlue,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                );
                              },
                            ),
                            const SizedBox(width: 14),
                            // Name and title
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // For Triple Visit, show both DM and MR names
                                  if (report.typeOfVisit == 'Triple' && report.dmName.isNotEmpty && report.mrName.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${widget.coachRole.toUpperCase()} Coaching Report',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${report.dmName} - ${report.mrName}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Triple Visit',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${widget.coachRole.toUpperCase()} Coaching Report',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          personName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        const SizedBox(height: 2),
                                        if (report.typeOfVisit == 'Single')
                                          Text(
                                            'Type of Visit: Single',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 12,
                                            ),
                                          )
                                        else
                                          Text(
                                            _getRoleLabel(personRoleFromSupabase),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            // Score circle
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: scoreColor.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: CircularProgressIndicator(
                                      value: scorePercent / 100,
                                      strokeWidth: 4,
                                      backgroundColor: AppColors.gray200,
                                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        avgScore.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: scoreColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '/6',
                                        style: TextStyle(
                                          color: AppColors.gray600,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Modal Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Basic Info
                          _buildModalSection(
                            'Basic Information',
                            [
                              _buildModalInfoItem('Date', report.date),
                              _buildModalInfoItem('Average Score', '${avgScore.toStringAsFixed(2)} / 6.0'),
                              // Show Coach name (Product Manager) from users table
                              if (widget.coachId != null && widget.coachId!.isNotEmpty)
                                FutureBuilder<String?>(
                                  future: _getCoachName(widget.coachId!),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return _buildModalInfoItem(
                                        'Coach',
                                        'Loading...',
                                      );
                                    }
                                    
                                    final coachName = snapshot.data;
                                    if (coachName != null && coachName.isNotEmpty) {
                                      // Show role prefix (PM or MSL) with the actual coach name
                                      final rolePrefix = widget.coachRole == 'pm' ? 'PM' : 'MSL';
                                      return _buildModalInfoItem(
                                        'Coach',
                                        '$rolePrefix: $coachName',
                                      );
                                    } else {
                                      // Fallback if name not found
                                      final roleLabel = widget.coachRole == 'pm' ? 'Product Manager' : 'Medical Science Liaison';
                                      return _buildModalInfoItem(
                                        'Coach',
                                        roleLabel,
                                      );
                                    }
                                  },
                                ),
                              // Show Type of Visit for PM/MSL reports
                              if (isPMMSLReport && report.typeOfVisit != null && report.typeOfVisit!.isNotEmpty)
                                _buildModalInfoItem('Type of Visit', report.typeOfVisit!),
                              // For Triple Visit, show both DM and MR
                              if (report.typeOfVisit == 'Triple' && report.dmName.isNotEmpty && report.mrName.isNotEmpty) ...[
                                _buildModalInfoItem('District Manager', report.dmName),
                                _buildModalInfoItem('Medical Rep', report.mrName),
                              ] else ...[
                                if (report.dmName.isNotEmpty && !isDMReport)
                                  _buildModalInfoItem(
                                    _getRoleLabel(_dmRoles[report.dmId]),
                                    report.dmName,
                                  ),
                                // Don't show Medical Rep for Single visits
                                if (report.typeOfVisit != 'Single')
                                  _buildModalInfoItem(
                                    _getRoleLabel(personRoleFromSupabase),
                                    personName,
                                  ),
                              ],
                              if (report.brickName != null && report.brickName!.isNotEmpty)
                                _buildModalInfoItem('Brick Name', report.brickName!),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // PM/MSL Specific Fields
                          if (isPMMSLReport) ...[
                            // Visit Details
                            if (report.visitedAccountsNames != null && report.visitedAccountsNames!.isNotEmpty)
                              _buildModalSection(
                                'Visit Details',
                                [
                                  _buildModalInfoItem('Visited Accounts', report.visitedAccountsNames!),
                                  if (report.doctorsVisited != null && report.doctorsVisited!.isNotEmpty)
                                    _buildModalInfoItem('Doctors Visited', report.doctorsVisited!),
                                ],
                              ),
                            const SizedBox(height: 24),
                            // General Feedback (shown for both DM and MR reports)
                            if (report.generalFeedback != null && report.generalFeedback!.isNotEmpty)
                              _buildModalSection(
                                'General Feedback',
                                [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryCyan.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.primaryCyan.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      report.generalFeedback!,
                                      style: const TextStyle(
                                        color: AppColors.gray900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 24),
                            // For Triple Visit: show both DM and MR feedback
                            // For other visits: show DM or MR feedback based on report type
                            if (report.typeOfVisit == 'Triple') ...[
                              // DM Feedback for Triple Visit
                              if (report.dmFeedbackComments != null || report.customerAwareness != null || report.medicalProductKnowledgeDM != null || report.teamwork != null)
                                _buildModalSection(
                                  'DM Feedback',
                                  [
                                    if (report.teamwork != null)
                                      _buildModalInfoItem('Teamwork and Cooperation', report.teamwork!),
                                    if (report.customerAwareness != null)
                                      _buildModalInfoItem('Customer Awareness', report.customerAwareness!),
                                    if (report.medicalProductKnowledgeDM != null)
                                      _buildModalInfoItem('Medical & Product Knowledge', report.medicalProductKnowledgeDM!),
                                    if (report.dmFeedbackComments != null && report.dmFeedbackComments!.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.gray50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'DM Feedback Comments',
                                              style: TextStyle(
                                                color: AppColors.gray600,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              report.dmFeedbackComments!,
                                              style: const TextStyle(
                                                color: AppColors.gray900,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              const SizedBox(height: 24),
                              // MR Feedback for Triple Visit
                              if (report.punctuality != null || report.dressCode != null || report.pharmacyFeedback != null || 
                                  report.patientCentricApproach != null || report.medicalProductKnowledgeMR != null ||
                                  report.featureBenefits != null || report.closingCommitment != null ||
                                  report.engaging != null || report.mrFeedbackComments != null)
                                _buildModalSection(
                                  'MR Feedback',
                                  [
                                    if (report.punctuality != null)
                                      _buildModalYesNoItem('Punctuality', report.punctuality),
                                    if (report.dressCode != null)
                                      _buildModalYesNoItem('Dress Code', report.dressCode),
                                    if (report.pharmacyFeedback != null)
                                      _buildModalScoreItem('Pharmacy Feedback', report.pharmacyFeedback),
                                    if (report.reviewProfile != null)
                                      _buildModalScoreItem('Review Profile', report.reviewProfile),
                                    if (report.patientCentricApproach != null)
                                      _buildModalScoreItem('Patient Centric Approach', report.patientCentricApproach),
                                    if (report.medicalProductKnowledgeMR != null)
                                      _buildModalScoreItem('Medical Product Knowledge (MR)', report.medicalProductKnowledgeMR),
                                    if (report.featureBenefits != null)
                                      _buildModalScoreItem('Feature Benefits', report.featureBenefits),
                                    if (report.closingCommitment != null)
                                      _buildModalScoreItem('Closing Commitment', report.closingCommitment),
                                    if (report.engaging != null)
                                      _buildModalScoreItem('Engaging Customer', report.engaging),
                                    if (report.mrFeedbackComments != null && report.mrFeedbackComments!.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.gray50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'MR Feedback Comments',
                                              style: TextStyle(
                                                color: AppColors.gray600,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              report.mrFeedbackComments!,
                                              style: const TextStyle(
                                                color: AppColors.gray900,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                            ] else ...[
                              // DM Feedback (only for DM reports from Double visits)
                              if (isDMReport && (report.dmFeedbackComments != null || report.customerAwareness != null || report.medicalProductKnowledgeDM != null || report.teamwork != null))
                                _buildModalSection(
                                  'DM Feedback',
                                  [
                                    if (report.teamwork != null)
                                      _buildModalInfoItem('Teamwork and Cooperation', report.teamwork!),
                                    if (report.customerAwareness != null)
                                      _buildModalInfoItem('Customer Awareness', report.customerAwareness!),
                                    if (report.medicalProductKnowledgeDM != null)
                                      _buildModalInfoItem('Medical & Product Knowledge', report.medicalProductKnowledgeDM!),
                                    if (report.dmFeedbackComments != null && report.dmFeedbackComments!.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.gray50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'DM Feedback Comments',
                                              style: TextStyle(
                                                color: AppColors.gray600,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              report.dmFeedbackComments!,
                                              style: const TextStyle(
                                                color: AppColors.gray900,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              // MR Feedback (only for MR reports from Double visits)
                              if (!isDMReport && (report.punctuality != null || report.dressCode != null || report.pharmacyFeedback != null || 
                                  report.patientCentricApproach != null || report.medicalProductKnowledgeMR != null ||
                                  report.featureBenefits != null || report.closingCommitment != null ||
                                  report.engaging != null || report.mrFeedbackComments != null))
                                _buildModalSection(
                                  'MR Feedback',
                                  [
                                    if (report.punctuality != null)
                                      _buildModalYesNoItem('Punctuality', report.punctuality),
                                    if (report.dressCode != null)
                                      _buildModalYesNoItem('Dress Code', report.dressCode),
                                    if (report.pharmacyFeedback != null)
                                      _buildModalScoreItem('Pharmacy Feedback', report.pharmacyFeedback),
                                    if (report.reviewProfile != null)
                                      _buildModalScoreItem('Review Profile', report.reviewProfile),
                                    if (report.patientCentricApproach != null)
                                      _buildModalScoreItem('Patient Centric Approach', report.patientCentricApproach),
                                    if (report.medicalProductKnowledgeMR != null)
                                      _buildModalScoreItem('Medical Product Knowledge (MR)', report.medicalProductKnowledgeMR),
                                    if (report.featureBenefits != null)
                                      _buildModalScoreItem('Feature Benefits', report.featureBenefits),
                                    if (report.closingCommitment != null)
                                      _buildModalScoreItem('Closing Commitment', report.closingCommitment),
                                    if (report.engaging != null)
                                      _buildModalScoreItem('Engaging Customer', report.engaging),
                                    if (report.mrFeedbackComments != null && report.mrFeedbackComments!.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.gray50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'MR Feedback Comments',
                                              style: TextStyle(
                                                color: AppColors.gray600,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              report.mrFeedbackComments!,
                                              style: const TextStyle(
                                                color: AppColors.gray900,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ],
                          // Score circle
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: scoreColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: CircularProgressIndicator(
                                    value: scorePercent / 100,
                                    strokeWidth: 4,
                                    backgroundColor: AppColors.gray200,
                                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      avgScore.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: scoreColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '/6',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Modal Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.gray200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedReport = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.gray100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Close',
                                    style: TextStyle(
                                      color: AppColors.gray700,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  try {
                                    final filePath = await ExportUtils.exportSingleReportToText(report);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('✅ Report exported successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
                                              SizedBox(height: 4),
                                              Text('📁 Location:', style: TextStyle(fontSize: 12)),
                                              Text(filePath, style: TextStyle(fontSize: 11, color: Colors.white70)),
                                            ],
                                          ),
                                          duration: const Duration(seconds: 6),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Export failed: $e')),
                                      );
                                    }
                                  }
                                  if (mounted) {
                                    setState(() {
                                      _selectedReport = null;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.download, color: Colors.white, size: 18),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Export',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

