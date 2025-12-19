import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/widgets/bottom_nav.dart';
import 'package:biosyn_report_flutter/widgets/app_header.dart';
import 'package:biosyn_report_flutter/widgets/connectivity_indicator.dart';
import 'package:biosyn_report_flutter/widgets/sync_status_indicator.dart';
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

  String _getRoleLabel(String? role) {
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
        return 'Coach';
    }
  }

  /// Check if coach has any quick sessions
  bool _hasQuickSessionsForCoach(String coachName) {
    // Extract clean name (remove role suffix if exists)
    String cleanName = coachName;
    if (cleanName.contains(' (')) {
      cleanName = cleanName.substring(0, cleanName.indexOf(' ('));
    }
    
    return allReports.any((r) {
      final reportCoachName = r.coachRole != null && r.coachRole!.isNotEmpty
          ? '${r.dmName} (${r.coachRole!.toUpperCase()})'
          : r.dmName;
      String reportCleanName = reportCoachName;
      if (reportCleanName.contains(' (')) {
        reportCleanName = reportCleanName.substring(0, reportCleanName.indexOf(' ('));
      }
      return reportCleanName == cleanName && r.isQuickSession == true && r.mrId.isNotEmpty;
    });
  }

  double _calculateAvgScore(CoachingReport report) {
    return report.getAverageScore();
  }

  List<Map<String, dynamic>> _calculateDMPerformance() {
    final coachStats = <String, Map<String, dynamic>>{};

    // Filter: Only include reports with MRs (mrId is not empty)
    // This excludes reports where PM/MSL coached a DM (typeOfVisit = 'DM')
    final mrReports = allReports.where((r) => r.mrId.isNotEmpty).toList();

    for (final report in mrReports) {
      // Use coach name based on coachRole, fallback to dmName
      final coachName = report.coachRole != null && report.coachRole!.isNotEmpty
          ? '${report.dmName} (${report.coachRole!.toUpperCase()})'
          : report.dmName;
      
      if (coachName.isEmpty) continue;
      
      if (!coachStats.containsKey(coachName)) {
        coachStats[coachName] = {
          'visits': 0,
          'scores': <double>[],
          'mrIds': <String>{},
          'role': report.coachRole ?? 'dm',
        };
      }

      coachStats[coachName]!['visits'] = (coachStats[coachName]!['visits'] as int) + 1;
      // mrId is guaranteed to be non-empty here due to filter above
      (coachStats[coachName]!['mrIds'] as Set<String>).add(report.mrId);

      final avgScore = _calculateAvgScore(report);
      if (avgScore > 0) {
        (coachStats[coachName]!['scores'] as List<double>).add(avgScore);
      }
    }

    return coachStats.entries.map((entry) {
      final scores = entry.value['scores'] as List<double>;
      final avgScore = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;
      
      // Extract name without role suffix FIRST (e.g., "Ahmed (MSL)" -> "Ahmed")
      String cleanName = entry.key;
      if (cleanName.contains(' (')) {
        cleanName = cleanName.substring(0, cleanName.indexOf(' ('));
      }
      
      // Skip if name is a role name (should not happen, but safety check)
      final roleNames = ['district manager', 'field trainer', 'product manager', 'medical science liaison', 'dm', 'ft', 'pm', 'msl'];
      if (roleNames.contains(cleanName.toLowerCase())) {
        // Skip this entry - it's not a real person name
        return null;
      }
      
      // Create shorter name for display from clean name
      String shortName;
      final nameParts = cleanName.split(' ').where((part) => part.isNotEmpty).toList();
      
      if (nameParts.length >= 2) {
        // Take first name and first letter of second name
        // Example: "Ahmed Sabry" -> "Ahmed S."
        shortName = '${nameParts[0]} ${nameParts[1][0].toUpperCase()}.';
      } else if (cleanName.length > 12) {
        // If name is too long, truncate it
        shortName = '${cleanName.substring(0, 12)}...';
      } else {
        shortName = cleanName;
      }
      
      return {
        'name': shortName,
        'fullName': cleanName, // Name without role suffix
        'visits': entry.value['visits'],
        'avgScore': double.parse(avgScore.toStringAsFixed(2)),
        'mrCount': (entry.value['mrIds'] as Set<String>).length,
        'role': entry.value['role'],
      };
    }).whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _calculateScoreDistribution() {
    final distribution = {
      'excellent': 0,
      'good': 0,
      'average': 0,
      'needs': 0,
    };

    // Filter: Only include reports with MRs (mrId is not empty)
    final mrReports = allReports.where((r) => r.mrId.isNotEmpty).toList();

    for (final report in mrReports) {
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

    // Filter: Only include reports with MRs (mrId is not empty)
    final mrReports = allReports.where((r) => r.mrId.isNotEmpty).toList();

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final month = months[date.month - 1];
      
      final monthReports = mrReports.where((r) {
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

    // Filter: Only include reports with MRs (mrId is not empty)
    final mrReports = allReports.where((r) => r.mrId.isNotEmpty).toList();
    
    final totalVisits = mrReports.length;
    final totalDMs = mrReports.map((r) => r.dmId).where((id) => id.isNotEmpty).toSet().length;
    final totalMRs = mrReports.map((r) => r.mrId).where((id) => id.isNotEmpty).toSet().length;
    
    final allScores = mrReports
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
            // Connectivity Indicator
            const ConnectivityIndicator(),
            // Header
            const AppHeader(
              title: 'GM Dashboard',
              subtitle: 'Organization-wide coaching analytics',
            ),
            // Content
            Expanded(
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
                          'Total Visits',
                          '$totalVisits',
                          'All Coaches combined',
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
                          'Coaches',
                          '$totalDMs',
                          'DM/FT/PM/MSL',
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
                          'Coach Performance (DM/FT/PM/MSL)',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Horizontal scrollable chart container
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: dmPerformance.length > 5 
                                ? (dmPerformance.length * 80.0).clamp(400.0, double.infinity)
                                : MediaQuery.of(context).size.width - 48,
                            height: 300,
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
                                      reservedSize: 100, // Increased for rotated text
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() >= 0 && value.toInt() < dmPerformance.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: RotatedBox(
                                              quarterTurns: 1, // Rotate 45 degrees (90 degrees)
                                              child: Text(
                                                dmPerformance[value.toInt()]['name'] as String,
                                                style: const TextStyle(
                                                  color: AppColors.gray600,
                                                  fontSize: 9,
                                                ),
                                                maxLines: 1,
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
                          'Coach Details (DM/FT/PM/MSL)',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        dmPerformance.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: AppColors.gray100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.people_outline, size: 32, color: AppColors.gray400),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No data available',
                                        style: TextStyle(color: AppColors.gray600, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Column(
                                children: dmPerformance.map((dm) {
                                  final avgScore = dm['avgScore'] as double;
                                  final scoreColor = avgScore >= 5 
                                      ? AppColors.success 
                                      : avgScore >= 3 
                                          ? AppColors.warning 
                                          : AppColors.error;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.gray200),
                                    ),
                                    child: Column(
                                      children: [
                                        // Header with Avatar
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              // Avatar
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  gradient: AppColors.primaryGradient,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    ((dm['fullName'] ?? dm['name']) as String).split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            dm['fullName'] ?? dm['name'],
                                                            style: const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.gray900,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                            maxLines: 1,
                                                          ),
                                                        ),
                                                        // Quick Session indicator (if any reports are quick sessions)
                                                        if (_hasQuickSessionsForCoach(dm['fullName'] ?? dm['name']))
                                                          Container(
                                                            margin: const EdgeInsets.only(left: 8),
                                                            padding: const EdgeInsets.all(4),
                                                            decoration: BoxDecoration(
                                                              color: AppColors.error.withOpacity(0.1),
                                                              shape: BoxShape.circle,
                                                              border: Border.all(color: AppColors.error, width: 1.5),
                                                            ),
                                                            child: const Icon(
                                                              Icons.close,
                                                              color: AppColors.error,
                                                              size: 12,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _getRoleLabel(dm['role'] as String? ?? 'dm'),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.gray400,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Score Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: scoreColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star, color: scoreColor, size: 14),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${dm['avgScore']}',
                                                      style: TextStyle(
                                                        color: scoreColor,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Stats Row
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppColors.gray50,
                                            borderRadius: const BorderRadius.only(
                                              bottomLeft: Radius.circular(16),
                                              bottomRight: Radius.circular(16),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: _buildDMStatItem('Visits', '${dm['visits']}', AppColors.primaryBlue),
                                              ),
                                              Container(width: 1, height: 32, color: AppColors.gray200),
                                              Expanded(
                                                child: _buildDMStatItem('MRs', '${dm['mrCount']}', Colors.purple),
                                              ),
                                              Container(width: 1, height: 32, color: AppColors.gray200),
                                              Expanded(
                                                child: _buildDMStatItem('Score', '${dm['avgScore']}/6', scoreColor),
                                              ),
                                            ],
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
                  // Action Buttons
                  Column(
                    children: [
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
                                        Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Export',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
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
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  onTabChange('reports');
                                },
                                borderRadius: BorderRadius.circular(12),
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
                                      Icon(Icons.analytics_outlined, color: AppColors.primaryBlue, size: 20),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Reports',
                                          style: TextStyle(
                                            color: AppColors.primaryBlue,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
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
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            onTabChange('plans');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: AppColors.primaryCyan,
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
                                Icon(Icons.calendar_month_outlined, color: AppColors.primaryCyan, size: 20),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'View Plans',
                                    style: TextStyle(
                                      color: AppColors.primaryCyan,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Bottom padding for navigation
                  const SizedBox(height: 20),
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

  Widget _buildDMStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.gray600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
