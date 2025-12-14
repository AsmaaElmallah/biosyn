import 'package:connectivity_plus/connectivity_plus.dart';

/// Service للتحقق من حالة الاتصال بالإنترنت
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device is connected to internet
  static Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Get current connectivity status
  static Future<ConnectivityResult> getConnectivityStatus() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      return ConnectivityResult.none;
    }
  }

  /// Stream of connectivity changes
  static Stream<ConnectivityResult> get connectivityStream {
    return _connectivity.onConnectivityChanged;
  }

  /// Check if connected via WiFi
  static Future<bool> isWiFi() async {
    final status = await getConnectivityStatus();
    return status == ConnectivityResult.wifi;
  }

  /// Check if connected via mobile data
  static Future<bool> isMobile() async {
    final status = await getConnectivityStatus();
    return status == ConnectivityResult.mobile;
  }
}

