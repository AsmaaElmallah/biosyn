import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:geolocator/geolocator.dart';
import 'package:biosyn_report_flutter/utils/error_handler.dart';

class PMMSLCoachingFormScreen extends StatefulWidget {
  final String date;
  final String coachId;
  final String coachName;
  final String coachRole; // 'pm' or 'msl'
  final String? dmId; // Optional - if provided, pre-select DM
  final String? dmName; // Optional - if provided, pre-select DM
  final String? mrId; // Optional - if provided, pre-select MR
  final String? mrName; // Optional - if provided, pre-select MR
  final bool isQuickSession; // True if started without a plan
  final Future<void> Function(CoachingReport) onSubmit;
  final VoidCallback onBack;

  const PMMSLCoachingFormScreen({
    super.key,
    required this.date,
    required this.coachId,
    required this.coachName,
    required this.coachRole,
    this.dmId,
    this.dmName,
    this.mrId,
    this.mrName,
    this.isQuickSession = false,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<PMMSLCoachingFormScreen> createState() => _PMMSLCoachingFormScreenState();
}

class _PMMSLCoachingFormScreenState extends State<PMMSLCoachingFormScreen> {
  final Map<String, String?> _formData = {};
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false; // Loading state for submit button

  // Controllers
  late final TextEditingController _areaBrickNameController;
  late final TextEditingController _generalFeedbackController;
  late final TextEditingController _dmFeedbackCommentsController;
  late final TextEditingController _mrFeedbackCommentsController;
  late final TextEditingController _doctorsVisitedController;

  // Dropdown data - no longer needed, DM and MR are passed from previous screen


  @override
  void initState() {
    super.initState();
    _formData['date'] = widget.date;
    _formData['coachId'] = widget.coachId;
    _formData['coachName'] = widget.coachName;
    _formData['coachRole'] = widget.coachRole;
    
    // Pre-fill DM and MR if provided
    if (widget.dmId != null) {
      _formData['dmId'] = widget.dmId;
    }
    if (widget.mrId != null) {
      _formData['mrId'] = widget.mrId;
    }
    
    _areaBrickNameController = TextEditingController();
    _generalFeedbackController = TextEditingController();
    _dmFeedbackCommentsController = TextEditingController();
    _mrFeedbackCommentsController = TextEditingController();
    _doctorsVisitedController = TextEditingController();

    // No need to load dropdowns - DM and MR are passed from previous screen
  }

  @override
  void dispose() {
    _areaBrickNameController.dispose();
    _generalFeedbackController.dispose();
    _dmFeedbackCommentsController.dispose();
    _mrFeedbackCommentsController.dispose();
    _doctorsVisitedController.dispose();
    super.dispose();
  }

  void _updateField(String field, String value) {
    setState(() {
      _formData[field] = value;
    });
  }

  /// Determine visit type automatically based on DM and MR selection
  String _determineVisitType() {
    final hasDM = widget.dmId != null && widget.dmId!.isNotEmpty;
    final hasMR = widget.mrId != null && widget.mrId!.isNotEmpty;
    
    if (!hasDM && !hasMR) {
      return 'Single'; // No DM, No MR = Single
    } else if (!hasDM && hasMR) {
      return 'Double'; // No DM, Has MR = Double with MR only
    } else if (hasDM && !hasMR) {
      return 'Double'; // Has DM, No MR = Double with DM only
    } else {
      return 'Triple'; // Has DM, Has MR = Triple
    }
  }

  bool _validateAllFields() {
    final typeOfVisit = _determineVisitType();
    List<String> requiredFields = [];
    
    // Always required
    requiredFields.addAll(['areaBrickName']);
    
    // Based on type of visit
    if (typeOfVisit == 'Single') {
      // Single: Only general fields required (no DM or MR questions)
      // No additional required fields beyond areaBrickName
    } else if (typeOfVisit == 'Double') {
      // Double: Check if it's with DM or MR
      final hasDM = widget.dmId != null && widget.dmId!.isNotEmpty;
      final hasMR = widget.mrId != null && widget.mrId!.isNotEmpty;
      
      if (hasDM && !hasMR) {
        // Double with DM only: DM questions required
        requiredFields.addAll(['customerAwareness', 'medicalProductKnowledgeDM']);
      } else if (!hasDM && hasMR) {
        // Double with MR only: MR questions required
        requiredFields.addAll(['punctuality', 'dressCode', 'pharmacyFeedback']);
      }
    } else if (typeOfVisit == 'Triple') {
      // Triple: Both DM and MR Feedback required
      requiredFields.addAll(['customerAwareness', 'medicalProductKnowledgeDM', 'punctuality', 'dressCode', 'pharmacyFeedback']);
    }
    
    return requiredFields.every((field) => _formData[field] != null && _formData[field]!.isNotEmpty);
  }

  Future<void> _handleSubmit() async {
    // Prevent multiple submissions
    if (_isSubmitting) {
      debugPrint('⚠️ Submit already in progress, ignoring duplicate submit');
      return;
    }
    
    if (!_validateAllFields()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }
    
    // Set loading state
    setState(() {
      _isSubmitting = true;
    });

    // Verify Location Services and Permission before allowing submit
    // User should not know we're taking location - show generic "Verifying..." message
    double? lat;
    double? lng;
    String? locationName;
    String? googleMapsUrl;
    
    try {
      // Step 1: Check if Location Services are enabled
      debugPrint('📍 Step 1: Checking Location Services...');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location Services are disabled');
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى تفعيل خدمات الموقع من إعدادات الهاتف'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      debugPrint('✅ Location Services are enabled');
      
      // Step 2: Check and request permission if needed
      debugPrint('📍 Step 2: Checking Location Permission...');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ Location permission denied, requesting...');
        permission = await Geolocator.requestPermission();
      }
      
      // Step 3: Verify permission is granted
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        debugPrint('❌ Location permission not granted: $permission');
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى السماح بالوصول للموقع من إعدادات التطبيق'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      debugPrint('✅ Location Permission granted: $permission');
      
      // Step 4: Try to get current location with timeout
      debugPrint('📍 Step 4: Attempting to get current location...');
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10), // 10 second timeout
        );
        
        // Verify location accuracy (optional - can be removed if too strict)
        if (position.accuracy > 100) {
          debugPrint('⚠️ Location accuracy is low: ${position.accuracy}m');
          // Still accept it, but log a warning
        }
        
        lat = position.latitude;
        lng = position.longitude;
        locationName = 'Location at ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
        googleMapsUrl = 'https://www.google.com/maps?q=$lat,$lng';
        
        debugPrint('✅ Location captured successfully: $lat, $lng');
      } catch (e) {
        // Location capture failed - GPS not available
        debugPrint('❌ Failed to get location: $e');
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى الانتظار حتى يتوفر GPS أو تحقق من إعدادات الموقع'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    } catch (e, stackTrace) {
      // Unexpected error
      debugPrint('❌ Unexpected error checking location: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ في التحقق من الموقع. يرجى المحاولة مرة أخرى'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    // Location verified successfully - continue with report submission
    debugPrint('✅ Location verification passed, proceeding with report submission...');

    // Get DM and MR names from widget (passed from previous screen)
    final selectedDMName = widget.dmName ?? '';
    final selectedMRName = widget.mrName ?? '';

    // For PM/MSL: dmId in report should be the coach ID (PM/MSL ID), not the selected DM
    // The selected DM is the one being coached, but dm_id in Supabase is the coach ID
    debugPrint('📝 Creating PM/MSL report:');
    debugPrint('   coachId: ${widget.coachId}');
    debugPrint('   coachName: ${widget.coachName}');
    debugPrint('   coachRole: ${widget.coachRole}');
    debugPrint('   selectedDMId: ${_formData['dmId'] ?? widget.dmId}');
    debugPrint('   selectedDMName: $selectedDMName');
    debugPrint('   selectedMRName: $selectedMRName');
    debugPrint('   typeOfVisit: ${_formData['typeOfVisit']}');
    
    // Helper function to create a report
    CoachingReport createReport({
      required String mrId,
      required String mrName,
      String? dmId,
      String? dmName,
      required bool isDMReport, // New parameter to distinguish DM report from MR report
    }) {
      final finalDmId = dmId ?? widget.coachId;
      debugPrint('   📝 createReport called:');
      debugPrint('      mrId: $mrId');
      debugPrint('      mrName: $mrName');
      debugPrint('      dmId parameter: $dmId');
      debugPrint('      widget.coachId: ${widget.coachId}');
      debugPrint('      final dmId: $finalDmId');
      debugPrint('      coachRole: ${widget.coachRole}');
      debugPrint('      isDMReport: $isDMReport');
      
      return CoachingReport(
        date: widget.date,
        dmId: finalDmId, // For Double: DM report uses selected DM ID, MR report uses coach ID
        dmName: dmName ?? widget.coachName,
        mrId: mrId,
        mrName: mrName,
        coachRole: widget.coachRole,
        // Brick Information
        brickName: _formData['areaBrickName'],
        brickLocationLat: lat,
        brickLocationLng: lng,
        locationName: locationName,
        googleMapsUrl: googleMapsUrl,
        visitCount: _formData['visitCount'] != null ? int.tryParse(_formData['visitCount']!) : 1,
        doctorsVisited: _doctorsVisitedController.text.trim().isNotEmpty ? _doctorsVisitedController.text.trim() : null,
        // PM/MSL Specific Fields
        areaBrickName: _areaBrickNameController.text.trim().isNotEmpty ? _areaBrickNameController.text.trim() : null,
        typeOfVisit: _determineVisitType(), // Determine automatically based on DM and MR selection
        visitedAccountsNames: null, // Removed - Visit Details section deleted
        generalFeedback: _generalFeedbackController.text.trim().isNotEmpty ? _generalFeedbackController.text.trim() : null,
        // DM Feedback - only for DM reports
        teamwork: isDMReport ? _formData['teamwork'] : null,
        customerAwareness: isDMReport ? _formData['customerAwareness'] : null,
        medicalProductKnowledgeDM: isDMReport ? _formData['medicalProductKnowledgeDM'] : null,
        dmFeedbackComments: isDMReport && _dmFeedbackCommentsController.text.trim().isNotEmpty ? _dmFeedbackCommentsController.text.trim() : null,
        // MR Feedback - only for MR reports
        punctuality: isDMReport ? null : _formData['punctuality'],
        dressCode: isDMReport ? null : _formData['dressCode'],
        pharmacyFeedback: isDMReport ? null : _formData['pharmacyFeedback'],
        reviewProfile: isDMReport ? null : _formData['reviewProfile'],
        patientCentricApproach: isDMReport ? null : _formData['patientCentricApproach'],
        medicalProductKnowledgeMR: isDMReport ? null : _formData['medicalProductKnowledgeMR'],
        engaging: isDMReport ? null : _formData['engaging'],
        featureBenefits: isDMReport ? null : _formData['featureBenefits'],
        closingCommitment: isDMReport ? null : _formData['closingCommitment'],
        mrFeedbackComments: isDMReport ? null : (_mrFeedbackCommentsController.text.trim().isNotEmpty ? _mrFeedbackCommentsController.text.trim() : null),
        isQuickSession: widget.isQuickSession,
      );
    }

    // Determine visit type automatically based on DM and MR selection
    final typeOfVisit = _determineVisitType();
    final hasDM = widget.dmId != null && widget.dmId!.isNotEmpty;
    final hasMR = widget.mrId != null && widget.mrId!.isNotEmpty;
    
    if (typeOfVisit == 'Single') {
      // Single: No DM, No MR - only general fields
      debugPrint('📝 Single Visit - creating one report with general fields only');
      
      final report = createReport(
        mrId: widget.coachId, // Use coach ID as MR ID for single visit
        mrName: widget.coachName, // Use coach name as MR name
        isDMReport: false, // No DM or MR questions, just general
      );
      
      try {
        await widget.onSubmit(report);
        
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Single visit: Report submitted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Wait a bit before navigating back to ensure SnackBar is shown
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (mounted) {
            widget.onBack();
          }
        }
      } catch (e, stackTrace) {
        ErrorHandler.logError(e, context: 'PMMSLCoachingFormScreen._handleSubmit (Single)', stackTrace: stackTrace);
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorHandler.getUserFriendlyMessage(e)),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else if (typeOfVisit == 'Double') {
      if (hasDM && !hasMR) {
        // Double with DM only
        debugPrint('📝 Double Visit (DM only) - creating one report for DM');
        
        final dmReport = createReport(
          mrId: _formData['dmId'] ?? widget.dmId ?? '', // Use DM ID as "MR" ID
          mrName: selectedDMName, // Use DM name as "MR" name
          dmId: widget.coachId, // Coach ID
          dmName: widget.coachName, // Coach name
          isDMReport: true, // This is DM report
        );
        
        try {
          await widget.onSubmit(dmReport);
          
          if (mounted) {
            setState(() {
              _isSubmitting = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Double visit (DM only): Report submitted successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            
            // Wait a bit before navigating back to ensure SnackBar is shown
            await Future.delayed(const Duration(milliseconds: 500));
            
            if (mounted) {
              widget.onBack();
            }
          }
        } catch (e, stackTrace) {
          ErrorHandler.logError(e, context: 'PMMSLCoachingFormScreen._handleSubmit (Double DM)', stackTrace: stackTrace);
          if (mounted) {
            setState(() {
              _isSubmitting = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ErrorHandler.getUserFriendlyMessage(e)),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (!hasDM && hasMR) {
        // Double with MR only
        debugPrint('📝 Double Visit (MR only) - creating one report for MR');
        
        final mrReport = createReport(
          mrId: _formData['mrId'] ?? widget.mrId ?? '',
          mrName: selectedMRName,
          isDMReport: false, // This is MR report
        );
        
        try {
          await widget.onSubmit(mrReport);
          
          if (mounted) {
            setState(() {
              _isSubmitting = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Double visit (MR only): Report submitted successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            
            // Wait a bit before navigating back to ensure SnackBar is shown
            await Future.delayed(const Duration(milliseconds: 500));
            
            if (mounted) {
              widget.onBack();
            }
          }
        } catch (e, stackTrace) {
          ErrorHandler.logError(e, context: 'PMMSLCoachingFormScreen._handleSubmit (Double MR)', stackTrace: stackTrace);
          if (mounted) {
            setState(() {
              _isSubmitting = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ErrorHandler.getUserFriendlyMessage(e)),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } else if (typeOfVisit == 'Triple') {
      // Triple: Both DM and MR Feedback - create ONE report with both DM and MR questions
      debugPrint('📝 Triple Visit - creating ONE report with both DM and MR questions');
      
      // Get selected DM info (the DM being coached)
      final selectedDMId = _formData['dmId'] ?? widget.dmId ?? '';
      
      // Create a single report that includes both DM and MR feedback fields
      // For Triple visit: dmId and dmName should contain the District Manager info (not the coach)
      final tripleReport = CoachingReport(
        date: widget.date,
        dmId: selectedDMId.isNotEmpty ? selectedDMId : widget.coachId, // DM ID (the DM being coached)
        dmName: selectedDMName.isNotEmpty ? selectedDMName : widget.coachName, // DM name (the DM being coached)
        mrId: _formData['mrId'] ?? widget.mrId ?? '', // MR ID
        mrName: selectedMRName, // MR name
        coachRole: widget.coachRole,
        coachId: widget.coachId, // Coach ID (PM/MSL who is coaching)
        coachName: widget.coachName, // Coach Name (PM/MSL who is coaching)
        // Brick Information
        brickName: _formData['areaBrickName'],
        brickLocationLat: lat,
        brickLocationLng: lng,
        locationName: locationName,
        googleMapsUrl: googleMapsUrl,
        visitCount: _formData['visitCount'] != null ? int.tryParse(_formData['visitCount']!) : 1,
        doctorsVisited: _doctorsVisitedController.text.trim().isNotEmpty ? _doctorsVisitedController.text.trim() : null,
        // PM/MSL Specific Fields
        areaBrickName: _areaBrickNameController.text.trim().isNotEmpty ? _areaBrickNameController.text.trim() : null,
        typeOfVisit: 'Triple',
        visitedAccountsNames: null,
        generalFeedback: _generalFeedbackController.text.trim().isNotEmpty ? _generalFeedbackController.text.trim() : null,
        // DM Feedback - included in Triple report
        teamwork: _formData['teamwork'],
        customerAwareness: _formData['customerAwareness'],
        medicalProductKnowledgeDM: _formData['medicalProductKnowledgeDM'],
        dmFeedbackComments: _dmFeedbackCommentsController.text.trim().isNotEmpty ? _dmFeedbackCommentsController.text.trim() : null,
        // MR Feedback - included in Triple report
        punctuality: _formData['punctuality'],
        dressCode: _formData['dressCode'],
        pharmacyFeedback: _formData['pharmacyFeedback'],
        reviewProfile: _formData['reviewProfile'],
        patientCentricApproach: _formData['patientCentricApproach'],
        medicalProductKnowledgeMR: _formData['medicalProductKnowledgeMR'],
        engaging: _formData['engaging'],
        featureBenefits: _formData['featureBenefits'],
        closingCommitment: _formData['closingCommitment'],
        mrFeedbackComments: _mrFeedbackCommentsController.text.trim().isNotEmpty ? _mrFeedbackCommentsController.text.trim() : null,
        isQuickSession: widget.isQuickSession,
      );
      
      try {
        await widget.onSubmit(tripleReport);
        
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Triple visit: Report submitted successfully with both DM and MR questions!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Wait a bit before navigating back to ensure SnackBar is shown
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (mounted) {
            widget.onBack();
          }
        }
      } catch (e, stackTrace) {
        ErrorHandler.logError(e, context: 'PMMSLCoachingFormScreen._handleSubmit (Triple)', stackTrace: stackTrace);
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorHandler.getUserFriendlyMessage(e)),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.gray50,
        body: Column(
          children: [
            // Sticky Header and Content
            Expanded(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                      child: Container(
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
                        padding: EdgeInsets.only(
                          left: 24,
                          right: 24,
                          top: MediaQuery.of(context).padding.top + 16,
                          bottom: 24,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                                    onPressed: widget.onBack,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.coachRole.toUpperCase()} Coaching Form',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.coachName,
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
                    ),
                  // Form Content - All sections in one scrollable page
                  SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Container(
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
                            child: _buildAllSections(),
                          ),
                        ),
                      ),
                    ),
                  // Bottom spacing for submit button
                  const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
            // Submit Button (Fixed at bottom)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradientHorizontal,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSubmitting ? null : _handleSubmit,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSubmitting)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            else
                              const Icon(Icons.send, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isSubmitting ? 'Submitting...' : 'Submit',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSections() {
    // Determine visit type automatically based on DM and MR selection
    final typeOfVisit = _determineVisitType();
    final hasDM = widget.dmId != null && widget.dmId!.isNotEmpty;
    final hasMR = widget.mrId != null && widget.mrId!.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Basic Information
        _buildBasicInformation(),
        const SizedBox(height: 32),
        // DM Feedback - only show if:
        // - Triple (has both DM and MR)
        // - Double with DM only (has DM, no MR)
        if ((typeOfVisit == 'Triple') || (typeOfVisit == 'Double' && hasDM && !hasMR)) ...[
          const Text(
            'DM Feedback',
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildDMFeedback(),
          const SizedBox(height: 32),
        ],
        // MR Feedback - only show if:
        // - Triple (has both DM and MR)
        // - Double with MR only (no DM, has MR)
        // - Single (no DM, no MR) - but this shouldn't show MR questions, only general
        if ((typeOfVisit == 'Triple') || (typeOfVisit == 'Double' && !hasDM && hasMR)) ...[
          const Text(
            'MR Feedback',
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildMRFeedback(),
          const SizedBox(height: 32),
        ],
        // Comments & Insights - always show
        const Text(
          'Comments & Insights',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildComments(),
      ],
    );
  }

  Widget _buildBasicInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          label: 'Date',
          value: widget.date,
          enabled: false,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Coach',
          value: widget.coachName,
          enabled: false,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'District Manager',
          value: widget.dmName ?? 'No District Manager',
          enabled: false,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Medical Representative (MR)',
          value: widget.mrName ?? 'No Medical Rep',
          enabled: false,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _areaBrickNameController,
          onChanged: (value) => _updateField('areaBrickName', value),
          decoration: InputDecoration(
            labelText: 'Area & Brick Name *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        // Display visit type automatically (read-only)
        _buildTextField(
          label: 'Type of Visit',
          value: _determineVisitType(),
          enabled: false,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _doctorsVisitedController,
          decoration: InputDecoration(
            labelText: 'Doctors Visited (comma-separated)',
            hintText: 'Dr. Ahmed, Dr. Mohamed, ...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          keyboardType: TextInputType.number,
          onChanged: (value) => _updateField('visitCount', value),
          decoration: InputDecoration(
            labelText: 'Visit Count',
            hintText: '1',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }


  Widget _buildDMFeedback() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _generalFeedbackController,
          maxLines: 4,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: 'General Feedback and Special Insights',
            hintText: 'Enter general feedback...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        _buildDropdownField(
          label: 'Teamwork and Cooperation',
          value: _formData['teamwork'],
          items: const [
            DropdownMenuItem(value: 'High', child: Text('High')),
            DropdownMenuItem(value: 'Medium', child: Text('Medium')),
            DropdownMenuItem(value: 'Low', child: Text('Low')),
          ],
          onChanged: (value) => _updateField('teamwork', value ?? ''),
        ),
        const SizedBox(height: 24),
        _buildDropdownField(
          label: 'Customer Awareness *',
          value: _formData['customerAwareness'],
          items: const [
            DropdownMenuItem(value: 'High', child: Text('High')),
            DropdownMenuItem(value: 'Medium', child: Text('Medium')),
            DropdownMenuItem(value: 'Low', child: Text('Low')),
          ],
          onChanged: (value) => _updateField('customerAwareness', value ?? ''),
        ),
        const SizedBox(height: 24),
        _buildDropdownField(
          label: 'Medical & Product Knowledge *',
          value: _formData['medicalProductKnowledgeDM'],
          items: const [
            DropdownMenuItem(value: 'High', child: Text('High')),
            DropdownMenuItem(value: 'Medium', child: Text('Medium')),
            DropdownMenuItem(value: 'Low', child: Text('Low')),
          ],
          onChanged: (value) => _updateField('medicalProductKnowledgeDM', value ?? ''),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _dmFeedbackCommentsController,
          maxLines: 4,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: 'DM Feedback Comments and Insights',
            hintText: 'Enter comments...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMRFeedback() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildYesNoField('punctuality', 'Punctuality *'),
        const SizedBox(height: 24),
        _buildYesNoField('dressCode', 'Dress Code *'),
        const SizedBox(height: 24),
        _buildStarRating('pharmacyFeedback', 'Pharmacy Feedback *'),
        const SizedBox(height: 24),
        _buildStarRating('reviewProfile', 'Review customer Profile/Potential/Preference'),
        const SizedBox(height: 24),
        _buildStarRating('patientCentricApproach', 'Patient Centric Approach'),
        const SizedBox(height: 24),
        _buildStarRating('medicalProductKnowledgeMR', 'Medical and Product Knowledge'),
        const SizedBox(height: 24),
        _buildStarRating('engaging', 'Engaging the customer'),
        const SizedBox(height: 24),
        _buildStarRating('featureBenefits', 'Feature and Benefits'),
        const SizedBox(height: 24),
        _buildStarRating('closingCommitment', 'Closing and commitment'),
      ],
    );
  }

  Widget _buildComments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _mrFeedbackCommentsController,
          maxLines: 6,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: 'MR Feedback Comments and Insights',
            hintText: 'Enter comments...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    bool enabled = true,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : AppColors.gray100,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    bool isLoading = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: isLoading ? null : onChanged,
      isExpanded: true, // Prevent overflow by expanding dropdown
      selectedItemBuilder: (BuildContext context) {
        return items.map<Widget>((DropdownMenuItem<String> item) {
          return Text(
            (item.child as Text).data ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(color: AppColors.gray700),
          );
        }).toList();
      },
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildYesNoField(String field, String label) {
    final isYes = _formData[field] == 'Yes';
    final isNo = _formData[field] == 'No';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.gray700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            InkWell(
              onTap: () => _updateField(field, 'Yes'),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: isYes ? AppColors.primaryGradientHorizontal : null,
                  color: isYes ? null : Colors.white,
                  border: Border.all(
                    color: isYes ? Colors.transparent : AppColors.gray300,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: isYes
                      ? [
                          BoxShadow(
                            color: AppColors.primaryCyan.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Yes',
                    style: TextStyle(
                      color: isYes ? Colors.white : AppColors.gray700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _updateField(field, 'No'),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: isNo 
                      ? LinearGradient(
                          colors: [Colors.red.shade400, Colors.red.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isNo ? null : Colors.white,
                  border: Border.all(
                    color: isNo ? Colors.transparent : AppColors.gray300,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: isNo
                      ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'No',
                    style: TextStyle(
                      color: isNo ? Colors.white : AppColors.gray700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStarRating(String field, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.gray700,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            final rating = (index + 1).toString();
            final isSelected = _formData[field] == rating;
            return InkWell(
              onTap: () => _updateField(field, rating),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? AppColors.primaryGradientHorizontal
                      : null,
                  color: isSelected ? null : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : AppColors.gray300,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Center(
                  child: Text(
                    rating,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.gray700,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

