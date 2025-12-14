import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/services/sync_service.dart';
import 'package:biosyn_report_flutter/services/connectivity_service.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';

/// Widget لعرض حالة Sync
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  bool _isSyncing = false;
  Map<String, int> _syncStatus = {
    'unsynced_reports': 0,
    'unsynced_plans': 0,
    'queue_items': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
    _periodicCheck();
  }

  Future<void> _loadSyncStatus() async {
    try {
      final status = await SyncService.getSyncStatus();
      if (mounted) {
        setState(() {
          _syncStatus = status;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _periodicCheck() {
    // Check sync status every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadSyncStatus();
        _periodicCheck();
      }
    });
  }

  Future<void> _manualSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final isConnected = await ConnectivityService.isConnected();
      if (!isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No internet connection. Cannot sync.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      await SyncService.manualSync();
      await _loadSyncStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  int get _totalUnsynced {
    return _syncStatus['unsynced_reports']! +
        _syncStatus['unsynced_plans']! +
        _syncStatus['queue_items']!;
  }

  @override
  Widget build(BuildContext context) {
    if (_totalUnsynced == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _isSyncing ? null : _manualSync,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          border: Border.all(
            color: AppColors.warning,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSyncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
                ),
              )
            else
              const Icon(
                Icons.cloud_upload,
                color: AppColors.warning,
                size: 16,
              ),
            const SizedBox(width: 8),
            Text(
              '$_totalUnsynced pending sync',
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

