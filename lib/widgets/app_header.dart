import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/theme/text_styles.dart';
import 'package:biosyn_report_flutter/theme/spacing.dart';
import 'package:biosyn_report_flutter/utils/responsive.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? leading;
  final VoidCallback? onLeadingTap;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;

  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.onLeadingTap,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Leading widget (back button)
            if (leading != null)
              GestureDetector(
                onTap: onLeadingTap,
                child: leading!,
              )
            else
              const SizedBox(width: 0),
            // Title and subtitle in the middle
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h2.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
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
            ),
            // Trailing widget (notifications, etc.)
            if (trailing != null)
              GestureDetector(
                onTap: onTrailingTap,
                child: trailing!,
              )
            else
              const SizedBox(width: 0),
          ],
        ),
      ),
    );
  }
}

