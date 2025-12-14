import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:intl/intl.dart';

class DMPlanningScreen extends StatefulWidget {
  final Function(String, String, String) onStartCoaching;
  final String activeTab;
  final Function(String) onTabChange;

  const DMPlanningScreen({
    super.key,
    required this.onStartCoaching,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  State<DMPlanningScreen> createState() => _DMPlanningScreenState();
}

class _DMPlanningScreenState extends State<DMPlanningScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedMR;
  String _view = 'today';

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

  Future<void> _selectDate() async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  // Date Selection
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
                          onTap: _selectDate,
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
                  // Start Coaching Button
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
                        onTap: _selectedMR == null ? null : _handleStartCoaching,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.description, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                'Start Coaching Session',
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
}

