class CoachingReport {
  final String date;
  final String dmId;
  final String dmName;
  final String mrId;
  final String mrName;
  final String? punctuality;
  final String? dressCode;
  final String? timeManagement;
  final String? pharmacyFeedback;
  final String? reviewProfile;
  final String? brandBonding;
  final String? smartObjectives;
  final String? opening;
  final String? patientProfile;
  final String? engaging;
  final String? insightfulQuestions;
  final String? activeListening;
  final String? linkFeatures;
  final String? productKnowledge;
  final String? eDetailing;
  final String? answeringQuestions;
  final String? summarizeCall;
  final String? askCommitment;
  final String? bridging;
  final String? selfAssessment;
  final String? strengths;
  final String? improvements;
  final String? filledWithMR;

  CoachingReport({
    required this.date,
    required this.dmId,
    required this.dmName,
    required this.mrId,
    required this.mrName,
    this.punctuality,
    this.dressCode,
    this.timeManagement,
    this.pharmacyFeedback,
    this.reviewProfile,
    this.brandBonding,
    this.smartObjectives,
    this.opening,
    this.patientProfile,
    this.engaging,
    this.insightfulQuestions,
    this.activeListening,
    this.linkFeatures,
    this.productKnowledge,
    this.eDetailing,
    this.answeringQuestions,
    this.summarizeCall,
    this.askCommitment,
    this.bridging,
    this.selfAssessment,
    this.strengths,
    this.improvements,
    this.filledWithMR,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'dmId': dmId,
      'dmName': dmName,
      'mrId': mrId,
      'mrName': mrName,
      'punctuality': punctuality,
      'dressCode': dressCode,
      'timeManagement': timeManagement,
      'pharmacyFeedback': pharmacyFeedback,
      'reviewProfile': reviewProfile,
      'brandBonding': brandBonding,
      'smartObjectives': smartObjectives,
      'opening': opening,
      'patientProfile': patientProfile,
      'engaging': engaging,
      'insightfulQuestions': insightfulQuestions,
      'activeListening': activeListening,
      'linkFeatures': linkFeatures,
      'productKnowledge': productKnowledge,
      'eDetailing': eDetailing,
      'answeringQuestions': answeringQuestions,
      'summarizeCall': summarizeCall,
      'askCommitment': askCommitment,
      'bridging': bridging,
      'selfAssessment': selfAssessment,
      'strengths': strengths,
      'improvements': improvements,
      'filledWithMR': filledWithMR,
    };
  }

  factory CoachingReport.fromJson(Map<String, dynamic> json) {
    return CoachingReport(
      date: json['date'] ?? '',
      dmId: json['dmId'] ?? '',
      dmName: json['dmName'] ?? '',
      mrId: json['mrId'] ?? '',
      mrName: json['mrName'] ?? '',
      punctuality: json['punctuality'],
      dressCode: json['dressCode'],
      timeManagement: json['timeManagement'],
      pharmacyFeedback: json['pharmacyFeedback'],
      reviewProfile: json['reviewProfile'],
      brandBonding: json['brandBonding'],
      smartObjectives: json['smartObjectives'],
      opening: json['opening'],
      patientProfile: json['patientProfile'],
      engaging: json['engaging'],
      insightfulQuestions: json['insightfulQuestions'],
      activeListening: json['activeListening'],
      linkFeatures: json['linkFeatures'],
      productKnowledge: json['productKnowledge'],
      eDetailing: json['eDetailing'],
      answeringQuestions: json['answeringQuestions'],
      summarizeCall: json['summarizeCall'],
      askCommitment: json['askCommitment'],
      bridging: json['bridging'],
      selfAssessment: json['selfAssessment'],
      strengths: json['strengths'],
      improvements: json['improvements'],
      filledWithMR: json['filledWithMR'],
    );
  }

  double getAverageScore() {
    final scores = [
      pharmacyFeedback,
      reviewProfile,
      brandBonding,
      smartObjectives,
      opening,
      patientProfile,
      engaging,
      insightfulQuestions,
      activeListening,
      linkFeatures,
      productKnowledge,
      eDetailing,
      answeringQuestions,
      summarizeCall,
      askCommitment,
      bridging,
      selfAssessment,
    ].where((s) => s != null).map((s) => double.tryParse(s!) ?? 0.0).toList();

    if (scores.isEmpty) return 0.0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }
}

