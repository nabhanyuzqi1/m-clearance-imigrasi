import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../localization/app_strings.dart';
import '../../../models/clearance_application.dart';
import '../../../services/user_service.dart';
import 'clearance_result_screen.dart';

class ClearanceFormScreen extends StatefulWidget {
  final ApplicationType type;
  final String agentName;
  final String initialLanguage;
  final ClearanceApplication? existingApplication;

  const ClearanceFormScreen({
    super.key,
    required this.type,
    required this.agentName,
    required this.initialLanguage,
    this.existingApplication,
  });

  @override
  State<ClearanceFormScreen> createState() => _ClearanceFormScreenState();
}

class _ClearanceFormScreenState extends State<ClearanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();

  // Form controllers
  final _shipNameController = TextEditingController();
  final _flagController = TextEditingController();
  final _portController = TextEditingController();
  final _dateController = TextEditingController();
  final _wniCrewController = TextEditingController();
  final _wnaCrewController = TextEditingController();
  final _officerNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  String _selectedLanguage = 'EN';

  String _tr(String key) => AppStrings.tr(
    context: context,
    screenKey: 'clearanceForm',
    stringKey: key,
    langCode: _selectedLanguage,
  );

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;

    // Pre-fill form if editing existing application
    if (widget.existingApplication != null) {
      final app = widget.existingApplication!;
      _shipNameController.text = app.shipName;
      _flagController.text = app.flag;
      _portController.text = app.port ?? '';
      _dateController.text = app.date ?? '';
      _wniCrewController.text = app.wniCrew ?? '';
      _wnaCrewController.text = app.wnaCrew ?? '';
      _officerNameController.text = app.officerName ?? '';
      _locationController.text = app.location ?? '';
      _notesController.text = app.notes ?? '';
    }
  }

  @override
  void dispose() {
    _shipNameController.dispose();
    _flagController.dispose();
    _portController.dispose();
    _dateController.dispose();
    _wniCrewController.dispose();
    _wnaCrewController.dispose();
    _officerNameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final application = ClearanceApplication(
        id: widget.existingApplication?.id ?? '',
        shipName: _shipNameController.text.trim(),
        flag: _flagController.text.trim(),
        agentName: widget.agentName,
        agentUid: '', // Will be set by the service
        type: widget.type,
        port: _portController.text.trim().isEmpty ? null : _portController.text.trim(),
        date: _dateController.text.trim().isEmpty ? null : _dateController.text.trim(),
        wniCrew: _wniCrewController.text.trim().isEmpty ? null : _wniCrewController.text.trim(),
        wnaCrew: _wnaCrewController.text.trim().isEmpty ? null : _wnaCrewController.text.trim(),
        officerName: _officerNameController.text.trim().isEmpty ? null : _officerNameController.text.trim(),
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      String? applicationId;
      if (widget.existingApplication != null) {
        // Update existing application
        final success = await _userService.updateApplication(widget.existingApplication!.id, application);
        if (success) {
          applicationId = widget.existingApplication!.id;
        }
      } else {
        // Submit new application
        applicationId = await _userService.submitClearanceApplication(application);
      }

      if (applicationId != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('success_message')),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to result screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ClearanceResultScreen(
                application: ClearanceApplication(
                  id: applicationId!,
                  shipName: application.shipName,
                  flag: application.flag,
                  agentName: application.agentName,
                  agentUid: application.agentUid,
                  type: application.type,
                  status: application.status,
                  notes: application.notes,
                  port: application.port,
                  date: application.date,
                  wniCrew: application.wniCrew,
                  wnaCrew: application.wnaCrew,
                  officerName: application.officerName,
                  location: application.location,
                  createdAt: application.createdAt,
                  updatedAt: application.updatedAt,
                ),
                initialLanguage: _selectedLanguage,
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to submit application');
      }
    } catch (e) {
      print('Error submitting application: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('error_message')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == ApplicationType.kedatangan
        ? _tr('arrival_form')
        : _tr('departure_form');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Ship Information Section
            _buildSectionTitle('Ship Information'),
            _buildTextField(
              _tr('ship_name'),
              _shipNameController,
              validator: (value) => value?.isEmpty ?? true ? _tr('required_field') : null,
            ),
            _buildTextField(
              _tr('flag'),
              _flagController,
              validator: (value) => value?.isEmpty ?? true ? _tr('required_field') : null,
            ),
            _buildTextField(_tr('port'), _portController),
            _buildTextField(_tr('date'), _dateController),

            const SizedBox(height: 24),

            // Crew Information Section
            _buildSectionTitle('Crew Information'),
            _buildTextField(
              _tr('wni_crew'),
              _wniCrewController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value?.isEmpty ?? true) return null;
                final number = int.tryParse(value!);
                if (number == null) return _tr('invalid_number');
                return null;
              },
            ),
            _buildTextField(
              _tr('wna_crew'),
              _wnaCrewController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value?.isEmpty ?? true) return null;
                final number = int.tryParse(value!);
                if (number == null) return _tr('invalid_number');
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Officer Information Section
            _buildSectionTitle('Officer Information'),
            _buildTextField(_tr('officer_name'), _officerNameController),
            _buildTextField(_tr('location'), _locationController),

            const SizedBox(height: 24),

            // Notes Section
            _buildSectionTitle('Additional Information'),
            _buildTextField(
              _tr('notes'),
              _notesController,
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(_tr('saving')),
                        ],
                      )
                    : Text(_tr('submit')),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        validator: validator,
      ),
    );
  }
}
