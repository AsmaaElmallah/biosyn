import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/utils/responsive.dart';

class BottomNav extends StatelessWidget {
  final String role;
  final String activeTab;
  final Function(String) onTabChange;

  const BottomNav({
    super.key,
    required this.role,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = role == 'dm' || role == 'ft'
        ? _dmTabs
        : role == 'pm' || role == 'msl'
            ? _pmMslTabs
            : _gmTabs;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: Responsive.isMobile(context) ? 60 : 70,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.responsiveSpacing(context, mobile: 16, tablet: 24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: tabs.map((tab) {
              final isActive = activeTab == tab['id'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTabChange(tab['id'] as String),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab['icon'] as IconData,
                        color: isActive ? AppColors.primaryBlue : AppColors.gray400,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: isActive ? AppColors.primaryBlue : AppColors.gray400,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Short centered indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        width: isActive ? 40 : 0,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static const List<Map<String, dynamic>> _dmTabs = [
    {'id': 'planning', 'label': 'Coaching', 'icon': Icons.home_outlined},
    {'id': 'dashboard', 'label': 'Dashboard', 'icon': Icons.bar_chart},
    {'id': 'profile', 'label': 'Profile', 'icon': Icons.settings_outlined},
  ];

  static const List<Map<String, dynamic>> _pmMslTabs = [
    {'id': 'planning', 'label': 'Coaching', 'icon': Icons.home_outlined},
    {'id': 'dashboard', 'label': 'Dashboard', 'icon': Icons.bar_chart},
    {'id': 'profile', 'label': 'Profile', 'icon': Icons.settings_outlined},
  ];

  static const List<Map<String, dynamic>> _gmTabs = [
    {'id': 'dashboard', 'label': 'Dashboard', 'icon': Icons.home_outlined},
    {'id': 'users', 'label': 'Users', 'icon': Icons.people_outline},
    {'id': 'reports', 'label': 'Reports', 'icon': Icons.description_outlined},
    {'id': 'plans', 'label': 'Plans', 'icon': Icons.calendar_month_outlined},
    {'id': 'profile', 'label': 'Profile', 'icon': Icons.settings_outlined},
  ];
}
