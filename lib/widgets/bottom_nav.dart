import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';

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
    final tabs = role == 'dm' ? _dmTabs : _gmTabs;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.gray200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl
          margin: const EdgeInsets.symmetric(horizontal: 0),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: tabs.map((tab) {
              final isActive = activeTab == tab['id'];
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTabChange(tab['id'] as String),
                    child: Container(
                      height: 64,
                      child: Stack(
                        children: [
                          Column(
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
                            ],
                          ),
                          if (isActive)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 4,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.primaryGradientHorizontal,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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
    {'id': 'planning', 'label': 'Coaching', 'icon': Icons.home},
    {'id': 'dashboard', 'label': 'Dashboard', 'icon': Icons.bar_chart},
    {'id': 'profile', 'label': 'Profile', 'icon': Icons.settings},
  ];

  static const List<Map<String, dynamic>> _gmTabs = [
    {'id': 'dashboard', 'label': 'Dashboard', 'icon': Icons.home},
    {'id': 'users', 'label': 'Users', 'icon': Icons.people},
    {'id': 'reports', 'label': 'Reports', 'icon': Icons.description},
    {'id': 'profile', 'label': 'Profile', 'icon': Icons.settings},
  ];
}

