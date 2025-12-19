import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/utils/export_utils.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String _selectedDM = 'all';
  String _selectedMR = 'all';
  String _dateFilter = 'all';
  bool _showFilters = false;
  CoachingReport? _selectedReport;
  Map<String, String> _mrRoles = {}; // Map of MR ID to role

  List<String> get _uniqueDMs {
    // Include coach name with role for PM/MSL
    return widget.reports
        .map((r) {
          if (r.coachRole != null && r.coachRole!.isNotEmpty) {
            return '${r.dmName} (${r.coachRole!.toUpperCase()})';
          }
          return r.dmName;
        })
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> get _uniqueMRs {
    return widget.reports
        .map((r) => r.mrName)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  List<CoachingReport> get _filteredReports {
    return widget.reports.where((report) {
      final matchesSearch = _searchController.text.isEmpty ||
          report.mrName.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          report.dmName.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          report.mrId.contains(_searchController.text) ||
          (report.coachRole != null && report.coachRole!.toLowerCase().contains(_searchController.text.toLowerCase()));

      // Match DM/Coach name with role
      final reportCoachName = report.coachRole != null && report.coachRole!.isNotEmpty
          ? '${report.dmName} (${report.coachRole!.toUpperCase()})'
          : report.dmName;
      final matchesDM = _selectedDM == 'all' || reportCoachName == _selectedDM;
      final matchesMR = _selectedMR == 'all' || report.mrName == _selectedMR;

      bool matchesDate = true;
      if (_dateFilter != 'all' && report.date.isNotEmpty) {
        try {
          final reportDate = DateTime.parse(report.date);
          final today = DateTime.now();
          
          if (_dateFilter == 'today') {
            matchesDate = reportDate.year == today.year &&
                reportDate.month == today.month &&
                reportDate.day == today.day;
          } else if (_dateFilter == 'week') {
            final weekAgo = today.subtract(const Duration(days: 7));
            matchesDate = reportDate.isAfter(weekAgo) || reportDate.isAtSameMomentAs(weekAgo);
          } else if (_dateFilter == 'month') {
            matchesDate = reportDate.month == today.month &&
                reportDate.year == today.year;
          }
        } catch (e) {
          matchesDate = false;
        }
      }

      return matchesSearch && matchesDM && matchesMR && matchesDate;
    }).toList();
  }

  double _calculateAvgScore(CoachingReport report) {
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
  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'mr':
        return 'MR';
      case 'dm':
        return 'DM';
      case 'ft':
        return 'FT';
      case 'pm':
        return 'PM';
      case 'msl':
        return 'MSL';
      case 'gm':
        return 'GM';
      default:
        return role.toUpperCase();
    }
  }

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

  @override
  void initState() {
    super.initState();
    _loadMRRoles();
  }

  void _clearFilters() {
    setState(() {
      _selectedDM = 'all';
      _selectedMR = 'all';
      _dateFilter = 'all';
      _searchController.clear();
    });
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
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _showFilters = !_showFilters;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _showFilters
                                            ? AppColors.primaryBlue
                                            : Colors.white,
                                        border: Border.all(
                                          color: _showFilters
                                              ? AppColors.primaryBlue
                                              : AppColors.gray200,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.filter_list,
                                            color: _showFilters ? Colors.white : AppColors.gray700,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Filters',
                                            style: TextStyle(
                                              color: _showFilters
                                                  ? Colors.white
                                                  : AppColors.gray700,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
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
                                        await ExportUtils.exportAllReportsToText(widget.reports);
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
                                ),
                              ],
                            ),
                            if (_showFilters) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedDM,
                                decoration: InputDecoration(
                                  labelText: 'District Manager',
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
                                  const DropdownMenuItem(value: 'all', child: Text('All District Managers')),
                                  ..._uniqueDMs.map((dm) => DropdownMenuItem(value: dm, child: Text(dm))),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDM = value ?? 'all';
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _selectedMR,
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
                                  const DropdownMenuItem(value: 'all', child: Text('All Medical Reps')),
                                  ..._uniqueMRs.map((mr) => DropdownMenuItem(value: mr, child: Text(mr))),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMR = value ?? 'all';
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _dateFilter,
                                decoration: InputDecoration(
                                  labelText: 'Date Range',
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
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                                  DropdownMenuItem(value: 'today', child: Text('Today')),
                                  DropdownMenuItem(value: 'week', child: Text('Last 7 Days')),
                                  DropdownMenuItem(value: 'month', child: Text('This Month')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _dateFilter = value ?? 'all';
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _clearFilters,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Clear All Filters',
                                      style: TextStyle(
                                        color: AppColors.primaryBlue,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                                            // Avatar
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  report.mrName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
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
                                      // Quick Stats
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
                                                      await ExportUtils.exportSingleReportToText(report);
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
                          _buildModalInfoItem('Coach Role', '${_getCoachRoleLabel(report.coachRole)}: ${report.dmName}'),
                          _buildModalInfoItem('Coached Person Role', '${_getRoleLabel(_mrRoles[report.mrId] ?? 'MR')}: ${report.mrName}'),
                          _buildModalInfoItem('Medical Rep ID', report.mrId),
                          if (report.isQuickSession == true)
                            _buildModalInfoItem('Session Type', 'Quick Session (No Plan)'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Personal Attributes
                      _buildModalSection(
                        'Personal Attributes',
                        [
                          _buildModalYesNoItem('Punctuality', report.punctuality),
                          _buildModalYesNoItem('Dress Code', report.dressCode),
                          _buildModalYesNoItem('Time & Territory Management', report.timeManagement),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Performance Scores
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
                      const SizedBox(height: 24),
                      // Feedback
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
                      const SizedBox(height: 24),
                      // Location Information
                      if (report.locationName != null || report.googleMapsUrl != null || report.brickName != null)
                        _buildModalSection(
                          'Location Information',
                          [
                            if (report.brickName != null)
                              _buildModalInfoItem('Brick Name', report.brickName!),
                            if (report.locationName != null)
                              _buildModalInfoItem('Location Name', report.locationName!),
                            if (report.brickLocationLat != null && report.brickLocationLng != null)
                              _buildModalInfoItem('Coordinates', '${report.brickLocationLat!.toStringAsFixed(6)}, ${report.brickLocationLng!.toStringAsFixed(6)}'),
                            if (report.googleMapsUrl != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.gray50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 120,
                                      child: Text(
                                        'Google Maps',
                                        style: TextStyle(
                                          color: AppColors.gray600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final url = Uri.parse(report.googleMapsUrl!);
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                          }
                                        },
                                        child: Text(
                                          'Open in Maps',
                                          style: TextStyle(
                                            color: AppColors.primaryBlue,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (report.visitCount != null)
                              _buildModalInfoItem('Visit Count', report.visitCount.toString()),
                            if (report.doctorsVisited != null && report.doctorsVisited!.isNotEmpty)
                              _buildModalInfoItem('Doctors Visited', report.doctorsVisited!),
                          ],
                        ),
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
                                      'MR Feedback Comments and Insights',
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
                      const SizedBox(height: 24),
                      // Additional Info
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
                                await ExportUtils.exportSingleReportToText(report);
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
