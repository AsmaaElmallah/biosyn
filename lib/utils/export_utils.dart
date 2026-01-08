import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';

class ExportUtils {
  // Helper function to apply borders to a style
  static void _applyBorders(dynamic style) {
    style.borders.all.lineStyle = LineStyle.thin;
    style.borders.all.color = '#000000';
  }
  
  // Helper function to apply header style
  static void _applyHeaderStyle(dynamic style, {bool isMainHeader = false}) {
    style.bold = true;
    style.fontColor = isMainHeader ? '#FFFFFF' : '#1E3A8A';
    style.backColor = isMainHeader ? '#1E3A8A' : '#F3F4F6';
    style.hAlign = HAlignType.center;
    style.vAlign = VAlignType.center;
    style.wrapText = true; // Enable text wrapping
    _applyBorders(style);
  }
  
  // Helper function to apply section header style
  static void _applySectionHeaderStyle(dynamic style) {
    style.bold = true;
    style.fontColor = '#1E3A8A';
    style.backColor = '#F3F4F6';
    style.hAlign = HAlignType.left;
    style.vAlign = VAlignType.center;
    style.wrapText = true; // Enable text wrapping
    _applyBorders(style);
  }
  
  // Helper function to apply label style
  static void _applyLabelStyle(dynamic style) {
    style.bold = true;
    style.fontColor = '#1F2937';
    style.backColor = '#FFFFFF';
    style.hAlign = HAlignType.left;
    style.vAlign = VAlignType.center;
    _applyBorders(style);
  }
  
  // Helper function to apply data style
  static void _applyDataStyle(dynamic style) {
    style.fontColor = '#1F2937';
    style.backColor = '#FFFFFF';
    style.hAlign = HAlignType.left;
    style.vAlign = VAlignType.center;
    _applyBorders(style);
  }
  
  // Helper function to apply table header style
  static void _applyTableHeaderStyle(dynamic style) {
    style.bold = true;
    style.fontColor = '#FFFFFF';
    style.backColor = '#3B82F6';
    style.hAlign = HAlignType.center;
    style.vAlign = VAlignType.center;
    style.wrapText = true; // Enable text wrapping
    _applyBorders(style);
  }
  
// Export single report to Excel
  static Future<String> exportSingleReportToText(CoachingReport report) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Coaching Report';
    
    // Note: Column widths will be auto-adjusted based on content
    // Initial widths - will be adjusted automatically
    sheet.setColumnWidthInPixels(1, 50); // Labels column (A)
    sheet.setColumnWidthInPixels(2, 60); // Values column (B)
    
    // Determine report type
    final isPMMSL = report.coachRole == 'pm' || report.coachRole == 'msl';
    final isDMReport = isPMMSL && (report.customerAwareness != null || report.medicalProductKnowledgeDM != null);
    
    int row = 1; // Excel rows start from 1
    
    // Helper function to set cell with style
    void setCell(int col, int r, String value, {String style = 'data'}) {
      final range = sheet.getRangeByIndex(r, col);
      range.setText(value);
      final cellStyle = range.cellStyle;
      switch (style) {
        case 'mainHeader':
          _applyHeaderStyle(cellStyle, isMainHeader: true);
          break;
        case 'sectionHeader':
          _applySectionHeaderStyle(cellStyle);
          break;
        case 'label':
          _applyLabelStyle(cellStyle);
          break;
        case 'tableHeader':
          _applyTableHeaderStyle(cellStyle);
          break;
        default:
          _applyDataStyle(cellStyle);
      }
    }
    
    // Header - Main Company Header
    final headerRange1 = sheet.getRangeByIndex(row, 1, row, 4);
    headerRange1.setText('BIOSYN PHARMACEUTICALS');
    headerRange1.merge();
    _applyHeaderStyle(headerRange1.cellStyle, isMainHeader: true);
    row++;
    
    final headerRange2 = sheet.getRangeByIndex(row, 1, row, 4);
    headerRange2.setText('COACHING REPORT');
    headerRange2.merge();
    _applyHeaderStyle(headerRange2.cellStyle, isMainHeader: true);
    row += 2;
    
    // Basic Information - Section Header
    final basicInfoHeader = sheet.getRangeByIndex(row, 1, row, 2);
    basicInfoHeader.setText('BASIC INFORMATION');
    basicInfoHeader.merge();
    _applySectionHeaderStyle(basicInfoHeader.cellStyle);
    row++;
    
    setCell(1, row, 'Date:', style: 'label');
    setCell(2, row, report.date);
    row++;
    
    // Coach Name - Handle Triple Visit correctly
    setCell(1, row, 'Coach:');
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
        setCell(2, row, '${report.dmName}${report.coachRole != null ? ' (${report.coachRole!.toUpperCase()})' : ''}');
    }
    row++;
    
    // Coached Person - Handle Triple Visit correctly
    setCell(1, row, 'Coached Person:', style: 'label');
    if (report.typeOfVisit == 'Triple' && isPMMSL) {
      setCell(2, row, 'DM: ${report.dmName} & MR: ${report.mrName}');
    } else {
      final coachedPersonRole = isDMReport ? 'DM' : 'MR';
      setCell(2, row, '${report.mrName} ($coachedPersonRole)');
    }
    row++;
    
    // Average Score
    final avgScore = (report.typeOfVisit == 'Triple' && isPMMSL) 
        ? report.getTripleVisitScore()
        : (isDMReport ? report.getDMScore() : report.getAverageScore());
    setCell(1, row, 'Average Score:', style: 'label');
    setCell(2, row, '${avgScore.toStringAsFixed(2)} / 6.0');
    row++;
    
    // Brick Information
    if (report.brickName != null || report.visitCount != null || (report.doctorsVisited != null && report.doctorsVisited!.isNotEmpty)) {
      final brickInfoHeader = sheet.getRangeByIndex(row, 1, row, 2);
      brickInfoHeader.setText('Brick Information:');
      brickInfoHeader.merge();
      _applyLabelStyle(brickInfoHeader.cellStyle);
      row++;
      
      if (report.brickName != null) {
        setCell(1, row, 'Brick Name:', style: 'label');
        setCell(2, row, report.brickName!);
        row++;
      }
      
      if (report.visitCount != null) {
        setCell(1, row, 'Visits Count:', style: 'label');
        setCell(2, row, report.visitCount.toString());
        row++;
      }
      
      if (report.doctorsVisited != null && report.doctorsVisited!.isNotEmpty) {
        setCell(1, row, 'Doctors Visited:', style: 'label');
        setCell(2, row, report.doctorsVisited!);
        row++;
      }
      
      row++;
    }
    
    // Location
    if (report.googleMapsUrl != null && report.googleMapsUrl!.isNotEmpty) {
      setCell(1, row, 'Location:', style: 'label');
      setCell(2, row, report.googleMapsUrl!);
      row++;
    }
    
    // Quick Session Flag
    if (report.isQuickSession == true) {
      setCell(1, row, 'Session Type:', style: 'label');
      setCell(2, row, 'Quick Session (No Plan)');
      row++;
    }
    
    row++;
    
    // PM/MSL Specific Information
    if (isPMMSL) {
      final pmmslHeader = sheet.getRangeByIndex(row, 1, row, 2);
      pmmslHeader.setText('PM/MSL SPECIFIC INFORMATION');
      pmmslHeader.merge();
      _applySectionHeaderStyle(pmmslHeader.cellStyle);
      row++;
      
      if (report.areaBrickName != null) {
        setCell(1, row, 'Area & Brick Name:', style: 'label');
        setCell(2, row, report.areaBrickName!);
        row++;
      }
      
      if (report.typeOfVisit != null) {
        setCell(1, row, 'Type of Visit:', style: 'label');
        setCell(2, row, report.typeOfVisit!);
        row++;
      }
      
      if (report.visitedAccountsNames != null && report.visitedAccountsNames!.isNotEmpty) {
        setCell(1, row, 'Visited Accounts:', style: 'label');
        setCell(2, row, report.visitedAccountsNames!);
        row++;
      }
      
      if (report.generalFeedback != null && report.generalFeedback!.isNotEmpty) {
        setCell(1, row, 'General Feedback:', style: 'label');
        setCell(2, row, report.generalFeedback!);
        row++;
      }
      row++;
    }
    
    // DM Feedback
    final isTripleVisit = report.typeOfVisit == 'Triple' && isPMMSL;
    if (isDMReport || isTripleVisit) {
      final dmHeader = sheet.getRangeByIndex(row, 1, row, 2);
      dmHeader.setText('DM FEEDBACK');
      dmHeader.merge();
      _applySectionHeaderStyle(dmHeader.cellStyle);
      row++;
      
      if (report.teamwork != null) {
        setCell(1, row, 'Teamwork and Cooperation:', style: 'label');
        setCell(2, row, report.teamwork!);
        row++;
      }
      
      if (report.customerAwareness != null) {
        setCell(1, row, 'Customer Awareness:', style: 'label');
        setCell(2, row, report.customerAwareness!);
        row++;
      }
      
      if (report.medicalProductKnowledgeDM != null) {
        setCell(1, row, 'Medical & Product Knowledge:', style: 'label');
        setCell(2, row, report.medicalProductKnowledgeDM!);
        row++;
      }
      
      if (report.dmFeedbackComments != null && report.dmFeedbackComments!.isNotEmpty) {
        setCell(1, row, 'DM Feedback Comments:', style: 'label');
        setCell(2, row, report.dmFeedbackComments!);
        row++;
      }
      row++;
    }
    
    // MR Feedback / Personal Attributes
    if (!isDMReport || isTripleVisit) {
      final mrHeader = sheet.getRangeByIndex(row, 1, row, 2);
      if (isPMMSL) {
        mrHeader.setText('MR FEEDBACK');
      } else {
        mrHeader.setText('PERSONAL ATTRIBUTES');
      }
      mrHeader.merge();
      _applySectionHeaderStyle(mrHeader.cellStyle);
      row++;
      
      if (report.punctuality != null) {
        setCell(1, row, 'Punctuality:', style: 'label');
        setCell(2, row, report.punctuality!);
        row++;
      }
      
      if (report.dressCode != null) {
        setCell(1, row, 'Dress Code:', style: 'label');
        setCell(2, row, report.dressCode!);
        row++;
      }
      
      if (!isPMMSL && report.timeManagement != null) {
        setCell(1, row, 'Time & Territory Management:', style: 'label');
        setCell(2, row, report.timeManagement!);
        row++;
      }
      
      if (isPMMSL) {
        // PM/MSL MR Feedback
        if (report.pharmacyFeedback != null) {
          setCell(1, row, 'Pharmacy Feedback:');
          setCell(2, row, '${report.pharmacyFeedback}/6');
          row++;
        }
        if (report.reviewProfile != null) {
          setCell(1, row, 'Review customer Profile/Potential/Preference:');
          setCell(2, row, '${report.reviewProfile}/6');
          row++;
        }
        if (report.patientCentricApproach != null) {
          setCell(1, row, 'Patient Centric Approach:');
          setCell(2, row, '${report.patientCentricApproach}/6');
          row++;
        }
        if (report.medicalProductKnowledgeMR != null) {
          setCell(1, row, 'Medical and Product Knowledge:');
          setCell(2, row, '${report.medicalProductKnowledgeMR}/6');
          row++;
        }
        if (report.engaging != null) {
          setCell(1, row, 'Engaging the customer:');
          setCell(2, row, '${report.engaging}/6');
          row++;
        }
        if (report.featureBenefits != null) {
          setCell(1, row, 'Feature and Benefits:');
          setCell(2, row, '${report.featureBenefits}/6');
          row++;
        }
        if (report.closingCommitment != null) {
          setCell(1, row, 'Closing and commitment:');
          setCell(2, row, '${report.closingCommitment}/6');
          row++;
        }
        if (report.mrFeedbackComments != null && report.mrFeedbackComments!.isNotEmpty) {
          setCell(1, row, 'MR Feedback Comments:');
          setCell(2, row, report.mrFeedbackComments!);
          row++;
        }
      } else {
        // DM/FT specific fields
        if (report.pharmacyFeedback != null) {
          setCell(1, row, 'Pharmacy Feedback:');
          setCell(2, row, '${report.pharmacyFeedback}/6');
          row++;
        }
        if (report.reviewProfile != null) {
          setCell(1, row, 'Review customer Profile/Potential/Preference:');
          setCell(2, row, '${report.reviewProfile}/6');
          row++;
        }
        if (report.brandBonding != null) {
          setCell(1, row, 'Brand bonding ladder (review last call commitment):');
          setCell(2, row, '${report.brandBonding}/6');
          row++;
        }
        if (report.smartObjectives != null) {
          setCell(1, row, 'Set SMART call objectives:');
          setCell(2, row, '${report.smartObjectives}/6');
          row++;
        }
        if (report.opening != null) {
          setCell(1, row, 'Opening / Rapport:');
          setCell(2, row, '${report.opening}/6');
          row++;
        }
        if (report.patientProfile != null) {
          setCell(1, row, 'Specific Patient profile:');
          setCell(2, row, '${report.patientProfile}/6');
          row++;
        }
        if (report.engaging != null) {
          setCell(1, row, 'Engaging the customer:');
          setCell(2, row, '${report.engaging}/6');
          row++;
        }
        if (report.insightfulQuestions != null) {
          setCell(1, row, 'Asking insightful Question(s):');
          setCell(2, row, '${report.insightfulQuestions}/6');
          row++;
        }
        if (report.activeListening != null) {
          setCell(1, row, 'Active Listening (no interruptions, confirm/clarify):');
          setCell(2, row, '${report.activeListening}/6');
          row++;
        }
        if (report.linkFeatures != null) {
          setCell(1, row, 'Link product feature(s) with customer need:');
          setCell(2, row, '${report.linkFeatures}/6');
          row++;
        }
        if (report.productKnowledge != null) {
          setCell(1, row, 'Proper Product, Medical & Competitor Knowledge:');
          setCell(2, row, '${report.productKnowledge}/6');
          row++;
        }
        if (report.eDetailing != null) {
          setCell(1, row, 'Proper use of E-detailing:');
          setCell(2, row, '${report.eDetailing}/6');
          row++;
        }
        if (report.answeringQuestions != null) {
          setCell(1, row, 'Answering Customer Questions & Concerns (APACT):');
          setCell(2, row, '${report.answeringQuestions}/6');
          row++;
        }
        if (report.summarizeCall != null) {
          setCell(1, row, 'Summarize Call:');
          setCell(2, row, '${report.summarizeCall}/6');
          row++;
        }
        if (report.askCommitment != null) {
          setCell(1, row, 'Ask for specific commitment:');
          setCell(2, row, '${report.askCommitment}/6');
          row++;
        }
        if (report.bridging != null) {
          setCell(1, row, 'Bridging to next product(s):');
          setCell(2, row, '${report.bridging}/6');
          row++;
        }
        if (report.selfAssessment != null) {
          setCell(1, row, 'Self-assessment & Updating customer profile:');
          setCell(2, row, '${report.selfAssessment}/6');
          row++;
        }
        if (report.strengths != null && report.strengths!.isNotEmpty) {
          setCell(1, row, 'Strengths:');
          setCell(2, row, report.strengths!);
          row++;
        }
        if (report.improvements != null && report.improvements!.isNotEmpty) {
          setCell(1, row, 'Areas of Improvement:');
          setCell(2, row, report.improvements!);
          row++;
        }
        if (report.filledWithMR != null) {
          setCell(1, row, 'Filled with MR:');
          setCell(2, row, report.filledWithMR!);
          row++;
        }
      }
    }
    
    row += 2;
    final timestampRange = sheet.getRangeByIndex(row, 1, row, 2);
    timestampRange.setText('Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    timestampRange.merge();
    _applyDataStyle(timestampRange.cellStyle);
    
    // Auto-fit columns based on content (finds largest cell in each column)
    sheet.autoFitColumn(1); // Labels column
    sheet.autoFitColumn(2); // Values column
    
    // Save file
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    
    final filename = 'coaching_report_${report.mrName.replaceAll(' ', '_')}_${report.date}.xlsx';
    final filePath = await _saveAndShareExcel(bytes, filename);
    return filePath;
  }

  // Export monthly report to Excel
  static Future<String> exportMonthlyReport(List<CoachingReport> reports, String? dmName) async {
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

    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Monthly Report';
    
    // Note: Column widths will be auto-fitted based on content (headers + data)
    // No initial widths set - autoFitColumn will calculate based on all cells
    
    int row = 1;
    
    // Helper function to set cell with style
    void setCell(int col, int r, String value, {String style = 'data'}) {
      final range = sheet.getRangeByIndex(r, col);
      range.setText(value);
      final cellStyle = range.cellStyle;
      switch (style) {
        case 'mainHeader':
          _applyHeaderStyle(cellStyle, isMainHeader: true);
          break;
        case 'sectionHeader':
          _applySectionHeaderStyle(cellStyle);
          break;
        case 'label':
          _applyLabelStyle(cellStyle);
          break;
        case 'tableHeader':
          _applyTableHeaderStyle(cellStyle);
          break;
        default:
          _applyDataStyle(cellStyle);
      }
    }
    
    // Header
    final headerRange1 = sheet.getRangeByIndex(row, 1, row, 4);
    headerRange1.setText('BIOSYN PHARMACEUTICALS');
    headerRange1.merge();
    _applyHeaderStyle(headerRange1.cellStyle, isMainHeader: true);
    row++;
    
    final headerRange2 = sheet.getRangeByIndex(row, 1, row, 4);
    headerRange2.setText('MONTHLY COACHING REPORT');
    headerRange2.merge();
    _applyHeaderStyle(headerRange2.cellStyle, isMainHeader: true);
    row++;
    
    final monthRange = sheet.getRangeByIndex(row, 1, row, 4);
    monthRange.setText(monthName);
    monthRange.merge();
    _applyHeaderStyle(monthRange.cellStyle, isMainHeader: true);
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
    
    final summaryHeader = sheet.getRangeByIndex(row, 1, row, 2);
    summaryHeader.setText('SUMMARY');
    summaryHeader.merge();
    _applySectionHeaderStyle(summaryHeader.cellStyle);
    row++;
    
    if (dmName != null) {
      setCell(1, row, 'District Manager:', style: 'label');
      setCell(2, row, dmName);
      row++;
    }
    setCell(1, row, 'Total Field Visits:', style: 'label');
    setCell(2, row, totalVisits.toString());
    row++;
    setCell(1, row, 'Average Score:', style: 'label');
    setCell(2, row, '$avgScore / 6.0');
    row++;
    setCell(1, row, 'Medical Reps Coached:', style: 'label');
    setCell(2, row, uniqueMRs.toString());
    row += 2;
    
    // Detailed Visits - Table headers
    setCell(1, row, 'Date', style: 'tableHeader');
    setCell(2, row, 'Coach', style: 'tableHeader');
    setCell(3, row, 'Coach Role', style: 'tableHeader');
    setCell(4, row, 'MR Name', style: 'tableHeader');
    setCell(5, row, 'MR ID', style: 'tableHeader');
    setCell(6, row, 'Score', style: 'tableHeader');
    setCell(7, row, 'Punctuality', style: 'tableHeader');
    setCell(8, row, 'Dress Code', style: 'tableHeader');
    setCell(9, row, 'Time Management', style: 'tableHeader');
    setCell(10, row, 'Pharmacy Feedback', style: 'tableHeader');
    setCell(11, row, 'Review Profile', style: 'tableHeader');
    setCell(12, row, 'Brand Bonding', style: 'tableHeader');
    setCell(13, row, 'SMART Objectives', style: 'tableHeader');
    setCell(14, row, 'Opening', style: 'tableHeader');
    setCell(15, row, 'Patient Profile', style: 'tableHeader');
    setCell(16, row, 'Engaging', style: 'tableHeader');
    setCell(17, row, 'Insightful Questions', style: 'tableHeader');
    setCell(18, row, 'Active Listening', style: 'tableHeader');
    setCell(19, row, 'Link Features', style: 'tableHeader');
    setCell(20, row, 'Product Knowledge', style: 'tableHeader');
    setCell(21, row, 'E-detailing', style: 'tableHeader');
    setCell(22, row, 'Answering Questions', style: 'tableHeader');
    setCell(23, row, 'Summarize Call', style: 'tableHeader');
    setCell(24, row, 'Ask Commitment', style: 'tableHeader');
    setCell(25, row, 'Bridging', style: 'tableHeader');
    setCell(26, row, 'Self Assessment', style: 'tableHeader');
    setCell(27, row, 'Strengths', style: 'tableHeader');
    setCell(28, row, 'Areas of Improvement', style: 'tableHeader');
    setCell(29, row, 'Filled with MR', style: 'tableHeader');
    setCell(30, row, 'Brick Name', style: 'tableHeader');
    setCell(31, row, 'Location', style: 'tableHeader');
    setCell(32, row, 'Visits Count', style: 'tableHeader');
    setCell(33, row, 'Doctors Visited', style: 'tableHeader');
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
      
      setCell(1, row, report.date);
      setCell(2, row, coachName);
      setCell(3, row, report.coachRole ?? 'dm');
      setCell(4, row, report.mrName);
      setCell(5, row, report.mrId);
      setCell(6, row, score);
      setCell(7, row, report.punctuality ?? '');
      setCell(8, row, report.dressCode ?? '');
      setCell(9, row, report.timeManagement ?? '');
      setCell(10, row, report.pharmacyFeedback != null ? '${report.pharmacyFeedback}/6' : '');
      setCell(11, row, report.reviewProfile != null ? '${report.reviewProfile}/6' : '');
      setCell(12, row, report.brandBonding != null ? '${report.brandBonding}/6' : '');
      setCell(13, row, report.smartObjectives != null ? '${report.smartObjectives}/6' : '');
      setCell(14, row, report.opening != null ? '${report.opening}/6' : '');
      setCell(15, row, report.patientProfile != null ? '${report.patientProfile}/6' : '');
      setCell(16, row, report.engaging != null ? '${report.engaging}/6' : '');
      setCell(17, row, report.insightfulQuestions != null ? '${report.insightfulQuestions}/6' : '');
      setCell(18, row, report.activeListening != null ? '${report.activeListening}/6' : '');
      setCell(19, row, report.linkFeatures != null ? '${report.linkFeatures}/6' : '');
      setCell(20, row, report.productKnowledge != null ? '${report.productKnowledge}/6' : '');
      setCell(21, row, report.eDetailing != null ? '${report.eDetailing}/6' : '');
      setCell(22, row, report.answeringQuestions != null ? '${report.answeringQuestions}/6' : '');
      setCell(23, row, report.summarizeCall != null ? '${report.summarizeCall}/6' : '');
      setCell(24, row, report.askCommitment != null ? '${report.askCommitment}/6' : '');
      setCell(25, row, report.bridging != null ? '${report.bridging}/6' : '');
      setCell(26, row, report.selfAssessment != null ? '${report.selfAssessment}/6' : '');
      setCell(27, row, strengthsShort);
      setCell(28, row, improvementsShort);
      setCell(29, row, report.filledWithMR ?? '');
      setCell(30, row, report.brickName ?? '');
      setCell(31, row, report.googleMapsUrl ?? '');
      setCell(32, row, report.visitCount?.toString() ?? '');
      setCell(33, row, report.doctorsVisited ?? '');
      row++;
    }
    
    row += 2;
    final timestampRange = sheet.getRangeByIndex(row, 1, row, 4);
    timestampRange.setText('Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}');
    timestampRange.merge();
    _applyDataStyle(timestampRange.cellStyle);
    
    // Find header row (where table headers are written)
    final headerRow = 605; // Row where table headers start
    
    // Auto-fit all columns based on content (including headers)
    // This ensures headers with multiple words are fully visible
    for (int col = 1; col <= 33; col++) {
      // First, auto-fit the column
      sheet.autoFitColumn(col);
      
      // Get the header text to ensure it's fully visible
      final headerRange = sheet.getRangeByIndex(headerRow, col);
      final headerText = headerRange.displayText;
      
      // If header has multiple words, ensure column is wide enough
      if (headerText.isNotEmpty && headerText.contains(' ')) {
        // Calculate approximate width needed for header (7 pixels per character + padding)
        final headerWidth = (headerText.length * 7.0) + 30.0; // Extra padding for multi-word headers
        
        // Apply the calculated width to ensure header is fully visible
        sheet.setColumnWidthInPixels(col, headerWidth.round());
      }
    }
    
    // Save file
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    
    final filename = 'monthly_report_${monthName.replaceAll(' ', '_')}.xlsx';
    final filePath = await _saveAndShareExcel(bytes, filename);
    return filePath;
  }

  // Export all reports to Excel
  static Future<String> exportAllReportsToText(List<CoachingReport> reports) async {
    if (reports.isEmpty) {
      throw Exception('No reports to export');
    }

    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'All Reports';
    
    // Note: Column widths will be auto-fitted based on content (headers + data)
    // No initial widths set - autoFitColumn will calculate based on all cells
    
    int row = 1;
    final reportDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Helper function to set cell with style
    void setCell(int col, int r, String value, {String style = 'data'}) {
      final range = sheet.getRangeByIndex(r, col);
      range.setText(value);
      final cellStyle = range.cellStyle;
      switch (style) {
        case 'mainHeader':
          _applyHeaderStyle(cellStyle, isMainHeader: true);
          break;
        case 'sectionHeader':
          _applySectionHeaderStyle(cellStyle);
          break;
        case 'label':
          _applyLabelStyle(cellStyle);
          break;
        case 'tableHeader':
          _applyTableHeaderStyle(cellStyle);
          break;
        default:
          _applyDataStyle(cellStyle);
      }
    }
    
    // Header
    final headerRange1 = sheet.getRangeByIndex(row, 1, row, 4);
    headerRange1.setText('BIOSYN PHARMACEUTICALS');
    headerRange1.merge();
    _applyHeaderStyle(headerRange1.cellStyle, isMainHeader: true);
    row++;
    
    final headerRange2 = sheet.getRangeByIndex(row, 1, row, 4);
    headerRange2.setText('ALL COACHING REPORTS');
    headerRange2.merge();
    _applyHeaderStyle(headerRange2.cellStyle, isMainHeader: true);
    row += 2;
    
    setCell(1, row, 'Total Reports:', style: 'label');
    setCell(2, row, reports.length.toString());
    row++;
    
    final uniqueDMs = reports.map((r) => r.dmName).where((name) => name.isNotEmpty).toSet().length;
    setCell(1, row, 'District Managers:', style: 'label');
    setCell(2, row, uniqueDMs.toString());
    row++;
    setCell(1, row, 'Export Date:', style: 'label');
    setCell(2, row, reportDate);
    row += 2;
    
    // Table Headers
    setCell(1, row, 'Date', style: 'tableHeader');
    setCell(2, row, 'Coach', style: 'tableHeader');
    setCell(3, row, 'Coach Role', style: 'tableHeader');
    setCell(4, row, 'MR Name', style: 'tableHeader');
    setCell(5, row, 'MR ID', style: 'tableHeader');
    setCell(6, row, 'Score', style: 'tableHeader');
    setCell(7, row, 'Punctuality', style: 'tableHeader');
    setCell(8, row, 'Dress Code', style: 'tableHeader');
    setCell(9, row, 'Time Management', style: 'tableHeader');
    setCell(10, row, 'Pharmacy Feedback', style: 'tableHeader');
    setCell(11, row, 'Review Profile', style: 'tableHeader');
    setCell(12, row, 'Brand Bonding', style: 'tableHeader');
    setCell(13, row, 'SMART Objectives', style: 'tableHeader');
    setCell(14, row, 'Opening', style: 'tableHeader');
    setCell(15, row, 'Patient Profile', style: 'tableHeader');
    setCell(16, row, 'Engaging', style: 'tableHeader');
    setCell(17, row, 'Insightful Questions', style: 'tableHeader');
    setCell(18, row, 'Active Listening', style: 'tableHeader');
    setCell(19, row, 'Link Features', style: 'tableHeader');
    setCell(20, row, 'Product Knowledge', style: 'tableHeader');
    setCell(21, row, 'E-detailing', style: 'tableHeader');
    setCell(22, row, 'Answering Questions', style: 'tableHeader');
    setCell(23, row, 'Summarize Call', style: 'tableHeader');
    setCell(24, row, 'Ask Commitment', style: 'tableHeader');
    setCell(25, row, 'Bridging', style: 'tableHeader');
    setCell(26, row, 'Self Assessment', style: 'tableHeader');
    setCell(27, row, 'Strengths', style: 'tableHeader');
    setCell(28, row, 'Areas of Improvement', style: 'tableHeader');
    setCell(29, row, 'Filled with MR', style: 'tableHeader');
    setCell(30, row, 'Brick Name', style: 'tableHeader');
    setCell(31, row, 'Location', style: 'tableHeader');
    setCell(32, row, 'Visits Count', style: 'tableHeader');
    setCell(33, row, 'Doctors Visited', style: 'tableHeader');
    setCell(34, row, 'Type of Visit', style: 'tableHeader');
    setCell(35, row, 'Visited Accounts', style: 'tableHeader');
    setCell(36, row, 'General Feedback', style: 'tableHeader');
    setCell(37, row, 'Teamwork', style: 'tableHeader');
    setCell(38, row, 'Customer Awareness', style: 'tableHeader');
    setCell(39, row, 'Medical Product Knowledge DM', style: 'tableHeader');
    setCell(40, row, 'DM Feedback Comments', style: 'tableHeader');
    setCell(41, row, 'Patient Centric Approach', style: 'tableHeader');
    setCell(42, row, 'Medical Product Knowledge MR', style: 'tableHeader');
    setCell(43, row, 'Feature Benefits', style: 'tableHeader');
    setCell(44, row, 'Closing Commitment', style: 'tableHeader');
    setCell(45, row, 'MR Feedback Comments', style: 'tableHeader');
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
      
      setCell(1, row, report.date);
      setCell(2, row, coachName);
      setCell(3, row, report.coachRole ?? 'dm');
      setCell(4, row, report.mrName);
      setCell(5, row, report.mrId);
      setCell(6, row, score);
      setCell(7, row, report.punctuality ?? '');
      setCell(8, row, report.dressCode ?? '');
      setCell(9, row, report.timeManagement ?? '');
      setCell(10, row, report.pharmacyFeedback != null ? '${report.pharmacyFeedback}/6' : '');
      setCell(11, row, report.reviewProfile != null ? '${report.reviewProfile}/6' : '');
      setCell(12, row, report.brandBonding != null ? '${report.brandBonding}/6' : '');
      setCell(13, row, report.smartObjectives != null ? '${report.smartObjectives}/6' : '');
      setCell(14, row, report.opening != null ? '${report.opening}/6' : '');
      setCell(15, row, report.patientProfile != null ? '${report.patientProfile}/6' : '');
      setCell(16, row, report.engaging != null ? '${report.engaging}/6' : '');
      setCell(17, row, report.insightfulQuestions != null ? '${report.insightfulQuestions}/6' : '');
      setCell(18, row, report.activeListening != null ? '${report.activeListening}/6' : '');
      setCell(19, row, report.linkFeatures != null ? '${report.linkFeatures}/6' : '');
      setCell(20, row, report.productKnowledge != null ? '${report.productKnowledge}/6' : '');
      setCell(21, row, report.eDetailing != null ? '${report.eDetailing}/6' : '');
      setCell(22, row, report.answeringQuestions != null ? '${report.answeringQuestions}/6' : '');
      setCell(23, row, report.summarizeCall != null ? '${report.summarizeCall}/6' : '');
      setCell(24, row, report.askCommitment != null ? '${report.askCommitment}/6' : '');
      setCell(25, row, report.bridging != null ? '${report.bridging}/6' : '');
      setCell(26, row, report.selfAssessment != null ? '${report.selfAssessment}/6' : '');
      setCell(27, row, strengthsShort);
      setCell(28, row, improvementsShort);
      setCell(29, row, report.filledWithMR ?? '');
      setCell(30, row, report.brickName ?? report.areaBrickName ?? '');
      setCell(31, row, report.googleMapsUrl ?? '');
      setCell(32, row, report.visitCount?.toString() ?? '');
      setCell(33, row, report.doctorsVisited ?? '');
      setCell(34, row, report.typeOfVisit ?? '');
      setCell(35, row, report.visitedAccountsNames ?? '');
      setCell(36, row, generalFeedbackShort);
      setCell(37, row, report.teamwork ?? '');
      setCell(38, row, report.customerAwareness ?? '');
      setCell(39, row, report.medicalProductKnowledgeDM ?? '');
      setCell(40, row, dmFeedbackCommentsShort);
      setCell(41, row, report.patientCentricApproach != null ? '${report.patientCentricApproach}/6' : '');
      setCell(42, row, report.medicalProductKnowledgeMR != null ? '${report.medicalProductKnowledgeMR}/6' : '');
      setCell(43, row, report.featureBenefits != null ? '${report.featureBenefits}/6' : '');
      setCell(44, row, report.closingCommitment != null ? '${report.closingCommitment}/6' : '');
      setCell(45, row, mrFeedbackCommentsShort);
      row++;
    }
    
    row += 2;
    final timestampRange = sheet.getRangeByIndex(row, 1, row, 4);
    timestampRange.setText('Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    timestampRange.merge();
    _applyDataStyle(timestampRange.cellStyle);
    
    // Find header row (where table headers are written)
    final headerRow = 777; // Row where table headers start
    
    // Auto-fit all columns based on content (including headers)
    // This ensures headers with multiple words are fully visible
    for (int col = 1; col <= 45; col++) {
      // First, auto-fit the column
      sheet.autoFitColumn(col);
      
      // Get the header text to ensure it's fully visible
      final headerRange = sheet.getRangeByIndex(headerRow, col);
      final headerText = headerRange.displayText;
      
      // If header has multiple words, ensure column is wide enough
      if (headerText.isNotEmpty && headerText.contains(' ')) {
        // Calculate approximate width needed for header (7 pixels per character + padding)
        final headerWidth = (headerText.length * 7.0) + 30.0; // Extra padding for multi-word headers
        
        // Apply the calculated width to ensure header is fully visible
        sheet.setColumnWidthInPixels(col, headerWidth.round());
      }
    }
    
    // Save file
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    
    final filename = 'all_coaching_reports_$reportDate.xlsx';
    final filePath = await _saveAndShareExcel(bytes, filename);
    return filePath;
  }

  // Helper method to save Excel file and share via WhatsApp
  static Future<String> _saveAndShareExcel(List<int> bytes, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$filename';
      final file = File(filePath);
      
      await file.writeAsBytes(bytes);
      debugPrint('✅ File saved to temporary location: $filePath');
      debugPrint('📊 File size: ${bytes.length} bytes');
      
      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        text: 'Coaching Report',
        subject: filename,
      );
      
      debugPrint('✅ File shared successfully');
      return filePath;
    } catch (e) {
      debugPrint('❌ Error saving and sharing file: $e');
      rethrow;
    }
  }

  // Legacy method for CSV (kept for backward compatibility)
  static Future<void> exportToCSV(List<CoachingReport> reports, String filename) async {
    await exportAllReportsToText(reports);
  }
}
