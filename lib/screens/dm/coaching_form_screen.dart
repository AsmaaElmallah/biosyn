import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

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
  int _currentSection = 0;
  final Map<String, String?> _formData = {};

  final List<Map<String, String>> _sections = [
    {'title': 'Basic Information', 'key': 'basic'},
    {'title': 'Personal Attributes', 'key': 'personal'},
    {'title': 'Pre-Call Planning', 'key': 'preCall'},
    {'title': 'Sales Call Steps', 'key': 'salesCall'},
    {'title': 'Closing', 'key': 'closing'},
    {'title': 'Post Call Analysis', 'key': 'postCall'},
  ];

  // Text controllers for text areas (to prevent RTL issues)
  late final TextEditingController _strengthsController;
  late final TextEditingController _improvementsController;
  late final TextEditingController _brickNameController;
  late final TextEditingController _doctorsVisitedController;

  // Location
  Position? _currentPosition;
  bool _locationLoading = false;
  String? _locationName;
  String? _googleMapsUrl;

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
    _doctorsVisitedController = TextEditingController();
  }

  @override
  void dispose() {
    _strengthsController.dispose();
    _improvementsController.dispose();
    _brickNameController.dispose();
    _doctorsVisitedController.dispose();
    super.dispose();
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
      0: ['dmId'],
      1: ['punctuality', 'dressCode', 'timeManagement'],
      2: ['pharmacyFeedback', 'reviewProfile', 'brandBonding', 'smartObjectives'],
      3: ['opening', 'patientProfile', 'engaging', 'insightfulQuestions', 'activeListening', 'linkFeatures', 'productKnowledge', 'eDetailing', 'answeringQuestions'],
      4: ['summarizeCall', 'askCommitment', 'bridging'],
      5: ['selfAssessment', 'strengths', 'improvements', 'filledWithMR'],
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
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot submit coaching reports after 12:00 AM (midnight)')),
      );
      return;
    }

    if (!_validateSection()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    final report = CoachingReport(
      date: _formData['date']!,
      dmId: _formData['dmId']!,
      dmName: _formData['dmName']!,
      mrId: _formData['mrId']!,
      mrName: _formData['mrName']!,
      coachRole: widget.coachRole, // 'dm' or 'ft'
      // Brick Information
      brickName: _brickNameController.text.trim().isNotEmpty ? _brickNameController.text.trim() : null,
      brickLocationLat: _formData['brickLocationLat'] != null ? double.tryParse(_formData['brickLocationLat']!) : null,
      brickLocationLng: _formData['brickLocationLng'] != null ? double.tryParse(_formData['brickLocationLng']!) : null,
      locationName: _formData['locationName'],
      googleMapsUrl: _formData['googleMapsUrl'],
      visitCount: _formData['visitCount'] != null ? int.tryParse(_formData['visitCount']!) : 1,
      doctorsVisited: _doctorsVisitedController.text.trim().isNotEmpty ? _doctorsVisitedController.text.trim() : null,
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

    widget.onSubmit(report);
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
                            _sections[_currentSection]['title']!,
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
                                blurRadius: 10,
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
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_currentSection > 0) const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _currentSection < _sections.length - 1
                              ? AppColors.primaryGradientHorizontal
                              : const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (_currentSection < _sections.length - 1
                                      ? AppColors.primaryBlue
                                      : const Color(0xFF10B981))
                                  .withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _currentSection < _sections.length - 1
                                ? _handleNext
                                : _handleSubmit,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_currentSection == _sections.length - 1)
                                    const Icon(Icons.send, color: Colors.white, size: 20),
                                  if (_currentSection == _sections.length - 1)
                                    const SizedBox(width: 8),
                                  Text(
                                    _currentSection < _sections.length - 1
                                        ? 'Next'
                                        : 'Submit Report',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
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
        return _buildPersonalAttributes();
      case 2:
        return _buildPreCallPlanning();
      case 3:
        return _buildSalesCallSteps();
      case 4:
        return _buildClosing();
      case 5:
        return _buildPostCallAnalysis();
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
          label: 'District Manager (DM)',
          value: '${widget.dmName} - ${widget.dmId}',
          enabled: false,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Medical Representative (MR)',
          value: '${widget.mrName} - ${widget.mrId}',
          enabled: false,
        ),
        const SizedBox(height: 24),
        // Brick Name
        TextField(
          controller: _brickNameController,
          onChanged: (value) => _updateField('brickName', value),
          decoration: InputDecoration(
            labelText: 'Brick Name',
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
                Text(
                  'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: AppColors.gray600),
                ),
                if (_locationName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryCyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place, color: AppColors.primaryCyan, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationName!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.gray700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
        // Doctors Visited
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
  }) {
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
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            enabled: enabled,
            controller: TextEditingController(text: value),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? Colors.white : AppColors.gray50,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _updateField(field, 'Yes'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: value == 'Yes'
                        ? [
                            BoxShadow(
                              color: AppColors.primaryBlue.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'Yes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: value == 'Yes' ? Colors.white : AppColors.gray700,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _updateField(field, 'No'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: value == 'No' ? AppColors.error : Colors.white,
                    border: Border.all(
                      color: value == 'No'
                          ? Colors.transparent
                          : AppColors.gray200,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: value == 'No'
                        ? [
                            BoxShadow(
                              color: AppColors.error.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'No',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: value == 'No' ? Colors.white : AppColors.gray700,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Increased spacing from 8 to 12
            final spacing = 12.0;
            final buttonWidth = (constraints.maxWidth - (5 * spacing)) / 6;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final rating = (index + 1).toString();
                final isSelected = _formData[field] == rating;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  width: buttonWidth,
                  transform: isSelected 
                      ? (Matrix4.identity()..scale(1.05))
                      : Matrix4.identity(),
                  transformAlignment: Alignment.center,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _updateField(field, rating),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        // Increased vertical padding from 12 to 16
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              rating,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.gray700,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 2),
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}


