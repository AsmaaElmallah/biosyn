import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/widgets/logo_widget.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';

class WelcomeScreen extends StatelessWidget {
  final Function(String) onSelectRole;

  const WelcomeScreen({super.key, required this.onSelectRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0077B6),
              Color(0xFF00A8E8),
              Color(0xFF00B4D8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Main card - NO shadow
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 380),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      // NO shadow - removed
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Column(
                      children: [
                        // Logo inside card
                        const LogoWidget(size: 120),
                        const SizedBox(height: 40),
                        // Welcome text
                        const Text(
                          'Welcome',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose your role to continue',
                          style: TextStyle(
                            color: AppColors.gray600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // District Manager / Field Trainer Button
                        _buildPrimaryButton(
                          text: 'Login as District Manager / Field Trainer',
                          icon: Icons.person_outline,
                          onPressed: () => onSelectRole('dm'),
                        ),
                        const SizedBox(height: 16),
                        // Product Manager / Medical Science Liaison Button
                        _buildPrimaryButton(
                          text: 'Login as Product Manager / Medical Science Liaison',
                          icon: Icons.medical_services_outlined,
                          onPressed: () => onSelectRole('pm'),
                        ),
                        const SizedBox(height: 16),
                        // General Manager Button
                        _buildSecondaryButton(
                          text: 'Login as General Manager',
                          icon: Icons.business_outlined,
                          onPressed: () => onSelectRole('gm'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Footer
                  const Text(
                    'Biosyn Pharmaceuticals © 2024',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
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

  Widget _buildPrimaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.primaryBlue, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
