import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/utils/export_utils.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class GMReportsScreen extends StatefulWidget {
  final List<CoachingReport> reports;
  final Function(String?) onExport;
  final String activeTab;
  final Function(String) onTabChange;

  const GMReportsScreen({
    super.key,
    required this.reports,
    required this.onExport,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  State<GMReportsScreen> createState() => _GMReportsScreenState();
}

class _GMReportsScreenState extends State<GMReportsScreen> {
  final _searchController = TextEditingController();
  String? _selectedCoachId; // Changed from _selectedDM
  String? _selectedMRId = null; // Changed to MR ID instead of name
  CoachingReport? _selectedReport;
  Map<String, String> _mrRoles = {}; // Map of MR ID to role
  Map<String, String?> _mrProfilePictures = {}; // Map of MR ID -> profile_picture_url
  Map<String, String?> _mrNamesToIds = {}; // Map of MR name -> MR ID for lookup
  Set<String> _mrIds = {}; // Set of MR IDs from users table
  Set<String> _dmIds = {}; // Set of DM IDs from users table
  Map<String, String> _coachNames = {}; // Map of coach ID -> coach name
  List<Map<String, dynamic>> _allMRs = []; // All MRs from Supabase
  
  // Date filtering (like Plans)
  DateTime _selectedMonth = DateTime.now();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _useDateRange = false;
  
  // All coaches list (DM, FT, PM, MSL)
  List<Map<String, dynamic>> _allCoaches = [];
  
  // Colors for different coaches
  final List<Color> _colorPalette = [
    AppColors.primaryBlue,
    AppColors.primaryCyan,
    Colors.purple,
    Colors.orange,
    Colors.green,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _loadMRProfiles();
    _loadMRRoles();
    _loadCoachNames();
    _loadAllCoaches();
  }
  
  Future<void> _loadAllCoaches() async {
    try {
      debugPrint('👤 Loading all coaches for filter...');
      final dms = await SupabaseService.getAllDMs();
      final fts = await SupabaseService.getAllFTs();
      final pms = await SupabaseService.getAllPMs();
      final msls = await SupabaseService.getAllMSLs();
      
      // Combine all coaches
      final allCoaches = [
        ...dms.map((dm) => {...dm, 'role': 'dm'}),
        ...fts.map((ft) => {...ft, 'role': 'ft'}),
        ...pms.map((pm) => {...pm, 'role': 'pm'}),
        ...msls.map((msl) => {...msl, 'role': 'msl'}),
      ];
      
      debugPrint('   ✅ Loaded ${allCoaches.length} Coaches (${dms.length} DMs, ${fts.length} FTs, ${pms.length} PMs, ${msls.length} MSLs)');
      if (mounted) {
        setState(() {
          _allCoaches = allCoaches;
        });
      }
    } catch (e) {
      debugPrint('   ❌ Error loading all coaches: $e');
    }
  }
  
  Color _getColorForCoach(int index) {
    return _colorPalette[index % _colorPalette.length];
  }
  
  String _getRoleLabel(String? role) {
    if (role == null || role.isEmpty) return 'DM';
    switch (role.toLowerCase()) {
      case 'dm':
        return 'DM';
      case 'ft':
        return 'FT';
      case 'pm':
        return 'PM';
      case 'msl':
        return 'MSL';
      case 'mr':
        return 'MR';
      case 'gm':
        return 'GM';
      default:
        return role.toUpperCase();
    }
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

  Future<void> _loadCoachNames() async {
    try {
      debugPrint('👤 Loading coach names...');
      final dms = await SupabaseService.getAllDMs();
      final fts = await SupabaseService.getAllFTs();
      final pms = await SupabaseService.getAllPMs();
      final msls = await SupabaseService.getAllMSLs();
      
      final coachNamesMap = <String, String>{};
      for (final coach in [...dms, ...fts, ...pms, ...msls]) {
        final id = (coach['id'] ?? '').toString();
        final name = (coach['name'] ?? '').toString();
        if (id.isNotEmpty && name.isNotEmpty) {
          coachNamesMap[id] = name;
        }
      }
      
      // For Triple Visit reports without coachId, pre-load PM/MSL names
      // This ensures names are available immediately without FutureBuilder
      // Store PM/MSL IDs by role for quick lookup
      String? firstPMId;
      String? firstMSLId;
      if (pms.isNotEmpty) {
        firstPMId = (pms.first['id'] ?? '').toString();
        if (firstPMId.isNotEmpty && !coachNamesMap.containsKey(firstPMId)) {
          final pmName = (pms.first['name'] ?? '').toString();
          if (pmName.isNotEmpty) {
            coachNamesMap[firstPMId] = pmName;
          }
        }
      }
      if (msls.isNotEmpty) {
        firstMSLId = (msls.first['id'] ?? '').toString();
        if (firstMSLId.isNotEmpty && !coachNamesMap.containsKey(firstMSLId)) {
          final mslName = (msls.first['name'] ?? '').toString();
          if (mslName.isNotEmpty) {
            coachNamesMap[firstMSLId] = mslName;
          }
        }
      }
      
      // Store PM/MSL IDs for Triple Visit reports without coachId
      // IMPORTANT: Store default PM/MSL names in coachNamesMap BEFORE assigning to _coachNames
      // This ensures _pm_default and _msl_default are always available
      if (firstPMId != null && firstPMId.isNotEmpty && coachNamesMap.containsKey(firstPMId)) {
        coachNamesMap['_pm_default'] = coachNamesMap[firstPMId]!;
        debugPrint('   ✅ Stored _pm_default: ${coachNamesMap[firstPMId]}');
      }
      if (firstMSLId != null && firstMSLId.isNotEmpty && coachNamesMap.containsKey(firstMSLId)) {
        coachNamesMap['_msl_default'] = coachNamesMap[firstMSLId]!;
        debugPrint('   ✅ Stored _msl_default: ${coachNamesMap[firstMSLId]}');
      }
      
      debugPrint('   ✅ Loaded ${coachNamesMap.length} coach names');
      if (mounted) {
        setState(() {
          _coachNames = coachNamesMap;
        });
      }
    } catch (e) {
      debugPrint('   ❌ Error loading coach names: $e');
    }
  }

  Future<String?> _getCoachName(String? coachId, String? coachRole) async {
    // If coachId is null or empty, try to find PM/MSL by role from Supabase
    if (coachId == null || coachId.isEmpty) {
      if (coachRole == 'pm' || coachRole == 'msl') {
        final roleUpper = coachRole?.toUpperCase() ?? 'UNKNOWN';
        debugPrint('   🔍 Triple Visit: coachId is null, searching for $roleUpper from Supabase...');
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
              debugPrint('   ✅ Triple Visit: Found $roleUpper from Supabase: $name (ID: $id)');
              // Cache it for future use
              if (mounted) {
                setState(() {
                  _coachNames[id] = name;
                });
              }
              return name;
            }
          } else {
            debugPrint('   ⚠️ Triple Visit: No $roleUpper found in Supabase');
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

  String? _getCoachIdFromReport(CoachingReport report) {
    final coachRole = report.coachRole ?? 'dm';
    final isPMMSL = coachRole == 'pm' || coachRole == 'msl';
    
    if (isPMMSL) {
      // For PM/MSL reports:
      // - In Single/Double visits: dmId contains the coach ID
      // - In Triple visits: use coachId if available (from model), DO NOT use dmId as fallback
      if (report.typeOfVisit == 'Triple') {
        // For Triple Visit: use coachId directly from model if available
        // DO NOT fallback to dmId - that's the DM's ID, not the PM/MSL coach ID
        if (report.coachId != null && report.coachId!.isNotEmpty) {
          return report.coachId;
        }
        // If coachId is not available, return null (will use coachName from model instead)
        debugPrint('   ⚠️ Triple Visit: No coachId available for ${report.coachRole}. Will use coachName from model.');
        return null;
      } else {
        // For Single/Double visits, dmId contains the coach ID
        return report.dmId;
      }
    } else {
      // For DM/FT: dmId contains the coach ID
      return report.dmId;
    }
  }
  
  String? _getCoachNameFromReport(CoachingReport report) {
    final coachRole = report.coachRole ?? 'dm';
    final isPMMSL = coachRole == 'pm' || coachRole == 'msl';
    
    if (isPMMSL && report.typeOfVisit == 'Triple') {
      // For Triple Visit: use coachName directly from model if available
      if (report.coachName != null && report.coachName!.isNotEmpty) {
        return report.coachName;
      }
    }
    
    // For other cases: use dmName (which is the coach name)
    return report.dmName;
  }

  Future<void> _loadMRProfiles() async {
    try {
      debugPrint('🖼️ Loading MR and DM profile pictures...');
      // Load both MRs and DMs to support PM/MSL reports (Triple Visit)
      final mrs = await SupabaseService.getAllMRs();
      final dms = await SupabaseService.getAllDMs();
      
      final profileMap = <String, String?>{};
      final nameToIdMap = <String, String?>{};
      final mrIdsSet = <String>{};
      final dmIdsSet = <String>{};
      
      // Load MR profiles
      final allMRsList = <Map<String, dynamic>>[];
      for (final mr in mrs) {
        final id = (mr['id'] ?? '').toString();
        final name = (mr['name'] ?? '').toString();
        final profileUrl = mr['profile_picture_url']?.toString();
        
        if (id.isNotEmpty) {
          profileMap[id] = profileUrl;
          mrIdsSet.add(id);
          allMRsList.add({
            'id': id,
            'name': name,
            'profile_picture_url': profileUrl,
          });
        }
        if (name.isNotEmpty && id.isNotEmpty) {
          nameToIdMap[name] = id;
        }
      }
      
      // Load DM profiles (for PM/MSL Triple Visit reports)
      for (final dm in dms) {
        final id = (dm['id'] ?? '').toString();
        final name = (dm['name'] ?? '').toString();
        final profileUrl = dm['profile_picture_url']?.toString();
        
        if (id.isNotEmpty) {
          if (!profileMap.containsKey(id)) {
            profileMap[id] = profileUrl;
          }
          dmIdsSet.add(id);
        }
        if (name.isNotEmpty && id.isNotEmpty && !nameToIdMap.containsKey(name)) {
          nameToIdMap[name] = id;
        }
      }
      
      debugPrint('   ✅ Loaded ${profileMap.length} profiles (MRs + DMs)');
      debugPrint('   📋 MR IDs: ${mrIdsSet.length}, DM IDs: ${dmIdsSet.length}');
      debugPrint('   📋 All MRs from Supabase: ${allMRsList.length}');
      if (mounted) {
        setState(() {
          _mrProfilePictures = profileMap;
          _mrNamesToIds = nameToIdMap;
          _mrIds = mrIdsSet;
          _dmIds = dmIdsSet;
          _allMRs = allMRsList;
        });
      }
    } catch (e) {
      debugPrint('   ❌ Error loading MR profiles: $e');
    }
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


  // Get all MRs from Supabase (not just from reports)
  List<Map<String, dynamic>> get _uniqueMRs {
    // Return MRs from Supabase, sorted by name
    return _allMRs.toList()
      ..sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
  }

  List<CoachingReport> get _filteredReports {
    return widget.reports.where((report) {
      // Search filter
      final matchesSearch = _searchController.text.isEmpty ||
          report.mrName.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          report.dmName.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          report.mrId.contains(_searchController.text) ||
          (report.coachRole != null && report.coachRole!.toLowerCase().contains(_searchController.text.toLowerCase()));

      // Coach filter - match by coach ID
      bool matchesCoach = true;
      if (_selectedCoachId != null) {
        final reportCoachId = _getCoachIdFromReport(report);
        matchesCoach = reportCoachId == _selectedCoachId;
      }
      
      // MR filter - match by MR ID
      bool matchesMR = true;
      if (_selectedMRId != null) {
        matchesMR = report.mrId == _selectedMRId;
      }

      // Date filter - Month or Date Range
      bool matchesDate = true;
      if (report.date.isNotEmpty) {
        try {
          final reportDate = DateTime.parse(report.date);
          final reportDateOnly = DateTime(reportDate.year, reportDate.month, reportDate.day);
          
          if (_useDateRange && _startDate != null && _endDate != null) {
            // Filter by date range
            final startOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
            final endOnly = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
            matchesDate = reportDateOnly.isAtSameMomentAs(startOnly) || 
                         reportDateOnly.isAtSameMomentAs(endOnly) ||
                         (reportDateOnly.isAfter(startOnly) && reportDateOnly.isBefore(endOnly));
          } else {
            // Filter by selected month
            final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
            final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
            matchesDate = reportDateOnly.isAfter(monthStart.subtract(const Duration(days: 1))) &&
                         reportDateOnly.isBefore(monthEnd.add(const Duration(days: 1)));
          }
        } catch (e) {
          matchesDate = false;
        }
      }

      return matchesSearch && matchesCoach && matchesMR && matchesDate;
    }).toList();
  }

  /// Determine if a report is a DM report or MR report based on mr_id in users table
  /// This is important for PM/MSL reports (Triple Visit) where we have separate reports for DM and MR
  bool _isDMReport(CoachingReport report) {
    // Only check for PM/MSL reports (coachRole is pm or msl)
    if (report.coachRole != 'pm' && report.coachRole != 'msl') {
      // For DM/FT reports, always MR reports (they coach MRs)
      return false;
    }
    
    // For PM/MSL reports, check if mr_id is in DM IDs set (most reliable)
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

  double _calculateAvgScore(CoachingReport report) {
    // For Triple Visit, use combined average of DM and MR scores
    if (report.typeOfVisit == 'Triple') {
      return report.getTripleVisitScore();
    }
    // For PM/MSL reports, use getDMScore() for DM reports and getAverageScore() for MR reports
    if (report.coachRole == 'pm' || report.coachRole == 'msl') {
      final isDMReport = _isDMReport(report);
      return isDMReport ? report.getDMScore() : report.getAverageScore();
    }
    // For DM/FT reports, always use getAverageScore() (they coach MRs)
    return report.getAverageScore();
  }

  /// Get role label for coach role
  String _getCoachRoleLabel(String? coachRole) {
    if (coachRole == null || coachRole.isEmpty) return 'DM';
    switch (coachRole.toLowerCase()) {
      case 'dm':
        return 'DM';
      case 'ft':
        return 'FT';
      case 'pm':
        return 'PM';
      case 'msl':
        return 'MSL';
      default:
        return coachRole.toUpperCase();
    }
  }

  /// Get role label for MR/DM role

  /// Load MR roles from Supabase
  Future<void> _loadMRRoles() async {
    try {
      final uniqueMRIds = widget.reports
          .map((r) => r.mrId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      
      for (final mrId in uniqueMRIds) {
        if (!_mrRoles.containsKey(mrId)) {
          final user = await SupabaseService.getUserById(mrId);
          if (user != null && user['role'] != null) {
            setState(() {
              _mrRoles[mrId] = user['role'] as String;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading MR roles: $e');
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCoachId = null;
      _selectedMRId = null;
      _selectedMonth = DateTime.now();
      _useDateRange = false;
      _startDate = null;
      _endDate = null;
      _searchController.clear();
    });
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
  
  Widget _buildCoachFilter() {
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
          const Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.primaryBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'Filter by Coach',
                style: TextStyle(
                  color: AppColors.gray700,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCoachId,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gray200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gray200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
              ),
              filled: true,
              fillColor: AppColors.gray50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            hint: const Text('All Coaches'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Coaches'),
              ),
              ..._allCoaches.asMap().entries.map((entry) {
                final coach = entry.value;
                final index = entry.key;
                return DropdownMenuItem<String>(
                  value: coach['id']?.toString(),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getColorForCoach(index),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${coach['name']?.toString() ?? 'Unknown'} (${_getRoleLabel(coach['role']?.toString())})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCoachId = value;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.gray50,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                const AppHeader(
                  title: 'Coaching Reports',
                  subtitle: 'View and analyze all reports',
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // Search and Filter Bar
                      _buildCard(
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search by name or ID...',
                                prefixIcon: const Icon(Icons.search, color: AppColors.gray400),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    try {
                                      // GM should see Location
                                      final filePath = await ExportUtils.exportAllReportsToText(widget.reports, showLocation: true);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('✅ All reports exported successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                          SnackBar(content: Text('Export failed: ${e.toString()}')),
                                        );
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.download, color: Colors.white, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          'Export All',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Filter by Date
                            _buildDateSelector(),
                            const SizedBox(height: 16),
                            // Filter by Coach
                            _buildCoachFilter(),
                            const SizedBox(height: 16),
                            // Medical Rep filter - using MRs from Supabase
                            DropdownButtonFormField<String?>(
                              value: _selectedMRId,
                              decoration: InputDecoration(
                                labelText: 'Medical Rep',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('All Medical Reps')),
                                ..._uniqueMRs.map((mr) {
                                  final mrId = (mr['id'] ?? '').toString();
                                  final mrName = (mr['name'] ?? '').toString();
                                  return DropdownMenuItem<String?>(
                                    value: mrId,
                                    child: Text(mrName),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedMRId = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear All Filters'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Results Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryCyan.withOpacity(0.3),
                          ),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: AppColors.gray700,
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(text: 'Showing '),
                              TextSpan(
                                text: '${_filteredReports.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: ' of '),
                              TextSpan(
                                text: '${widget.reports.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: ' reports'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Reports List
                      _filteredReports.isEmpty
                          ? _buildCard(
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.gray100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.description_outlined, size: 40, color: AppColors.gray400),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No reports found',
                                    style: TextStyle(
                                      color: AppColors.gray700,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Try adjusting your filters',
                                    style: TextStyle(
                                      color: AppColors.gray400,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: _filteredReports.map((report) {
                                final avgScore = _calculateAvgScore(report);
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
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
                                                final profileUrl = _getMRProfilePictureUrl(report.mrId, report.mrName);
                                                final initials = report.mrName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join();
                                                
                                                return Container(
                                                  width: 52,
                                                  height: 52,
                                                  decoration: BoxDecoration(
                                                    gradient: profileUrl == null ? const LinearGradient(
                                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                                    ) : null,
                                                    shape: BoxShape.circle,
                                                    border: profileUrl != null ? Border.all(color: AppColors.gray200, width: 2) : null,
                                                  ),
                                                  child: profileUrl != null && profileUrl.isNotEmpty
                                                      ? ClipOval(
                                                          child: Image.network(
                                                            profileUrl,
                                                            width: 52,
                                                            height: 52,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return Container(
                                                                decoration: const BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                                                  ),
                                                                  shape: BoxShape.circle,
                                                                ),
                                                                child: Center(
                                                                  child: Text(
                                                                    initials,
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
                                                                decoration: const BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                                                  ),
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
                                                            initials,
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
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // For Triple visit, show first name of DM + dash + first name of MR
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
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.gray900,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          'Triple Visit',
                                                          style: const TextStyle(
                                                            color: AppColors.gray600,
                                                            fontSize: 12,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                        const SizedBox(height: 4),
                                                        // Show PM/MSL + name
                                                        Builder(
                                                          builder: (context) {
                                                            final coachRole = report.coachRole ?? 'pm';
                                                            final roleAbbrev = coachRole == 'pm' ? 'PM' : coachRole == 'msl' ? 'MSL' : coachRole.toUpperCase();
                                                            // For Triple Visit, use coachName directly from model if available
                                                            if (report.typeOfVisit == 'Triple' && report.coachName != null && report.coachName!.isNotEmpty) {
                                                              return Row(
                                                                children: [
                                                                  const Icon(Icons.person_outline, size: 14, color: AppColors.gray400),
                                                                  const SizedBox(width: 4),
                                                                  Expanded(
                                                                    child: Text(
                                                                      '$roleAbbrev: ${report.coachName}',
                                                                      style: const TextStyle(
                                                                        color: AppColors.gray600,
                                                                        fontSize: 12,
                                                                      ),
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              );
                                                            } else {
                                                              // For Triple Visit without coachName, get from cache or use pre-loaded PM/MSL name
                                                              final coachId = _getCoachIdFromReport(report);
                                                              String coachName;
                                                              
                                                              if (coachId != null && coachId.isNotEmpty && _coachNames.containsKey(coachId)) {
                                                                coachName = _coachNames[coachId]!;
                                                              } else if (coachId == null || coachId.isEmpty) {
                                                                // If coachId is null in Triple Visit, MUST use pre-loaded PM/MSL name
                                                                // NEVER use dmName as it's the coached DM, not the coach
                                                                if (report.coachRole == 'pm' && _coachNames.containsKey('_pm_default') && _coachNames['_pm_default']!.isNotEmpty) {
                                                                  coachName = _coachNames['_pm_default']!;
                                                                } else if (report.coachRole == 'msl' && _coachNames.containsKey('_msl_default') && _coachNames['_msl_default']!.isNotEmpty) {
                                                                  coachName = _coachNames['_msl_default']!;
                                                                } else {
                                                                  // Fallback: use role abbreviation if no name found
                                                                  coachName = report.coachRole?.toUpperCase() ?? 'Unknown';
                                                                }
                                                              } else {
                                                                // If coachId exists but not in cache, use role abbreviation
                                                                coachName = report.coachRole?.toUpperCase() ?? 'Unknown';
                                                              }
                                                              
                                                              return Row(
                                                                children: [
                                                                  const Icon(Icons.person_outline, size: 14, color: AppColors.gray400),
                                                                  const SizedBox(width: 4),
                                                                  Expanded(
                                                                    child: Text(
                                                                      '$roleAbbrev: $coachName',
                                                                      style: const TextStyle(
                                                                        color: AppColors.gray600,
                                                                        fontSize: 12,
                                                                      ),
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              );
                                                            }
                                                          },
                                                        ),
                                                        const SizedBox(height: 2),
                                                        // Show DM + name
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.person_outline, size: 14, color: AppColors.gray400),
                                                            const SizedBox(width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                'DM: ${report.dmName}',
                                                                style: const TextStyle(
                                                                  color: AppColors.gray600,
                                                                  fontSize: 12,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 2),
                                                        // Show MR + name
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.badge_outlined, size: 14, color: AppColors.gray400),
                                                            const SizedBox(width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                'MR: ${report.mrName}',
                                                                style: const TextStyle(
                                                                  color: AppColors.gray600,
                                                                  fontSize: 12,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    )
                                                  else
                                                    // For Single Visit or other visit types
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          report.mrName,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.gray900,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                        const SizedBox(height: 4),
                                                        // For Single Visit, show "Single Visit" and PM once
                                                        if (report.typeOfVisit == 'Single')
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                'Single Visit',
                                                                style: const TextStyle(
                                                                  color: AppColors.gray600,
                                                                  fontSize: 12,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                                maxLines: 1,
                                                              ),
                                                              const SizedBox(height: 4),
                                                              Builder(
                                                                builder: (context) {
                                                                  final coachRole = report.coachRole ?? 'pm';
                                                                  final roleAbbrev = coachRole == 'pm' ? 'PM' : coachRole == 'msl' ? 'MSL' : coachRole.toUpperCase();
                                                                  // For Triple Visit, use coachName directly from model
                                                                  if (report.typeOfVisit == 'Triple' && report.coachName != null && report.coachName!.isNotEmpty) {
                                                                    return Row(
                                                                      children: [
                                                                        const Icon(Icons.person_outline, size: 14, color: AppColors.gray400),
                                                                        const SizedBox(width: 4),
                                                                        Expanded(
                                                                          child: Text(
                                                                            '$roleAbbrev: ${report.coachName}',
                                                                            style: const TextStyle(
                                                                              color: AppColors.gray600,
                                                                              fontSize: 12,
                                                                            ),
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  } else {
                                                                    // For other visits, fetch from Supabase
                                                                    return FutureBuilder<String?>(
                                                                      future: _getCoachName(_getCoachIdFromReport(report), report.coachRole),
                                                                      builder: (context, snapshot) {
                                                                        final coachName = snapshot.data ?? _getCoachNameFromReport(report) ?? report.dmName;
                                                                        return Row(
                                                                          children: [
                                                                            const Icon(Icons.person_outline, size: 14, color: AppColors.gray400),
                                                                            const SizedBox(width: 4),
                                                                            Expanded(
                                                                              child: Text(
                                                                                '$roleAbbrev: $coachName',
                                                                                style: const TextStyle(
                                                                                  color: AppColors.gray600,
                                                                                  fontSize: 12,
                                                                                ),
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        );
                                                                      },
                                                                    );
                                                                  }
                                                                },
                                                              ),
                                                            ],
                                                          )
                                                        else
                                                          // For other visit types (Double, etc.)
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  const Icon(Icons.person_outline, size: 14, color: AppColors.gray400),
                                                                  const SizedBox(width: 4),
                                                                  Expanded(
                                                                    child: Text(
                                                                      '${_getCoachRoleLabel(report.coachRole)}: ${report.dmName}',
                                                                      style: const TextStyle(
                                                                        color: AppColors.gray600,
                                                                        fontSize: 12,
                                                                      ),
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(height: 2),
                                                              Row(
                                                                children: [
                                                                  const Icon(Icons.badge_outlined, size: 14, color: AppColors.gray400),
                                                                  const SizedBox(width: 4),
                                                                  Expanded(
                                                                    child: Text(
                                                                      '${_getRoleLabel(_mrRoles[report.mrId] ?? 'MR')}: ${report.mrName}',
                                                                      style: const TextStyle(
                                                                        color: AppColors.gray600,
                                                                        fontSize: 12,
                                                                      ),
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                      ],
                                                    ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.gray400),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        report.date,
                                                        style: const TextStyle(
                                                          color: AppColors.gray600,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Quick Session Badge (if applicable)
                                            if (report.isQuickSession == true)
                                              Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.error.withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppColors.error, width: 2),
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: AppColors.error,
                                                  size: 16,
                                                ),
                                              ),
                                            // Score Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: scoreColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(Icons.star, color: scoreColor, size: 16),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    avgScore.toStringAsFixed(1),
                                                    style: TextStyle(
                                                      color: scoreColor,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Quick Stats - Only show for DM/FT reports
                                      if (report.coachRole != 'pm' && report.coachRole != 'msl')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: AppColors.gray50,
                                          ),
                                          child: Row(
                                            children: [
                                              _buildQuickStat('Punctuality', report.punctuality ?? 'N/A', report.punctuality == 'Yes'),
                                              _buildQuickStat('Dress Code', report.dressCode ?? 'N/A', report.dressCode == 'Yes'),
                                              _buildQuickStat('With MR', report.filledWithMR ?? 'N/A', report.filledWithMR == 'Yes'),
                                            ],
                                          ),
                                        ),
                                      // Action Buttons
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
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
                                                      _selectedReport = report;
                                                    });
                                                  },
                                                  borderRadius: const BorderRadius.only(
                                                    bottomLeft: Radius.circular(16),
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    child: const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.visibility_outlined, color: AppColors.primaryBlue, size: 18),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'View Details',
                                                          style: TextStyle(
                                                            color: AppColors.primaryBlue,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 24,
                                              color: AppColors.gray200,
                                            ),
                                            Expanded(
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
                                                          SnackBar(content: Text('Export failed: ${e.toString()}')),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  borderRadius: const BorderRadius.only(
                                                    bottomRight: Radius.circular(16),
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    child: const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.download_outlined, color: AppColors.success, size: 18),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Export',
                                                          style: TextStyle(
                                                            color: AppColors.success,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
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
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
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
                  activeTab: widget.activeTab,
                  onTabChange: widget.onTabChange,
                ),
              ],
            ),
          ),
        ),
        // Detailed Report Modal
        if (_selectedReport != null)
          _buildReportModal(context, _selectedReport!),
      ],
    );
  }

  Widget _buildReportModal(BuildContext context, CoachingReport report) {
    final avgScore = _calculateAvgScore(report);
    
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
              borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Modal Header
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradientHorizontal,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    const Text(
                      'Coaching Report Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                      // For Triple visit, show both DM and MR names
                      if (report.typeOfVisit == 'Triple' && report.dmName.isNotEmpty && report.mrName.isNotEmpty)
                        Column(
                          children: [
                            Text(
                              '${report.dmName} & ${report.mrName}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'District Manager & Medical Rep',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          report.mrName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              // Modal Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Quick Session Warning (if applicable)
                      if (report.isQuickSession == true)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error, width: 2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Quick Coaching Session',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'This session was started without a scheduled plan for this date.',
                                      style: TextStyle(
                                        color: AppColors.error.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Basic Info
                      _buildModalSection(
                        'Basic Information',
                        [
                          _buildModalInfoItem('Date', report.date),
                          _buildModalInfoItem('Average Score', '${avgScore.toStringAsFixed(2)} / 6.0'),
                          // Show Coach Role with actual coach name - use coachName directly from model for Triple Visit
                          Builder(
                            builder: (context) {
                              final coachRole = report.coachRole ?? 'pm';
                              final roleLabel = _getCoachRoleLabel(coachRole);
                              // For Triple Visit, use coachName directly from model
                              if (report.typeOfVisit == 'Triple' && report.coachName != null && report.coachName!.isNotEmpty) {
                                return _buildModalInfoItem('Coach Role', '$roleLabel: ${report.coachName}');
                              } else {
                                // For Triple Visit without coachName, get from cache or use pre-loaded PM/MSL name
                                final coachId = _getCoachIdFromReport(report);
                                String coachName;
                                
                                if (coachId != null && coachId.isNotEmpty && _coachNames.containsKey(coachId)) {
                                  coachName = _coachNames[coachId]!;
                                } else if (coachId == null || coachId.isEmpty) {
                                  // If coachId is null in Triple Visit, MUST use pre-loaded PM/MSL name
                                  // NEVER use dmName as it's the coached DM, not the coach
                                  if (report.coachRole == 'pm' && _coachNames.containsKey('_pm_default') && _coachNames['_pm_default']!.isNotEmpty) {
                                    coachName = _coachNames['_pm_default']!;
                                  } else if (report.coachRole == 'msl' && _coachNames.containsKey('_msl_default') && _coachNames['_msl_default']!.isNotEmpty) {
                                    coachName = _coachNames['_msl_default']!;
                                  } else {
                                    // Fallback: use role abbreviation if no name found
                                    coachName = report.coachRole?.toUpperCase() ?? 'Unknown';
                                  }
                                } else {
                                  // If coachId exists but not in cache, use role abbreviation
                                  coachName = report.coachRole?.toUpperCase() ?? 'Unknown';
                                }
                                
                                return _buildModalInfoItem('Coach Role', '$roleLabel: $coachName');
                              }
                            },
                          ),
                          // For Triple visit, show both DM and MR
                          if (report.typeOfVisit == 'Triple' && report.dmName.isNotEmpty && report.mrName.isNotEmpty) ...[
                            _buildModalInfoItem('District Manager', report.dmName),
                            _buildModalInfoItem('Medical Rep', report.mrName),
                          ] else
                            _buildModalInfoItem('Coached Person Role', '${_getRoleLabel(_mrRoles[report.mrId] ?? 'MR')}: ${report.mrName}'),
                          if (report.typeOfVisit != null)
                            _buildModalInfoItem('Type of Visit', report.typeOfVisit!),
                          if (report.isQuickSession == true)
                            _buildModalInfoItem('Session Type', 'Quick Session (No Plan)'),
                        ],
                      ),
                      // Personal Attributes - Only for DM/FT reports
                      if (report.coachRole != 'pm' && report.coachRole != 'msl') ...[
                        const SizedBox(height: 24),
                        _buildModalSection(
                          'Personal Attributes',
                          [
                            _buildModalYesNoItem('Punctuality', report.punctuality),
                            _buildModalYesNoItem('Dress Code', report.dressCode),
                            _buildModalYesNoItem('Time & Territory Management', report.timeManagement),
                          ],
                        ),
                      ],
                      // Performance Scores - Only for DM/FT reports
                      if (report.coachRole != 'pm' && report.coachRole != 'msl') ...[
                        const SizedBox(height: 24),
                        _buildModalSection(
                          'Performance Scores',
                          [
                            _buildModalScoreItem('Pharmacy Feedback', report.pharmacyFeedback),
                            _buildModalScoreItem('Review Customer Profile', report.reviewProfile),
                            _buildModalScoreItem('Brand Bonding Ladder', report.brandBonding),
                            _buildModalScoreItem('SMART Objectives', report.smartObjectives),
                            _buildModalScoreItem('Opening / Rapport', report.opening),
                            _buildModalScoreItem('Patient Profile', report.patientProfile),
                            _buildModalScoreItem('Engaging Customer', report.engaging),
                            _buildModalScoreItem('Insightful Questions', report.insightfulQuestions),
                            _buildModalScoreItem('Active Listening', report.activeListening),
                            _buildModalScoreItem('Link Features', report.linkFeatures),
                            _buildModalScoreItem('Product Knowledge', report.productKnowledge),
                            _buildModalScoreItem('E-detailing', report.eDetailing),
                            _buildModalScoreItem('Answering Questions', report.answeringQuestions),
                            _buildModalScoreItem('Summarize Call', report.summarizeCall),
                            _buildModalScoreItem('Ask for Commitment', report.askCommitment),
                            _buildModalScoreItem('Bridging', report.bridging),
                            _buildModalScoreItem('Self-assessment', report.selfAssessment),
                          ],
                        ),
                      ],
                      // Feedback - Only for DM/FT reports
                      if (report.coachRole != 'pm' && report.coachRole != 'msl') ...[
                        const SizedBox(height: 24),
                        _buildModalSection(
                          'Feedback',
                          [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: AppColors.success, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Strengths',
                                        style: TextStyle(
                                          color: AppColors.gray700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    report.strengths ?? 'No feedback provided',
                                    style: const TextStyle(
                                      color: AppColors.gray900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.warning.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.track_changes, color: AppColors.warning, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Areas of Improvement',
                                        style: TextStyle(
                                          color: AppColors.gray700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    report.improvements ?? 'No feedback provided',
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
                      const SizedBox(height: 24),
                      // Brick Information
                      if (report.brickName != null || report.visitCount != null || (report.doctorsVisited != null && report.doctorsVisited!.isNotEmpty))
                        _buildModalSection(
                          'Brick Information',
                          [
                            if (report.brickName != null)
                              _buildModalInfoItem('Brick Name', report.brickName!),
                            if (report.visitCount != null)
                              _buildModalInfoItem('Visits Count', report.visitCount.toString()),
                            if (report.doctorsVisited != null && report.doctorsVisited!.isNotEmpty)
                              _buildModalInfoItem('Doctors Visited', report.doctorsVisited!),
                          ],
                        ),
                      // Location Information (Google Maps Link only)
                      if (report.googleMapsUrl != null && report.googleMapsUrl!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildModalSection(
                          'Location',
                          [
                            _buildModalLinkItem('Location', report.googleMapsUrl!),
                          ],
                        ),
                      ],
                      // PM/MSL Specific Fields
                      if (report.coachRole == 'pm' || report.coachRole == 'msl') ...[
                        const SizedBox(height: 24),
                        _buildModalSection(
                          'PM/MSL Specific Information',
                          [
                            if (report.areaBrickName != null)
                              _buildModalInfoItem('Area & Brick Name', report.areaBrickName!),
                            if (report.typeOfVisit != null)
                              _buildModalInfoItem('Type of Visit', report.typeOfVisit!),
                            if (report.visitedAccountsNames != null && report.visitedAccountsNames!.isNotEmpty)
                              _buildModalInfoItem('Visited Accounts Names', report.visitedAccountsNames!),
                            if (report.generalFeedback != null && report.generalFeedback!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.gray50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'General Feedback and Special Insights',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      report.generalFeedback!,
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
                        // DM Feedback - Show for DM reports or Triple visits (which contain both DM and MR feedback)
                        if (_isDMReport(report) || report.typeOfVisit == 'Triple') ...[
                          const SizedBox(height: 24),
                          _buildModalSection(
                            'DM Feedback',
                            [
                              if (report.teamwork != null)
                                _buildModalInfoItem('Teamwork and Cooperation', report.teamwork!),
                              if (report.customerAwareness != null)
                                _buildModalInfoItem('Customer Awareness', report.customerAwareness!),
                              if (report.medicalProductKnowledgeDM != null)
                                _buildModalInfoItem('DM Medical Product Knowledge', report.medicalProductKnowledgeDM!),
                              if (report.dmFeedbackComments != null && report.dmFeedbackComments!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.gray50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DM Feedback Comments and Insights',
                                        style: TextStyle(
                                          color: AppColors.gray600,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
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
                        ],
                        // MR Feedback - Show for MR reports or Triple visits (which contain both DM and MR feedback)
                        if (!_isDMReport(report) || report.typeOfVisit == 'Triple') ...[
                          const SizedBox(height: 24),
                          _buildModalSection(
                            'MR Feedback',
                            [
                              if (report.punctuality != null)
                                _buildModalYesNoItem('Punctuality', report.punctuality),
                              if (report.dressCode != null)
                                _buildModalYesNoItem('Dress Code', report.dressCode),
                              if (report.patientCentricApproach != null)
                                _buildModalScoreItem('Patient Centric Approach', report.patientCentricApproach),
                              if (report.medicalProductKnowledgeMR != null)
                                _buildModalScoreItem('MR Medical Product Knowledge', report.medicalProductKnowledgeMR),
                              if (report.featureBenefits != null)
                                _buildModalScoreItem('Feature Benefits', report.featureBenefits),
                              if (report.closingCommitment != null)
                                _buildModalScoreItem('Closing Commitment', report.closingCommitment),
                              if (report.mrFeedbackComments != null && report.mrFeedbackComments!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.gray50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Comments and Insights',
                                        style: TextStyle(
                                          color: AppColors.gray600,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
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
                      // Additional Info - Only for DM/FT reports
                      if (report.coachRole != 'pm' && report.coachRole != 'msl') ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryCyan.withOpacity(0.3),
                            ),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: AppColors.gray700,
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Filled with Medical Representative: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: report.filledWithMR ?? 'N/A',
                                  style: TextStyle(
                                    color: report.filledWithMR == 'Yes'
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Modal Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                    SnackBar(content: Text('Export failed: ${e.toString()}')),
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
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Export Report',
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

  Widget _buildModalSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildModalInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.gray600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.gray900,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalLinkItem(String label, String url) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.gray600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                url,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalYesNoItem(String label, String? value) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
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
                color: AppColors.gray700,
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
              color: value == 'Yes'
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                color: value == 'Yes' ? AppColors.success : AppColors.error,
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
    final score = double.tryParse(value ?? '0') ?? 0.0;
    final percentage = (score / 6) * 100;
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.gray700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: AppColors.gray200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryCyan,
                ),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 32,
            child: Text(
              '${value ?? '0'}/6',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
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

  Widget _buildQuickStat(String label, String value, bool isPositive) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.gray600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isPositive ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: isPositive ? AppColors.success : AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
