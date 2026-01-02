import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:geolocator/geolocator.dart';

class CoachingFormScreen extends StatefulWidget {
  final String date;
  final String mrId;
  final String mrName;
  final String dmId;
  final String dmName;
  final String coachRole; // 'dm' or 'ft'
  final bool isQuickSession; // True if started without a plan
  final Function(CoachingReport) onSubmit;
  final VoidCallback onBack;

  const CoachingFormScreen({
    super.key,
    required this.date,
    required this.mrId,
    required this.mrName,
    required this.dmId,
    required this.dmName,
    required this.coachRole, // 'dm' or 'ft'
    this.isQuickSession = false,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<CoachingFormScreen> createState() => _CoachingFormScreenState();
}

class _CoachingFormScreenState extends State<CoachingFormScreen> {
  final Map<String, String?> _formData = {};

  // Text controllers for text areas (to prevent RTL issues)
  late final TextEditingController _strengthsController;
  late final TextEditingController _improvementsController;
  late final TextEditingController _brickNameController;

  @override
  void initState() {
    super.initState();
    _formData['date'] = widget.date;
    _formData['mrId'] = widget.mrId;
    _formData['mrName'] = widget.mrName;
    _formData['dmId'] = widget.dmId;
    _formData['dmName'] = widget.dmName;
    
    // Initialize text controllers
    _strengthsController = TextEditingController();
    _improvementsController = TextEditingController();
    _brickNameController = TextEditingController();
  }

  @override
  void dispose() {
    _strengthsController.dispose();
    _improvementsController.dispose();
    _brickNameController.dispose();
    super.dispose();
  }

  String _getRoleLabel(String? role) {
    switch (role?.toLowerCase()) {
      case 'dm':
        return 'District Manager (DM)';
      case 'ft':
        return 'Field Trainer (FT)';
      case 'pm':
        return 'Product Manager (PM)';
      case 'msl':
        return 'Medical Science Liaison (MSL)';
      default:
        return 'Coach';
    }
  }


  void _updateField(String field, String value) {
    setState(() {
      _formData[field] = value;
    });
  }

  bool _validateAllFields() {
    final requiredFields = [
      'punctuality', 'dressCode', 'timeManagement',
      'pharmacyFeedback', 'reviewProfile', 'brandBonding', 'smartObjectives',
      'opening', 'patientProfile', 'engaging', 'insightfulQuestions', 'activeListening', 
      'linkFeatures', 'productKnowledge', 'eDetailing', 'answeringQuestions',
      'summarizeCall', 'askCommitment', 'bridging',
      'selfAssessment',
    ];
    
    return requiredFields.every((field) => _formData[field] != null && _formData[field]!.isNotEmpty);
  }


  Future<void> _handleSubmit() async {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot submit coaching reports after 12:00 AM (midnight)')),
      );
      return;
    }

    if (!_validateAllFields()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    // Verify Location Services and Permission before allowing submit
    // User should not know we're taking location - show generic "Verifying..." message
    double? lat;
    double? lng;
    String? locationName;
    String? googleMapsUrl;
    
    try {
      // Step 1: Check if Location Services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location Services are disabled');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تفعيل خدمات الموقع من إعدادات الهاتف'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      
      // Step 2: Check and request permission if needed
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ Location permission denied, requesting...');
        permission = await Geolocator.requestPermission();
      }
      
      // Step 3: Verify permission is granted
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        debugPrint('❌ Location permission not granted: $permission');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى السماح بالوصول للموقع من إعدادات التطبيق'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      
      // Step 4: Try to get current location with timeout
      debugPrint('📍 Attempting to get current location...');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى الانتظار حتى يتوفر GPS أو تحقق من إعدادات الموقع'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    } catch (e, stackTrace) {
      // Unexpected error
      debugPrint('❌ Unexpected error checking location: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ في التحقق من الموقع. يرجى المحاولة مرة أخرى'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    
    // Location verified successfully - continue with report submission
    debugPrint('✅ Location verification passed, proceeding with report submission...');

    final report = CoachingReport(
      date: _formData['date']!,
      dmId: _formData['dmId']!,
      dmName: _formData['dmName']!,
      mrId: _formData['mrId']!,
      mrName: _formData['mrName']!,
      coachRole: widget.coachRole, // 'dm' or 'ft'
      // Brick Information
      brickName: _brickNameController.text.trim().isNotEmpty ? _brickNameController.text.trim() : null,
      brickLocationLat: lat,
      brickLocationLng: lng,
      locationName: locationName,
      googleMapsUrl: googleMapsUrl,
      visitCount: _formData['visitCount'] != null ? int.tryParse(_formData['visitCount']!) : 1,
      doctorsVisited: null, // Not used for DM/FT
      punctuality: _formData['punctuality'],
      dressCode: _formData['dressCode'],
      timeManagement: _formData['timeManagement'],
      pharmacyFeedback: _formData['pharmacyFeedback'],
      reviewProfile: _formData['reviewProfile'],
      brandBonding: _formData['brandBonding'],
      smartObjectives: _formData['smartObjectives'],
      opening: _formData['opening'],
      patientProfile: _formData['patientProfile'],
      engaging: _formData['engaging'],
      insightfulQuestions: _formData['insightfulQuestions'],
      activeListening: _formData['activeListening'],
      linkFeatures: _formData['linkFeatures'],
      productKnowledge: _formData['productKnowledge'],
      eDetailing: _formData['eDetailing'],
      answeringQuestions: _formData['answeringQuestions'],
      summarizeCall: _formData['summarizeCall'],
      askCommitment: _formData['askCommitment'],
      bridging: _formData['bridging'],
      selfAssessment: _formData['selfAssessment'],
      strengths: _strengthsController.text.isNotEmpty ? _strengthsController.text : _formData['strengths'],
      improvements: _improvementsController.text.isNotEmpty ? _improvementsController.text : _formData['improvements'],
      filledWithMR: _formData['filledWithMR'],
      isQuickSession: widget.isQuickSession,
    );

    try {
      widget.onSubmit(report);
      debugPrint('✅ Report submitted successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error submitting report: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إرسال التقرير: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
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
                        const Text(
                          'Coaching Report',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.mrName,
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
                // Bottom spacing for submit button
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
          // Navigation Buttons (Fixed at bottom)
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleSubmit,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Submit Report',
                            textAlign: TextAlign.center,
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
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAllSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Basic Information
        _buildBasicInformation(),
        const SizedBox(height: 32),
        // Section Title: Personal Attributes
        const Text(
          'Personal Attributes',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildPersonalAttributes(),
        const SizedBox(height: 32),
        // Section Title: Pre-Call Planning
        const Text(
          'Pre-Call Planning',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildPreCallPlanning(),
        const SizedBox(height: 32),
        // Section Title: Sales Call Steps
        const Text(
          'Sales Call Steps',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildSalesCallSteps(),
        const SizedBox(height: 32),
        // Section Title: Closing
        const Text(
          'Closing',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildClosing(),
        const SizedBox(height: 32),
        // Section Title: Post Call Analysis
        const Text(
          'Post Call Analysis',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildPostCallAnalysis(),
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
          label: _getRoleLabel(widget.coachRole),
          value: widget.dmName,
          enabled: false,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Medical Representative (MR)',
          value: widget.mrName,
          enabled: false,
        ),
        const SizedBox(height: 24),
        // Brick Name
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.business_outlined,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Brick Name',
                  style: TextStyle(
                    color: AppColors.gray700,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _brickNameController,
                onChanged: (value) => _updateField('brickName', value),
                maxLines: 1,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.business_outlined,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
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
                    borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Visit Count
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

  Widget _buildPersonalAttributes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildYesNoField('punctuality', 'Punctuality (started on time exactly)'),
        const SizedBox(height: 24),
        _buildYesNoField('dressCode', 'Dress code'),
        const SizedBox(height: 24),
        _buildYesNoField('timeManagement', 'Time & Territory Management'),
      ],
    );
  }

  Widget _buildPreCallPlanning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStarRating('pharmacyFeedback', 'Pharmacy Feedback'),
        const SizedBox(height: 24),
        _buildStarRating('reviewProfile', 'Review customer Profile/Potential/Preference'),
        const SizedBox(height: 24),
        _buildStarRating('brandBonding', 'Brand bonding ladder (review last call commitment)'),
        const SizedBox(height: 24),
        _buildStarRating('smartObjectives', 'Set SMART call objectives'),
      ],
    );
  }

  Widget _buildSalesCallSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStarRating('opening', 'Opening / Rapport'),
        const SizedBox(height: 24),
        _buildStarRating('patientProfile', 'Specific Patient profile'),
        const SizedBox(height: 24),
        _buildStarRating('engaging', 'Engaging the customer'),
        const SizedBox(height: 24),
        _buildStarRating('insightfulQuestions', 'Asking insightful Question(s)'),
        const SizedBox(height: 24),
        _buildStarRating('activeListening', 'Active Listening (no interruptions, confirm/clarify)'),
        const SizedBox(height: 24),
        _buildStarRating('linkFeatures', 'Link product feature(s) with customer need'),
        const SizedBox(height: 24),
        _buildStarRating('productKnowledge', 'Proper Product, Medical & Competitor Knowledge'),
        const SizedBox(height: 24),
        _buildStarRating('eDetailing', 'Proper use of E-detailing'),
        const SizedBox(height: 24),
        _buildStarRating('answeringQuestions', 'Answering Customer Questions & Concerns (APACT)'),
      ],
    );
  }

  Widget _buildClosing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStarRating('summarizeCall', 'Summarize Call'),
        const SizedBox(height: 24),
        _buildStarRating('askCommitment', 'Ask for specific commitment'),
        const SizedBox(height: 24),
        _buildStarRating('bridging', 'Bridging to next product(s)'),
      ],
    );
  }

  Widget _buildPostCallAnalysis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStarRating('selfAssessment', 'Self-assessment & Updating customer profile'),
        const SizedBox(height: 24),
        _buildTextAreaField(
          'strengths',
          'Mention strengths exhibited during the day',
          'Describe the key strengths demonstrated...',
        ),
        const SizedBox(height: 24),
        _buildTextAreaField(
          'improvements',
          'Mention Areas of improvement till next Visit',
          'Describe areas that need improvement...',
        ),
        const SizedBox(height: 24),
        _buildYesNoField('filledWithMR', 'Did you fill this coaching report with the Medical Representative?'),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    bool enabled = true,
    IconData? icon,
  }) {
    // Determine icon based on label if not provided
    IconData? fieldIcon = icon;
    if (fieldIcon == null) {
      if (label.toLowerCase().contains('date')) {
        fieldIcon = Icons.calendar_today;
      } else if (label.toLowerCase().contains('district') || label.toLowerCase().contains('dm')) {
        fieldIcon = Icons.person_outline;
      } else if (label.toLowerCase().contains('medical') || label.toLowerCase().contains('mr')) {
        fieldIcon = Icons.medical_services_outlined;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (fieldIcon != null) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  fieldIcon,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                '$label *',
                style: const TextStyle(
                  color: AppColors.gray700,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              enabled: enabled,
              controller: TextEditingController(text: value),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              keyboardType: TextInputType.text,
              maxLines: 1,
              style: TextStyle(
                color: enabled ? AppColors.gray900 : AppColors.gray600,
                fontWeight: enabled ? FontWeight.w500 : FontWeight.w400,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: enabled ? Colors.white : AppColors.gray50,
                prefixIcon: fieldIcon != null
                    ? Icon(
                        fieldIcon,
                        color: enabled ? AppColors.primaryBlue : AppColors.gray400,
                        size: 20,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: enabled ? AppColors.gray200 : AppColors.gray300,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: enabled ? AppColors.gray200 : AppColors.gray300,
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryCyan,
                    width: 2.5,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.gray300,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextAreaField(String field, String label, String placeholder) {
    // Use the appropriate controller based on field
    final controller = field == 'strengths' ? _strengthsController : _improvementsController;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: const TextStyle(
            color: AppColors.gray700,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: (value) => _updateField(field, value),
          maxLines: 4,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: placeholder,
            hintTextDirection: TextDirection.ltr,
            filled: true,
            fillColor: Colors.white,
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
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildYesNoField(String field, String label) {
    final value = _formData[field];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: const TextStyle(
            color: AppColors.gray700,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
                  gradient: value == 'Yes'
                      ? AppColors.primaryGradientHorizontal
                      : null,
                  color: value == 'Yes' ? null : Colors.white,
                  border: Border.all(
                    color: value == 'Yes'
                        ? Colors.transparent
                        : AppColors.gray200,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: value == 'Yes'
                      ? [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Yes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: value == 'Yes' ? Colors.white : AppColors.gray700,
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
                  color: value == 'No' ? AppColors.error : Colors.white,
                  border: Border.all(
                    color: value == 'No'
                        ? Colors.transparent
                        : AppColors.gray200,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: value == 'No'
                      ? [
                          BoxShadow(
                            color: AppColors.error.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'No',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: value == 'No' ? Colors.white : AppColors.gray700,
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
          '$label *',
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


