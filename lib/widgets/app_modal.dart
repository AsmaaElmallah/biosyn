import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/spacing.dart';

class AppModal {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool dismissible = true,
    bool barrierDismissible = true,
    double? maxWidth,
    double? maxHeight,
    EdgeInsets? padding,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? MediaQuery.of(context).size.width * 0.95,
            maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.9,
          ),
          child: Container(
            margin: padding ?? AppSpacing.paddingSymmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    double? height,
    EdgeInsets? padding,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: height,
        padding: padding ?? EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: child,
      ),
    );
  }
}

