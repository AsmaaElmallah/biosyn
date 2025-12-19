import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/widgets/sync_status_indicator.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:biosyn_report_flutter/utils/export_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class PMMSLDashboardScreen extends StatefulWidget {
  final List<CoachingReport> reports;
  final Function(String?) onExport;
  final String activeTab;
  final Function(String) onTabChange;
  final Future<void> Function()? onRefresh;
  final String? coachId;
  final String coachRole; // 'pm' or 'msl'

  const PMMSLDashboardScreen({
    super.key,
    required this.reports,
    required this.onExport,
    required this.activeTab,
    required this.onTabChange,
    this.onRefresh,
    this.coachId,
    required this.coachRole,
  });

  @override
  State<PMMSLDashboardScreen> createState() => _PMMSLDashboardScreenState();
}

class _PMMSLDashboardScreenState extends State<PMMSLDashboardScreen> {
  StreamSubscription<List<CoachingReport>>? _reportsSubscription;
  List<CoachingReport> _currentReports = [];
  CoachingReport? _selectedReport;

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
    final uniqueDMs = thisMonthReports.map((r) => r.dmId).toSet().length;

    return {
      'totalVisitsThisMonth': thisMonthReports.length,
      'averageScore': avgScore,
      'totalMRsCoached': uniqueMRs,
      'totalDMsCoached': uniqueDMs,
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
      if (report.mrId.isEmpty || report.mrName.isEmpty) continue;
      
      final key = report.mrId;
      if (!mrStats.containsKey(key)) {
        mrStats[key] = {
          'mrId': report.mrId,
          'mrName': report.mrName,
          'visitCount': 0,
          'totalScore': 0.0,
          'reports': <CoachingReport>[],
        };
      }
      
      mrStats[key]!['visitCount'] = (mrStats[key]!['visitCount'] as int) + 1;
      mrStats[key]!['reports'].add(report);
    }

    return mrStats.values.map((stats) {
      final reports = stats['reports'] as List<CoachingReport>;
      final scores = reports.map((r) => r.getAverageScore()).where((s) => s > 0).toList();
      final avgScore = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;

      return {
        'mrId': stats['mrId'],
        'mrName': stats['mrName'],
        'visitCount': stats['visitCount'],
        'averageScore': avgScore,
      };
    }).toList()
      ..sort((a, b) {
        final visitDiff = (b['visitCount'] as int) - (a['visitCount'] as int);
        if (visitDiff != 0) return visitDiff;
        return (b['averageScore'] as double).compareTo(a['averageScore'] as double);
      });
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
  void initState() {
    super.initState();
    _currentReports = List.from(widget.reports);
    _startRealtimeUpdates();
  }

  void _startRealtimeUpdates() {
    if (widget.coachId != null && SupabaseService.isInitialized) {
      _reportsSubscription = SupabaseService.watchReports(widget.coachId!, coachRole: widget.coachRole).listen(
        (reports) {
          if (mounted) {
            setState(() {
              _currentReports = reports;
            });
            if (widget.onRefresh != null) {
              widget.onRefresh!();
            }
          }
        },
        onError: (error) {
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
    _reportsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                // Header
                AppHeader(
                  title: 'Dashboard',
                  subtitle: widget.coachRole == 'pm' 
                      ? 'Product Manager performance overview'
                      : 'Medical Science Liaison performance overview',
                ),
                // Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: widget.onRefresh ?? () async {},
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sync Status Indicator
                          const SyncStatusIndicator(),
                          const SizedBox(height: 16),
                          // Stats Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'This Month',
                                  '${stats['totalVisitsThisMonth']}',
                                  'Coaching sessions',
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
                          const SizedBox(height: 12),
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
                                  'DMs Coached',
                                  '${stats['totalDMsCoached']}',
                                  'District managers',
                                  Icons.business,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
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
                          // MR Performance Overview
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
                                            'No MR performance data available',
                                            style: TextStyle(color: AppColors.gray600),
                                          ),
                                        )
                                      : BarChart(
                                          BarChartData(
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
                                                  reservedSize: 70,
                                                  getTitlesWidget: (value, meta) {
                                                    if (value.toInt() >= 0 && value.toInt() < mrPerformance.length) {
                                                      return Padding(
                                                        padding: const EdgeInsets.only(top: 8),
                                                        child: RotatedBox(
                                                          quarterTurns: 0,
                                                          child: Text(
                                                            mrPerformance[value.toInt()]['mrName'] as String,
                                                            style: const TextStyle(
                                                              color: AppColors.gray600,
                                                              fontSize: 10,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                            textAlign: TextAlign.center,
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
                                            borderData: FlBorderData(show: false),
                                            barGroups: mrPerformance.asMap().entries.map((entry) {
                                              return BarChartGroupData(
                                                x: entry.key,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: entry.value['averageScore'] as double,
                                                    color: AppColors.primaryCyan,
                                                    width: 20,
                                                    borderRadius: const BorderRadius.vertical(
                                                      top: Radius.circular(8),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
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
                                                      // Avatar with initials
                                                      Container(
                                                        width: 50,
                                                        height: 50,
                                                        decoration: BoxDecoration(
                                                          gradient: AppColors.primaryGradient,
                                                          shape: BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: AppColors.primaryBlue.withOpacity(0.3),
                                                              blurRadius: 8,
                                                              offset: const Offset(0, 3),
                                                            ),
                                                          ],
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
                                                                'Visits',
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
                                                                  final dateStr = visits[value.toInt()]['date'] as String;
                                                                  try {
                                                                    final date = DateTime.parse(dateStr);
                                                                    return Text(
                                                                      DateFormat('MMM d').format(date),
                                                                      style: const TextStyle(
                                                                        color: AppColors.gray600,
                                                                        fontSize: 9,
                                                                      ),
                                                                    );
                                                                  } catch (e) {
                                                                    return const Text('');
                                                                  }
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
                                                            spots: visits.asMap().entries.map((entry) {
                                                              return FlSpot(
                                                                entry.key.toDouble(),
                                                                entry.value['score'] as double,
                                                              );
                                                            }).toList(),
                                                            isCurved: true,
                                                            color: AppColors.primaryCyan,
                                                            barWidth: 2,
                                                            dotData: FlDotData(show: true),
                                                            belowBarData: BarAreaData(
                                                              show: true,
                                                              color: AppColors.primaryCyan.withOpacity(0.1),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                ],
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Recent Reports
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recent Reports',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                reports.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32),
                                          child: Text(
                                            'No reports available',
                                            style: TextStyle(color: AppColors.gray600),
                                          ),
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
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 16,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      report.date,
                                                      style: const TextStyle(
                                                        color: AppColors.gray600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(Icons.star, color: AppColors.primaryBlue, size: 16),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '${report.getAverageScore().toStringAsFixed(1)}/6',
                                                          style: const TextStyle(
                                                            color: AppColors.primaryBlue,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
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
                                                InkWell(
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
                // Bottom Navigation
                BottomNav(
                  role: widget.coachRole,
                  activeTab: widget.activeTab,
                  onTabChange: widget.onTabChange,
                ),
              ],
            ),
            // Report Modal
            if (_selectedReport != null)
              _buildReportModal(context, _selectedReport!),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.gray600,
            ),
          ),
        ],
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
    
    // Check if this is a PM/MSL report (has PM/MSL specific fields)
    final isPMMSLReport = report.visitedAccountsNames != null || report.generalFeedback != null ||
                         report.dmFeedbackComments != null || report.mrFeedbackComments != null ||
                         report.customerAwareness != null || report.medicalProductKnowledgeDM != null;
    
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
                            // Avatar
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
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
                            ),
                            const SizedBox(width: 14),
                            // Name and title
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.coachRole.toUpperCase()} Coaching Report',
                                    style: const TextStyle(
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
                              if (report.dmName.isNotEmpty)
                                _buildModalInfoItem('District Manager', report.dmName),
                              _buildModalInfoItem('Medical Rep', report.mrName),
                              if (report.brickName != null && report.brickName!.isNotEmpty)
                                _buildModalInfoItem('Brick Name', report.brickName!),
                              if (report.locationName != null && report.locationName!.isNotEmpty)
                                _buildModalInfoItem('Location', report.locationName!),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // PM/MSL Specific Fields or DM/FT Fields
                          if (isPMMSLReport) ...[
                            // Visit Details
                            if (report.visitedAccountsNames != null && report.visitedAccountsNames!.isNotEmpty)
                              _buildModalSection(
                                'Visit Details',
                                [
                                  _buildModalInfoItem('Visited Accounts', report.visitedAccountsNames!),
                                  if (report.doctorsVisited != null && report.doctorsVisited!.isNotEmpty)
                                    _buildModalInfoItem('Doctors Visited', report.doctorsVisited!),
                                ],
                              ),
                            const SizedBox(height: 24),
                            // DM Feedback
                            if (report.dmFeedbackComments != null || report.customerAwareness != null || report.medicalProductKnowledgeDM != null)
                              _buildModalSection(
                                'DM Feedback',
                                [
                                  if (report.customerAwareness != null)
                                    _buildModalInfoItem('Customer Awareness', report.customerAwareness!),
                                  if (report.medicalProductKnowledgeDM != null)
                                    _buildModalInfoItem('Medical & Product Knowledge', report.medicalProductKnowledgeDM!),
                                  if (report.dmFeedbackComments != null && report.dmFeedbackComments!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.gray50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'DM Feedback Comments',
                                            style: TextStyle(
                                              color: AppColors.gray600,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            report.dmFeedbackComments!,
                                            style: const TextStyle(
                                              color: AppColors.gray900,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 24),
                            // MR Feedback
                            if (report.punctuality != null || report.dressCode != null || report.pharmacyFeedback != null || report.mrFeedbackComments != null)
                              _buildModalSection(
                                'MR Feedback',
                                [
                                  if (report.punctuality != null)
                                    _buildModalYesNoItem('Punctuality', report.punctuality),
                                  if (report.dressCode != null)
                                    _buildModalYesNoItem('Dress Code', report.dressCode),
                                  if (report.pharmacyFeedback != null)
                                    _buildModalScoreItem('Pharmacy Feedback', report.pharmacyFeedback),
                                  if (report.reviewProfile != null)
                                    _buildModalScoreItem('Review Customer Profile', report.reviewProfile),
                                  if (report.mrFeedbackComments != null && report.mrFeedbackComments!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.gray50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'MR Feedback Comments',
                                            style: TextStyle(
                                              color: AppColors.gray600,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            report.mrFeedbackComments!,
                                            style: const TextStyle(
                                              color: AppColors.gray900,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 24),
                            // General Feedback
                            if (report.generalFeedback != null && report.generalFeedback!.isNotEmpty)
                              _buildModalSection(
                                'General Feedback',
                                [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryCyan.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.primaryCyan.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      report.generalFeedback!,
                                      style: const TextStyle(
                                        color: AppColors.gray900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ] else ...[
                            // DM/FT Fields
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
                                    await ExportUtils.exportSingleReportToText(report);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Report exported successfully!')),
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

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

