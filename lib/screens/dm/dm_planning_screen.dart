import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/connectivity_indicator.dart';
import 'package:biosyn_report_flutter/widgets/sync_status_indicator.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:biosyn_report_flutter/models/plan.dart';
import 'package:biosyn_report_flutter/services/plan_service.dart';

class DMPlanningScreen extends StatefulWidget {
  final Function(String, String, String) onStartCoaching;
  final String activeTab;
  final Function(String) onTabChange;
  final String? dmId;
  final String? dmName;

  const DMPlanningScreen({
    super.key,
    required this.onStartCoaching,
    required this.activeTab,
    required this.onTabChange,
    this.dmId,
    this.dmName,
  });

  @override
  State<DMPlanningScreen> createState() => _DMPlanningScreenState();
}

class _DMPlanningScreenState extends State<DMPlanningScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String? _selectedMR;
  String _view = 'today';
  List<Plan> _plans = [];
  bool _isLoading = true;

  final List<Map<String, String>> _medicalReps = [
    {'id': '2333', 'name': 'Aya Montaser Saber AbdElhamied'},
    {'id': '2318', 'name': 'Nancy Samy Shady'},
    {'id': '2334', 'name': 'Reman Karem'},
    {'id': '2332', 'name': 'Aml Abdelsattar Mohamad Nossir'},
    {'id': '2348', 'name': 'Amira Adel'},
    {'id': '2319', 'name': 'Omnia Fathi Abdel Monem Madara'},
    {'id': '2336', 'name': 'Farah Selim'},
    {'id': '2360', 'name': 'Aya Sayed'},
    {'id': '2361', 'name': 'Doha Elsayed'},
    {'id': '2339', 'name': 'Haneen Emad Eldeen Zayed'},
    {'id': '2347', 'name': 'Hanem Mohamed'},
    {'id': '2349', 'name': 'Rania Tawfik'},
    {'id': '2350', 'name': 'Eman Mahmoud'},
    {'id': '2351', 'name': 'Basma Maher'},
    {'id': '2352', 'name': 'Asmaa Attia'},
    {'id': '2354', 'name': 'Shorouk Tarek'},
    {'id': '2355', 'name': 'Mayada Adel'},
    {'id': '2356', 'name': 'Taghreed Hamdy'},
    {'id': '2357', 'name': 'Khaled Abd Elgawad'},
    {'id': '2358', 'name': 'Amira Ibrahim'},
    {'id': '2359', 'name': 'Mostafa Gamal'},
  ];

  String get _dmId => widget.dmId ?? 'dm_001';
  String get _dmName => widget.dmName ?? 'District Manager';

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await PlanService.getPlansByDM(_dmId);
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
      _loadPlanForSelectedDate();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _loadPlanForSelectedDate() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final plan = _plans.firstWhere(
      (p) => p.date == dateStr,
      orElse: () => Plan(
        id: '',
        dmId: _dmId,
        dmName: _dmName,
        date: dateStr,
        mrId: '',
        mrName: '',
      ),
    );
    if (plan.id.isNotEmpty) {
      setState(() {
        _selectedMR = plan.mrId;
      });
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _handleStartCoaching() {
    if (_selectedMR == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Medical Representative')),
      );
      return;
    }

    final mr = _medicalReps.firstWhere((m) => m['id'] == _selectedMR);
    widget.onStartCoaching(
      DateFormat('yyyy-MM-dd').format(_selectedDate),
      mr['id']!,
      mr['name']!,
    );
  }

  Future<void> _savePlan() async {
    if (_selectedMR == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Medical Representative')),
      );
      return;
    }

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final mr = _medicalReps.firstWhere((m) => m['id'] == _selectedMR);
      
      // Check if plan exists
      final existingPlan = await PlanService.getPlanByDate(_dmId, dateStr);
      
      final plan = existingPlan != null
          ? existingPlan.copyWith(
              mrId: mr['id']!,
              mrName: mr['name']!,
              updatedAt: DateTime.now(),
            )
          : Plan(
              id: 'plan_${_dmId}_$dateStr',
              dmId: _dmId,
              dmName: _dmName,
              date: dateStr,
              mrId: mr['id']!,
              mrName: mr['name']!,
              status: 'pending',
            );

      await PlanService.savePlan(plan);
      await _loadPlans();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save plan: $e')),
        );
      }
    }
  }

  Future<void> _deletePlan() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final plan = await PlanService.getPlanByDate(_dmId, dateStr);
    
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No plan found for this date')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: const Text('Are you sure you want to delete this plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await PlanService.deletePlan(plan.id);
        setState(() {
          _selectedMR = null;
        });
        await _loadPlans();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plan deleted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete plan: $e')),
          );
        }
      }
    }
  }

  List<Plan> _getPlansForDay(DateTime day) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    return _plans.where((plan) => plan.date == dateStr).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Column(
          children: [
            // Connectivity Indicator
            const ConnectivityIndicator(),
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
                    'Field Coaching',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Schedule and manage coaching visits',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
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
                          // Sync Status Indicator
                          const SyncStatusIndicator(),
                          const SizedBox(height: 16),
                          // View Toggle
                          Container(
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
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildToggleButton('Today', 'today'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildToggleButton('Schedule', 'schedule'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Calendar View (Schedule mode)
                          if (_view == 'schedule') ...[
                            _buildCard(
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
                                      return isSameDay(_selectedDate, day);
                                    },
                                    eventLoader: _getPlansForDay,
                                    calendarStyle: const CalendarStyle(
                                      outsideDaysVisible: false,
                                      weekendTextStyle: TextStyle(color: AppColors.primaryBlue),
                                      selectedDecoration: BoxDecoration(
                                        color: AppColors.primaryCyan,
                                        shape: BoxShape.circle,
                                      ),
                                      todayDecoration: BoxDecoration(
                                        color: AppColors.primaryBlue,
                                        shape: BoxShape.circle,
                                      ),
                                      markerDecoration: BoxDecoration(
                                        color: AppColors.primaryCyan,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    headerStyle: const HeaderStyle(
                                      formatButtonVisible: false,
                                      titleCentered: true,
                                    ),
                                    onDaySelected: (selectedDay, focusedDay) {
                                      setState(() {
                                        _selectedDate = selectedDay;
                                        _focusedDay = focusedDay;
                                      });
                                      _loadPlanForSelectedDate();
                                    },
                                    onPageChanged: (focusedDay) {
                                      setState(() {
                                        _focusedDay = focusedDay;
                                      });
                                    },
                                    calendarBuilders: CalendarBuilders(
                                      markerBuilder: (context, date, events) {
                                        if (events.isNotEmpty) {
                                          return Positioned(
                                            bottom: 1,
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primaryCyan,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Date Selection (Today mode)
                          if (_view == 'today') ...[
                            _buildCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          color: AppColors.primaryBlue, size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Select Date',
                                        style: TextStyle(
                                          color: AppColors.gray700,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _selectedDate = picked;
                                        });
                                        _loadPlanForSelectedDate();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.gray200, width: 2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              DateFormat('yyyy-MM-dd').format(_selectedDate),
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                          const Icon(Icons.arrow_drop_down),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_isToday) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryCyan,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Today's visit",
                                          style: TextStyle(
                                            color: AppColors.primaryCyan,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Medical Rep Selection
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Medical Representative',
                                  style: TextStyle(
                                    color: AppColors.gray700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedMR,
                                  isExpanded: true,
                                  decoration: InputDecoration(
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
                                  hint: const Text('Choose a Medical Rep...'),
                                  items: _medicalReps.map((mr) {
                                    return DropdownMenuItem(
                                      value: mr['id'],
                                      child: Text(
                                        '${mr['name']} - ${mr['id']}',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedMR = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (_selectedMR != null) ...[
                            const SizedBox(height: 24),
                            // Selected MR Card
                            Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.person, color: Colors.white, size: 32),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Selected Medical Rep',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _medicalReps.firstWhere((m) => m['id'] == _selectedMR)['name']!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: $_selectedMR',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Action Buttons
                          Row(
                            children: [
                              if (_view == 'schedule') ...[
                                Expanded(
                                  child: _buildActionButton(
                                    label: 'Save Plan',
                                    icon: Icons.save,
                                    onTap: _savePlan,
                                    gradient: AppColors.primaryGradientHorizontal,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionButton(
                                    label: 'Delete Plan',
                                    icon: Icons.delete,
                                    onTap: _deletePlan,
                                    color: Colors.red,
                                  ),
                                ),
                              ] else ...[
                                Expanded(
                                  child: _buildActionButton(
                                    label: 'Start Coaching Session',
                                    icon: Icons.description,
                                    onTap: _handleStartCoaching,
                                    gradient: AppColors.primaryGradientHorizontal,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Info Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryCyan.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline,
                                    color: AppColors.primaryBlue, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Note: Coaching reports cannot be submitted after 12:00 AM (midnight). Make sure to complete your session before the deadline.',
                                    style: TextStyle(
                                      color: AppColors.gray700,
                                      fontSize: 14,
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
            // Bottom Navigation
            BottomNav(
              role: 'dm',
              activeTab: widget.activeTab,
              onTabChange: widget.onTabChange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
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
      child: child,
    );
  }

  Widget _buildToggleButton(String label, String value) {
    final isSelected = _view == value;
    return InkWell(
      onTap: () {
        setState(() {
          _view = value;
        });
        if (_view == 'schedule') {
          _loadPlanForSelectedDate();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradientHorizontal : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.gray600,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    LinearGradient? gradient,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (color ?? AppColors.primaryBlue).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
