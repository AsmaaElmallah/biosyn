class CoachingReport {
  final String date;
  final String dmId;
  final String dmName;
  final String mrId;
  final String mrName;
  
  // Coach Role (dm, ft, pm, msl)
  final String? coachRole;
  
  // Brick Information (for all forms)
  final String? brickName;
  final double? brickLocationLat;
  final double? brickLocationLng;
  final String? locationName; // Name from Google Maps
  final String? googleMapsUrl; // Google Maps link
  final int? visitCount;
  final String? doctorsVisited; // Comma-separated list
  
  // DM/FT Form Fields
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
  
  // PM/MSL Form Fields
  final String? areaBrickName; // "Area & Brick Name"
  final String? typeOfVisit; // DM, Single, Double, Triple
  final String? visitedAccountsNames;
  final String? generalFeedback; // "General Feedback and Special Insights"
  final String? customerAwareness; // High, Medium, Low
  final String? medicalProductKnowledgeDM; // High, Medium, Low
  final String? dmFeedbackComments; // "DM Feedback Comments and Insights"
  final String? patientCentricApproach; // 1-6 scale
  final String? medicalProductKnowledgeMR; // 1-6 scale
  final String? featureBenefits; // 1-6 scale
  final String? closingCommitment; // 1-6 scale
  final String? mrFeedbackComments; // "MR Feedback Comments and Insights"
  
  // Quick Session Flag
  final bool? isQuickSession; // True if session started without a plan

  CoachingReport({
    required this.date,
    required this.dmId,
    required this.dmName,
    required this.mrId,
    required this.mrName,
    this.coachRole,
    this.brickName,
    this.brickLocationLat,
    this.brickLocationLng,
    this.locationName,
    this.googleMapsUrl,
    this.visitCount,
    this.doctorsVisited,
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
    this.areaBrickName,
    this.typeOfVisit,
    this.visitedAccountsNames,
    this.generalFeedback,
    this.customerAwareness,
    this.medicalProductKnowledgeDM,
    this.dmFeedbackComments,
    this.patientCentricApproach,
    this.medicalProductKnowledgeMR,
    this.featureBenefits,
    this.closingCommitment,
    this.mrFeedbackComments,
    this.isQuickSession,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'dmId': dmId,
      'dmName': dmName,
      'mrId': mrId,
      'mrName': mrName,
      'coachRole': coachRole,
      'brickName': brickName,
      'brickLocationLat': brickLocationLat,
      'brickLocationLng': brickLocationLng,
      'locationName': locationName,
      'googleMapsUrl': googleMapsUrl,
      'visitCount': visitCount,
      'doctorsVisited': doctorsVisited,
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
      'areaBrickName': areaBrickName,
      'typeOfVisit': typeOfVisit,
      'visitedAccountsNames': visitedAccountsNames,
      'generalFeedback': generalFeedback,
      'customerAwareness': customerAwareness,
      'medicalProductKnowledgeDM': medicalProductKnowledgeDM,
      'dmFeedbackComments': dmFeedbackComments,
      'patientCentricApproach': patientCentricApproach,
      'medicalProductKnowledgeMR': medicalProductKnowledgeMR,
      'featureBenefits': featureBenefits,
      'closingCommitment': closingCommitment,
      'mrFeedbackComments': mrFeedbackComments,
      'isQuickSession': isQuickSession,
    };
  }

  factory CoachingReport.fromJson(Map<String, dynamic> json) {
    return CoachingReport(
      date: json['date'] ?? '',
      dmId: json['dmId'] ?? '',
      dmName: json['dmName'] ?? '',
      mrId: json['mrId'] ?? '',
      mrName: json['mrName'] ?? '',
      coachRole: json['coachRole'],
      brickName: json['brickName'],
      brickLocationLat: json['brickLocationLat'] != null ? double.tryParse(json['brickLocationLat'].toString()) : null,
      brickLocationLng: json['brickLocationLng'] != null ? double.tryParse(json['brickLocationLng'].toString()) : null,
      locationName: json['locationName'],
      googleMapsUrl: json['googleMapsUrl'],
      visitCount: json['visitCount'] != null ? int.tryParse(json['visitCount'].toString()) : null,
      doctorsVisited: json['doctorsVisited'],
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
      areaBrickName: json['areaBrickName'],
      typeOfVisit: json['typeOfVisit'],
      visitedAccountsNames: json['visitedAccountsNames'],
      generalFeedback: json['generalFeedback'],
      customerAwareness: json['customerAwareness'],
      medicalProductKnowledgeDM: json['medicalProductKnowledgeDM'],
      dmFeedbackComments: json['dmFeedbackComments'],
      patientCentricApproach: json['patientCentricApproach'],
      medicalProductKnowledgeMR: json['medicalProductKnowledgeMR'],
      featureBenefits: json['featureBenefits'],
      closingCommitment: json['closingCommitment'],
      mrFeedbackComments: json['mrFeedbackComments'],
      isQuickSession: json['isQuickSession'] == true || json['isQuickSession'] == 1,
    );
  }

  /// From Supabase JSON (snake_case)
  factory CoachingReport.fromSupabaseJson(Map<String, dynamic> json) {
    return CoachingReport(
      date: json['date']?.toString() ?? '',
      dmId: json['dm_id']?.toString() ?? '',
      dmName: json['dm_name']?.toString() ?? '',
      mrId: json['mr_id']?.toString() ?? '',
      mrName: json['mr_name']?.toString() ?? '',
      coachRole: json['coach_role']?.toString(),
      brickName: json['brick_name']?.toString(),
      brickLocationLat: json['brick_location_lat'] != null ? double.tryParse(json['brick_location_lat'].toString()) : null,
      brickLocationLng: json['brick_location_lng'] != null ? double.tryParse(json['brick_location_lng'].toString()) : null,
      locationName: json['location_name']?.toString(),
      googleMapsUrl: json['google_maps_url']?.toString(),
      visitCount: json['visit_count'] != null ? int.tryParse(json['visit_count'].toString()) : null,
      doctorsVisited: json['doctors_visited']?.toString(),
      punctuality: json['punctuality']?.toString(),
      dressCode: json['dress_code']?.toString(),
      timeManagement: json['time_management']?.toString(),
      pharmacyFeedback: json['pharmacy_feedback']?.toString(),
      reviewProfile: json['review_profile']?.toString(),
      brandBonding: json['brand_bonding']?.toString(),
      smartObjectives: json['smart_objectives']?.toString(),
      opening: json['opening']?.toString(),
      patientProfile: json['patient_profile']?.toString(),
      engaging: json['engaging']?.toString(),
      insightfulQuestions: json['insightful_questions']?.toString(),
      activeListening: json['active_listening']?.toString(),
      linkFeatures: json['link_features']?.toString(),
      productKnowledge: json['product_knowledge']?.toString(),
      eDetailing: json['e_detailing']?.toString(),
      answeringQuestions: json['answering_questions']?.toString(),
      summarizeCall: json['summarize_call']?.toString(),
      askCommitment: json['ask_commitment']?.toString(),
      bridging: json['bridging']?.toString(),
      selfAssessment: json['self_assessment']?.toString(),
      strengths: json['strengths']?.toString(),
      improvements: json['improvements']?.toString(),
      filledWithMR: json['filled_with_mr']?.toString(),
      areaBrickName: json['area_brick_name']?.toString(),
      typeOfVisit: json['type_of_visit']?.toString(),
      visitedAccountsNames: json['visited_accounts_names']?.toString(),
      generalFeedback: json['general_feedback']?.toString(),
      customerAwareness: json['customer_awareness']?.toString(),
      medicalProductKnowledgeDM: json['medical_product_knowledge_dm']?.toString(),
      dmFeedbackComments: json['dm_feedback_comments']?.toString(),
      patientCentricApproach: json['patient_centric_approach']?.toString(),
      medicalProductKnowledgeMR: json['medical_product_knowledge_mr']?.toString(),
      featureBenefits: json['feature_benefits']?.toString(),
      closingCommitment: json['closing_commitment']?.toString(),
      mrFeedbackComments: json['mr_feedback_comments']?.toString(),
      isQuickSession: json['is_quick_session'] == true || json['is_quick_session'] == 1,
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

