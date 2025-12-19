import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final Function(CoachingReport) onSubmit;
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
  int _currentSection = 0;
  final Map<String, String?> _formData = {};
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, String>> _sections = [
    {'title': 'Basic Information', 'key': 'basic'},
    {'title': 'Visit Details', 'key': 'visit'},
    {'title': 'DM Feedback', 'key': 'dmFeedback'},
    {'title': 'MR Feedback', 'key': 'mrFeedback'},
    {'title': 'Comments & Insights', 'key': 'comments'},
  ];

  // Controllers
  late final TextEditingController _areaBrickNameController;
  late final TextEditingController _visitedAccountsController;
  late final TextEditingController _generalFeedbackController;
  late final TextEditingController _dmFeedbackCommentsController;
  late final TextEditingController _mrFeedbackCommentsController;
  late final TextEditingController _doctorsVisitedController;

  // Dropdown data
  List<Map<String, dynamic>> _dmsAndFTs = [];
  List<Map<String, dynamic>> _mrs = [];
  bool _loadingDropdowns = true;

  // Location
  Position? _currentPosition;
  bool _locationLoading = false;
  String? _locationName;
  String? _googleMapsUrl;

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
    _visitedAccountsController = TextEditingController();
    _generalFeedbackController = TextEditingController();
    _dmFeedbackCommentsController = TextEditingController();
    _mrFeedbackCommentsController = TextEditingController();
    _doctorsVisitedController = TextEditingController();

    _loadDropdowns();
  }

  @override
  void dispose() {
    _areaBrickNameController.dispose();
    _visitedAccountsController.dispose();
    _generalFeedbackController.dispose();
    _dmFeedbackCommentsController.dispose();
    _mrFeedbackCommentsController.dispose();
    _doctorsVisitedController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _loadingDropdowns = true);
    try {
      final dmsAndFTs = await SupabaseService.getAllDMsAndFTs();
      final mrs = await SupabaseService.getAllMRs();
      setState(() {
        _dmsAndFTs = dmsAndFTs;
        _mrs = mrs;
        _loadingDropdowns = false;
      });
    } catch (e) {
      setState(() => _loadingDropdowns = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dropdowns: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        setState(() => _locationLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          setState(() => _locationLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied')),
          );
        }
        setState(() => _locationLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get location name - will be filled from Google Maps when user confirms
      // For now, use coordinates as placeholder
      String? locationName = 'Location at ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      
      // Note: Reverse geocoding can be added later using Google Geocoding API
      // For now, user will see the location on Google Maps and can confirm

      // Generate Google Maps URL
      final googleMapsUrl = 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';

      setState(() {
        _currentPosition = position;
        _formData['brickLocationLat'] = position.latitude.toString();
        _formData['brickLocationLng'] = position.longitude.toString();
        _locationName = locationName;
        _googleMapsUrl = googleMapsUrl;
        _formData['locationName'] = locationName;
        _formData['googleMapsUrl'] = googleMapsUrl;
        _locationLoading = false;
      });

      // Show preview dialog
      if (mounted) {
        _showLocationPreviewDialog(position, locationName, googleMapsUrl);
      }
    } catch (e) {
      setState(() => _locationLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  Future<void> _showLocationPreviewDialog(Position position, String? locationName, String googleMapsUrl) async {
    final locationNameController = TextEditingController(text: locationName ?? '');
    
    final confirmed = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Location Preview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coordinates Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryCyan.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: AppColors.primaryCyan, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Location Name Input
                TextField(
                  controller: locationNameController,
                  decoration: InputDecoration(
                    labelText: 'Location Name (from Google Maps)',
                    hintText: 'Enter location name as shown on Google Maps...',
                    prefixIcon: const Icon(Icons.place, color: AppColors.primaryCyan),
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
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                // Google Maps Button
                Container(
                  width: double.infinity,
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
                      onTap: () async {
                        final uri = Uri.parse(googleMapsUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.map, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Open in Google Maps',
                              style: TextStyle(
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
                const SizedBox(height: 8),
                const Text(
                  '💡 Tip: Open Google Maps to see the location name, then enter it above',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.gray600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gray600,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Cancel'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradientHorizontal,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryCyan.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context, {
                      'locationName': locationNameController.text.trim(),
                      'confirmed': 'true',
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: const Text(
                      'Confirm Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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

    if (confirmed != null && confirmed['confirmed'] == 'true') {
      // User confirmed, update location name
      final newLocationName = confirmed['locationName'] ?? locationName;
      setState(() {
        _locationName = newLocationName;
        _formData['locationName'] = newLocationName;
      });
    } else {
      // User cancelled, clear location
      setState(() {
        _currentPosition = null;
        _locationName = null;
        _googleMapsUrl = null;
        _formData.remove('brickLocationLat');
        _formData.remove('brickLocationLng');
        _formData.remove('locationName');
        _formData.remove('googleMapsUrl');
      });
    }
  }

  void _updateField(String field, String value) {
    setState(() {
      _formData[field] = value;
    });
  }

  bool _validateSection() {
    final requiredFields = {
      0: ['dmId', 'mrId', 'areaBrickName', 'typeOfVisit'],
      1: ['visitedAccountsNames'],
      2: ['customerAwareness', 'medicalProductKnowledgeDM'],
      3: ['punctuality', 'dressCode', 'pharmacyFeedback'],
      4: [], // Comments section - optional
    };

    final fields = requiredFields[_currentSection] ?? [];
    return fields.every((field) => _formData[field] != null && _formData[field]!.isNotEmpty);
  }

  void _handleNext() {
    if (!_validateSection()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields in this section')),
      );
      return;
    }
    if (_currentSection < _sections.length - 1) {
      setState(() {
        _currentSection++;
      });
    }
  }

  void _handlePrevious() {
    if (_currentSection > 0) {
      setState(() {
        _currentSection--;
      });
    }
  }

  void _handleSubmit() {
    if (!_validateSection()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    // Get selected DM and MR names
    final selectedDM = _dmsAndFTs.firstWhere(
      (dm) => (dm['id'] ?? '').toString() == _formData['dmId'],
      orElse: () => {},
    );
    final selectedMR = _mrs.firstWhere(
      (mr) => (mr['id'] ?? '').toString() == _formData['mrId'],
      orElse: () => {},
    );

    // For PM/MSL: dmId in report should be the coach ID (PM/MSL ID), not the selected DM
    // The selected DM is the one being coached, but dm_id in Supabase is the coach ID
    debugPrint('📝 Creating PM/MSL report:');
    debugPrint('   coachId: ${widget.coachId}');
    debugPrint('   coachName: ${widget.coachName}');
    debugPrint('   coachRole: ${widget.coachRole}');
    debugPrint('   selectedDMId: ${_formData['dmId']}');
    debugPrint('   selectedDMName: ${selectedDM['name']}');
    debugPrint('   typeOfVisit: ${_formData['typeOfVisit']}');
    
    // Helper function to create a report
    CoachingReport createReport({
      required String mrId,
      required String mrName,
      String? dmId,
      String? dmName,
    }) {
      return CoachingReport(
        date: widget.date,
        dmId: dmId ?? widget.coachId, // For Double: DM report uses selected DM ID, MR report uses coach ID
        dmName: dmName ?? widget.coachName,
        mrId: mrId,
        mrName: mrName,
        coachRole: widget.coachRole,
        // Brick Information
        brickName: _formData['areaBrickName'],
        brickLocationLat: _formData['brickLocationLat'] != null ? double.tryParse(_formData['brickLocationLat']!) : null,
        brickLocationLng: _formData['brickLocationLng'] != null ? double.tryParse(_formData['brickLocationLng']!) : null,
        locationName: _formData['locationName'],
        googleMapsUrl: _formData['googleMapsUrl'],
        visitCount: _formData['visitCount'] != null ? int.tryParse(_formData['visitCount']!) : 1,
        doctorsVisited: _doctorsVisitedController.text.trim().isNotEmpty ? _doctorsVisitedController.text.trim() : null,
        // PM/MSL Specific Fields
        areaBrickName: _areaBrickNameController.text.trim().isNotEmpty ? _areaBrickNameController.text.trim() : null,
        typeOfVisit: _formData['typeOfVisit'],
        visitedAccountsNames: _visitedAccountsController.text.trim().isNotEmpty ? _visitedAccountsController.text.trim() : null,
        generalFeedback: _generalFeedbackController.text.trim().isNotEmpty ? _generalFeedbackController.text.trim() : null,
        customerAwareness: _formData['customerAwareness'],
        medicalProductKnowledgeDM: _formData['medicalProductKnowledgeDM'],
        dmFeedbackComments: _dmFeedbackCommentsController.text.trim().isNotEmpty ? _dmFeedbackCommentsController.text.trim() : null,
        // MR Feedback
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
    }

    // Check if Double Visit - create two separate reports
    if (_formData['typeOfVisit'] == 'Double') {
      debugPrint('📝 Double Visit detected - creating two reports');
      
      // Report 1: For Medical Representative (MR)
      final mrReport = createReport(
        mrId: _formData['mrId'] ?? '',
        mrName: (selectedMR['name'] ?? '').toString(),
      );
      
      // Report 2: For District Manager (DM) - use selected DM as the "MR" in this report
      final dmReport = createReport(
        mrId: _formData['dmId'] ?? '', // Use DM ID as "MR" ID for DM report
        mrName: (selectedDM['name'] ?? '').toString(), // Use DM name as "MR" name
        dmId: widget.coachId, // Coach ID
        dmName: widget.coachName, // Coach name
      );
      
      // Submit both reports
      widget.onSubmit(mrReport);
      widget.onSubmit(dmReport);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Double visit: Two reports submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      // Single visit - create one report
      final report = createReport(
        mrId: _formData['mrId'] ?? '',
        mrName: (selectedMR['name'] ?? '').toString(),
      );
      
      widget.onSubmit(report);
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
                  // Progress Bar
                  SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Section ${_currentSection + 1} of ${_sections.length}',
                                    style: const TextStyle(
                                      color: AppColors.gray600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${((_currentSection + 1) / _sections.length * 100).round()}%',
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.gray200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: (_currentSection + 1) / _sections.length,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.primaryGradientHorizontal,
                                    borderRadius: BorderRadius.all(Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _sections[_currentSection]['title'] ?? '',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Form Content
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
                            child: _buildSectionContent(),
                          ),
                        ),
                      ),
                    ),
                  // Bottom spacing for navigation buttons
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
                child: Row(
                  children: [
                    if (_currentSection > 0)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.primaryBlue, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _handlePrevious,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: const Text(
                                  'Previous',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_currentSection > 0) const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
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
                            onTap: _currentSection < _sections.length - 1 ? _handleNext : _handleSubmit,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                _currentSection < _sections.length - 1 ? 'Next' : 'Submit',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildSectionContent() {
    switch (_currentSection) {
      case 0:
        return _buildBasicInformation();
      case 1:
        return _buildVisitDetails();
      case 2:
        return _buildDMFeedback();
      case 3:
        return _buildMRFeedback();
      case 4:
        return _buildComments();
      default:
        return const SizedBox();
    }
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
          value: '${widget.coachName} - ${widget.coachId}',
          enabled: false,
        ),
        const SizedBox(height: 24),
        _buildDropdownField(
          label: 'DM / Field Trainer *',
          value: _formData['dmId'],
          items: _dmsAndFTs.map((dm) {
            final id = (dm['id'] ?? '').toString();
            final name = (dm['name'] ?? '').toString();
            // Show only name in dropdown to avoid overflow
            return DropdownMenuItem(
              value: id,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
          onChanged: (value) => _updateField('dmId', value ?? ''),
          isLoading: _loadingDropdowns,
        ),
        const SizedBox(height: 24),
        _buildDropdownField(
          label: 'Medical Representative (MR) *',
          value: _formData['mrId'],
          items: _mrs.map((mr) {
            final id = (mr['id'] ?? '').toString();
            final name = (mr['name'] ?? '').toString();
            // Show only name in dropdown to avoid overflow
            return DropdownMenuItem(
              value: id,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
          onChanged: (value) => _updateField('mrId', value ?? ''),
          isLoading: _loadingDropdowns,
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
        _buildDropdownField(
          label: 'Type of Visit *',
          value: _formData['typeOfVisit'],
          items: const [
            DropdownMenuItem(value: 'DM', child: Text('DM')),
            DropdownMenuItem(value: 'Single', child: Text('Single')),
            DropdownMenuItem(value: 'Double', child: Text('Double')),
            DropdownMenuItem(value: 'Triple', child: Text('Triple')),
          ],
          onChanged: (value) => _updateField('typeOfVisit', value ?? ''),
        ),
        const SizedBox(height: 24),
        // Location Picker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gray200, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Brick Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray700,
                ),
              ),
              const SizedBox(height: 12),
              if (_currentPosition != null) ...[
                if (_locationName != null && _locationName!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place, color: AppColors.primaryCyan, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationName!,
                            style: const TextStyle(
                              color: AppColors.gray700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: AppColors.gray600),
                ),
                if (_googleMapsUrl != null) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(_googleMapsUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('View on Google Maps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCyan,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: _locationLoading ? null : _getCurrentLocation,
                icon: _locationLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on),
                label: Text(_locationLoading ? 'Getting Location...' : 'Get Current Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
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

  Widget _buildVisitDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _visitedAccountsController,
          maxLines: 4,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          keyboardType: TextInputType.multiline,
          onChanged: (value) => _updateField('visitedAccountsNames', value),
          decoration: InputDecoration(
            labelText: 'Visited Accounts Names *',
            hintText: 'Enter account names...',
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.gray700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _updateField(field, 'Yes'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: isYes ? AppColors.primaryGradientHorizontal : null,
                    color: isYes ? null : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isYes ? AppColors.primaryCyan : AppColors.gray300,
                      width: isYes ? 3 : 2,
                    ),
                    boxShadow: isYes
                        ? [
                            BoxShadow(
                              color: AppColors.primaryCyan.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: isYes ? Colors.white : AppColors.gray400,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Yes',
                        style: TextStyle(
                          color: isYes ? Colors.white : AppColors.gray700,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _updateField(field, 'No'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: isNo 
                        ? LinearGradient(
                            colors: [Colors.red.shade400, Colors.red.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isNo ? null : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isNo ? Colors.red.shade400 : AppColors.gray300,
                      width: isNo ? 3 : 2,
                    ),
                    boxShadow: isNo
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cancel,
                        color: isNo ? Colors.white : AppColors.gray400,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No',
                        style: TextStyle(
                          color: isNo ? Colors.white : AppColors.gray700,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildStarRating(String field, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.gray700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: List.generate(6, (index) {
            final value = (index + 1).toString();
            final isSelected = _formData[field] == value;
            return GestureDetector(
              onTap: () => _updateField(field, value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? AppColors.primaryGradient
                      : null,
                  color: isSelected ? null : Colors.white,
                  shape: BoxShape.circle, // Circular buttons
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryCyan
                        : AppColors.gray300,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryCyan.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                            spreadRadius: 0,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Center(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.gray700,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
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

