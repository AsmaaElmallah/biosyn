import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/theme/text_styles.dart';
import 'package:biosyn_report_flutter/theme/spacing.dart';
import 'package:biosyn_report_flutter/utils/responsive.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;

  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue,
            AppColors.primaryCyan,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        Responsive.responsiveSpacing(context, mobile: AppSpacing.lg, tablet: AppSpacing.xl),
        Responsive.responsiveSpacing(context, mobile: AppSpacing.md, tablet: AppSpacing.lg) + AppSpacing.xs,
        Responsive.responsiveSpacing(context, mobile: AppSpacing.lg, tablet: AppSpacing.xl),
        Responsive.responsiveSpacing(context, mobile: AppSpacing.lg, tablet: AppSpacing.xl),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Text(
                  title,
                  style: AppTextStyles.h2.copyWith(color: Colors.white),
                ),
                AppSpacing.vertical(AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            if (trailing != null)
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: onTrailingTap,
                  child: trailing!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

