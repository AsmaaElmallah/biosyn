import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:biosyn_report_flutter/models/plan.dart';
import 'package:biosyn_report_flutter/services/plan_service.dart';

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
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _selectedDMId;
  List<Plan> _allPlans = [];
  List<String> _dmIds = [];
  Map<String, String> _dmNames = {};
  Map<String, Color> _dmColors = {};
  bool _isLoading = true;

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
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final allPlans = await PlanService.getPlans();
      
      // Extract unique DM IDs and names
      final dmSet = <String>{};
      final dmNamesMap = <String, String>{};
      
      for (final plan in allPlans) {
        if (plan.dmId.isNotEmpty) {
          dmSet.add(plan.dmId);
          dmNamesMap[plan.dmId] = plan.dmName;
        }
      }

      // Assign colors to DMs
      final dmColorsMap = <String, Color>{};
      int colorIndex = 0;
      for (final dmId in dmSet) {
        dmColorsMap[dmId] = _colorPalette[colorIndex % _colorPalette.length];
        colorIndex++;
      }

      setState(() {
        _allPlans = allPlans;
        _dmIds = dmSet.toList()..sort();
        _dmNames = dmNamesMap;
        _dmColors = dmColorsMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Plan> _getFilteredPlans() {
    if (_selectedDMId == null) {
      return _allPlans;
    }
    return _allPlans.where((plan) => plan.dmId == _selectedDMId).toList();
  }

  List<Plan> _getPlansForDay(DateTime day) {
    final filteredPlans = _getFilteredPlans();
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    return filteredPlans.where((plan) => plan.date == dateStr).toList();
  }

  Color _getColorForPlan(Plan plan) {
    return _dmColors[plan.dmId] ?? AppColors.primaryBlue;
  }

  Map<String, dynamic> _calculateStatistics() {
    final stats = <String, Map<String, dynamic>>{};
    
    for (final plan in _allPlans) {
      if (!stats.containsKey(plan.dmId)) {
        stats[plan.dmId] = {
          'dmName': plan.dmName,
          'total': 0,
          'pending': 0,
          'completed': 0,
          'cancelled': 0,
        };
      }
      
      final dmStats = stats[plan.dmId]!;
      dmStats['total'] = (dmStats['total'] as int) + 1;
      
      switch (plan.status) {
        case 'pending':
          dmStats['pending'] = (dmStats['pending'] as int) + 1;
          break;
        case 'completed':
          dmStats['completed'] = (dmStats['completed'] as int) + 1;
          break;
        case 'cancelled':
          dmStats['cancelled'] = (dmStats['cancelled'] as int) + 1;
          break;
      }
    }
    
    return {
      'totalPlans': _allPlans.length,
      'totalDMs': _dmIds.length,
      'dmStats': stats.values.toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlans = _getFilteredPlans();
    final plansForSelectedDay = _getPlansForDay(_selectedDay);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Column(
                children: [
                  const Text(
                    'View Plans',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'View all District Managers\' monthly plans',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Statistics Card
                          if (_allPlans.isNotEmpty) ...[
                            _buildStatisticsCard(),
                            const SizedBox(height: 24),
                          ],
                          // Filter by DM
                          if (_dmIds.isNotEmpty) ...[
                            Container(
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
                                      const Icon(Icons.filter_list,
                                          color: AppColors.primaryBlue, size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Filter by District Manager',
                                        style: TextStyle(
                                          color: AppColors.gray700,
                                          fontSize: 16,
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
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.gray200,
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.gray200,
                                          width: 2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.primaryCyan,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    hint: const Text('All District Managers'),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('All District Managers'),
                                      ),
                                      ..._dmIds.map((dmId) {
                                        return DropdownMenuItem<String>(
                                          value: dmId,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: _dmColors[dmId] ??
                                                      AppColors.primaryBlue,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _dmNames[dmId] ?? dmId,
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
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
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Calendar
                          Container(
                            padding: const EdgeInsets.all(24),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month,
                                        color: AppColors.primaryBlue, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Monthly Schedule',
                                      style: TextStyle(
                                        color: AppColors.gray700,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TableCalendar<Plan>(
                                  firstDay: DateTime.utc(2020, 1, 1),
                                  lastDay: DateTime.utc(2030, 12, 31),
                                  focusedDay: _focusedDay,
                                  selectedDayPredicate: (day) {
                                    return isSameDay(_selectedDay, day);
                                  },
                                  eventLoader: _getPlansForDay,
                                  calendarStyle: const CalendarStyle(
                                    outsideDaysVisible: false,
                                    weekendTextStyle:
                                        TextStyle(color: AppColors.primaryBlue),
                                    selectedDecoration: BoxDecoration(
                                      color: AppColors.primaryCyan,
                                      shape: BoxShape.circle,
                                    ),
                                    todayDecoration: BoxDecoration(
                                      color: AppColors.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  headerStyle: const HeaderStyle(
                                    formatButtonVisible: false,
                                    titleCentered: true,
                                  ),
                                  onDaySelected: (selectedDay, focusedDay) {
                                    setState(() {
                                      _selectedDay = selectedDay;
                                      _focusedDay = focusedDay;
                                    });
                                  },
                                  onPageChanged: (focusedDay) {
                                    setState(() {
                                      _focusedDay = focusedDay;
                                    });
                                  },
                                  calendarBuilders: CalendarBuilders(
                                    markerBuilder: (context, date, events) {
                                      if (events.isNotEmpty) {
                                        final plans = events;
                                        if (plans.length == 1) {
                                          // Single plan - show colored dot
                                          return Positioned(
                                            bottom: 1,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: _getColorForPlan(plans[0]),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          );
                                        } else {
                                          // Multiple plans - show indicator
                                          return Positioned(
                                            bottom: 1,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primaryCyan,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Selected Day Plans
                          if (plansForSelectedDay.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(24),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.event,
                                          color: AppColors.primaryBlue, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Plans for ${DateFormat('MMM dd, yyyy').format(_selectedDay)}',
                                        style: const TextStyle(
                                          color: AppColors.gray700,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ...plansForSelectedDay.map((plan) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _getColorForPlan(plan),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        color: _getColorForPlan(plan)
                                            .withOpacity(0.05),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: _getColorForPlan(plan),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  plan.dmName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.gray900,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'MR: ${plan.mrName}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.gray600,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: plan.status == 'completed'
                                                  ? AppColors.success
                                                  : plan.status == 'cancelled'
                                                      ? AppColors.error
                                                      : AppColors.warning,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              plan.status.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Legend
                          if (_dmIds.isNotEmpty) ...[
                            Container(
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
                                  const Text(
                                    'Legend',
                                    style: TextStyle(
                                      color: AppColors.gray700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: _dmIds.map((dmId) {
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: _dmColors[dmId] ??
                                                  AppColors.primaryBlue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _dmNames[dmId] ?? dmId,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.gray600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Empty State
                          if (filteredPlans.isEmpty) ...[
                            const SizedBox(height: 24),
                            Container(
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
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 64,
                                    color: AppColors.gray400,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No plans found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.gray700,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'District Managers haven\'t created any plans yet.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.gray600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildStatisticsCard() {
    final stats = _calculateStatistics();
    final dmStatsList = stats['dmStats'] as List<Map<String, dynamic>>;

    return Container(
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Plans Statistics',
                style: TextStyle(
                  color: AppColors.gray700,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Overall Stats
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Plans',
                  '${stats['totalPlans']}',
                  AppColors.primaryBlue,
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'District Managers',
                  '${stats['totalDMs']}',
                  AppColors.primaryCyan,
                  Icons.people,
                ),
              ),
            ],
          ),
          if (dmStatsList.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Per District Manager',
              style: TextStyle(
                color: AppColors.gray700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ...dmStatsList.map((dmStat) {
              final total = dmStat['total'] as int;
              final pending = dmStat['pending'] as int;
              final completed = dmStat['completed'] as int;
              final completionRate = total > 0 ? (completed / total * 100).toStringAsFixed(1) : '0.0';

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
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _dmColors[_dmIds.firstWhere(
                              (id) => _dmNames[id] == dmStat['dmName'],
                              orElse: () => '',
                            )] ?? AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dmStat['dmName'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gray900,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  color: AppColors.gray600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$total',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pending',
                                style: TextStyle(
                                  color: AppColors.gray600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$pending',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Completed',
                                style: TextStyle(
                                  color: AppColors.gray600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$completed',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rate',
                                style: TextStyle(
                                  color: AppColors.gray600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$completionRate%',
                                style: const TextStyle(
                                  color: AppColors.primaryCyan,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.gray600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

