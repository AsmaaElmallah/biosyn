import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
    
    // Coach Name - Handle Triple Visit correctly
    setCell(0, row, 'Coach:');
    if (report.typeOfVisit == 'Triple' && isPMMSL) {
      // For Triple Visit: use coachName if available (from model), otherwise use full role label
      if (report.coachName != null && report.coachName!.isNotEmpty) {
        // Use full role label like in View: "Medical Science Liaison (MSL)" or "Product Manager (PM)"
        final roleLabel = report.coachRole == 'pm' 
            ? 'Product Manager (PM)' 
            : 'Medical Science Liaison (MSL)';
        setCell(1, row, '$roleLabel: ${report.coachName}');
      } else {
        // Fallback: use full role label only
        final roleLabel = report.coachRole == 'pm' 
            ? 'Product Manager (PM)' 
            : 'Medical Science Liaison (MSL)';
        setCell(1, row, roleLabel);
      }
    } else {
      // For other visits: dmName is the coach
      setCell(1, row, '${report.dmName}${report.coachRole != null ? ' (${report.coachRole!.toUpperCase()})' : ''}');
    }
    row++;
    
    // Coached Person - Handle Triple Visit correctly
    setCell(0, row, 'Coached Person:');
    if (report.typeOfVisit == 'Triple' && isPMMSL) {
      // For Triple Visit: show both DM and MR
      setCell(1, row, 'DM: ${report.dmName} & MR: ${report.mrName}');
    } else {
      final coachedPersonRole = isDMReport ? 'DM' : 'MR';
      setCell(1, row, '${report.mrName} ($coachedPersonRole)');
    }
    row++;
    
    // Average Score - Handle Triple Visit correctly
    final avgScore = (report.typeOfVisit == 'Triple' && isPMMSL) 
        ? report.getTripleVisitScore() // For Triple, use combined average of DM and MR scores
        : (isDMReport ? report.getDMScore() : report.getAverageScore());
    setCell(0, row, 'Average Score:');
    setCell(1, row, '${avgScore.toStringAsFixed(2)} / 6.0');
    row++;
    
    // Brick Information (for all forms) - Location data removed
    if (report.brickName != null || report.visitCount != null || (report.doctorsVisited != null && report.doctorsVisited!.isNotEmpty)) {
      setCell(0, row, 'Brick Information:');
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                  CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      row++;
      
      if (report.brickName != null) {
        setCell(0, row, 'Brick Name:');
        setCell(1, row, report.brickName!);
        row++;
      }
      
      if (report.visitCount != null) {
        setCell(0, row, 'Visit Count:');
        setCell(1, row, report.visitCount.toString());
        row++;
      }
      
      if (report.doctorsVisited != null && report.doctorsVisited!.isNotEmpty) {
        setCell(0, row, 'Doctors Visited:');
        setCell(1, row, report.doctorsVisited!);
        row++;
      }
      
      row++;
    }
    
    // Location (Google Maps URL only)
    if (report.googleMapsUrl != null && report.googleMapsUrl!.isNotEmpty) {
      setCell(0, row, 'Location:');
      setCell(1, row, report.googleMapsUrl!);
      row++;
    }
    
    // Quick Session Flag
    if (report.isQuickSession == true) {
      setCell(0, row, 'Session Type:');
      setCell(1, row, 'Quick Session (No Plan)');
      row++;
    }
    
    row++;
    
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
      
      if (report.visitedAccountsNames != null && report.visitedAccountsNames!.isNotEmpty) {
        setCell(0, row, 'Visited Accounts:');
        setCell(1, row, report.visitedAccountsNames!);
        row++;
      }
      
      if (report.generalFeedback != null && report.generalFeedback!.isNotEmpty) {
        setCell(0, row, 'General Feedback:');
        setCell(1, row, report.generalFeedback!);
        row++;
      }
      row++;
    }
    
    // DM Feedback - Show for DM reports OR Triple Visit (which contains both DM and MR feedback)
    final isTripleVisit = report.typeOfVisit == 'Triple' && isPMMSL;
    if (isDMReport || isTripleVisit) {
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
    
    // MR Feedback - Show for MR reports OR Triple Visit (which contains both DM and MR feedback)
    if (!isDMReport || isTripleVisit) {
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
        // PM/MSL MR Feedback - All fields
        if (report.pharmacyFeedback != null) {
          setCell(0, row, 'Pharmacy Feedback:');
          setCell(1, row, '${report.pharmacyFeedback}/6');
          row++;
        }
        
        if (report.reviewProfile != null) {
          setCell(0, row, 'Review customer Profile/Potential/Preference:');
          setCell(1, row, '${report.reviewProfile}/6');
          row++;
        }
        
        if (report.patientCentricApproach != null) {
          setCell(0, row, 'Patient Centric Approach:');
          setCell(1, row, '${report.patientCentricApproach}/6');
          row++;
        }
        
        if (report.medicalProductKnowledgeMR != null) {
          setCell(0, row, 'Medical and Product Knowledge:');
          setCell(1, row, '${report.medicalProductKnowledgeMR}/6');
          row++;
        }
        
        if (report.engaging != null) {
          setCell(0, row, 'Engaging the customer:');
          setCell(1, row, '${report.engaging}/6');
          row++;
        }
        
        if (report.featureBenefits != null) {
          setCell(0, row, 'Feature and Benefits:');
          setCell(1, row, '${report.featureBenefits}/6');
          row++;
        }
        
        if (report.closingCommitment != null) {
          setCell(0, row, 'Closing and commitment:');
          setCell(1, row, '${report.closingCommitment}/6');
          row++;
        }
        
        if (report.mrFeedbackComments != null && report.mrFeedbackComments!.isNotEmpty) {
          setCell(0, row, 'MR Feedback Comments:');
          setCell(1, row, report.mrFeedbackComments!);
          row++;
        }
      } else {
        // DM/FT specific fields - Pre-Call Planning
        if (report.pharmacyFeedback != null) {
          setCell(0, row, 'Pharmacy Feedback:');
          setCell(1, row, '${report.pharmacyFeedback}/6');
          row++;
        }
        
        if (report.reviewProfile != null) {
          setCell(0, row, 'Review customer Profile/Potential/Preference:');
          setCell(1, row, '${report.reviewProfile}/6');
          row++;
        }
        
        if (report.brandBonding != null) {
          setCell(0, row, 'Brand bonding ladder (review last call commitment):');
          setCell(1, row, '${report.brandBonding}/6');
          row++;
        }
        
        if (report.smartObjectives != null) {
          setCell(0, row, 'Set SMART call objectives:');
          setCell(1, row, '${report.smartObjectives}/6');
          row++;
        }
        
        // Sales Call Steps
        if (report.opening != null) {
          setCell(0, row, 'Opening / Rapport:');
          setCell(1, row, '${report.opening}/6');
          row++;
        }
        
        if (report.patientProfile != null) {
          setCell(0, row, 'Specific Patient profile:');
          setCell(1, row, '${report.patientProfile}/6');
          row++;
        }
        
        if (report.engaging != null) {
          setCell(0, row, 'Engaging the customer:');
          setCell(1, row, '${report.engaging}/6');
          row++;
        }
        
        if (report.insightfulQuestions != null) {
          setCell(0, row, 'Asking insightful Question(s):');
          setCell(1, row, '${report.insightfulQuestions}/6');
          row++;
        }
        
        if (report.activeListening != null) {
          setCell(0, row, 'Active Listening (no interruptions, confirm/clarify):');
          setCell(1, row, '${report.activeListening}/6');
          row++;
        }
        
        if (report.linkFeatures != null) {
          setCell(0, row, 'Link product feature(s) with customer need:');
          setCell(1, row, '${report.linkFeatures}/6');
          row++;
        }
        
        if (report.productKnowledge != null) {
          setCell(0, row, 'Proper Product, Medical & Competitor Knowledge:');
          setCell(1, row, '${report.productKnowledge}/6');
          row++;
        }
        
        if (report.eDetailing != null) {
          setCell(0, row, 'Proper use of E-detailing:');
          setCell(1, row, '${report.eDetailing}/6');
          row++;
        }
        
        if (report.answeringQuestions != null) {
          setCell(0, row, 'Answering Customer Questions & Concerns (APACT):');
          setCell(1, row, '${report.answeringQuestions}/6');
          row++;
        }
        
        // Closing
        if (report.summarizeCall != null) {
          setCell(0, row, 'Summarize Call:');
          setCell(1, row, '${report.summarizeCall}/6');
          row++;
        }
        
        if (report.askCommitment != null) {
          setCell(0, row, 'Ask for specific commitment:');
          setCell(1, row, '${report.askCommitment}/6');
          row++;
        }
        
        if (report.bridging != null) {
          setCell(0, row, 'Bridging to next product(s):');
          setCell(1, row, '${report.bridging}/6');
          row++;
        }
        
        // Post Call Analysis
        if (report.selfAssessment != null) {
          setCell(0, row, 'Self-assessment & Updating customer profile:');
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
    
    // Detailed Visits - Table headers (expanded with more details)
    setCell(0, row, 'Date');
    setCell(1, row, 'Coach');
    setCell(2, row, 'Coach Role');
    setCell(3, row, 'MR Name');
    setCell(4, row, 'MR ID');
    setCell(5, row, 'Score');
    setCell(6, row, 'Punctuality');
    setCell(7, row, 'Dress Code');
    setCell(8, row, 'Time Management');
    setCell(9, row, 'Pharmacy Feedback');
    setCell(10, row, 'Review Profile');
    setCell(11, row, 'Brand Bonding');
    setCell(12, row, 'SMART Objectives');
    setCell(13, row, 'Opening');
    setCell(14, row, 'Patient Profile');
    setCell(15, row, 'Engaging');
    setCell(16, row, 'Insightful Questions');
    setCell(17, row, 'Active Listening');
    setCell(18, row, 'Link Features');
    setCell(19, row, 'Product Knowledge');
    setCell(20, row, 'E-detailing');
    setCell(21, row, 'Answering Questions');
    setCell(22, row, 'Summarize Call');
    setCell(23, row, 'Ask Commitment');
    setCell(24, row, 'Bridging');
    setCell(25, row, 'Self Assessment');
    setCell(26, row, 'Strengths');
    setCell(27, row, 'Areas of Improvement');
    setCell(28, row, 'Filled with MR');
    setCell(29, row, 'Brick Name');
    setCell(30, row, 'Location');
    setCell(31, row, 'Visit Count');
    setCell(32, row, 'Doctors Visited');
    row++;
    
    // Data rows
    for (final report in monthlyReports) {
      final isPMMSL = report.coachRole == 'pm' || report.coachRole == 'msl';
      final isTripleVisit = report.typeOfVisit == 'Triple' && isPMMSL;
      
      // Get coach name - for Triple Visit use coachName, otherwise use dmName
      final coachName = isTripleVisit && report.coachName != null && report.coachName!.isNotEmpty
          ? report.coachName!
          : report.dmName;
      
      final score = report.getAverageScore().toStringAsFixed(2);
      final strengths = (report.strengths ?? '').replaceAll('\n', ' ');
      final strengthsShort = strengths.length > 200 ? '${strengths.substring(0, 200)}...' : strengths;
      final improvements = (report.improvements ?? '').replaceAll('\n', ' ');
      final improvementsShort = improvements.length > 200 ? '${improvements.substring(0, 200)}...' : improvements;
      
      setCell(0, row, report.date);
      setCell(1, row, coachName);
      setCell(2, row, report.coachRole ?? 'dm');
      setCell(3, row, report.mrName);
      setCell(4, row, report.mrId);
      setCell(5, row, score);
      setCell(6, row, report.punctuality ?? '');
      setCell(7, row, report.dressCode ?? '');
      setCell(8, row, report.timeManagement ?? '');
      setCell(9, row, report.pharmacyFeedback != null ? '${report.pharmacyFeedback}/6' : '');
      setCell(10, row, report.reviewProfile != null ? '${report.reviewProfile}/6' : '');
      setCell(11, row, report.brandBonding != null ? '${report.brandBonding}/6' : '');
      setCell(12, row, report.smartObjectives != null ? '${report.smartObjectives}/6' : '');
      setCell(13, row, report.opening != null ? '${report.opening}/6' : '');
      setCell(14, row, report.patientProfile != null ? '${report.patientProfile}/6' : '');
      setCell(15, row, report.engaging != null ? '${report.engaging}/6' : '');
      setCell(16, row, report.insightfulQuestions != null ? '${report.insightfulQuestions}/6' : '');
      setCell(17, row, report.activeListening != null ? '${report.activeListening}/6' : '');
      setCell(18, row, report.linkFeatures != null ? '${report.linkFeatures}/6' : '');
      setCell(19, row, report.productKnowledge != null ? '${report.productKnowledge}/6' : '');
      setCell(20, row, report.eDetailing != null ? '${report.eDetailing}/6' : '');
      setCell(21, row, report.answeringQuestions != null ? '${report.answeringQuestions}/6' : '');
      setCell(22, row, report.summarizeCall != null ? '${report.summarizeCall}/6' : '');
      setCell(23, row, report.askCommitment != null ? '${report.askCommitment}/6' : '');
      setCell(24, row, report.bridging != null ? '${report.bridging}/6' : '');
      setCell(25, row, report.selfAssessment != null ? '${report.selfAssessment}/6' : '');
      setCell(26, row, strengthsShort);
      setCell(27, row, improvementsShort);
      setCell(28, row, report.filledWithMR ?? '');
      setCell(29, row, report.brickName ?? '');
      setCell(30, row, report.googleMapsUrl ?? '');
      setCell(31, row, report.visitCount?.toString() ?? '');
      setCell(32, row, report.doctorsVisited ?? '');
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
    
    // Table Headers (expanded with all details)
    setCell(0, row, 'Date');
    setCell(1, row, 'Coach');
    setCell(2, row, 'Coach Role');
    setCell(3, row, 'MR Name');
    setCell(4, row, 'MR ID');
    setCell(5, row, 'Score');
    setCell(6, row, 'Punctuality');
    setCell(7, row, 'Dress Code');
    setCell(8, row, 'Time Management');
    setCell(9, row, 'Pharmacy Feedback');
    setCell(10, row, 'Review Profile');
    setCell(11, row, 'Brand Bonding');
    setCell(12, row, 'SMART Objectives');
    setCell(13, row, 'Opening');
    setCell(14, row, 'Patient Profile');
    setCell(15, row, 'Engaging');
    setCell(16, row, 'Insightful Questions');
    setCell(17, row, 'Active Listening');
    setCell(18, row, 'Link Features');
    setCell(19, row, 'Product Knowledge');
    setCell(20, row, 'E-detailing');
    setCell(21, row, 'Answering Questions');
    setCell(22, row, 'Summarize Call');
    setCell(23, row, 'Ask Commitment');
    setCell(24, row, 'Bridging');
    setCell(25, row, 'Self Assessment');
    setCell(26, row, 'Strengths');
    setCell(27, row, 'Areas of Improvement');
    setCell(28, row, 'Filled with MR');
    setCell(29, row, 'Brick Name');
    setCell(30, row, 'Location');
    setCell(31, row, 'Visit Count');
    setCell(32, row, 'Doctors Visited');
    setCell(33, row, 'Type of Visit');
    setCell(34, row, 'Visited Accounts');
    setCell(35, row, 'General Feedback');
    setCell(36, row, 'Teamwork');
    setCell(37, row, 'Customer Awareness');
    setCell(38, row, 'Medical Product Knowledge DM');
    setCell(39, row, 'DM Feedback Comments');
    setCell(40, row, 'Patient Centric Approach');
    setCell(41, row, 'Medical Product Knowledge MR');
    setCell(42, row, 'Feature Benefits');
    setCell(43, row, 'Closing Commitment');
    setCell(44, row, 'MR Feedback Comments');
    row++;
    
    // Data rows
    for (final report in reports) {
      final isPMMSL = report.coachRole == 'pm' || report.coachRole == 'msl';
      final isDMReport = isPMMSL && (report.customerAwareness != null || report.medicalProductKnowledgeDM != null);
      final isTripleVisit = report.typeOfVisit == 'Triple' && isPMMSL;
      
      // Get coach name - for Triple Visit use coachName, otherwise use dmName
      final coachName = isTripleVisit && report.coachName != null && report.coachName!.isNotEmpty
          ? report.coachName!
          : report.dmName;
      
      final score = isDMReport ? report.getDMScore().toStringAsFixed(2) : report.getAverageScore().toStringAsFixed(2);
      final strengths = (report.strengths ?? '').replaceAll('\n', ' ');
      final strengthsShort = strengths.length > 200 ? '${strengths.substring(0, 200)}...' : strengths;
      final improvements = (report.improvements ?? '').replaceAll('\n', ' ');
      final improvementsShort = improvements.length > 200 ? '${improvements.substring(0, 200)}...' : improvements;
      final generalFeedback = (report.generalFeedback ?? '').replaceAll('\n', ' ');
      final generalFeedbackShort = generalFeedback.length > 200 ? '${generalFeedback.substring(0, 200)}...' : generalFeedback;
      final dmFeedbackComments = (report.dmFeedbackComments ?? '').replaceAll('\n', ' ');
      final dmFeedbackCommentsShort = dmFeedbackComments.length > 200 ? '${dmFeedbackComments.substring(0, 200)}...' : dmFeedbackComments;
      final mrFeedbackComments = (report.mrFeedbackComments ?? '').replaceAll('\n', ' ');
      final mrFeedbackCommentsShort = mrFeedbackComments.length > 200 ? '${mrFeedbackComments.substring(0, 200)}...' : mrFeedbackComments;
      
      setCell(0, row, report.date);
      setCell(1, row, coachName);
      setCell(2, row, report.coachRole ?? 'dm');
      setCell(3, row, report.mrName);
      setCell(4, row, report.mrId);
      setCell(5, row, score);
      setCell(6, row, report.punctuality ?? '');
      setCell(7, row, report.dressCode ?? '');
      setCell(8, row, report.timeManagement ?? '');
      setCell(9, row, report.pharmacyFeedback != null ? '${report.pharmacyFeedback}/6' : '');
      setCell(10, row, report.reviewProfile != null ? '${report.reviewProfile}/6' : '');
      setCell(11, row, report.brandBonding != null ? '${report.brandBonding}/6' : '');
      setCell(12, row, report.smartObjectives != null ? '${report.smartObjectives}/6' : '');
      setCell(13, row, report.opening != null ? '${report.opening}/6' : '');
      setCell(14, row, report.patientProfile != null ? '${report.patientProfile}/6' : '');
      setCell(15, row, report.engaging != null ? '${report.engaging}/6' : '');
      setCell(16, row, report.insightfulQuestions != null ? '${report.insightfulQuestions}/6' : '');
      setCell(17, row, report.activeListening != null ? '${report.activeListening}/6' : '');
      setCell(18, row, report.linkFeatures != null ? '${report.linkFeatures}/6' : '');
      setCell(19, row, report.productKnowledge != null ? '${report.productKnowledge}/6' : '');
      setCell(20, row, report.eDetailing != null ? '${report.eDetailing}/6' : '');
      setCell(21, row, report.answeringQuestions != null ? '${report.answeringQuestions}/6' : '');
      setCell(22, row, report.summarizeCall != null ? '${report.summarizeCall}/6' : '');
      setCell(23, row, report.askCommitment != null ? '${report.askCommitment}/6' : '');
      setCell(24, row, report.bridging != null ? '${report.bridging}/6' : '');
      setCell(25, row, report.selfAssessment != null ? '${report.selfAssessment}/6' : '');
      setCell(26, row, strengthsShort);
      setCell(27, row, improvementsShort);
      setCell(28, row, report.filledWithMR ?? '');
      setCell(29, row, report.brickName ?? report.areaBrickName ?? '');
      setCell(30, row, report.googleMapsUrl ?? '');
      setCell(31, row, report.visitCount?.toString() ?? '');
      setCell(32, row, report.doctorsVisited ?? '');
      setCell(33, row, report.typeOfVisit ?? '');
      setCell(34, row, report.visitedAccountsNames ?? '');
      setCell(35, row, generalFeedbackShort);
      setCell(36, row, report.teamwork ?? '');
      setCell(37, row, report.customerAwareness ?? '');
      setCell(38, row, report.medicalProductKnowledgeDM ?? '');
      setCell(39, row, dmFeedbackCommentsShort);
      setCell(40, row, report.patientCentricApproach != null ? '${report.patientCentricApproach}/6' : '');
      setCell(41, row, report.medicalProductKnowledgeMR != null ? '${report.medicalProductKnowledgeMR}/6' : '');
      setCell(42, row, report.featureBenefits != null ? '${report.featureBenefits}/6' : '');
      setCell(43, row, report.closingCommitment != null ? '${report.closingCommitment}/6' : '');
      setCell(44, row, mrFeedbackCommentsShort);
      row++;
    }
    
    row += 2;
    setCell(0, row, 'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), 
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    
    final filename = 'all_coaching_reports_$reportDate.xlsx';
    await _saveAndOpenExcel(excel, filename);
  }

  // Helper method to save Excel file and share it for download
  static Future<void> _saveAndOpenExcel(Excel excel, String filename) async {
    try {
      // Get temporary directory for saving the file
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      
      // Save Excel file
      final excelBytes = excel.save();
      if (excelBytes == null) {
        throw Exception('Failed to generate Excel file');
      }
      
      await file.writeAsBytes(excelBytes);
      
      // Share the file for download (this will trigger download on Android/iOS)
      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        subject: filename,
        text: 'Coaching Report Export',
      );
    } catch (e) {
      throw Exception('Failed to export Excel file: $e');
    }
  }

  // Legacy method for CSV (kept for backward compatibility)
  static Future<void> exportToCSV(List<CoachingReport> reports, String filename) async {
    await exportAllReportsToText(reports);
  }
}
