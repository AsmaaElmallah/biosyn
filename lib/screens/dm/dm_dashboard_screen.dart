import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/utils/export_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DMDashboardScreen extends StatefulWidget {
  final List<CoachingReport> reports;
  final Function(String?) onExport;
  final String activeTab;
  final Function(String) onTabChange;

  const DMDashboardScreen({
    super.key,
    required this.reports,
    required this.onExport,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  State<DMDashboardScreen> createState() => _DMDashboardScreenState();
}

class _DMDashboardScreenState extends State<DMDashboardScreen> {
  CoachingReport? _selectedReport;

  Map<String, dynamic> _calculateStats() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final thisMonthReports = widget.reports.where((r) {
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

  List<Map<String, dynamic>> _calculateMonthlyVisits() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final monthlyData = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final month = months[date.month - 1];
      
      final visitsCount = widget.reports.where((r) {
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

  List<Map<String, dynamic>> _calculateMRPerformance() {
    final mrStats = <String, Map<String, dynamic>>{};

    for (final report in widget.reports) {
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

  List<Map<String, dynamic>> _calculateMonthlyMRVisits() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final thisMonthReports = widget.reports.where((r) {
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
    final stats = _calculateStats();
    final monthlyVisits = _calculateMonthlyVisits();
    final mrPerformance = _calculateMRPerformance();
    final monthlyMRVisits = _calculateMonthlyMRVisits();

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Column(
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your coaching performance overview',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                          'Reports',
                          '${widget.reports.length}',
                          'Total submissions',
                          Icons.description,
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
                          child: BarChart(
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
                                              mrPerformance[value.toInt()]['name'],
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
                                      toY: entry.value['avgScore'] as double,
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
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.primaryCyan, width: 2),
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.primaryCyan.withOpacity(0.1),
                                          AppColors.primaryBlue.withOpacity(0.05),
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    mr['mrName'],
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.gray900,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'ID: ${mr['mrId']}',
                                                    style: const TextStyle(
                                                      color: AppColors.gray600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                const Text(
                                                  'Visits',
                                                  style: TextStyle(
                                                    color: AppColors.gray600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  '${mr['visitCount']}',
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primaryBlue,
                                                  ),
                                                ),
                                                Text(
                                                  'Avg: ${mr['averageScore']}/6',
                                                  style: const TextStyle(
                                                    color: AppColors.gray600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final availableWidth = constraints.maxWidth;
                                            int crossAxisCount;
                                            if (visitCount == 1) {
                                              crossAxisCount = 1;
                                            } else if (visitCount == 2) {
                                              crossAxisCount = 2;
                                            } else {
                                              // Calculate based on available width
                                              final itemWidth = 100.0; // Minimum width per item
                                              crossAxisCount = (availableWidth / itemWidth).floor().clamp(1, 3);
                                            }
                                            
                                            return GridView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: crossAxisCount,
                                                crossAxisSpacing: 8,
                                                mainAxisSpacing: 8,
                                                childAspectRatio: 1.2,
                                              ),
                                              itemCount: visits.length,
                                              itemBuilder: (context, index) {
                                                final visit = visits[index];
                                                return Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AppColors.gray200),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          'Visit ${index + 1}',
                                                          style: const TextStyle(
                                                            color: AppColors.gray600,
                                                            fontSize: 10,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Flexible(
                                                        child: Text(
                                                          DateFormat('MMM dd').format(DateTime.parse(visit['date'])),
                                                          style: const TextStyle(
                                                            color: AppColors.gray600,
                                                            fontSize: 10,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                                        textBaseline: TextBaseline.alphabetic,
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              visit['score'].toString(),
                                                              style: const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight: FontWeight.bold,
                                                                color: AppColors.primaryBlue,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          const Text(
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
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Total Visits',
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
                  const SizedBox(height: 24),
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
                                children: widget.reports.take(5).map((report) {
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
                                            Text(
                                              'ID: ${report.mrId}',
                                              style: const TextStyle(
                                                color: AppColors.gray600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'Completed',
                                                style: TextStyle(
                                                  color: AppColors.success,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
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
                ],
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
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.gray600,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.gray900,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.gray600,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value != null ? '$value/6' : 'N/A',
            style: const TextStyle(
              color: AppColors.gray900,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportModal(BuildContext context, CoachingReport report) {
    final avgScore = _calculateAvgScore(report);
    
    return Container(
      color: Colors.black54,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            maxWidth: MediaQuery.of(context).size.width * 0.95,
          ),
          child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // Modal Header
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradientHorizontal,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Coaching Report Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.mrName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                // Modal Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Basic Info
                        _buildModalSection(
                          'Basic Information',
                          [
                            _buildModalInfoItem('Date', report.date),
                            _buildModalInfoItem('Average Score', '${avgScore.toStringAsFixed(2)} / 6.0'),
                            _buildModalInfoItem('District Manager', report.dmName),
                            _buildModalInfoItem('Medical Rep ID', report.mrId),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Export Report',
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
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.gray600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.gray600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
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
