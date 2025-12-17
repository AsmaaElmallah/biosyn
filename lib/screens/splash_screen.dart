import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/widgets/logo_widget.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    
    // Dots animation controller
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    
    // Navigate after 4 seconds (increased time)
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo container - simple white box, NO shadow
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    // NO shadow - removed
                  ),
                  padding: const EdgeInsets.all(32),
                  child: const LogoWidget(size: 140),
                ),
                const SizedBox(height: 32),
                // App name
                const Text(
                  'Biosyn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Coaching App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 48),
                // Loading dots
                AnimatedBuilder(
                  animation: _dotsController,
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDot(0),
                        const SizedBox(width: 12),
                        _buildDot(1),
                        const SizedBox(width: 12),
                        _buildDot(2),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    // Staggered animation for each dot
    final delay = index * 0.2;
    final value = (_dotsController.value + delay) % 1.0;
    
    // Create bounce effect
    double scale;
    double opacity;
    
    if (value < 0.5) {
      scale = 1.0 + (value * 0.6);
      opacity = 0.5 + (value * 1.0);
    } else {
      scale = 1.3 - ((value - 0.5) * 0.6);
      opacity = 1.0 - ((value - 0.5) * 1.0);
    }
    
    return Transform.scale(
      scale: scale.clamp(0.8, 1.3),
      child: Opacity(
        opacity: opacity.clamp(0.4, 1.0),
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
