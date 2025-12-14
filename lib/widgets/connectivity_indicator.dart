import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:biosyn_report_flutter/services/connectivity_service.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';

/// Widget لعرض حالة الاتصال بالإنترنت
class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final isConnected = await ConnectivityService.isConnected();
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });
    }
  }

  void _listenToConnectivity() {
    ConnectivityService.connectivityStream.listen((result) {
      if (mounted) {
        setState(() {
          _isConnected = result != ConnectivityResult.none;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No internet connection. Data will be saved locally and synced when connection is restored.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact connectivity indicator (icon only)
class CompactConnectivityIndicator extends StatefulWidget {
  const CompactConnectivityIndicator({super.key});

  @override
  State<CompactConnectivityIndicator> createState() =>
      _CompactConnectivityIndicatorState();
}

class _CompactConnectivityIndicatorState
    extends State<CompactConnectivityIndicator> {
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final isConnected = await ConnectivityService.isConnected();
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });
    }
  }

  void _listenToConnectivity() {
    ConnectivityService.connectivityStream.listen((result) {
      if (mounted) {
        setState(() {
          _isConnected = result != ConnectivityResult.none;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
    );
  }
}

