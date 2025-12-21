import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';

class ExportUtils {
  // Export single report to Excel
  static Future<void> exportSingleReportToText(CoachingReport report) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['Coaching Report'];
    
    // Determine report type
    final isPMMSL = report.coachRole == 'pm' || report.coachRole == 'msl';
    final isDMReport = isPMMSL && (report.customerAwareness != null || report.medicalProductKnowledgeDM != null);
    
    int row = 0;
    
    // Helper function to set cell value
    void setCell(int col, int r, String value) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: r));
      cell.value = value;
    }
    
    // Header
    setCell(0, row, 'BIOSYN PHARMACEUTICALS');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    row++;
    setCell(0, row, 'COACHING REPORT');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    row += 2;
    
    // Basic Information
    setCell(0, row, 'BASIC INFORMATION');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    row++;
    
    setCell(0, row, 'Date:');
    setCell(1, row, report.date);
    row++;
    
    setCell(0, row, 'Coach:');
    setCell(1, row, '${report.dmName}${report.coachRole != null ? ' (${report.coachRole!.toUpperCase()})' : ''}');
    row++;
    
    setCell(0, row, 'Coached Person:');
    final coachedPersonRole = isDMReport ? 'DM' : 'MR';
    setCell(1, row, '${report.mrName} ($coachedPersonRole)');
    row++;
    
    final avgScore = isDMReport ? report.getDMScore() : report.getAverageScore();
    setCell(0, row, 'Average Score:');
    setCell(1, row, '${avgScore.toStringAsFixed(2)} / 6.0');
    row += 2;
    
    // PM/MSL Specific Information
    if (isPMMSL) {
      setCell(0, row, 'PM/MSL SPECIFIC INFORMATION');
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                  CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      row++;
      
      if (report.areaBrickName != null) {
        setCell(0, row, 'Area & Brick Name:');
        setCell(1, row, report.areaBrickName!);
        row++;
      }
      
      if (report.typeOfVisit != null) {
        setCell(0, row, 'Type of Visit:');
        setCell(1, row, report.typeOfVisit!);
        row++;
      }
      
      if (report.generalFeedback != null && report.generalFeedback!.isNotEmpty) {
        setCell(0, row, 'General Feedback:');
        setCell(1, row, report.generalFeedback!);
        row++;
      }
      row++;
    }
    
    // DM Feedback (for PM/MSL DM reports)
    if (isDMReport) {
      setCell(0, row, 'DM FEEDBACK');
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                  CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      row++;
      
      if (report.teamwork != null) {
        setCell(0, row, 'Teamwork and Cooperation:');
        setCell(1, row, report.teamwork!);
        row++;
      }
      
      if (report.customerAwareness != null) {
        setCell(0, row, 'Customer Awareness:');
        setCell(1, row, report.customerAwareness!);
        row++;
      }
      
      if (report.medicalProductKnowledgeDM != null) {
        setCell(0, row, 'Medical & Product Knowledge:');
        setCell(1, row, report.medicalProductKnowledgeDM!);
        row++;
      }
      
      if (report.dmFeedbackComments != null && report.dmFeedbackComments!.isNotEmpty) {
        setCell(0, row, 'DM Feedback Comments:');
        setCell(1, row, report.dmFeedbackComments!);
        row++;
      }
      row++;
    }
    
    // MR Feedback (for PM/MSL MR reports or DM/FT reports)
    if (!isDMReport) {
      if (isPMMSL) {
        setCell(0, row, 'MR FEEDBACK');
        sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                    CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
        row++;
      } else {
        setCell(0, row, 'PERSONAL ATTRIBUTES');
        sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                    CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
        row++;
      }
      
      if (report.punctuality != null) {
        setCell(0, row, 'Punctuality:');
        setCell(1, row, report.punctuality!);
        row++;
      }
      
      if (report.dressCode != null) {
        setCell(0, row, 'Dress Code:');
        setCell(1, row, report.dressCode!);
        row++;
      }
      
      if (!isPMMSL && report.timeManagement != null) {
        setCell(0, row, 'Time & Territory Management:');
        setCell(1, row, report.timeManagement!);
        row++;
      }
      
      if (isPMMSL) {
        if (report.patientCentricApproach != null) {
          setCell(0, row, 'Patient Centric Approach:');
          setCell(1, row, '${report.patientCentricApproach}/6');
          row++;
        }
        
        if (report.medicalProductKnowledgeMR != null) {
          setCell(0, row, 'MR Medical Product Knowledge:');
          setCell(1, row, '${report.medicalProductKnowledgeMR}/6');
          row++;
        }
        
        if (report.featureBenefits != null) {
          setCell(0, row, 'Feature Benefits:');
          setCell(1, row, '${report.featureBenefits}/6');
          row++;
        }
        
        if (report.closingCommitment != null) {
          setCell(0, row, 'Closing Commitment:');
          setCell(1, row, '${report.closingCommitment}/6');
          row++;
        }
        
        if (report.mrFeedbackComments != null && report.mrFeedbackComments!.isNotEmpty) {
          setCell(0, row, 'MR Feedback Comments:');
          setCell(1, row, report.mrFeedbackComments!);
          row++;
        }
      } else {
        // DM/FT specific fields
        if (report.pharmacyFeedback != null) {
          setCell(0, row, 'Pharmacy Feedback:');
          setCell(1, row, '${report.pharmacyFeedback}/6');
          row++;
        }
        
        if (report.reviewProfile != null) {
          setCell(0, row, 'Review Customer Profile:');
          setCell(1, row, '${report.reviewProfile}/6');
          row++;
        }
        
        if (report.brandBonding != null) {
          setCell(0, row, 'Brand Bonding Ladder:');
          setCell(1, row, '${report.brandBonding}/6');
          row++;
        }
        
        if (report.smartObjectives != null) {
          setCell(0, row, 'SMART Objectives:');
          setCell(1, row, '${report.smartObjectives}/6');
          row++;
        }
        
        if (report.opening != null) {
          setCell(0, row, 'Opening / Rapport:');
          setCell(1, row, '${report.opening}/6');
          row++;
        }
        
        if (report.patientProfile != null) {
          setCell(0, row, 'Patient Profile:');
          setCell(1, row, '${report.patientProfile}/6');
          row++;
        }
        
        if (report.engaging != null) {
          setCell(0, row, 'Engaging Customer:');
          setCell(1, row, '${report.engaging}/6');
          row++;
        }
        
        if (report.insightfulQuestions != null) {
          setCell(0, row, 'Insightful Questions:');
          setCell(1, row, '${report.insightfulQuestions}/6');
          row++;
        }
        
        if (report.activeListening != null) {
          setCell(0, row, 'Active Listening:');
          setCell(1, row, '${report.activeListening}/6');
          row++;
        }
        
        if (report.linkFeatures != null) {
          setCell(0, row, 'Link Features:');
          setCell(1, row, '${report.linkFeatures}/6');
          row++;
        }
        
        if (report.productKnowledge != null) {
          setCell(0, row, 'Product Knowledge:');
          setCell(1, row, '${report.productKnowledge}/6');
          row++;
        }
        
        if (report.eDetailing != null) {
          setCell(0, row, 'E-detailing:');
          setCell(1, row, '${report.eDetailing}/6');
          row++;
        }
        
        if (report.answeringQuestions != null) {
          setCell(0, row, 'Answering Questions:');
          setCell(1, row, '${report.answeringQuestions}/6');
          row++;
        }
        
        if (report.summarizeCall != null) {
          setCell(0, row, 'Summarize Call:');
          setCell(1, row, '${report.summarizeCall}/6');
          row++;
        }
        
        if (report.askCommitment != null) {
          setCell(0, row, 'Ask for Commitment:');
          setCell(1, row, '${report.askCommitment}/6');
          row++;
        }
        
        if (report.bridging != null) {
          setCell(0, row, 'Bridging:');
          setCell(1, row, '${report.bridging}/6');
          row++;
        }
        
        if (report.selfAssessment != null) {
          setCell(0, row, 'Self-assessment:');
          setCell(1, row, '${report.selfAssessment}/6');
          row++;
        }
        
        // Feedback for DM/FT
        if (report.strengths != null && report.strengths!.isNotEmpty) {
          setCell(0, row, 'Strengths:');
          setCell(1, row, report.strengths!);
          row++;
        }
        
        if (report.improvements != null && report.improvements!.isNotEmpty) {
          setCell(0, row, 'Areas of Improvement:');
          setCell(1, row, report.improvements!);
          row++;
        }
        
        if (report.filledWithMR != null) {
          setCell(0, row, 'Filled with MR:');
          setCell(1, row, report.filledWithMR!);
          row++;
        }
      }
    }
    
    row += 2;
    setCell(0, row, 'Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    
    // Save as Excel file
    final filename = 'coaching_report_${report.mrName.replaceAll(' ', '_')}_${report.date}.xlsx';
    await _saveAndOpenExcel(excel, filename);
  }

  // Export monthly report to Excel
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

    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['Monthly Report'];
    
    int row = 0;
    
    // Helper function to set cell value
    void setCell(int col, int r, String value) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: r));
      cell.value = value;
    }
    
    // Header
    setCell(0, row, 'BIOSYN PHARMACEUTICALS');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    row++;
    setCell(0, row, 'MONTHLY COACHING REPORT');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    row++;
    setCell(0, row, monthName);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    row += 2;
    
    // Summary
    final totalVisits = monthlyReports.length;
    final allScores = <double>[];
    for (final report in monthlyReports) {
      final score = report.getAverageScore();
      if (score > 0) {
        allScores.add(score);
      }
    }
    final avgScore = allScores.isEmpty ? '0.00' : (allScores.reduce((a, b) => a + b) / allScores.length).toStringAsFixed(2);
    final uniqueMRs = monthlyReports.map((r) => r.mrId).toSet().length;
    
    setCell(0, row, 'SUMMARY');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    row++;
    
    if (dmName != null) {
      setCell(0, row, 'District Manager:');
      setCell(1, row, dmName);
      row++;
    }
    setCell(0, row, 'Total Field Visits:');
    setCell(1, row, totalVisits.toString());
    row++;
    setCell(0, row, 'Average Score:');
    setCell(1, row, '$avgScore / 6.0');
    row++;
    setCell(0, row, 'Medical Reps Coached:');
    setCell(1, row, uniqueMRs.toString());
    row += 2;
    
    // Detailed Visits - Table headers
    setCell(0, row, 'Date');
    setCell(1, row, 'MR Name');
    setCell(2, row, 'MR ID');
    setCell(3, row, 'DM Name');
    setCell(4, row, 'Score');
    setCell(5, row, 'Punctuality');
    setCell(6, row, 'Dress Code');
    setCell(7, row, 'Strengths');
    row++;
    
    // Data rows
    for (final report in monthlyReports) {
      final score = report.getAverageScore().toStringAsFixed(2);
      final strengths = (report.strengths ?? '').replaceAll('\n', ' ');
      final strengthsShort = strengths.length > 100 ? '${strengths.substring(0, 100)}...' : strengths;
      
      setCell(0, row, report.date);
      setCell(1, row, report.mrName);
      setCell(2, row, report.mrId);
      setCell(3, row, report.dmName);
      setCell(4, row, score);
      setCell(5, row, report.punctuality ?? '');
      setCell(6, row, report.dressCode ?? '');
      setCell(7, row, strengthsShort);
      row++;
    }
    
    row += 2;
    setCell(0, row, 'Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    
    final filename = 'monthly_report_${monthName.replaceAll(' ', '_')}.xlsx';
    await _saveAndOpenExcel(excel, filename);
  }

  // Export all reports to Excel
  static Future<void> exportAllReportsToText(List<CoachingReport> reports) async {
    if (reports.isEmpty) {
      throw Exception('No reports to export');
    }

    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['All Reports'];
    
    int row = 0;
    final reportDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Helper function to set cell value
    void setCell(int col, int r, String value) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: r));
      cell.value = value;
    }
    
    // Header
    setCell(0, row, 'BIOSYN PHARMACEUTICALS');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    row++;
    setCell(0, row, 'ALL COACHING REPORTS');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    row += 2;
    
    setCell(0, row, 'Total Reports:');
    setCell(1, row, reports.length.toString());
    row++;
    
    final uniqueDMs = reports.map((r) => r.dmName).where((name) => name.isNotEmpty).toSet().length;
    setCell(0, row, 'District Managers:');
    setCell(1, row, uniqueDMs.toString());
    row++;
    setCell(0, row, 'Export Date:');
    setCell(1, row, reportDate);
    row += 2;
    
    // Table Headers
    setCell(0, row, 'Date');
    setCell(1, row, 'DM Name');
    setCell(2, row, 'MR Name');
    setCell(3, row, 'MR ID');
    setCell(4, row, 'Coach Role');
    setCell(5, row, 'Score');
    setCell(6, row, 'Punctuality');
    setCell(7, row, 'Dress Code');
    setCell(8, row, 'Strengths');
    row++;
    
    // Data rows
    for (final report in reports) {
      final score = report.getAverageScore().toStringAsFixed(2);
      final strengths = (report.strengths ?? '').replaceAll('\n', ' ');
      final strengthsShort = strengths.length > 100 ? '${strengths.substring(0, 100)}...' : strengths;
      
      setCell(0, row, report.date);
      setCell(1, row, report.dmName);
      setCell(2, row, report.mrName);
      setCell(3, row, report.mrId);
      setCell(4, row, report.coachRole ?? 'dm');
      setCell(5, row, score);
      setCell(6, row, report.punctuality ?? '');
      setCell(7, row, report.dressCode ?? '');
      setCell(8, row, strengthsShort);
      row++;
    }
    
    row += 2;
    setCell(0, row, 'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    
    final filename = 'all_coaching_reports_$reportDate.xlsx';
    await _saveAndOpenExcel(excel, filename);
  }

  // Helper method to save Excel file and open it for download
  static Future<void> _saveAndOpenExcel(Excel excel, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      
      // Save Excel file
      final excelBytes = excel.save();
      if (excelBytes == null) {
        throw Exception('Failed to generate Excel file');
      }
      
      await file.writeAsBytes(excelBytes);
      
      // Open the file for download/viewing
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Failed to open file: ${result.message}');
      }
    } catch (e) {
      throw Exception('Failed to export Excel file: $e');
    }
  }

  // Legacy method for CSV (kept for backward compatibility)
  static Future<void> exportToCSV(List<CoachingReport> reports, String filename) async {
    await exportAllReportsToText(reports);
  }
}
