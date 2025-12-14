import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/models/coaching_report.dart';

class CoachingFormScreen extends StatefulWidget {
  final String date;
  final String mrId;
  final String mrName;
  final String dmName;
  final Function(CoachingReport) onSubmit;
  final VoidCallback onBack;

  const CoachingFormScreen({
    super.key,
    required this.date,
    required this.mrId,
    required this.mrName,
    required this.dmName,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<CoachingFormScreen> createState() => _CoachingFormScreenState();
}

class _CoachingFormScreenState extends State<CoachingFormScreen> {
  int _currentSection = 0;
  String? _selectedDM;
  
  final Map<String, String?> _formData = {};
  
  final List<Map<String, String>> _dms = [
    {'id': '2328', 'name': 'Mahmoud Zidan Menshawy'},
    {'id': '2329', 'name': 'Mostafa Amin Abd Elrahman'},
    {'id': '2345', 'name': 'Mohamed Arafa'},
    {'id': '2357', 'name': 'Mohamed Saeed'},
  ];

  final List<Map<String, String>> _sections = [
    {'title': 'Basic Information', 'key': 'basic'},
    {'title': 'Personal Attributes', 'key': 'personal'},
    {'title': 'Pre-Call Planning', 'key': 'preCall'},
    {'title': 'Sales Call Steps', 'key': 'salesCall'},
    {'title': 'Closing', 'key': 'closing'},
    {'title': 'Post Call Analysis', 'key': 'postCall'},
  ];

  @override
  void initState() {
    super.initState();
    _formData['date'] = widget.date;
    _formData['mrId'] = widget.mrId;
    _formData['mrName'] = widget.mrName;
    _formData['dmName'] = widget.dmName;
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
      strengths: _formData['strengths'],
      improvements: _formData['improvements'],
      filledWithMR: _formData['filledWithMR'],
    );

    widget.onSubmit(report);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_currentSection == _sections.length - 1)
                                    const Icon(Icons.send, color: Colors.white, size: 20),
                                  if (_currentSection == _sections.length - 1)
                                    const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _currentSection < _sections.length - 1
                                          ? 'Next'
                                          : 'Submit Report',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
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
        _buildDropdownField(
          label: 'District Manager (DM)',
          value: _selectedDM,
          items: _dms.map((dm) => '${dm['name']} - ${dm['id']}').toList(),
          onChanged: (value) {
            final dm = _dms.firstWhere((d) => '${d['name']} - ${d['id']}' == value);
            setState(() {
              _selectedDM = value;
              _formData['dmId'] = dm['id'];
              _formData['dmName'] = dm['name'];
            });
          },
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Medical Representative (MR)',
          value: '${widget.mrName} - ${widget.mrId}',
          enabled: false,
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
        TextField(
          enabled: enabled,
          controller: TextEditingController(text: value),
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
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    String? value,
    required List<String> items,
    required Function(String?) onChanged,
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
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          hint: const Text('Select District Manager...'),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTextAreaField(String field, String label, String placeholder) {
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
          controller: TextEditingController(text: _formData[field] ?? ''),
          onChanged: (value) => _updateField(field, value),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: placeholder,
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
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final buttonWidth = (constraints.maxWidth - (5 * 8)) / 6;
            return Row(
              children: List.generate(6, (index) {
                final rating = (index + 1).toString();
                final isSelected = _formData[field] == rating;
                return SizedBox(
                  width: buttonWidth,
                  child: Padding(
                    padding: EdgeInsets.only(right: index < 5 ? 8 : 0),
                    child: InkWell(
                      onTap: () => _updateField(field, rating),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? AppColors.primaryGradientHorizontal
                              : null,
                          color: isSelected ? null : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : AppColors.gray200,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
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
                          rating,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.gray700,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
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


