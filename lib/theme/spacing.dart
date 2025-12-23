import 'package:flutter/material.dart';

class AppSpacing {
  // Spacing Scale
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
  
  // Padding Scale
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);
  static const EdgeInsets paddingXXL = EdgeInsets.all(xxl);
  
  // Horizontal Padding
  static EdgeInsets paddingHorizontal(double spacing) => 
      EdgeInsets.symmetric(horizontal: spacing);
  
  // Vertical Padding
  static EdgeInsets paddingVertical(double spacing) => 
      EdgeInsets.symmetric(vertical: spacing);
  
  // Symmetric Padding
  static EdgeInsets paddingSymmetric({
    required double horizontal,
    required double vertical,
  }) => EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  
  // SizedBox Helpers
  static SizedBox vertical(double spacing) => SizedBox(height: spacing);
  static SizedBox horizontal(double spacing) => SizedBox(width: spacing);
  
  // Common Spacing Combinations
  static const EdgeInsets cardPadding = paddingLG;
  static const EdgeInsets screenPadding = paddingXL;
  static const EdgeInsets sectionSpacing = EdgeInsets.only(bottom: xl);
}

