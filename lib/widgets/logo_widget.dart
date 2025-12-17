import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  final bool showText;

  const LogoWidget({
    super.key,
    this.size = 100,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    // Just show the logo image without extra container
    return Image.asset(
      'assets/blue-logo.png',
      width: size,
      height: size * 0.6, // Adjust ratio to match logo aspect
      fit: BoxFit.contain,
    );
  }
}
