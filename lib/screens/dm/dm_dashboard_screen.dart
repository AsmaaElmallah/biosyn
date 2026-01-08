import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/theme/text_styles.dart';
import 'package:biosyn_report_flutter/theme/spacing.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/widgets/app_card.dart';
import 'package:biosyn_report_flutter/widgets/sync_status_indicator.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/utils/export_utils.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:biosyn_report_flutter/utils/responsive.dart';
import 'package:biosyn_report_flutter/screens/shared/notifications_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class DMDashboardScreen extends StatefulWidget {
  final List<CoachingReport> reports;
  final Function(String?) onExport;
  final String activeTab;
  final Function(String) onTabChange;
  final Future<void> Function()? onRefresh;
  final String? dmId; // For real-time updates

  const DMDashboardScreen({
    super.key,
    required this.reports,
    required this.onExport,
    required this.activeTab,
    required this.onTabChange,
    this.onRefresh,
    this.dmId,
  });

  @override
  State<DMDashboardScreen> createState() => _DMDashboardScreenState();
}

class _DMDashboardScreenState extends State<DMDashboardScreen> {
  CoachingReport? _selectedReport;
  StreamSubscription<List<CoachingReport>>? _reportsSubscription;
  List<CoachingReport> _currentReports = [];
  Map<String, String?> _mrProfilePictures = {}; // Map of MR ID -> profile_picture_url
  Map<String, String?> _mrNamesToIds = {}; // Map of MR name -> MR ID for lookup
  int _unreadNotificationsCount = 0;
  Timer? _notificationsTimer;

  @override
  void initState() {
    super.initState();
    _currentReports = List.from(widget.reports);
    _loadMRProfiles();
    _startRealtimeUpdates();
    if (widget.dmId != null) {
      _loadUnreadNotificationsCount();
      // Refresh notifications count every 30 seconds
      _notificationsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _loadUnreadNotificationsCount();
      });
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    if (widget.dmId == null) return;
    
    try {
      final count = await SupabaseService.getUnreadNotificationsCount(widget.dmId!);
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading unread notifications count: $e');
    }
  }

  void _openNotifications() {
    if (widget.dmId == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          userId: widget.dmId!,
          activeTab: widget.activeTab,
          onTabChange: widget.onTabChange,
        ),
      ),
    ).then((_) {
      // Refresh count when returning from notifications screen
      _loadUnreadNotificationsCount();
    });
  }

  Future<void> _loadMRProfiles() async {
    try {
      debugPrint('🖼️ Loading MR profile pictures...');
      final mrs = await SupabaseService.getAllMRs();
      debugPrint('   📦 Fetched ${mrs.length} MRs from Supabase');
      
      final profileMap = <String, String?>{};
      final nameToIdMap = <String, String?>{};
      
      for (final mr in mrs) {
        final id = (mr['id'] ?? '').toString();
        final name = (mr['name'] ?? '').toString();
        final profileUrl = mr['profile_picture_url']?.toString();
        
        debugPrint('   👤 MR: id=$id, name=$name, profileUrl=${profileUrl ?? 'null'}');
        
        if (id.isNotEmpty) {
          profileMap[id] = profileUrl;
          if (profileUrl != null && profileUrl.isNotEmpty) {
            debugPrint('      ✅ Added profile picture for $name (ID: $id)');
          }
        }
        if (name.isNotEmpty && id.isNotEmpty) {
          nameToIdMap[name] = id;
        }
      }
      
      final picturesCount = profileMap.values.where((url) => url != null && url.isNotEmpty).length;
      debugPrint('   ✅ Loaded ${profileMap.length} MR profiles ($picturesCount with pictures)');
      debugPrint('   📝 Name to ID map: ${nameToIdMap.length} entries');
      if (mounted) {
        setState(() {
          _mrProfilePictures = profileMap;
          _mrNamesToIds = nameToIdMap;
        });
      }
    } catch (e) {
      debugPrint('   ❌ Error loading MR profiles: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
    }
  }

  String? _getMRProfilePictureUrl(String mrId, String? mrName) {
    debugPrint('   🔍 Looking for profile picture: mrId=$mrId, mrName=$mrName');
    debugPrint('   📊 Available MR IDs: ${_mrProfilePictures.keys.toList()}');
    debugPrint('   📊 Available MR names: ${_mrNamesToIds.keys.toList()}');
    
    // Try by ID first
    if (mrId.isNotEmpty && _mrProfilePictures.containsKey(mrId)) {
      final url = _mrProfilePictures[mrId];
      debugPrint('   ✅ Found by ID: $url');
      return url;
    }
    
    // Try by name if ID not found
    if (mrName != null && mrName.isNotEmpty && _mrNamesToIds.containsKey(mrName)) {
      final id = _mrNamesToIds[mrName];
      debugPrint('   🔍 Found ID by name: $id');
      if (id != null && _mrProfilePictures.containsKey(id)) {
        final url = _mrProfilePictures[id];
        debugPrint('   ✅ Found by name: $url');
        return url;
      }
    }
    
    // Try case-insensitive name match
    if (mrName != null && mrName.isNotEmpty) {
      for (final entry in _mrNamesToIds.entries) {
        if (entry.key.toLowerCase().trim() == mrName.toLowerCase().trim()) {
          final id = entry.value;
          if (id != null && _mrProfilePictures.containsKey(id)) {
            final url = _mrProfilePictures[id];
            debugPrint('   ✅ Found by case-insensitive name match: $url');
            return url;
          }
        }
      }
    }
    
    debugPrint('   ❌ Profile picture not found');
    return null;
  }

  String _getCoachRoleLabel(String? role) {
    switch (role?.toLowerCase()) {
      case 'dm':
        return 'District Manager';
      case 'ft':
        return 'Field Trainer';
      case 'pm':
        return 'Product Manager';
      case 'msl':
        return 'Medical Science Liaison';
      default:
        return 'District Manager'; // Default for backward compatibility
    }
  }

  Map<String, dynamic> _calculateStatsFromReports(List<CoachingReport> reports) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final thisMonthReports = reports.where((r) {
      if (r.date.isEmpty) return false;
      try {
        final reportDate = DateTime.parse(r.date);
        return reportDate.month == currentMonth && reportDate.year == currentYear;
      } catch (e) {
        return false;
      }
    }).toList();

    final allScores = thisMonthReports
        .map((r) => r.getAverageScore())
        .where((s) => s > 0)
        .toList();
    final avgScore = allScores.isEmpty
        ? 0.0
        : allScores.reduce((a, b) => a + b) / allScores.length;

    final uniqueMRs = thisMonthReports.map((r) => r.mrId).toSet().length;

    return {
      'totalVisitsThisMonth': thisMonthReports.length,
      'averageScore': avgScore,
      'totalMRsCoached': uniqueMRs,
    };
  }

  List<Map<String, dynamic>> _calculateMonthlyVisitsFromReports(List<CoachingReport> reports) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final monthlyData = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final month = months[date.month - 1];
      
      final visitsCount = reports.where((r) {
        if (r.date.isEmpty) return false;
        try {
          final reportDate = DateTime.parse(r.date);
          return reportDate.month == date.month && reportDate.year == date.year;
        } catch (e) {
          return false;
        }
      }).length;

      monthlyData.add({'month': month, 'visits': visitsCount});
    }

    return monthlyData;
  }

  List<Map<String, dynamic>> _calculateMRPerformanceFromReports(List<CoachingReport> reports) {
    final mrStats = <String, Map<String, dynamic>>{};

    for (final report in reports) {
      if (report.mrName.isEmpty) continue;
      
      if (!mrStats.containsKey(report.mrName)) {
        mrStats[report.mrName] = {'visits': 0, 'scores': <double>[]};
      }

      mrStats[report.mrName]!['visits'] = (mrStats[report.mrName]!['visits'] as int) + 1;
      final score = report.getAverageScore();
      if (score > 0) {
        (mrStats[report.mrName]!['scores'] as List<double>).add(score);
      }
    }

    final mrPerformance = mrStats.entries.map((entry) {
      final scores = entry.value['scores'] as List<double>;
      final avgScore = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;
      
      final nameParts = entry.key.split(' ');
      final shortName = nameParts.length >= 2 
          ? '${nameParts[0]} ${nameParts[1]}'
          : entry.key;

      return {
        'name': shortName,
        'visits': entry.value['visits'],
        'avgScore': double.parse(avgScore.toStringAsFixed(2)),
      };
    }).toList()
      ..sort((a, b) => (b['avgScore'] as double).compareTo(a['avgScore'] as double));
    
    if (mrPerformance.length > 6) {
      mrPerformance.removeRange(6, mrPerformance.length);
    }
    
    return mrPerformance;
  }


  @override
  void didUpdateWidget(DMDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reports != widget.reports) {
      setState(() {
        _currentReports = List.from(widget.reports);
      });
    }
  }

  void _startRealtimeUpdates() {
    // Only start real-time if dmId is provided and Supabase is initialized
    if (widget.dmId != null && SupabaseService.isInitialized) {
      _reportsSubscription = SupabaseService.watchReports(widget.dmId!).listen(
        (reports) {
          if (mounted) {
            setState(() {
              _currentReports = reports;
            });
            // Notify parent to update reports
            if (widget.onRefresh != null) {
              widget.onRefresh!();
            }
          }
        },
        onError: (error) {
          // Silently handle errors - fallback to widget.reports
          if (mounted) {
            setState(() {
              _currentReports = List.from(widget.reports);
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _notificationsTimer?.cancel();
    _reportsSubscription?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _calculateMonthlyMRVisitsFromReports(List<CoachingReport> reports) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final thisMonthReports = reports.where((r) {
      if (r.date.isEmpty) return false;
      try {
        final reportDate = DateTime.parse(r.date);
        return reportDate.month == currentMonth && reportDate.year == currentYear;
      } catch (e) {
        return false;
      }
    }).toList();

    final mrReports = <String, List<CoachingReport>>{};
    
    for (final report in thisMonthReports) {
      if (report.mrId.isEmpty || report.mrName.isEmpty) continue;
      
      final key = '${report.mrId}_${report.mrName}';
      if (!mrReports.containsKey(key)) {
        mrReports[key] = [];
      }
      mrReports[key]!.add(report);
    }

    return mrReports.entries.map((entry) {
      final [mrId, ...nameParts] = entry.key.split('_');
      final mrName = nameParts.join('_');
      
      final sortedReports = List<CoachingReport>.from(entry.value)
        ..sort((a, b) => a.date.compareTo(b.date));

      final visitScores = sortedReports.map((r) => <String, dynamic>{
        'date': r.date,
        'score': double.parse(r.getAverageScore().toStringAsFixed(2)),
      }).toList();

      final totalScore = visitScores.fold<double>(0.0, (sum, v) => sum + (v['score'] as double));
      final averageScore = visitScores.isEmpty
          ? 0.0
          : double.parse((totalScore / visitScores.length).toStringAsFixed(2));

      return {
        'mrId': mrId,
        'mrName': mrName,
        'visitCount': visitScores.length,
        'visits': visitScores,
        'averageScore': averageScore,
      };
    }).toList()
      ..sort((a, b) {
        final visitDiff = (b['visitCount'] as int) - (a['visitCount'] as int);
        if (visitDiff != 0) return visitDiff;
        return (b['averageScore'] as double).compareTo(a['averageScore'] as double);
      });
  }

  @override
  Widget build(BuildContext context) {
    // Use _currentReports for real-time updates, fallback to widget.reports
    final reports = _currentReports.isNotEmpty ? _currentReports : widget.reports;
    final stats = _calculateStatsFromReports(reports);
    final monthlyVisits = _calculateMonthlyVisitsFromReports(reports);
    final mrPerformance = _calculateMRPerformanceFromReports(reports);
    final monthlyMRVisits = _calculateMonthlyMRVisitsFromReports(reports);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
            // Header with notifications bell
            AppHeader(
              title: 'Dashboard',
              subtitle: 'Your coaching performance overview',
              trailing: widget.dmId != null
                  ? Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: _openNotifications,
                        ),
                        if (_unreadNotificationsCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    )
                  : null,
            ),
            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.onRefresh ?? () async {},
                  child: SingleChildScrollView(
                  padding: Responsive.responsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sync Status Indicator
                    const SyncStatusIndicator(),
                    AppSpacing.vertical(AppSpacing.lg),
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'This Month',
                          '${stats['totalVisitsThisMonth']}',
                          'Field visits completed',
                          Icons.calendar_today,
                          AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Avg Score',
                          (stats['averageScore'] as double).toStringAsFixed(2),
                          'Out of 6.0',
                          Icons.trending_up,
                          AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vertical(AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'MRs Coached',
                          '${stats['totalMRsCoached']}',
                          'Medical reps trained',
                          Icons.people,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Reports',
                          '${widget.reports.length}',
                          'Total submissions',
                          Icons.description,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vertical(AppSpacing.xl),
                  // Monthly Visits Chart
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Visits Trend',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 1,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: AppColors.gray200,
                                    strokeWidth: 1,
                                    dashArray: [3, 3],
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(
                                          color: AppColors.gray600,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >= 0 && value.toInt() < monthlyVisits.length) {
                                        return Text(
                                          monthlyVisits[value.toInt()]['month'],
                                          style: const TextStyle(
                                            color: AppColors.gray600,
                                            fontSize: 12,
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: monthlyVisits.asMap().entries.map((entry) {
                                    return FlSpot(entry.key.toDouble(), (entry.value['visits'] as int).toDouble());
                                  }).toList(),
                                  isCurved: false,
                                  color: AppColors.primaryBlue,
                                  barWidth: 3,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 5,
                                        color: AppColors.primaryCyan,
                                        strokeWidth: 0,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // MR Performance
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MR Performance Overview',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 250,
                          child: mrPerformance.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No performance data available',
                                    style: TextStyle(color: AppColors.gray600),
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    // مساحة أفقية كافية لكل MR مع سكرول لو العدد كبير
                                    width: (mrPerformance.length * 90.0)
                                        .clamp(300.0, double.infinity),
                                    child: BarChart(
                                      BarChartData(
                                        alignment: BarChartAlignment.spaceAround,
                                        gridData: FlGridData(
                                          show: true,
                                          drawVerticalLine: false,
                                          getDrawingHorizontalLine: (value) {
                                            return FlLine(
                                              color: AppColors.gray200,
                                              strokeWidth: 1,
                                              dashArray: [3, 3],
                                            );
                                          },
                                        ),
                                        titlesData: FlTitlesData(
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 40,
                                              getTitlesWidget: (value, meta) {
                                                return Text(
                                                  value.toInt().toString(),
                                                  style: const TextStyle(
                                                    color: AppColors.gray600,
                                                    fontSize: 12,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 80,
                                              getTitlesWidget: (value, meta) {
                                                if (value.toInt() >= 0 &&
                                                    value.toInt() <
                                                        mrPerformance.length) {
                                                  final name =
                                                      mrPerformance[value.toInt()]
                                                          ['name'] as String? ??
                                                              '';
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8),
                                                    child: SizedBox(
                                                      width: 70,
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          color:
                                                              AppColors.gray600,
                                                          fontSize: 9,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return const Text('');
                                              },
                                            ),
                                          ),
                                          rightTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                          topTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                        ),
                                        borderData:
                                            FlBorderData(show: false),
                                        barGroups: mrPerformance
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          return BarChartGroupData(
                                            x: entry.key,
                                            barRods: [
                                              BarChartRodData(
                                                toY: entry.value['avgScore']
                                                    as double,
                                                color: AppColors.primaryCyan,
                                                width: 20,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                  top: Radius.circular(8),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Monthly Report
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Monthly Report',
                              style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${monthlyMRVisits.length} MR${monthlyMRVisits.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'All Medical Representatives you visited this month with visit counts and scores',
                          style: TextStyle(
                            color: AppColors.gray600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        monthlyMRVisits.isEmpty
                            ? Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.people, size: 48, color: AppColors.gray300),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No visits this month',
                                      style: TextStyle(color: AppColors.gray600),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Start coaching sessions to see your monthly report',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: monthlyMRVisits.map((mr) {
                                  final visits = mr['visits'] as List<dynamic>;
                                  final visitCount = mr['visitCount'] as int;
                                  final mrName = mr['mrName'] as String;
                                  final avgScore = mr['averageScore'] as double;
                                  // Get initials from name
                                  final initials = mrName.split(' ')
                                      .take(2)
                                      .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
                                      .join();
                                  // Score color based on value
                                  final scoreColor = avgScore >= 5.0 ? AppColors.success 
                                      : avgScore >= 4.0 ? AppColors.warning 
                                      : AppColors.error;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryBlue.withOpacity(0.08),
                                          blurRadius: 15,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        // Header with gradient
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                AppColors.primaryBlue.withOpacity(0.05),
                                                AppColors.primaryCyan.withOpacity(0.1),
                                              ],
                                            ),
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                          ),
                                          child: Row(
                                            children: [
                                              // Avatar - Show profile picture if available
                                              Builder(
                                                builder: (context) {
                                                  final mrId = mr['mrId'] as String? ?? '';
                                                  final profileUrl = _getMRProfilePictureUrl(mrId, mrName);
                                                  
                                                  return Container(
                                                    width: 50,
                                                    height: 50,
                                                    decoration: BoxDecoration(
                                                      gradient: profileUrl == null ? AppColors.primaryGradient : null,
                                                      shape: BoxShape.circle,
                                                      border: profileUrl != null ? Border.all(color: AppColors.gray200, width: 2) : null,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppColors.primaryBlue.withOpacity(0.3),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 3),
                                                        ),
                                                      ],
                                                    ),
                                                    child: profileUrl != null && profileUrl.isNotEmpty
                                                        ? ClipOval(
                                                            child: Image.network(
                                                              profileUrl,
                                                              width: 50,
                                                              height: 50,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (context, error, stackTrace) {
                                                                return Container(
                                                                  decoration: BoxDecoration(
                                                                    gradient: AppColors.primaryGradient,
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                  child: Center(
                                                                    child: Text(
                                                                      initials.isNotEmpty ? initials : 'MR',
                                                                      style: const TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 18,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              loadingBuilder: (context, child, loadingProgress) {
                                                                if (loadingProgress == null) return child;
                                                                return Container(
                                                                  decoration: BoxDecoration(
                                                                    gradient: AppColors.primaryGradient,
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                  child: Center(
                                                                    child: CircularProgressIndicator(
                                                                      value: loadingProgress.expectedTotalBytes != null
                                                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                                          : null,
                                                                      strokeWidth: 2,
                                                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          )
                                                        : Center(
                                                            child: Text(
                                                              initials.isNotEmpty ? initials : 'MR',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 18,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 10),
                                              // Name and role
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      mrName,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.gray900,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.medical_services, 
                                                            size: 11, color: AppColors.gray600),
                                                        const SizedBox(width: 3),
                                                        Flexible(
                                                          child: Text(
                                                            'Medical Rep',
                                                            style: TextStyle(
                                                              color: AppColors.gray600,
                                                              fontSize: 11,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Score badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: scoreColor.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: scoreColor.withOpacity(0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star, size: 12, color: scoreColor),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      '${avgScore.toStringAsFixed(1)}',
                                                      style: TextStyle(
                                                        color: scoreColor,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Stats row
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              // Visits count
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryBlue.withOpacity(0.05),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        '$visitCount',
                                                        style: const TextStyle(
                                                          fontSize: 24,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primaryBlue,
                                                        ),
                                                      ),
                                                      const Text(
                                                        'Coaching Visits',
                                                        style: TextStyle(
                                                          color: AppColors.gray600,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Average score
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: scoreColor.withOpacity(0.05),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        avgScore.toStringAsFixed(1),
                                                        style: TextStyle(
                                                          fontSize: 24,
                                                          fontWeight: FontWeight.bold,
                                                          color: scoreColor,
                                                        ),
                                                      ),
                                                      const Text(
                                                        'Avg Score',
                                                        style: TextStyle(
                                                          color: AppColors.gray600,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Trend Chart
                                        if (visitCount > 1) ...[
                                          Container(
                                            height: 120,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.gray200),
                                            ),
                                            child: LineChart(
                                              LineChartData(
                                                gridData: FlGridData(
                                                  show: true,
                                                  drawVerticalLine: false,
                                                  getDrawingHorizontalLine: (value) {
                                                    return FlLine(
                                                      color: AppColors.gray200,
                                                      strokeWidth: 1,
                                                      dashArray: [3, 3],
                                                    );
                                                  },
                                                ),
                                                titlesData: FlTitlesData(
                                                  leftTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: true,
                                                      reservedSize: 35,
                                                      getTitlesWidget: (value, meta) {
                                                        return Text(
                                                          value.toStringAsFixed(1),
                                                          style: const TextStyle(
                                                            color: AppColors.gray600,
                                                            fontSize: 10,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  bottomTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: true,
                                                      reservedSize: 30,
                                                      getTitlesWidget: (value, meta) {
                                                        if (value.toInt() >= 0 && value.toInt() < visits.length) {
                                                          return Padding(
                                                            padding: const EdgeInsets.only(top: 4),
                                                            child: Text(
                                                              'V${value.toInt() + 1}',
                                                              style: const TextStyle(
                                                                color: AppColors.gray600,
                                                                fontSize: 10,
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                        return const Text('');
                                                      },
                                                    ),
                                                  ),
                                                  rightTitles: const AxisTitles(
                                                    sideTitles: SideTitles(showTitles: false),
                                                  ),
                                                  topTitles: const AxisTitles(
                                                    sideTitles: SideTitles(showTitles: false),
                                                  ),
                                                ),
                                                borderData: FlBorderData(
                                                  show: true,
                                                  border: Border.all(color: AppColors.gray200),
                                                ),
                                                lineBarsData: [
                                                  LineChartBarData(
                                                    spots: visits.asMap().entries.map((entry) {
                                                      return FlSpot(
                                                        entry.key.toDouble(),
                                                        entry.value['score'] as double,
                                                      );
                                                    }).toList(),
                                                    isCurved: true,
                                                    color: AppColors.primaryCyan,
                                                    barWidth: 3,
                                                    dotData: FlDotData(
                                                      show: true,
                                                      getDotPainter: (spot, percent, barData, index) {
                                                        return FlDotCirclePainter(
                                                          radius: 4,
                                                          color: AppColors.primaryBlue,
                                                          strokeWidth: 2,
                                                          strokeColor: Colors.white,
                                                        );
                                                      },
                                                    ),
                                                    belowBarData: BarAreaData(
                                                      show: true,
                                                      color: AppColors.primaryCyan.withOpacity(0.1),
                                                    ),
                                                  ),
                                                ],
                                                minY: 0,
                                                maxY: 6,
                                                lineTouchData: LineTouchData(
                                                  touchTooltipData: LineTouchTooltipData(
                                                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                                      return touchedSpots.map((LineBarSpot touchedSpot) {
                                                        final visit = visits[touchedSpot.x.toInt()];
                                                        return LineTooltipItem(
                                                          '${DateFormat('MMM dd').format(DateTime.parse(visit['date']))}\n${touchedSpot.y.toStringAsFixed(2)}/6',
                                                          const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        );
                                                      }).toList();
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        // Visits - Compact horizontal list
                                        SizedBox(
                                          height: 80,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: visits.length,
                                            itemBuilder: (context, index) {
                                              final visit = visits[index];
                                              final vScore = visit['score'] as double;
                                              final vScoreColor = vScore >= 5.0 ? AppColors.success 
                                                  : vScore >= 4.0 ? AppColors.warning 
                                                  : AppColors.error;
                                              return Container(
                                                width: 100,
                                                margin: EdgeInsets.only(right: index < visits.length - 1 ? 10 : 0),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      vScoreColor.withOpacity(0.08),
                                                      vScoreColor.withOpacity(0.15),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: vScoreColor.withOpacity(0.3)),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    // Visit number badge
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: vScoreColor.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        'Coaching Visit ${index + 1}',
                                                        style: TextStyle(
                                                          color: vScoreColor,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    // Date
                                                    Text(
                                                      DateFormat('MMM dd').format(DateTime.parse(visit['date'])),
                                                      style: const TextStyle(
                                                        color: AppColors.gray600,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    // Score
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                                      textBaseline: TextBaseline.alphabetic,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          vScore.toStringAsFixed(1),
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                            color: vScoreColor,
                                                          ),
                                                        ),
                                                        Text(
                                                          '/6',
                                                          style: TextStyle(
                                                            color: AppColors.gray600,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Total Coaching Visits',
                                              style: TextStyle(
                                                color: AppColors.gray600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '$visitCount visit${visitCount != 1 ? 's' : ''} completed',
                                              style: const TextStyle(
                                                color: AppColors.primaryBlue,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                  AppSpacing.vertical(AppSpacing.xl),
                  // Recent Reports
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Coaching Reports',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        widget.reports.isEmpty
                            ? Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.description, size: 48, color: AppColors.gray300),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No reports submitted yet',
                                      style: TextStyle(color: AppColors.gray600),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Start a coaching session to create your first report',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: reports.take(5).map((report) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.gray200),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                report.mrName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.gray900,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                report.date,
                                                style: const TextStyle(
                                                  color: AppColors.gray600,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Score badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBlue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.star, size: 14, color: AppColors.primaryBlue),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${report.getAverageScore().toStringAsFixed(1)}/6',
                                                    style: const TextStyle(
                                                      color: AppColors.primaryBlue,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle, size: 12, color: AppColors.success),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Completed',
                                                    style: TextStyle(
                                                      color: AppColors.success,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedReport = report;
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryBlue.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.visibility, color: AppColors.primaryBlue, size: 16),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'View Details',
                                                        style: TextStyle(
                                                          color: AppColors.primaryBlue,
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Export Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradientHorizontal,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => widget.onExport(null),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.file_download, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Export Monthly Report',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bottom padding to account for BottomNav
                  const SizedBox(height: 100),
                ],
              ),
                ),
              ),
            ),
              ],
            ),
            // Bottom Navigation
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomNav(
                role: 'dm',
                activeTab: widget.activeTab,
                onTabChange: widget.onTabChange,
              ),
            ),
            // Report Modal
            if (_selectedReport != null)
              _buildReportModal(context, _selectedReport!),
          ],
        ),
      ),
    );
  }

  double _calculateAvgScore(CoachingReport report) {
    return report.getAverageScore();
  }

  Widget _buildModalSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }


  Widget _buildModalInfoItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.gray600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.gray900,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalYesNoItem(String label, String? value) {
    final isYes = value == 'Yes';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.gray600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isYes
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                color: isYes ? AppColors.success : AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalScoreItem(String label, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.gray600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 1,
            child: Text(
              value != null ? '$value/6' : 'N/A',
              style: const TextStyle(
                color: AppColors.gray900,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportModal(BuildContext context, CoachingReport report) {
    final avgScore = _calculateAvgScore(report);
    final scorePercent = (avgScore / 6.0 * 100).clamp(0, 100);
    final scoreColor = avgScore >= 5.0 ? AppColors.success 
        : avgScore >= 4.0 ? AppColors.warning 
        : AppColors.error;
    // Get initials from name
    final initials = report.mrName.split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();
    
    return Container(
      color: Colors.black54,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            maxWidth: MediaQuery.of(context).size.width * 0.95,
          ),
          child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // Modal Header - Enhanced with Score
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradientHorizontal,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar - Show profile picture if available
                          Builder(
                            builder: (context) {
                              final profileUrl = _getMRProfilePictureUrl(report.mrId, report.mrName);
                              
                              return Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: profileUrl == null ? Colors.white : null,
                                  shape: BoxShape.circle,
                                  border: profileUrl != null ? Border.all(color: Colors.white, width: 2) : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: profileUrl != null && profileUrl.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          profileUrl,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.white,
                                              child: Center(
                                                child: Text(
                                                  initials.isNotEmpty ? initials : 'MR',
                                                  style: const TextStyle(
                                                    color: AppColors.primaryBlue,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              color: Colors.white,
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                      : null,
                                                  strokeWidth: 2,
                                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          initials.isNotEmpty ? initials : 'MR',
                                          style: const TextStyle(
                                            color: AppColors.primaryBlue,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          // Name and title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Coaching Report',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  report.mrName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  report.date,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Score circle
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: scoreColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: CircularProgressIndicator(
                                    value: scorePercent / 100,
                                    strokeWidth: 4,
                                    backgroundColor: AppColors.gray200,
                                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      avgScore.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: scoreColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '/6',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Modal Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Basic Info
                        _buildModalSection(
                          'Basic Information',
                          [
                            _buildModalInfoItem('Date', report.date),
                            _buildModalInfoItem('Average Score', '${avgScore.toStringAsFixed(2)} / 6.0'),
                            _buildModalInfoItem(_getCoachRoleLabel(report.coachRole), report.dmName),
                            _buildModalInfoItem('Medical Rep', report.mrName),
                            if (report.brickName != null && report.brickName!.isNotEmpty)
                              _buildModalInfoItem('Brick Name', report.brickName!),
                            if (report.visitCount != null && report.visitCount! > 0)
                              _buildModalInfoItem('Visits Count', report.visitCount.toString()),
                            if (report.doctorsVisited != null && report.doctorsVisited!.isNotEmpty)
                              _buildModalInfoItem('Doctors Visited', report.doctorsVisited!),
                            if (report.isQuickSession == true)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.error, width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.close, color: AppColors.error, size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Quick Session (No Plan)',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Personal Attributes
                        _buildModalSection(
                          'Personal Attributes',
                          [
                            _buildModalYesNoItem('Punctuality', report.punctuality),
                            _buildModalYesNoItem('Dress Code', report.dressCode),
                            _buildModalYesNoItem('Time & Territory Management', report.timeManagement),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Performance Scores
                        _buildModalSection(
                          'Performance Scores',
                          [
                            _buildModalScoreItem('Pharmacy Feedback', report.pharmacyFeedback),
                            _buildModalScoreItem('Review Customer Profile', report.reviewProfile),
                            _buildModalScoreItem('Brand Bonding Ladder', report.brandBonding),
                            _buildModalScoreItem('SMART Objectives', report.smartObjectives),
                            _buildModalScoreItem('Opening / Rapport', report.opening),
                            _buildModalScoreItem('Patient Profile', report.patientProfile),
                            _buildModalScoreItem('Engaging Customer', report.engaging),
                            _buildModalScoreItem('Insightful Questions', report.insightfulQuestions),
                            _buildModalScoreItem('Active Listening', report.activeListening),
                            _buildModalScoreItem('Link Features', report.linkFeatures),
                            _buildModalScoreItem('Product Knowledge', report.productKnowledge),
                            _buildModalScoreItem('E-detailing', report.eDetailing),
                            _buildModalScoreItem('Answering Questions', report.answeringQuestions),
                            _buildModalScoreItem('Summarize Call', report.summarizeCall),
                            _buildModalScoreItem('Ask for Commitment', report.askCommitment),
                            _buildModalScoreItem('Bridging', report.bridging),
                            _buildModalScoreItem('Self-assessment', report.selfAssessment),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Feedback
                        _buildModalSection(
                          'Feedback',
                          [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: AppColors.success, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Strengths',
                                        style: TextStyle(
                                          color: AppColors.gray700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    report.strengths ?? 'No feedback provided',
                                    style: const TextStyle(
                                      color: AppColors.gray900,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.visible,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.warning.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.track_changes, color: AppColors.warning, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Areas of Improvement',
                                        style: TextStyle(
                                          color: AppColors.gray700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    report.improvements ?? 'No feedback provided',
                                    style: const TextStyle(
                                      color: AppColors.gray900,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.visible,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Additional Info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryCyan.withOpacity(0.3),
                            ),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: AppColors.gray700,
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Filled with Medical Representative: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: report.filledWithMR ?? 'N/A',
                                  style: TextStyle(
                                    color: report.filledWithMR == 'Yes'
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Modal Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.gray200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedReport = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.gray100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Close',
                                  style: TextStyle(
                                    color: AppColors.gray700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                try {
                                  final filePath = await ExportUtils.exportSingleReportToText(report);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('✅ Report exported successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
                                            SizedBox(height: 4),
                                            Text('📁 Location:', style: TextStyle(fontSize: 12)),
                                            Text(filePath, style: TextStyle(fontSize: 11, color: Colors.white70)),
                                          ],
                                        ),
                                        duration: const Duration(seconds: 6),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Export failed: $e')),
                                    );
                                  }
                                }
                                if (mounted) {
                                  setState(() {
                                    _selectedReport = null;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                                child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.download, color: Colors.white, size: 18),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Export',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          AppSpacing.vertical(AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.bodySmall,
          ),
          AppSpacing.vertical(AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(color: color),
          ),
          AppSpacing.vertical(AppSpacing.xs),
          Text(
            subtitle,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return AppCard(
      padding: AppSpacing.paddingXL,
      child: child,
    );
  }
}
