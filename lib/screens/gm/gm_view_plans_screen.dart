import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:intl/intl.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:biosyn_report_flutter/services/connectivity_service.dart';

class GMViewPlansScreen extends StatefulWidget {
  final String activeTab;
  final Function(String) onTabChange;

  const GMViewPlansScreen({
    super.key,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  State<GMViewPlansScreen> createState() => _GMViewPlansScreenState();
}

class _GMViewPlansScreenState extends State<GMViewPlansScreen> {
  String? _selectedDMId;
  List<Map<String, dynamic>> _allPlans = [];
  List<Map<String, dynamic>> _allDMs = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Current month for filtering
  DateTime _selectedMonth = DateTime.now();

  // Colors for different DMs
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final isConnected = await ConnectivityService.isConnected();
      debugPrint('📅 GMViewPlansScreen._loadData()');
      debugPrint('   Is connected: $isConnected');
      debugPrint('   Supabase initialized: ${SupabaseService.isInitialized}');
      
      if (!isConnected) {
        setState(() {
          _errorMessage = 'No internet connection. Please check your network.';
          _isLoading = false;
        });
        return;
      }
      
      if (!SupabaseService.isInitialized) {
        setState(() {
          _errorMessage = 'Supabase is not initialized.';
          _isLoading = false;
        });
        return;
      }
      
      // Fetch all coaches (DM, FT, PM, MSL) and Plans from Supabase
      final dms = await SupabaseService.getAllDMs();
      final fts = await SupabaseService.getAllFTs();
      final pms = await SupabaseService.getAllPMs();
      final msls = await SupabaseService.getAllMSLs();
      final plans = await SupabaseService.getAllPlans();
      
      // Combine all coaches
      final allCoaches = [
        ...dms.map((dm) => {...dm, 'role': 'dm'}),
        ...fts.map((ft) => {...ft, 'role': 'ft'}),
        ...pms.map((pm) => {...pm, 'role': 'pm'}),
        ...msls.map((msl) => {...msl, 'role': 'msl'}),
      ];
      
      debugPrint('   ✅ Loaded ${allCoaches.length} Coaches (${dms.length} DMs, ${fts.length} FTs, ${pms.length} PMs, ${msls.length} MSLs)');
      debugPrint('   ✅ Loaded ${plans.length} Plans');
      
      setState(() {
        _allDMs = allCoaches;
        _allPlans = plans;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('   ❌ Error: $e');
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Color _getColorForDM(int index) {
    return _colorPalette[index % _colorPalette.length];
  }

  List<Map<String, dynamic>> _getFilteredPlans() {
    var plans = _allPlans;
    
    // Filter by selected DM
    if (_selectedDMId != null) {
      plans = plans.where((p) => p['dm_id'] == _selectedDMId).toList();
    }
    
    // Filter by selected month
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    
    plans = plans.where((p) {
      try {
        final planDate = DateTime.parse(p['date']);
        return planDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
               planDate.isBefore(monthEnd.add(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();
    
    // Sort by date
    plans.sort((a, b) {
      try {
        return DateTime.parse(a['date']).compareTo(DateTime.parse(b['date']));
      } catch (e) {
        return 0;
      }
    });
    
    return plans;
  }

  // Group plans by DM
  Map<String, List<Map<String, dynamic>>> _groupPlansByDM() {
    final filteredPlans = _getFilteredPlans();
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final plan in filteredPlans) {
      final dmId = plan['dm_id']?.toString() ?? '';
      final dmName = plan['dm_name']?.toString() ?? 'Unknown DM';
      final key = '$dmId|$dmName';
      
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(plan);
    }
    
    return grouped;
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

  @override
  Widget build(BuildContext context) {
    final groupedPlans = _groupPlansByDM();
    final filteredPlans = _getFilteredPlans();

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const AppHeader(
              title: 'View Plans',
              subtitle: 'View all District Managers\' monthly plans',
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Month Selector
                                _buildMonthSelector(),
                                const SizedBox(height: 16),
                                
                                // Filter by DM
                                _buildDMFilter(),
                                const SizedBox(height: 16),
                                
                                // Statistics Summary
                                _buildStatsSummary(filteredPlans),
                                const SizedBox(height: 20),
                                
                                // Plans List by DM
                                if (groupedPlans.isEmpty)
                                  _buildEmptyState()
                                else
                                  ...groupedPlans.entries.map((entry) {
                                    final parts = entry.key.split('|');
                                    final dmId = parts[0];
                                    final dmName = parts.length > 1 ? parts[1] : 'Unknown DM';
                                    final dmPlans = entry.value;
                                    final dmIndex = _allDMs.indexWhere((d) => d['id'] == dmId);
                                    final color = _getColorForDM(dmIndex >= 0 ? dmIndex : 0);
                                    
                                    return _buildDMPlanCard(dmName, dmPlans, color);
                                  }),
                                
                                // Bottom padding
                                const SizedBox(height: 20),
                              ],
                            ),
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
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left, color: AppColors.primaryBlue),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.gray700,
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right, color: AppColors.primaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildDMFilter() {
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
                'Filter by District Manager',
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
            value: _selectedDMId,
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
            hint: const Text('All District Managers'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All District Managers'),
              ),
              ..._allDMs.asMap().entries.map((entry) {
                final dm = entry.value;
                final index = entry.key;
                return DropdownMenuItem<String>(
                  value: dm['id']?.toString(),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getColorForDM(index),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dm['name']?.toString() ?? 'Unknown',
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
                _selectedDMId = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(List<Map<String, dynamic>> plans) {
    final totalPlans = plans.length;
    final pendingPlans = plans.where((p) => p['status'] == 'pending').length;
    final completedPlans = plans.where((p) => p['status'] == 'completed').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard('Total', '$totalPlans', AppColors.primaryBlue, Icons.calendar_today),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard('Pending', '$pendingPlans', AppColors.warning, Icons.pending_actions),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard('Done', '$completedPlans', AppColors.success, Icons.check_circle),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.gray600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDMPlanCard(String dmName, List<Map<String, dynamic>> plans, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // DM Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      dmName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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
                        dmName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${plans.length} planned visits',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Plans List
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: plans.asMap().entries.map((entry) {
                final plan = entry.value;
                final isLast = entry.key == plans.length - 1;
                
                return _buildPlanItem(plan, color, isLast);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItem(Map<String, dynamic> plan, Color color, bool isLast) {
    final date = plan['date']?.toString() ?? '';
    final mrName = plan['mr_name']?.toString() ?? 'Unknown MR';
    final status = plan['status']?.toString() ?? 'pending';
    
    DateTime? planDate;
    try {
      planDate = DateTime.parse(date);
    } catch (e) {
      planDate = null;
    }
    
    final isToday = planDate != null && 
        planDate.year == DateTime.now().year &&
        planDate.month == DateTime.now().month &&
        planDate.day == DateTime.now().day;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday ? color.withOpacity(0.05) : AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
        border: isToday ? Border.all(color: color.withOpacity(0.3), width: 1) : null,
      ),
      child: Row(
        children: [
          // Date
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isToday ? color : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isToday ? color : AppColors.gray200),
            ),
            child: Column(
              children: [
                Text(
                  planDate != null ? DateFormat('d').format(planDate) : '--',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : AppColors.gray700,
                  ),
                ),
                Text(
                  planDate != null ? DateFormat('EEE').format(planDate) : '',
                  style: TextStyle(
                    fontSize: 10,
                    color: isToday ? Colors.white70 : AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // MR Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mrName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 12, color: AppColors.gray400),
                    const SizedBox(width: 4),
                    const Text(
                      'Medical Rep',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.gray400,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'completed'
                  ? AppColors.success.withOpacity(0.1)
                  : status == 'cancelled'
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: status == 'completed'
                    ? AppColors.success
                    : status == 'cancelled'
                        ? AppColors.error
                        : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 40,
              color: AppColors.gray400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No plans for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'District Managers haven\'t created any plans for this month yet.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.gray400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.gray700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
