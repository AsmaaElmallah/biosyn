import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/theme/text_styles.dart';
import 'package:biosyn_report_flutter/theme/spacing.dart';
import 'package:biosyn_report_flutter/widgets/app_card.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/widgets/connectivity_indicator.dart';
import 'package:biosyn_report_flutter/widgets/sync_status_indicator.dart';
import 'package:biosyn_report_flutter/screens/gm/gm_notifications_screen.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class GMDashboardScreen extends StatefulWidget {
  final List<CoachingReport> allReports;
  final VoidCallback onExport;
  final String activeTab;
  final Function(String) onTabChange;
  final String? gmId;

  const GMDashboardScreen({
    super.key,
    required this.allReports,
    required this.onExport,
    required this.activeTab,
    required this.onTabChange,
    this.gmId,
  });

  @override
  State<GMDashboardScreen> createState() => _GMDashboardScreenState();
}

class _GMDashboardScreenState extends State<GMDashboardScreen> {
  Map<String, String?> _coachProfilePictures = {}; // Map of coach name -> profile_picture_url
  Map<String, String> _coachNames = {}; // Map of coach ID -> coach name
  Map<String, String> _pmMslIdsByRole = {}; // Map of role (pm/msl) -> first coach ID for that role
  int _unreadNotificationsCount = 0;
  Timer? _notificationsTimer;
  int _totalCoaches = 0; // Total coaches count from users table
  int _totalMRs = 0; // Total MRs count from users table
  
  // Date filtering (like Plans)
  DateTime _selectedMonth = DateTime.now();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _useDateRange = false;

  @override
  void initState() {
    super.initState();
    _loadCoachProfiles();
    _loadCoachNames();
    _loadUsersCount(); // Load total coaches and MRs count from users table
    if (widget.gmId != null) {
      _loadUnreadNotificationsCount();
      // Refresh notifications count every 30 seconds
      _notificationsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _loadUnreadNotificationsCount();
      });
    }
  }

  @override
  void didUpdateWidget(GMDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload users count when widget updates (e.g., when reports are refreshed)
    if (oldWidget.allReports.length != widget.allReports.length) {
      _loadUsersCount();
    }
  }

  @override
  void dispose() {
    _notificationsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadNotificationsCount() async {
    if (widget.gmId == null) return;
    
    try {
      final count = await SupabaseService.getUnreadNotificationsCount(widget.gmId!);
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
    if (widget.gmId == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GMNotificationsScreen(
          gmId: widget.gmId!,
          activeTab: widget.activeTab,
          onTabChange: widget.onTabChange,
        ),
      ),
    ).then((_) {
      // Refresh count when returning from notifications screen
      _loadUnreadNotificationsCount();
    });
  }
  
  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }
  
  /// Get filtered reports based on date filter
  List<CoachingReport> _getFilteredReports() {
    var reports = widget.allReports;
    
    // Filter by date range or month
    if (_useDateRange && _startDate != null && _endDate != null) {
      // Filter by date range
      reports = reports.where((r) {
        if (r.date.isEmpty) return false;
        try {
          final reportDate = DateTime.parse(r.date);
          final reportDateOnly = DateTime(reportDate.year, reportDate.month, reportDate.day);
          final startOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          final endOnly = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
          return reportDateOnly.isAtSameMomentAs(startOnly) || 
                 reportDateOnly.isAtSameMomentAs(endOnly) ||
                 (reportDateOnly.isAfter(startOnly) && reportDateOnly.isBefore(endOnly));
        } catch (e) {
          return false;
        }
      }).toList();
    } else {
      // Filter by selected month
      final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      
      reports = reports.where((r) {
        if (r.date.isEmpty) return false;
        try {
          final reportDate = DateTime.parse(r.date);
          final reportDateOnly = DateTime(reportDate.year, reportDate.month, reportDate.day);
          return reportDateOnly.isAfter(monthStart.subtract(const Duration(days: 1))) &&
                 reportDateOnly.isBefore(monthEnd.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }
    
    return reports;
  }
  
  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range, color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Filter by Date',
                style: TextStyle(
                  color: AppColors.gray700,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toggle between Month and Date Range
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _useDateRange = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_useDateRange ? AppColors.primaryBlue.withOpacity(0.1) : AppColors.gray50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !_useDateRange ? AppColors.primaryBlue : AppColors.gray200,
                        width: !_useDateRange ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month,
                          size: 16,
                          color: !_useDateRange ? AppColors.primaryBlue : AppColors.gray600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Month',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: !_useDateRange ? FontWeight.w600 : FontWeight.normal,
                            color: !_useDateRange ? AppColors.primaryBlue : AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _useDateRange = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _useDateRange ? AppColors.primaryBlue.withOpacity(0.1) : AppColors.gray50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _useDateRange ? AppColors.primaryBlue : AppColors.gray200,
                        width: _useDateRange ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 16,
                          color: _useDateRange ? AppColors.primaryBlue : AppColors.gray600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Date Range',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _useDateRange ? FontWeight.w600 : FontWeight.normal,
                            color: _useDateRange ? AppColors.primaryBlue : AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Month selector or Date range selector
          if (!_useDateRange)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left, color: AppColors.primaryBlue),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray700,
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right, color: AppColors.primaryBlue),
                ),
              ],
            )
          else
            Column(
              children: [
                // Start Date
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
                          _endDate = null;
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppColors.gray600),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _startDate != null
                                ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                : 'Start Date',
                            style: TextStyle(
                              fontSize: 14,
                              color: _startDate != null ? AppColors.gray900 : AppColors.gray400,
                              fontWeight: _startDate != null ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.gray600),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // End Date
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _endDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppColors.gray600),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _endDate != null
                                ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                : 'End Date',
                            style: TextStyle(
                              fontSize: 14,
                              color: _endDate != null ? AppColors.gray900 : AppColors.gray400,
                              fontWeight: _endDate != null ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.gray600),
                      ],
                    ),
                  ),
                ),
                // Clear button
                if (_startDate != null || _endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.gray600,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _loadCoachProfiles() async {
    try {
      debugPrint('🖼️ Loading coach profile pictures...');
      final dms = await SupabaseService.getAllDMs();
      final fts = await SupabaseService.getAllFTs();
      final pms = await SupabaseService.getAllPMs();
      final msls = await SupabaseService.getAllMSLs();
      
      final allCoaches = [
        ...dms.map((c) => {'name': c['name']?.toString() ?? '', 'profile_picture_url': c['profile_picture_url']?.toString()}),
        ...fts.map((c) => {'name': c['name']?.toString() ?? '', 'profile_picture_url': c['profile_picture_url']?.toString()}),
        ...pms.map((c) => {'name': c['name']?.toString() ?? '', 'profile_picture_url': c['profile_picture_url']?.toString()}),
        ...msls.map((c) => {'name': c['name']?.toString() ?? '', 'profile_picture_url': c['profile_picture_url']?.toString()}),
      ];
      
      final profileMap = <String, String?>{};
      for (final coach in allCoaches) {
        final name = coach['name'] ?? '';
        if (name.isNotEmpty) {
          profileMap[name] = coach['profile_picture_url'];
        }
      }
      
      debugPrint('   ✅ Loaded ${profileMap.length} coach profiles');
      if (mounted) {
        setState(() {
          _coachProfilePictures = profileMap;
        });
      }
    } catch (e) {
      debugPrint('   ❌ Error loading coach profiles: $e');
    }
  }

  Future<void> _loadCoachNames() async {
    try {
      debugPrint('👤 Loading coach names...');
      final dms = await SupabaseService.getAllDMs();
      final fts = await SupabaseService.getAllFTs();
      final pms = await SupabaseService.getAllPMs();
      final msls = await SupabaseService.getAllMSLs();
      
      final coachNamesMap = <String, String>{};
      final pmMslIdsByRole = <String, String>{};
      
      for (final coach in [...dms, ...fts, ...pms, ...msls]) {
        final id = (coach['id'] ?? '').toString();
        final name = (coach['name'] ?? '').toString();
        final role = (coach['role'] ?? '').toString().toLowerCase();
        if (id.isNotEmpty && name.isNotEmpty) {
          coachNamesMap[id] = name;
          // Store first PM/MSL ID for each role
          if ((role == 'pm' || role == 'msl') && !pmMslIdsByRole.containsKey(role)) {
            pmMslIdsByRole[role] = id;
          }
        }
      }
      
      debugPrint('   ✅ Loaded ${coachNamesMap.length} coach names');
      debugPrint('   ✅ PM/MSL IDs by role: $pmMslIdsByRole');
      if (mounted) {
        setState(() {
          _coachNames = coachNamesMap;
          _pmMslIdsByRole = pmMslIdsByRole;
        });
      }
    } catch (e) {
      debugPrint('   ❌ Error loading coach names: $e');
    }
  }

  /// Load total coaches and MRs count from users table (not from reports)
  /// This ensures accurate count from users table, not from reports
  Future<void> _loadUsersCount() async {
    try {
      debugPrint('📊 Loading users count from users table...');
      debugPrint('   🔍 Fetching all coaches and MRs from users table...');
      
      // Get all coaches (DM, FT, PM, MSL) from users table
      // These functions query users table with role filter and status = 'active'
      final dms = await SupabaseService.getAllDMs();
      final fts = await SupabaseService.getAllFTs();
      final pms = await SupabaseService.getAllPMs();
      final msls = await SupabaseService.getAllMSLs();
      
      // Get all MRs from users table
      // This function queries users table with role = 'mr' and status = 'active'
      final mrs = await SupabaseService.getAllMRs();
      
      // Calculate total coaches count (DM + FT + PM + MSL)
      final totalCoaches = dms.length + fts.length + pms.length + msls.length;
      
      // Calculate total MRs count
      final totalMRs = mrs.length;
      
      debugPrint('   📊 Users count from users table:');
      debugPrint('      - DMs: ${dms.length}');
      debugPrint('      - FTs: ${fts.length}');
      debugPrint('      - PMs: ${pms.length}');
      debugPrint('      - MSLs: ${msls.length}');
      debugPrint('      - Total Coaches: $totalCoaches');
      debugPrint('      - Total MRs: $totalMRs');
      
      if (mounted) {
        setState(() {
          _totalCoaches = totalCoaches;
          _totalMRs = totalMRs;
        });
        debugPrint('   ✅ Updated state: _totalCoaches=$_totalCoaches, _totalMRs=$_totalMRs');
      }
    } catch (e, stackTrace) {
      debugPrint('   ❌ Error loading users count: $e');
      debugPrint('   Stack trace: $stackTrace');
      // Set to 0 on error
      if (mounted) {
        setState(() {
          _totalCoaches = 0;
          _totalMRs = 0;
        });
      }
    }
  }

  Future<String?> _getCoachName(String? coachId, String? coachRole) async {
    // If coachId is null or empty, try to find PM/MSL by role from Supabase
    if (coachId == null || coachId.isEmpty) {
      if (coachRole == 'pm' || coachRole == 'msl') {
        final roleUpper = coachRole?.toUpperCase() ?? 'UNKNOWN';
        debugPrint('   🔍 GM Dashboard: coachId is null, searching for $roleUpper from Supabase...');
        try {
          List<Map<String, dynamic>> coaches;
          if (coachRole == 'pm') {
            coaches = await SupabaseService.getAllPMs();
          } else {
            coaches = await SupabaseService.getAllMSLs();
          }
          
          if (coaches.isNotEmpty) {
            // Use the first PM/MSL found (usually there's only one per role, or use the first one)
            final coach = coaches.first;
            final id = (coach['id'] ?? '').toString();
            final name = (coach['name'] ?? '').toString();
            if (id.isNotEmpty && name.isNotEmpty) {
              debugPrint('   ✅ GM Dashboard: Found $roleUpper from Supabase: $name (ID: $id)');
              // Cache it for future use
              if (mounted) {
                setState(() {
                  _coachNames[id] = name;
                });
              }
              return name;
            }
          } else {
            debugPrint('   ⚠️ GM Dashboard: No $roleUpper found in Supabase');
          }
        } catch (e) {
          debugPrint('   ❌ Error fetching $roleUpper from Supabase: $e');
        }
      }
      return null;
    }
    
    // First check cache
    if (_coachNames.containsKey(coachId)) {
      return _coachNames[coachId];
    }
    
    // If not in cache, fetch from Supabase
    try {
      final user = await SupabaseService.getUserById(coachId);
      if (user != null) {
        final id = (user['id'] ?? '').toString();
        final name = (user['name'] ?? '').toString();
        if (id.isNotEmpty && name.isNotEmpty) {
          if (mounted) {
            setState(() {
              _coachNames[id] = name;
            });
          }
          return name;
        }
      }
    } catch (e) {
      debugPrint('   ❌ Error fetching coach name: $e');
    }
    
    return null;
  }

  String _getProfilePictureUrl(String coachName) {
    // Extract clean name (remove role suffix if exists)
    String cleanName = coachName;
    if (cleanName.contains(' (')) {
      cleanName = cleanName.substring(0, cleanName.indexOf(' ('));
    }
    return _coachProfilePictures[cleanName] ?? '';
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
      default:
        return 'Coach';
    }
  }

  List<CoachingReport> get allReports => widget.allReports;
  VoidCallback get onExport => widget.onExport;
  String get activeTab => widget.activeTab;
  Function(String) get onTabChange => widget.onTabChange;

  /// Check if coach has any quick sessions
  bool _hasQuickSessionsForCoach(String coachName) {
    // Extract clean name (remove role suffix if exists)
    String cleanName = coachName;
    if (cleanName.contains(' (')) {
      cleanName = cleanName.substring(0, cleanName.indexOf(' ('));
    }
    
    return allReports.any((r) {
      final reportCoachName = r.coachRole != null && r.coachRole!.isNotEmpty
          ? '${r.dmName} (${r.coachRole!.toUpperCase()})'
          : r.dmName;
      String reportCleanName = reportCoachName;
      if (reportCleanName.contains(' (')) {
        reportCleanName = reportCleanName.substring(0, reportCleanName.indexOf(' ('));
      }
      return reportCleanName == cleanName && r.isQuickSession == true && r.mrId.isNotEmpty;
    });
  }

  double _calculateAvgScore(CoachingReport report) {
    return report.getAverageScore();
  }

  List<Map<String, dynamic>> _calculateDMPerformance(List<CoachingReport> reports) {
    final coachStats = <String, Map<String, dynamic>>{};

    // For PM/MSL: include both MR and DM reports
    // For DM/FT: include only MR reports
    // Note: reports are already filtered by date in _getFilteredReports()
    // So visits count will be for the selected month/date range only
    final allCoachReports = reports.where((r) => r.mrId.isNotEmpty).toList();

    // First, collect all coach IDs from Single/Double visits to map them to Triple visits
    // Group by coachRole to find coach IDs for each role
    final coachIdsByRole = <String, Set<String>>{}; // Map of coachRole -> Set of coach IDs
    for (final report in allCoachReports) {
      final coachRole = report.coachRole ?? 'dm';
      final isPMMSL = coachRole == 'pm' || coachRole == 'msl';
      
      if (isPMMSL && report.typeOfVisit != 'Triple' && report.dmId.isNotEmpty) {
        // For Single/Double visits, dmId contains the coach ID
        if (!coachIdsByRole.containsKey(coachRole)) {
          coachIdsByRole[coachRole] = <String>{};
        }
        coachIdsByRole[coachRole]!.add(report.dmId);
      }
    }
    
    for (final report in allCoachReports) {
      final coachRole = report.coachRole ?? 'dm';
      final isPMMSL = coachRole == 'pm' || coachRole == 'msl';
      
      // Get coach ID and name
      String? coachId;
      String coachName;
      
      if (isPMMSL) {
        // For PM/MSL reports:
        // - In Single/Double visits: dmId contains the coach ID
        // - In Triple visits: use coachId and coachName directly from model if available
        if (report.typeOfVisit == 'Triple') {
          // For Triple Visit: use coachId directly from model if available
          // If not available (from Supabase), find it from Single/Double visits with same coachRole
          if (report.coachId != null && report.coachId!.isNotEmpty) {
            coachId = report.coachId;
            debugPrint('   ✅ Triple Visit: Using coachId from model: $coachId');
          } else {
            // Fallback: try to find coach ID from Single/Double visits with same coachRole
            // This is necessary because coach_id is not stored in database
            final coachIdsForRole = coachIdsByRole[coachRole] ?? <String>{};
            if (coachIdsForRole.isNotEmpty) {
              // Prefer coach ID that has a name in cache
              coachId = coachIdsForRole.firstWhere(
                (id) => _coachNames.containsKey(id) && _coachNames[id]!.isNotEmpty,
                orElse: () => coachIdsForRole.first,
              );
              debugPrint('   ✅ Triple Visit: Found coachId from Single/Double visits: $coachId');
            } else {
              // If no coach IDs found for this role, try to get from any Single/Double report with same coachRole
              // Also check if there are any other Triple visits with the same coachRole that might have coachId
              String? foundCoachId;
              
              // First, try to find from Single/Double reports
              final similarReport = allCoachReports.firstWhere(
                (r) => r.coachRole == coachRole && 
                       r.typeOfVisit != 'Triple' && 
                       r.dmId.isNotEmpty &&
                       r.dmId != report.dmId, // Make sure it's not the same as the coached DM
                orElse: () => report,
              );
              if (similarReport.dmId.isNotEmpty && similarReport.dmId != report.dmId) {
                foundCoachId = similarReport.dmId;
                debugPrint('   ✅ Triple Visit: Found coachId from Single/Double report: $foundCoachId');
              }
              
              // If still not found, try to find from other Triple visits that have coachId in model
              if (foundCoachId == null || foundCoachId.isEmpty) {
                final tripleWithCoachId = allCoachReports.firstWhere(
                  (r) => r.coachRole == coachRole && 
                         r.typeOfVisit == 'Triple' && 
                         r.coachId != null && 
                         r.coachId!.isNotEmpty &&
                         r.coachId != report.dmId, // Make sure it's not the same as the coached DM
                  orElse: () => report,
                );
                if (tripleWithCoachId.coachId != null && tripleWithCoachId.coachId!.isNotEmpty && tripleWithCoachId.coachId != report.dmId) {
                  foundCoachId = tripleWithCoachId.coachId;
                  debugPrint('   ✅ Triple Visit: Found coachId from another Triple visit: $foundCoachId');
                }
              }
              
              if (foundCoachId != null && foundCoachId.isNotEmpty) {
                coachId = foundCoachId;
              } else {
                debugPrint('   ⚠️ Triple Visit: Could not find coachId for role $coachRole, dmId=${report.dmId}');
              }
            }
          }
          
          // Get coach name - use coachName directly from model if available
          // For Triple Visit, NEVER use dmName as it's the coached DM, not the coach
          if (report.coachName != null && report.coachName!.isNotEmpty) {
            // Use coachName from model (available when report is created locally)
            coachName = '${report.coachName} (${coachRole.toUpperCase()})';
            // Cache it for future use
            if (coachId != null && coachId.isNotEmpty) {
              _coachNames[coachId] = report.coachName!;
              debugPrint('   ✅ Triple Visit: Using coachName from model: ${report.coachName}, cached for coachId: $coachId');
            }
          } else if (coachId != null && coachId.isNotEmpty && _coachNames.containsKey(coachId) && _coachNames[coachId]!.isNotEmpty) {
            // Use cached name
            coachName = '${_coachNames[coachId]} (${coachRole.toUpperCase()})';
            debugPrint('   ✅ Triple Visit: Using cached coachName: ${_coachNames[coachId]}');
          } else {
            // Fallback: use first PM/MSL from loaded coaches by role
            final roleLower = coachRole?.toLowerCase() ?? '';
            final roleUpper = coachRole?.toUpperCase() ?? 'UNKNOWN';
            debugPrint('   ⚠️ Triple Visit: No coachId available, using first $roleUpper from loaded coaches...');
            if (_pmMslIdsByRole.containsKey(roleLower)) {
              final firstPmMslId = _pmMslIdsByRole[roleLower]!;
              if (_coachNames.containsKey(firstPmMslId)) {
                final name = _coachNames[firstPmMslId]!;
                coachName = '$name ($roleUpper)';
                debugPrint('   ✅ Triple Visit: Using first $roleUpper from loaded coaches: $name');
              } else {
                coachName = 'Coach ($roleUpper)';
              }
            } else {
              coachName = 'Coach ($roleUpper)';
            }
          }
        } else {
          // For Single/Double visits, dmId contains the coach ID
          coachId = report.dmId;
          // Get coach name from cache or use dmName as fallback
          if (coachId.isNotEmpty && _coachNames.containsKey(coachId) && _coachNames[coachId]!.isNotEmpty) {
            coachName = '${_coachNames[coachId]} (${coachRole.toUpperCase()})';
          } else {
            coachName = report.dmName.isNotEmpty 
                ? '${report.dmName} (${coachRole.toUpperCase()})'
                : 'Unknown (${coachRole.toUpperCase()})';
          }
        }
      } else {
        // For DM/FT: dmId contains the coach ID
        coachId = report.dmId;
        coachName = report.dmName;
      }
      
      if (coachName.isEmpty) continue;
      
      if (!coachStats.containsKey(coachName)) {
        coachStats[coachName] = {
          'visits': 0,
          'scores': <double>[],
          'mrIds': <String>{},
          'dmIds': <String>{}, // Add DM IDs for PM/MSL
          'role': coachRole,
          'coachId': coachId, // Store coach ID for later use
        };
      }

      coachStats[coachName]!['visits'] = (coachStats[coachName]!['visits'] as int) + 1;
      
      // For PM/MSL: check if this is a DM report or MR report
      if (isPMMSL) {
        // Check if mrId is a DM (has DM feedback fields)
        final isDMReport = report.customerAwareness != null || report.medicalProductKnowledgeDM != null;
        if (isDMReport) {
          (coachStats[coachName]!['dmIds'] as Set<String>).add(report.mrId);
        } else {
          (coachStats[coachName]!['mrIds'] as Set<String>).add(report.mrId);
        }
      } else {
        // For DM/FT: always MR
        (coachStats[coachName]!['mrIds'] as Set<String>).add(report.mrId);
      }

      final avgScore = _calculateAvgScore(report);
      if (avgScore > 0) {
        (coachStats[coachName]!['scores'] as List<double>).add(avgScore);
      }
    }

    return coachStats.entries.map((entry) {
      final scores = entry.value['scores'] as List<double>;
      final avgScore = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;
      
      // Extract name without role suffix FIRST (e.g., "Ahmed (MSL)" -> "Ahmed")
      String cleanName = entry.key;
      if (cleanName.contains(' (')) {
        cleanName = cleanName.substring(0, cleanName.indexOf(' ('));
      }
      
      // Skip if name is a role name (should not happen, but safety check)
      final roleNames = ['district manager', 'field trainer', 'product manager', 'medical science liaison', 'dm', 'ft', 'pm', 'msl'];
      if (roleNames.contains(cleanName.toLowerCase())) {
        // Skip this entry - it's not a real person name
        return null;
      }
      
      // Create shorter name for display from clean name
      String shortName;
      final nameParts = cleanName.split(' ').where((part) => part.isNotEmpty).toList();
      
      if (nameParts.length >= 2) {
        // Take first name and first letter of second name
        // Example: "Ahmed Sabry" -> "Ahmed S."
        shortName = '${nameParts[0]} ${nameParts[1][0].toUpperCase()}.';
      } else if (cleanName.length > 12) {
        // If name is too long, truncate it
        shortName = '${cleanName.substring(0, 12)}...';
      } else {
        shortName = cleanName;
      }
      
      final role = entry.value['role'] as String;
      final isPMMSL = role == 'pm' || role == 'msl';
      final mrCount = (entry.value['mrIds'] as Set<String>).length;
      final dmCount = isPMMSL ? (entry.value['dmIds'] as Set<String>).length : 0;
      final totalCount = isPMMSL ? mrCount + dmCount : mrCount;
      
      return {
        'name': shortName,
        'fullName': cleanName, // Name without role suffix
        'visits': entry.value['visits'],
        'avgScore': double.parse(avgScore.toStringAsFixed(2)),
        'mrCount': mrCount,
        'dmCount': dmCount,
        'totalCount': totalCount, // For PM/MSL: MRs + DMs
        'role': role,
        'coachId': entry.value['coachId'], // Store coach ID for fetching correct name
      };
    }).whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _calculateScoreDistribution(List<CoachingReport> reports) {
    final distribution = {
      'excellent': 0,
      'good': 0,
      'average': 0,
      'needs': 0,
    };

    // Filter: Only include reports with MRs (mrId is not empty)
    final mrReports = reports.where((r) => r.mrId.isNotEmpty).toList();

    for (final report in mrReports) {
      final avgScore = _calculateAvgScore(report);
      if (avgScore >= 5) {
        distribution['excellent'] = (distribution['excellent'] as int) + 1;
      } else if (avgScore >= 4) {
        distribution['good'] = (distribution['good'] as int) + 1;
      } else if (avgScore >= 3) {
        distribution['average'] = (distribution['average'] as int) + 1;
      } else if (avgScore > 0) {
        distribution['needs'] = (distribution['needs'] as int) + 1;
      }
    }

    final total = (distribution['excellent'] as int) +
        (distribution['good'] as int) +
        (distribution['average'] as int) +
        (distribution['needs'] as int);

    if (total == 0) return [];

    return [
      {
        'name': '5-6 (Excellent)',
        'value': distribution['excellent'],
        'color': AppColors.success,
      },
      {
        'name': '4-5 (Good)',
        'value': distribution['good'],
        'color': AppColors.primaryCyan,
      },
      {
        'name': '3-4 (Average)',
        'value': distribution['average'],
        'color': AppColors.warning,
      },
      {
        'name': '1-3 (Needs Improvement)',
        'value': distribution['needs'],
        'color': AppColors.error,
      },
    ];
  }

  List<Map<String, dynamic>> _calculateMonthlyTrend(List<CoachingReport> reports) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final monthlyData = <Map<String, dynamic>>[];

    // Filter: Only include reports with MRs (mrId is not empty)
    final mrReports = reports.where((r) => r.mrId.isNotEmpty).toList();

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final month = months[date.month - 1];
      
      final monthReports = mrReports.where((r) {
        if (r.date.isEmpty) return false;
        try {
          final reportDate = DateTime.parse(r.date);
          return reportDate.month == date.month && reportDate.year == date.year;
        } catch (e) {
          return false;
        }
      }).toList();

      final avgScores = monthReports
          .map((r) => _calculateAvgScore(r))
          .where((s) => s > 0)
          .toList();
      final avgScore = avgScores.isEmpty
          ? 0.0
          : double.parse((avgScores.reduce((a, b) => a + b) / avgScores.length).toStringAsFixed(2));

      monthlyData.add({
        'month': month,
        'visits': monthReports.length,
        'avgScore': avgScore,
      });
    }

    return monthlyData;
  }

  @override
  Widget build(BuildContext context) {
    // Get filtered reports based on date filter
    final filteredReports = _getFilteredReports();
    
    final dmPerformance = _calculateDMPerformance(filteredReports);
    final scoreDistribution = _calculateScoreDistribution(filteredReports);
    final monthlyTrend = _calculateMonthlyTrend(filteredReports);

    // Filter: Only include reports with MRs (mrId is not empty)
    final mrReports = filteredReports.where((r) => r.mrId.isNotEmpty).toList();
    
    final totalVisits = mrReports.length;
    
    // Use counts from users table (loaded in _loadUsersCount) instead of from reports
    // This ensures accurate count even when there are no reports yet
    // These values are loaded from users table in _loadUsersCount():
    // - _totalCoaches = count of all users with role in ['dm', 'ft', 'pm', 'msl'] and status = 'active'
    // - _totalMRs = count of all users with role = 'mr' and status = 'active'
    final totalDMs = _totalCoaches; // Total coaches from users table (DM + FT + PM + MSL)
    final totalMRs = _totalMRs; // Total MRs from users table
    
    debugPrint('📊 Dashboard build - Counts:');
    debugPrint('   - Total Visits: $totalVisits (from reports)');
    debugPrint('   - Total Coaches: $totalDMs (from users table: $_totalCoaches)');
    debugPrint('   - Total MRs: $totalMRs (from users table: $_totalMRs)');
    
    final allScores = mrReports
        .map((r) => _calculateAvgScore(r))
        .where((s) => s > 0)
        .toList();
    final overallAvgScore = allScores.isEmpty
        ? '0.00'
        : (allScores.reduce((a, b) => a + b) / allScores.length).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Column(
          children: [
            // Connectivity Indicator
            const ConnectivityIndicator(),
            // Header with notifications bell
            AppHeader(
              title: 'GM Dashboard',
              subtitle: 'Organization-wide coaching analytics',
              trailing: widget.gmId != null
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
                                minWidth: 18,
                                minHeight: 18,
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
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sync Status Indicator
                    const SyncStatusIndicator(),
                    AppSpacing.vertical(AppSpacing.lg),
                    // Filter by Date
                    _buildDateSelector(),
                    AppSpacing.vertical(AppSpacing.lg),
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Coaching Visits',
                          '$totalVisits',
                          'All Coaches combined',
                          Icons.timeline,
                          AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Avg Score',
                          overallAvgScore,
                          'Organization average',
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
                          'Coaches',
                          '$totalDMs',
                          'DM/FT/PM/MSL',
                          Icons.people,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Medical Reps',
                          '$totalMRs',
                          'Total in system',
                          Icons.description,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // DM Performance Chart
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Coach Performance (DM/FT/PM/MSL)',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 250,
                          child: dmPerformance.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No performance data available',
                                    style: TextStyle(color: AppColors.gray600),
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: (dmPerformance.length * 90.0)
                                        .clamp(300.0, double.infinity),
                                    child: BarChart(
                                      BarChartData(
                                        alignment: BarChartAlignment.spaceAround,
                                        minY: 0,
                                        maxY: 20,
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
                                              interval: 2, // Show every 2 units (0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20)
                                              getTitlesWidget: (value, meta) {
                                                if (value.toInt() % 2 == 0 && value.toInt() >= 0 && value.toInt() <= 20) {
                                                  return Text(
                                                    value.toInt().toString(),
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
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 80,
                                              getTitlesWidget: (value, meta) {
                                                if (value.toInt() >= 0 &&
                                                    value.toInt() <
                                                        dmPerformance.length) {
                                                  final name =
                                                      dmPerformance[value.toInt()]
                                                              ['name']
                                                          as String? ??
                                                      '';
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8),
                                                    child: SizedBox(
                                                      width: 70,
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          color:
                                                              AppColors.gray600,
                                                          fontSize: 9,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return const Text('');
                                              },
                                            ),
                                          ),
                                          rightTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                          topTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                        ),
                                        borderData:
                                            FlBorderData(show: false),
                                        barGroups: dmPerformance
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          return BarChartGroupData(
                                            x: entry.key,
                                            barRods: [
                                              BarChartRodData(
                                                toY: (entry.value['visits']
                                                        as int)
                                                    .toDouble(),
                                                color: AppColors.primaryCyan,
                                                width: 20,
                                                borderRadius:
                                                    const BorderRadius.vertical(
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
                  // Score Distribution Pie Chart
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Score Distribution',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 250,
                          child: scoreDistribution.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No data available',
                                    style: TextStyle(color: AppColors.gray600),
                                  ),
                                )
                              : PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 60,
                                    sections: scoreDistribution.map((entry) {
                                      final total = scoreDistribution
                                          .fold<int>(0, (sum, e) => sum + (e['value'] as int));
                                      final percent = total > 0
                                          ? (entry['value'] as int) / total
                                          : 0.0;
                                      return PieChartSectionData(
                                        value: entry['value'].toDouble(),
                                        title: '${(percent * 100).toStringAsFixed(0)}%',
                                        color: entry['color'] as Color,
                                        radius: 80,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                        if (scoreDistribution.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: scoreDistribution.map((entry) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: entry['color'] as Color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry['name'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray600,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Monthly Trends
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Coaching Trends',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
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
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >= 0 && value.toInt() < monthlyTrend.length) {
                                        return Text(
                                          monthlyTrend[value.toInt()]['month'],
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
                              barGroups: monthlyTrend.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: (entry.value['visits'] as int).toDouble(),
                                      color: AppColors.primaryBlue,
                                      width: 20,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // DM Details List
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Coach Details (DM/FT/PM/MSL)',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        dmPerformance.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: AppColors.gray100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.people_outline, size: 32, color: AppColors.gray400),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No data available',
                                        style: TextStyle(color: AppColors.gray600, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Column(
                                children: dmPerformance.map((dm) {
                                  final avgScore = dm['avgScore'] as double;
                                  final scoreColor = avgScore >= 5 
                                      ? AppColors.success 
                                      : avgScore >= 3 
                                          ? AppColors.warning 
                                          : AppColors.error;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.gray200),
                                    ),
                                    child: Column(
                                      children: [
                                        // Header with Avatar
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              // Avatar - Show profile picture if available
                                              Builder(
                                                builder: (context) {
                                                  final coachName = (dm['fullName'] ?? dm['name']) as String;
                                                  final profileUrl = _getProfilePictureUrl(coachName);
                                                  final initials = coachName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join();
                                                  
                                                  return Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      gradient: profileUrl.isEmpty ? AppColors.primaryGradient : null,
                                                      shape: BoxShape.circle,
                                                      border: profileUrl.isNotEmpty ? Border.all(color: AppColors.gray200, width: 2) : null,
                                                    ),
                                                    child: profileUrl.isNotEmpty
                                                        ? ClipOval(
                                                            child: Image.network(
                                                              profileUrl,
                                                              width: 48,
                                                              height: 48,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (context, error, stackTrace) {
                                                                return Container(
                                                                  decoration: BoxDecoration(
                                                                    gradient: AppColors.primaryGradient,
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                  child: Center(
                                                                    child: Text(
                                                                      initials.isNotEmpty ? initials : 'C',
                                                                      style: const TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 16,
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
                                                              initials.isNotEmpty ? initials : 'C',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 16,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Builder(
                                                            builder: (context) {
                                                              final coachId = dm['coachId'] as String?;
                                                              final role = dm['role'] as String?;
                                                              String? actualCoachName;
                                                              
                                                              if (coachId != null && coachId.isNotEmpty) {
                                                                // Use cached name directly
                                                                actualCoachName = _coachNames[coachId];
                                                              } else if (role == 'pm' || role == 'msl') {
                                                                // If coachId is null, use first PM/MSL from loaded coaches
                                                                final roleLower = role?.toLowerCase() ?? '';
                                                                if (_pmMslIdsByRole.containsKey(roleLower)) {
                                                                  final firstPmMslId = _pmMslIdsByRole[roleLower]!;
                                                                  actualCoachName = _coachNames[firstPmMslId];
                                                                }
                                                              }
                                                              
                                                              if (actualCoachName == null || actualCoachName.isEmpty) {
                                                                // Fallback: use role
                                                                return Text(
                                                                  'Coach (${role?.toUpperCase() ?? 'Unknown'})',
                                                                  style: const TextStyle(
                                                                    fontSize: 16,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: AppColors.gray900,
                                                                  ),
                                                                  overflow: TextOverflow.ellipsis,
                                                                  maxLines: 1,
                                                                );
                                                              }
                                                              
                                                              return Text(
                                                                actualCoachName,
                                                                style: const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: AppColors.gray900,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                                maxLines: 1,
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                        // Quick Session indicator (if any reports are quick sessions)
                                                        Builder(
                                                          builder: (context) {
                                                            final coachId = dm['coachId'] as String?;
                                                            final coachNameForCheck = coachId != null && _coachNames.containsKey(coachId) 
                                                                ? _coachNames[coachId]!
                                                                : (dm['fullName'] ?? dm['name']) as String;
                                                            return _hasQuickSessionsForCoach(coachNameForCheck)
                                                                ? Container(
                                                                    margin: const EdgeInsets.only(left: 8),
                                                                    padding: const EdgeInsets.all(4),
                                                                    decoration: BoxDecoration(
                                                                      color: AppColors.error.withOpacity(0.1),
                                                                      shape: BoxShape.circle,
                                                                      border: Border.all(color: AppColors.error, width: 1.5),
                                                                    ),
                                                                    child: const Icon(
                                                                      Icons.close,
                                                                      color: AppColors.error,
                                                                      size: 12,
                                                                    ),
                                                                  )
                                                                : const SizedBox.shrink();
                                                          },
                                                        ),
                                                          Container(
                                                            margin: const EdgeInsets.only(left: 8),
                                                            padding: const EdgeInsets.all(4),
                                                            decoration: BoxDecoration(
                                                              color: AppColors.error.withOpacity(0.1),
                                                              shape: BoxShape.circle,
                                                              border: Border.all(color: AppColors.error, width: 1.5),
                                                            ),
                                                            child: const Icon(
                                                              Icons.close,
                                                              color: AppColors.error,
                                                              size: 12,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _getRoleLabel(dm['role'] as String? ?? 'dm'),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.gray400,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Score Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: scoreColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star, color: scoreColor, size: 14),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${dm['avgScore']}',
                                                      style: TextStyle(
                                                        color: scoreColor,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Stats Row
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppColors.gray50,
                                            borderRadius: const BorderRadius.only(
                                              bottomLeft: Radius.circular(16),
                                              bottomRight: Radius.circular(16),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: _buildDMStatItem(
                                                  'Coaching Visits',
                                                  '${dm['visits']}',
                                                  AppColors.primaryBlue,
                                                ),
                                              ),
                                              Container(width: 1, height: 32, color: AppColors.gray200),
                                              Expanded(
                                                child: _buildDMStatItem(
                                                  dm['role'] == 'pm' || dm['role'] == 'msl'
                                                      ? 'MRs - DM'
                                                      : 'MRs',
                                                  dm['role'] == 'pm' || dm['role'] == 'msl'
                                                      ? '${dm['totalCount']}'
                                                      : '${dm['mrCount']}',
                                                  Colors.purple,
                                                ),
                                              ),
                                              Container(width: 1, height: 32, color: AppColors.gray200),
                                              Expanded(
                                                child: _buildDMStatItem('Score', '${dm['avgScore']}/6', scoreColor),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action Buttons
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
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
                                  onTap: () => onExport(),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Export',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  onTabChange('reports');
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: AppColors.primaryBlue,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.analytics_outlined, color: AppColors.primaryBlue, size: 20),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Reports',
                                          style: TextStyle(
                                            color: AppColors.primaryBlue,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            onTabChange('plans');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: AppColors.primaryCyan,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_month_outlined, color: AppColors.primaryCyan, size: 20),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'View Plans',
                                    style: TextStyle(
                                      color: AppColors.primaryCyan,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Bottom padding for navigation
                  const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Bottom Navigation
            BottomNav(
              role: 'gm',
              activeTab: activeTab,
              onTabChange: onTabChange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          AppSpacing.vertical(AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.bodySmall,
          ),
          AppSpacing.vertical(AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(color: color),
          ),
          AppSpacing.vertical(AppSpacing.xs),
          Text(
            subtitle,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return AppCard(
      padding: AppSpacing.paddingXL,
      child: child,
    );
  }

  Widget _buildDMStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.gray600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
