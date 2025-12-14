import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:fl_chart/fl_chart.dart';

class GMDashboardScreen extends StatelessWidget {
  final List<CoachingReport> allReports;
  final VoidCallback onExport;
  final String activeTab;
  final Function(String) onTabChange;

  const GMDashboardScreen({
    super.key,
    required this.allReports,
    required this.onExport,
    required this.activeTab,
    required this.onTabChange,
  });

  double _calculateAvgScore(CoachingReport report) {
    return report.getAverageScore();
  }

  List<Map<String, dynamic>> _calculateDMPerformance() {
    final dmStats = <String, Map<String, dynamic>>{};

    for (final report in allReports) {
      if (report.dmName.isEmpty) continue;
      
      if (!dmStats.containsKey(report.dmName)) {
        dmStats[report.dmName] = {
          'visits': 0,
          'scores': <double>[],
          'mrIds': <String>{},
        };
      }

      dmStats[report.dmName]!['visits'] = (dmStats[report.dmName]!['visits'] as int) + 1;
      if (report.mrId.isNotEmpty) {
        (dmStats[report.dmName]!['mrIds'] as Set<String>).add(report.mrId);
      }

      final avgScore = _calculateAvgScore(report);
      if (avgScore > 0) {
        (dmStats[report.dmName]!['scores'] as List<double>).add(avgScore);
      }
    }

    return dmStats.entries.map((entry) {
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
        'mrCount': (entry.value['mrIds'] as Set<String>).length,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _calculateScoreDistribution() {
    final distribution = {
      'excellent': 0,
      'good': 0,
      'average': 0,
      'needs': 0,
    };

    for (final report in allReports) {
      final avgScore = _calculateAvgScore(report);
      if (avgScore >= 5) {
        distribution['excellent'] = (distribution['excellent'] as int) + 1;
      } else if (avgScore >= 4) {
        distribution['good'] = (distribution['good'] as int) + 1;
      } else if (avgScore >= 3) {
        distribution['average'] = (distribution['average'] as int) + 1;
      } else if (avgScore > 0) {
        distribution['needs'] = (distribution['needs'] as int) + 1;
      }
    }

    final total = (distribution['excellent'] as int) +
        (distribution['good'] as int) +
        (distribution['average'] as int) +
        (distribution['needs'] as int);

    if (total == 0) return [];

    return [
      {
        'name': '5-6 (Excellent)',
        'value': distribution['excellent'],
        'color': AppColors.success,
      },
      {
        'name': '4-5 (Good)',
        'value': distribution['good'],
        'color': AppColors.primaryCyan,
      },
      {
        'name': '3-4 (Average)',
        'value': distribution['average'],
        'color': AppColors.warning,
      },
      {
        'name': '1-3 (Needs Improvement)',
        'value': distribution['needs'],
        'color': AppColors.error,
      },
    ];
  }

  List<Map<String, dynamic>> _calculateMonthlyTrend() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final monthlyData = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final month = months[date.month - 1];
      
      final monthReports = allReports.where((r) {
        if (r.date.isEmpty) return false;
        try {
          final reportDate = DateTime.parse(r.date);
          return reportDate.month == date.month && reportDate.year == date.year;
        } catch (e) {
          return false;
        }
      }).toList();

      final avgScores = monthReports
          .map((r) => _calculateAvgScore(r))
          .where((s) => s > 0)
          .toList();
      final avgScore = avgScores.isEmpty
          ? 0.0
          : double.parse((avgScores.reduce((a, b) => a + b) / avgScores.length).toStringAsFixed(2));

      monthlyData.add({
        'month': month,
        'visits': monthReports.length,
        'avgScore': avgScore,
      });
    }

    return monthlyData;
  }

  @override
  Widget build(BuildContext context) {
    final dmPerformance = _calculateDMPerformance();
    final scoreDistribution = _calculateScoreDistribution();
    final monthlyTrend = _calculateMonthlyTrend();

    final totalVisits = allReports.length;
    final totalDMs = allReports.map((r) => r.dmId).where((id) => id.isNotEmpty).toSet().length;
    final totalMRs = allReports.map((r) => r.mrId).where((id) => id.isNotEmpty).toSet().length;
    
    final allScores = allReports
        .map((r) => _calculateAvgScore(r))
        .where((s) => s > 0)
        .toList();
    final overallAvgScore = allScores.isEmpty
        ? '0.00'
        : (allScores.reduce((a, b) => a + b) / allScores.length).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Column(
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
                    'GM Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Organization-wide coaching analytics',
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
                          'Total Visits',
                          '$totalVisits',
                          'All DMs combined',
                          Icons.timeline,
                          AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Avg Score',
                          overallAvgScore,
                          'Organization average',
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
                          'District Mgrs',
                          '$totalDMs',
                          'Active managers',
                          Icons.people,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Medical Reps',
                          '$totalMRs',
                          'Total in system',
                          Icons.description,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // DM Performance Chart
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'District Manager Performance',
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
                                          fontSize: 11,
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
                                      if (value.toInt() >= 0 && value.toInt() < dmPerformance.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: RotatedBox(
                                            quarterTurns: 0,
                                            child: Text(
                                              dmPerformance[value.toInt()]['name'],
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
                              barGroups: dmPerformance.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: (entry.value['visits'] as int).toDouble(),
                                      color: AppColors.primaryBlue,
                                      width: 25,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                              maxY: dmPerformance.isEmpty
                                  ? 10
                                  : (dmPerformance.map((e) => e['visits'] as int).reduce((a, b) => a > b ? a : b) * 1.2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Score Distribution Pie Chart
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Score Distribution',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 250,
                          child: scoreDistribution.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No data available',
                                    style: TextStyle(color: AppColors.gray600),
                                  ),
                                )
                              : PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 60,
                                    sections: scoreDistribution.map((entry) {
                                      final total = scoreDistribution
                                          .fold<int>(0, (sum, e) => sum + (e['value'] as int));
                                      final percent = total > 0
                                          ? (entry['value'] as int) / total
                                          : 0.0;
                                      return PieChartSectionData(
                                        value: entry['value'].toDouble(),
                                        title: '${(percent * 100).toStringAsFixed(0)}%',
                                        color: entry['color'] as Color,
                                        radius: 80,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                        if (scoreDistribution.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: scoreDistribution.map((entry) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: entry['color'] as Color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry['name'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray600,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Monthly Trends
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Coaching Trends',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
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
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >= 0 && value.toInt() < monthlyTrend.length) {
                                        return Text(
                                          monthlyTrend[value.toInt()]['month'],
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
                              barGroups: monthlyTrend.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: (entry.value['visits'] as int).toDouble(),
                                      color: AppColors.primaryBlue,
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
                  // DM Details List
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'District Manager Details',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        dmPerformance.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text(
                                    'No data available',
                                    style: TextStyle(color: AppColors.gray600),
                                  ),
                                ),
                              )
                            : Column(
                                children: dmPerformance.map((dm) {
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
                                                dm['name'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.gray900,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBlue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'Active',
                                                style: TextStyle(
                                                  color: AppColors.primaryBlue,
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
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Visits',
                                                    style: TextStyle(
                                                      color: AppColors.gray600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${dm['visits']}',
                                                    style: const TextStyle(
                                                      color: AppColors.primaryBlue,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Avg Score',
                                                    style: TextStyle(
                                                      color: AppColors.gray600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${dm['avgScore']}',
                                                    style: const TextStyle(
                                                      color: AppColors.success,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'MRs Coached',
                                                    style: TextStyle(
                                                      color: AppColors.gray600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${dm['mrCount']}',
                                                    style: const TextStyle(
                                                      color: Colors.purple,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
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
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
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
                              onTap: () => onExport(),
                              borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.file_download, color: Colors.white, size: 20),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            onTabChange('reports');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: AppColors.primaryBlue,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.trending_up, color: AppColors.primaryBlue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'View Analytics',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 16,
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
              ),
            ),
            // Bottom Navigation
            BottomNav(
              role: 'gm',
              activeTab: activeTab,
              onTabChange: onTabChange,
            ),
          ],
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
