import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:geolocator/geolocator.dart';

class PMMSLCoachingFormScreen extends StatefulWidget {
  final String date;
  final String coachId;
  final String coachName;
  final String coachRole; // 'pm' or 'msl'
  final String? dmId; // Optional - if provided, pre-select DM
  final String? dmName; // Optional - if provided, pre-select DM
  final String? mrId; // Optional - if provided, pre-select MR
  final String? mrName; // Optional - if provided, pre-select MR
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

      setState(() {
        _currentPosition = position;
        _formData['brickLocationLat'] = position.latitude.toString();
        _formData['brickLocationLng'] = position.longitude.toString();
        _locationLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location captured: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}')),
        );
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

    final report = CoachingReport(
      date: widget.date,
      dmId: _formData['dmId'] ?? '',
      dmName: (selectedDM['name'] ?? '').toString(),
      mrId: _formData['mrId'] ?? '',
      mrName: (selectedMR['name'] ?? '').toString(),
      coachRole: widget.coachRole,
      // Brick Information
      brickName: _formData['areaBrickName'],
      brickLocationLat: _formData['brickLocationLat'] != null ? double.tryParse(_formData['brickLocationLat']!) : null,
      brickLocationLng: _formData['brickLocationLng'] != null ? double.tryParse(_formData['brickLocationLng']!) : null,
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
    );

    widget.onSubmit(report);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text('${widget.coachRole.toUpperCase()} Coaching Form'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentSection + 1) / _sections.length,
                      backgroundColor: AppColors.gray200,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryCyan),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_currentSection + 1}/${_sections.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
            // Section Title
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _sections[_currentSection]['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildSectionContent(),
              ),
            ),
            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  if (_currentSection > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handlePrevious,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.primaryBlue, width: 2),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentSection > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradientHorizontal,
                        borderRadius: BorderRadius.circular(12),
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
              if (_currentPosition != null)
                Text(
                  'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: AppColors.gray600),
                ),
              const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Yes'),
                value: 'Yes',
                groupValue: _formData[field],
                onChanged: (value) => _updateField(field, value ?? ''),
                activeColor: AppColors.primaryCyan,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('No'),
                value: 'No',
                groupValue: _formData[field],
                onChanged: (value) => _updateField(field, value ?? ''),
                activeColor: AppColors.primaryCyan,
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            final value = (index + 1).toString();
            return GestureDetector(
              onTap: () => _updateField(field, value),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _formData[field] == value
                      ? AppColors.primaryCyan
                      : AppColors.gray200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: _formData[field] == value
                          ? Colors.white
                          : AppColors.gray600,
                      fontWeight: FontWeight.bold,
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

