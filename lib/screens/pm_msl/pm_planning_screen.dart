import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/widgets/connectivity_indicator.dart';
import 'package:biosyn_report_flutter/widgets/sync_status_indicator.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:biosyn_report_flutter/models/plan.dart';
import 'package:biosyn_report_flutter/services/plan_service.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:biosyn_report_flutter/screens/pm_msl/pm_msl_coaching_form_screen.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';

class PMPlanningScreen extends StatefulWidget {
  final String activeTab;
  final Function(String) onTabChange;
  final String? coachId;
  final String? coachName;
  final String coachRole; // 'pm' or 'msl'
  final Function(CoachingReport) onReportSubmit;

  const PMPlanningScreen({
    super.key,
    required this.activeTab,
    required this.onTabChange,
    this.coachId,
    this.coachName,
    required this.coachRole,
    required this.onReportSubmit,
  });

  @override
  State<PMPlanningScreen> createState() => _PMPlanningScreenState();
}

class _PMPlanningScreenState extends State<PMPlanningScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String? _selectedDM;
  String? _selectedMR;
  String _view = 'today';
  List<Plan> _plans = [];
  bool _isLoading = true;
  List<Map<String, String>> _districtManagers = [];
  List<Map<String, String>> _medicalReps = [];
  bool _isDmLoading = true;
  bool _isMrLoading = true;
  String? _dmError;
  String? _mrError;

  String get _coachId => widget.coachId ?? '${widget.coachRole}_001';
  String get _coachName => widget.coachName ?? (widget.coachRole == 'pm' ? 'Product Manager' : 'Medical Science Liaison');

  // Helper to safely get selected DM name
  String _getSelectedDMName() {
    if (_selectedDM == null || _districtManagers.isEmpty) return 'DM';
    final dm = _districtManagers.firstWhere(
      (d) => d['id'] == _selectedDM,
      orElse: () => {'id': '', 'name': 'District Manager'},
    );
    return dm['name'] ?? 'District Manager';
  }

  // Helper to safely get selected MR name
  String _getSelectedMRName() {
    if (_selectedMR == null || _medicalReps.isEmpty) return 'MR';
    final mr = _medicalReps.firstWhere(
      (m) => m['id'] == _selectedMR,
      orElse: () => {'id': '', 'name': 'Medical Rep'},
    );
    return mr['name'] ?? 'Medical Rep';
  }

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadDistrictManagers();
    _loadMedicalReps();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await PlanService.getPlansByDM(_coachId);
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
      _loadPlanForSelectedDate();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDistrictManagers() async {
    setState(() {
      _isDmLoading = true;
      _dmError = null;
    });

    try {
      final dms = await SupabaseService.getAllDMsAndFTs();
      setState(() {
        _districtManagers = dms
            .map((u) => {
                  'id': (u['id'] ?? '').toString(),
                  'name': (u['name'] ?? '').toString(),
                })
            .toList();
      });
    } catch (e) {
      setState(() {
        _dmError = 'Failed to load District Managers. Please check Supabase connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDmLoading = false;
        });
      }
    }
  }

  Future<void> _loadMedicalReps() async {
    setState(() {
      _isMrLoading = true;
      _mrError = null;
    });

    try {
      final mrs = await SupabaseService.getAllMRs();
      setState(() {
        _medicalReps = mrs
            .map((u) => {
                  'id': (u['id'] ?? '').toString(),
                  'name': (u['name'] ?? '').toString(),
                })
            .toList();
      });
    } catch (e) {
      setState(() {
        _mrError = 'Failed to load Medical Reps. Please check Supabase connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMrLoading = false;
        });
      }
    }
  }

  void _loadPlanForSelectedDate() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final plan = _plans.firstWhere(
      (p) => p.date == dateStr,
      orElse: () => Plan(
        id: '',
        dmId: _coachId,
        dmName: _coachName,
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
    if (_selectedDM == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a District Manager')),
      );
      return;
    }
    if (_selectedMR == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Medical Representative')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PMMSLCoachingFormScreen(
          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
          coachId: _coachId,
          coachName: _coachName,
          coachRole: widget.coachRole,
          dmId: _selectedDM!,
          dmName: _getSelectedDMName(),
          mrId: _selectedMR!,
          mrName: _getSelectedMRName(),
          onSubmit: (report) async {
            widget.onReportSubmit(report);
            Navigator.pop(context);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coaching report submitted successfully!')),
              );
            }
          },
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _savePlan() async {
    if (_selectedDM == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a District Manager')),
      );
      return;
    }
    if (_selectedMR == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Medical Representative')),
      );
      return;
    }

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final mr = _medicalReps.firstWhere(
        (m) => m['id'] == _selectedMR,
        orElse: () => {'id': _selectedMR!, 'name': 'Medical Rep'},
      );
      
      // Check if plan exists
      final existingPlan = await PlanService.getPlanByDate(_coachId, dateStr);
      
      final plan = existingPlan != null
          ? existingPlan.copyWith(
              mrId: mr['id']!,
              mrName: mr['name']!,
              updatedAt: DateTime.now(),
            )
          : Plan(
              id: 'plan_${_coachId}_$dateStr',
              dmId: _coachId,
              dmName: _coachName,
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
    final plan = await PlanService.getPlanByDate(_coachId, dateStr);
    
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
            AppHeader(
              title: widget.coachRole == 'pm' ? 'Product Manager' : 'Medical Science Liaison',
              subtitle: 'Schedule and manage coaching visits',
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
                          // District Manager Selection
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select District Manager',
                                  style: TextStyle(
                                    color: AppColors.gray700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_isDmLoading)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else if (_dmError != null)
                                  Text(
                                    _dmError!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 14,
                                    ),
                                  )
                                else if (_districtManagers.isEmpty)
                                  const Text(
                                    'No District Managers found.\nPlease ask the General Manager to create DMs from User Management.',
                                    style: TextStyle(
                                      color: AppColors.gray600,
                                      fontSize: 14,
                                    ),
                                  )
                                else
                                  DropdownButtonFormField<String>(
                                    value: _selectedDM,
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
                                      prefixIcon: const Icon(Icons.business, color: AppColors.primaryCyan),
                                    ),
                                    hint: const Text('Choose a District Manager...'),
                                    items: _districtManagers.map((dm) {
                                      return DropdownMenuItem(
                                        value: dm['id'],
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryCyan.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  (dm['name'] ?? 'D')[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    color: AppColors.primaryBlue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                dm['name'] ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedDM = value;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
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
                                if (_isMrLoading)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else if (_mrError != null)
                                  Text(
                                    _mrError!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 14,
                                    ),
                                  )
                                else if (_medicalReps.isEmpty)
                                  const Text(
                                    'No Medical Representatives found.\nPlease ask the General Manager to create MRs from User Management.',
                                    style: TextStyle(
                                      color: AppColors.gray600,
                                      fontSize: 14,
                                    ),
                                  )
                                else
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
                                      prefixIcon: const Icon(Icons.person_search, color: AppColors.primaryCyan),
                                    ),
                                    hint: const Text('Choose a Medical Rep...'),
                                    items: _medicalReps.map((mr) {
                                      return DropdownMenuItem(
                                        value: mr['id'],
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryCyan.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  (mr['name'] ?? 'M')[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    color: AppColors.primaryBlue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                mr['name'] ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
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
                          if (_selectedDM != null && _selectedMR != null && _districtManagers.isNotEmpty && _medicalReps.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            // Selected DM & MR Card
                            Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    // DM Info
                                    Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              _getSelectedDMName()[0].toUpperCase(),
                                              style: const TextStyle(
                                                color: AppColors.primaryBlue,
                                                fontSize: 20,
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
                                              const Text(
                                                'District Manager',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                _getSelectedDMName(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(color: Colors.white30, height: 1),
                                    const SizedBox(height: 16),
                                    // MR Info
                                    Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              _getSelectedMRName()[0].toUpperCase(),
                                              style: const TextStyle(
                                                color: AppColors.primaryBlue,
                                                fontSize: 20,
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
                                              const Text(
                                                'Medical Representative',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                _getSelectedMRName(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Action Buttons - Only in Schedule mode
                          if (_view == 'schedule') ...[
                            Row(
                              children: [
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
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Monthly Plans Card
                            _buildMonthlyPlansCard(),
                          ] else ...[
                            // Today Plan Card with Start Session
                            _buildTodayPlanCard(),
                          ],
                          const SizedBox(height: 100), // Extra space for scroll
                        ],
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

  // Get all plans for the focused month
  List<Plan> _getMonthPlans() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    return _plans.where((plan) {
      final planDate = DateTime.parse(plan.date);
      return planDate.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))) &&
             planDate.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // Monthly Plans Card - Shows all scheduled plans for the month
  Widget _buildMonthlyPlansCard() {
    final monthPlans = _getMonthPlans();
    
    if (monthPlans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_busy, color: AppColors.gray400, size: 48),
            const SizedBox(height: 12),
            Text(
              'No plans for ${DateFormat('MMMM yyyy').format(_focusedDay)}',
              style: const TextStyle(
                color: AppColors.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a date, choose DM & MR, and save to schedule visits',
              style: TextStyle(color: AppColors.gray400, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradientHorizontal,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Plans for ${DateFormat('MMMM yyyy').format(_focusedDay)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${monthPlans.length} visits',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Plans list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: monthPlans.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.gray200),
            itemBuilder: (context, index) {
              final plan = monthPlans[index];
              final planDate = DateTime.parse(plan.date);
              final isToday = DateFormat('yyyy-MM-dd').format(planDate) == 
                              DateFormat('yyyy-MM-dd').format(DateTime.now());
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primaryCyan : AppColors.gray100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('d').format(planDate),
                        style: TextStyle(
                          color: isToday ? Colors.white : AppColors.gray700,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('E').format(planDate),
                        style: TextStyle(
                          color: isToday ? Colors.white70 : AppColors.gray400,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                title: Text(
                  plan.mrName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(Icons.badge, size: 14, color: AppColors.gray400),
                    const SizedBox(width: 4),
                    const Text('Medical Rep', style: TextStyle(fontSize: 12)),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deletePlanForDate(plan),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Today Plan Card - Shows plan for today or allows quick session start
  Widget _buildTodayPlanCard() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final plan = _plans.firstWhere(
      (p) => p.date == dateStr,
      orElse: () => Plan(
        id: '',
        dmId: _coachId,
        dmName: _coachName,
        date: dateStr,
        mrId: '',
        mrName: '',
      ),
    );

    // If plan exists for today - show it
    if (plan.id.isNotEmpty && _selectedMR != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryCyan.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            // Header - Scheduled
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradientHorizontal,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Scheduled Visit - ${DateFormat('MMM d').format(_selectedDate)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'FROM SCHEDULE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // MR Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        plan.mrName.isNotEmpty ? plan.mrName[0].toUpperCase() : 'M',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.mrName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Medical Representative',
                          style: TextStyle(color: AppColors.gray400, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Start Coaching Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: _buildActionButton(
                  label: 'Start Coaching Session',
                  icon: Icons.play_arrow,
                  onTap: _handleStartCoaching,
                  gradient: AppColors.primaryGradientHorizontal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // No plan for today - allow quick session start
    return Container(
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
          // Header - Quick Start
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Quick Coaching Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NO SCHEDULE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info text
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primaryCyan, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No scheduled visit for ${DateFormat('MMM d').format(_selectedDate)}. Select DM & MR above to start a quick session.',
                    style: const TextStyle(
                      color: AppColors.gray600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Start Button (only if DM & MR selected)
          if (_selectedDM != null && _selectedMR != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: _buildActionButton(
                  label: 'Start Quick Session',
                  icon: Icons.play_arrow,
                  onTap: _handleStartCoaching,
                  gradient: AppColors.primaryGradientHorizontal,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add, color: AppColors.gray400, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Select DM & MR to Start',
                      style: TextStyle(
                        color: AppColors.gray400,
                        fontSize: 15,
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
  }

  Future<void> _deletePlanForDate(Plan plan) async {
    final planDate = DateTime.parse(plan.date);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('Delete Plan')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete the plan for ${plan.mrName}?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${DateFormat('EEEE, MMM d, yyyy').format(planDate)}',
              style: const TextStyle(color: AppColors.gray400, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Plan for ${plan.mrName} deleted'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete plan: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
