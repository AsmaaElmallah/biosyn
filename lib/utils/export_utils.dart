import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:intl/intl.dart';

class ExportUtils {
  // Export all reports to CSV
  static Future<void> exportToCSV(List<CoachingReport> reports, String filename) async {
    if (reports.isEmpty) {
      throw Exception('No reports to export');
    }

    // CSV Headers
    final headers = [
      'Date',
      'District Manager',
      'DM ID',
      'Medical Rep',
      'MR ID',
      'Punctuality',
      'Dress Code',
      'Time Management',
      'Pharmacy Feedback',
      'Review Profile',
      'Brand Bonding',
      'SMART Objectives',
      'Opening/Rapport',
      'Patient Profile',
      'Engaging Customer',
      'Insightful Questions',
      'Active Listening',
      'Link Features',
      'Product Knowledge',
      'E-detailing',
      'Answering Questions',
      'Summarize Call',
      'Ask Commitment',
      'Bridging',
      'Self Assessment',
      'Average Score',
      'Strengths',
      'Areas of Improvement',
      'Filled with MR'
    ];

    // Convert reports to CSV rows
    final rows = reports.map((report) {
      final avgScore = report.getAverageScore().toStringAsFixed(2);
      return [
        report.date,
        report.dmName,
        report.dmId,
        report.mrName,
        report.mrId,
        report.punctuality ?? '',
        report.dressCode ?? '',
        report.timeManagement ?? '',
        report.pharmacyFeedback ?? '',
        report.reviewProfile ?? '',
        report.brandBonding ?? '',
        report.smartObjectives ?? '',
        report.opening ?? '',
        report.patientProfile ?? '',
        report.engaging ?? '',
        report.insightfulQuestions ?? '',
        report.activeListening ?? '',
        report.linkFeatures ?? '',
        report.productKnowledge ?? '',
        report.eDetailing ?? '',
        report.answeringQuestions ?? '',
        report.summarizeCall ?? '',
        report.askCommitment ?? '',
        report.bridging ?? '',
        report.selfAssessment ?? '',
        avgScore,
        '"${(report.strengths ?? '').replaceAll('"', '""')}"',
        '"${(report.improvements ?? '').replaceAll('"', '""')}"',
        report.filledWithMR ?? '',
      ];
    }).toList();

    // Combine headers and rows
    final csvContent = [
      headers.join(','),
      ...rows.map((row) => row.join(','))
    ].join('\n');

    // Save to file and share
    await _saveAndShare(csvContent, filename, 'text/csv');
  }

  // Export single report to text file
  static Future<void> exportSingleReportToText(CoachingReport report) async {
    final avgScore = report.getAverageScore().toStringAsFixed(2);

    final content = '''
BIOSYN PHARMACEUTICALS
COACHING REPORT
================================

BASIC INFORMATION
-----------------
Date: ${report.date}
District Manager: ${report.dmName} (ID: ${report.dmId})
Medical Representative: ${report.mrName} (ID: ${report.mrId})
Average Score: $avgScore / 6.0

PERSONAL ATTRIBUTES
-------------------
Punctuality: ${report.punctuality ?? 'N/A'}
Dress Code: ${report.dressCode ?? 'N/A'}
Time & Territory Management: ${report.timeManagement ?? 'N/A'}

PRE-CALL PLANNING
-----------------
Pharmacy Feedback: ${report.pharmacyFeedback ?? 'N/A'}/6
Review Customer Profile/Potential/Preference: ${report.reviewProfile ?? 'N/A'}/6
Brand Bonding Ladder: ${report.brandBonding ?? 'N/A'}/6
Set SMART Call Objectives: ${report.smartObjectives ?? 'N/A'}/6

SALES CALL STEPS
----------------
Opening / Rapport: ${report.opening ?? 'N/A'}/6
Specific Patient Profile: ${report.patientProfile ?? 'N/A'}/6
Engaging the Customer: ${report.engaging ?? 'N/A'}/6
Asking Insightful Questions: ${report.insightfulQuestions ?? 'N/A'}/6
Active Listening: ${report.activeListening ?? 'N/A'}/6
Link Product Features with Customer Need: ${report.linkFeatures ?? 'N/A'}/6
Proper Product, Medical & Competitor Knowledge: ${report.productKnowledge ?? 'N/A'}/6
Proper Use of E-detailing: ${report.eDetailing ?? 'N/A'}/6
Answering Customer Questions & Concerns: ${report.answeringQuestions ?? 'N/A'}/6

CLOSING
-------
Summarize Call: ${report.summarizeCall ?? 'N/A'}/6
Ask for Specific Commitment: ${report.askCommitment ?? 'N/A'}/6
Bridging to Next Product(s): ${report.bridging ?? 'N/A'}/6

POST CALL ANALYSIS
------------------
Self-assessment & Updating Customer Profile: ${report.selfAssessment ?? 'N/A'}/6

FEEDBACK
--------
Strengths Exhibited:
${report.strengths ?? 'No feedback provided'}

Areas of Improvement:
${report.improvements ?? 'No feedback provided'}

Was this report filled with the Medical Representative? ${report.filledWithMR ?? 'N/A'}

================================
Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}
Biosyn Coaching App v1.0.0
''';

    final filename = 'coaching_report_${report.mrName.replaceAll(' ', '_')}_${report.date}.txt';
    await _saveAndShare(content, filename, 'text/plain');
  }

  // Export monthly report
  static Future<void> exportMonthlyReport(List<CoachingReport> reports, String? dmName) async {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);

    // Filter for current month
    final monthlyReports = reports.where((r) {
      if (r.date.isEmpty) return false;
      try {
        final reportDate = DateTime.parse(r.date);
        return reportDate.month == now.month && reportDate.year == now.year;
      } catch (e) {
        return false;
      }
    }).toList();

    if (monthlyReports.isEmpty) {
      throw Exception('No reports found for this month');
    }

    // Calculate statistics
    final totalVisits = monthlyReports.length;
    
    final allScores = <double>[];
    for (final report in monthlyReports) {
      final score = report.getAverageScore();
      if (score > 0) {
        allScores.add(score);
      }
    }

    final avgScore = allScores.isEmpty
        ? '0.00'
        : (allScores.reduce((a, b) => a + b) / allScores.length).toStringAsFixed(2);

    final uniqueMRs = monthlyReports.map((r) => r.mrId).toSet().length;

    final content = '''
BIOSYN PHARMACEUTICALS
MONTHLY COACHING REPORT
$monthName
================================

SUMMARY
-------
${dmName != null ? 'District Manager: $dmName' : 'All District Managers'}
Total Field Visits: $totalVisits
Average Score: $avgScore / 6.0
Medical Reps Coached: $uniqueMRs

DETAILED VISITS
---------------
${monthlyReports.asMap().entries.map((entry) {
      final idx = entry.key;
      final r = entry.value;
      final strengths = (r.strengths ?? '').length > 100
          ? '${(r.strengths ?? '').substring(0, 100)}...'
          : (r.strengths ?? '');
      final improvements = (r.improvements ?? '').length > 100
          ? '${(r.improvements ?? '').substring(0, 100)}...'
          : (r.improvements ?? '');
      
      return '''
${idx + 1}. ${r.date} - ${r.mrName} (${r.mrId})
   DM: ${r.dmName}
   Scores: Punctuality: ${r.punctuality ?? 'N/A'} | Dress: ${r.dressCode ?? 'N/A'} | Time Mgmt: ${r.timeManagement ?? 'N/A'}
   Key Strengths: $strengths
   Areas to Improve: $improvements
''';
    }).join('\n')}

================================
Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}
Biosyn Coaching App v1.0.0
''';

    final filename = 'monthly_report_${monthName.replaceAll(' ', '_')}.txt';
    await _saveAndShare(content, filename, 'text/plain');
  }

  // Export all reports to readable text format (better for mobile viewing)
  static Future<void> exportAllReportsToText(List<CoachingReport> reports) async {
    if (reports.isEmpty) {
      throw Exception('No reports to export');
    }

    final now = DateTime.now();
    final reportDate = DateFormat('yyyy-MM-dd').format(now);

    // Group reports by DM
    final reportsByDM = <String, List<CoachingReport>>{};
    for (final report in reports) {
      final dmKey = report.dmName.isNotEmpty ? report.dmName : 'Unknown DM';
      reportsByDM.putIfAbsent(dmKey, () => []);
      reportsByDM[dmKey]!.add(report);
    }

    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════════');
    buffer.writeln('      BIOSYN PHARMACEUTICALS');
    buffer.writeln('      ALL COACHING REPORTS');
    buffer.writeln('═══════════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('📊 Total Reports: ${reports.length}');
    buffer.writeln('👥 District Managers: ${reportsByDM.length}');
    buffer.writeln('📅 Export Date: $reportDate');
    buffer.writeln('');

    for (final entry in reportsByDM.entries) {
      final dmName = entry.key;
      final dmReports = entry.value;

      buffer.writeln('───────────────────────────────────────────');
      buffer.writeln('👤 District Manager: $dmName');
      buffer.writeln('   Reports: ${dmReports.length}');
      buffer.writeln('───────────────────────────────────────────');
      buffer.writeln('');

      for (int i = 0; i < dmReports.length; i++) {
        final report = dmReports[i];
        final avgScore = report.getAverageScore().toStringAsFixed(2);

        buffer.writeln('  ${i + 1}. ${report.mrName}');
        buffer.writeln('     📅 Date: ${report.date}');
        buffer.writeln('     🆔 MR ID: ${report.mrId}');
        buffer.writeln('     ⭐ Score: $avgScore / 6.0');
        buffer.writeln('');
        buffer.writeln('     Personal Attributes:');
        buffer.writeln('       • Punctuality: ${report.punctuality ?? "N/A"}');
        buffer.writeln('       • Dress Code: ${report.dressCode ?? "N/A"}');
        buffer.writeln('       • Time Management: ${report.timeManagement ?? "N/A"}');
        buffer.writeln('');
        buffer.writeln('     Key Scores:');
        buffer.writeln('       • Opening: ${report.opening ?? "N/A"}/6');
        buffer.writeln('       • Product Knowledge: ${report.productKnowledge ?? "N/A"}/6');
        buffer.writeln('       • E-Detailing: ${report.eDetailing ?? "N/A"}/6');
        buffer.writeln('       • Ask Commitment: ${report.askCommitment ?? "N/A"}/6');
        buffer.writeln('');

        if (report.strengths != null && report.strengths!.isNotEmpty) {
          buffer.writeln('     ✅ Strengths:');
          buffer.writeln('       ${report.strengths}');
          buffer.writeln('');
        }

        if (report.improvements != null && report.improvements!.isNotEmpty) {
          buffer.writeln('     🎯 Areas to Improve:');
          buffer.writeln('       ${report.improvements}');
          buffer.writeln('');
        }

        buffer.writeln('     Filled with MR: ${report.filledWithMR ?? "N/A"}');
        buffer.writeln('');
        buffer.writeln('  - - - - - - - - - - - - - - - - - - - - -');
        buffer.writeln('');
      }
    }

    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════════');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}');
    buffer.writeln('Biosyn Coaching App v1.0.0');
    buffer.writeln('═══════════════════════════════════════════');

    final filename = 'all_coaching_reports_$reportDate.txt';
    await _saveAndShare(buffer.toString(), filename, 'text/plain');
  }

  // Helper method to save file and share
  static Future<void> _saveAndShare(String content, String filename, String mimeType) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(content);
      
      final xFile = XFile(file.path, mimeType: mimeType);
      await Share.shareXFiles([xFile], text: 'Coaching Report Export');
    } catch (e) {
      throw Exception('Failed to export file: $e');
    }
  }
}

