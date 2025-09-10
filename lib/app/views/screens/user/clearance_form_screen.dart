import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  int _currentStep = 1;
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();

  // Form controllers
  final _shipNameController = TextEditingController();
  final _agentNameController = TextEditingController();
  final _portController = TextEditingController();
  final _dateController = TextEditingController();
  final _wniCrewController = TextEditingController();
  final _wnaCrewController = TextEditingController();

  String? _selectedFlag;
  final List<String> _countryFlags = ["Indonesia", "Singapura", "Malaysia", "Panama", "Liberia", "Thailand", "Vietnam", "Filipina","Tiongkok", "Jepang", "Korea Selatan", "India", "Amerika Serikat"];
  String? _selectedLocation;
  final List<String> _locations = ["Bagendang", "Pulang Pisau"];
  String? _portClearanceFile, _crewListFile, _notificationLetterFile;
  final ImagePicker _picker = ImagePicker();
  late String _selectedLanguage;

  bool _isSubmitting = false;

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

    if (widget.existingApplication != null) {
      final app = widget.existingApplication!;
      _shipNameController.text = app.shipName;
      _selectedFlag = app.flag;
      _agentNameController.text = app.agentName;
      _portController.text = app.port ?? '';
      _dateController.text = app.date ?? '';
      _wniCrewController.text = app.wniCrew ?? '';
      _wnaCrewController.text = app.wnaCrew ?? '';
      _selectedLocation = app.location ?? _locations.first;
      _portClearanceFile = app.portClearanceFile;
      _crewListFile = app.crewListFile;
      _notificationLetterFile = app.notificationLetterFile;
    } else {
      _agentNameController.text = widget.agentName;
      _selectedLocation = _locations.first;
      _selectedFlag = "Indonesia";
      _dateController.text = DateFormat('dd MMMM yyyy').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _shipNameController.dispose();
    _agentNameController.dispose();
    _portController.dispose();
    _dateController.dispose();
    _wniCrewController.dispose();
    _wnaCrewController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (step > 1 && !_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _currentStep = step; });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030)
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd MMMM yyyy').format(picked);
      });
    }
  }

  void _showImageSourceActionSheet(String docType) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(_tr('gallery')),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFile(ImageSource.gallery, docType);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(_tr('camera')),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFile(ImageSource.camera, docType);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFile(ImageSource source, String documentType) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (!context.mounted) return;
    if (pickedFile != null) {
      setState(() {
        final fileName = pickedFile.name;
        if (documentType == 'Port Clearance') _portClearanceFile = fileName;
        if (documentType == 'Crew List') _crewListFile = fileName;
        if (documentType == 'Notification Letter') _notificationLetterFile = fileName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$documentType uploaded successfully: ${pickedFile.name}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _submitApplication() {
    if (_portClearanceFile == null || _crewListFile == null || _notificationLetterFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('upload_all_docs')),
          backgroundColor: Colors.red,
        ),
      );
      _goToStep(2);
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text(_tr('submit_dialog_title'), style: const TextStyle(fontWeight: FontWeight.bold))),
          content: Text(_tr('submit_dialog_content'), textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.blue.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
              ),
              child: Text(_tr('cancel'), style: const TextStyle(color: Colors.blue)),
              onPressed: () { Navigator.of(context).pop(); },
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
              ),
              child: Text(_tr('send')),
              onPressed: () {
                Navigator.of(context).pop();
                _performSubmission();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performSubmission() async {
    setState(() => _isSubmitting = true);

    try {
      print('DEBUG: Starting application submission process');
      print('DEBUG: Application type: ${widget.type}');
      print('DEBUG: Existing application: ${widget.existingApplication?.id}');

      final application = ClearanceApplication(
        id: widget.existingApplication?.id ?? '',
        shipName: _shipNameController.text.trim(),
        flag: _selectedFlag ?? "Indonesia",
        agentName: _agentNameController.text,
        agentUid: '', // Will be set by the service
        type: widget.type,
        port: _portController.text.trim().isEmpty ? null : _portController.text.trim(),
        date: _dateController.text.trim().isEmpty ? null : _dateController.text.trim(),
        wniCrew: _wniCrewController.text.trim().isEmpty ? null : _wniCrewController.text.trim(),
        wnaCrew: _wnaCrewController.text.trim().isEmpty ? null : _wnaCrewController.text.trim(),
        portClearanceFile: _portClearanceFile,
        crewListFile: _crewListFile,
        notificationLetterFile: _notificationLetterFile,
      );

      print('DEBUG: Created ClearanceApplication object: ${application.shipName}');

      String? applicationId;
      if (widget.existingApplication != null) {
        // Update existing application
        print('DEBUG: Updating existing application');
        final success = await _userService.updateApplication(widget.existingApplication!.id, application);
        if (success) {
          applicationId = widget.existingApplication!.id;
        }
      } else {
        // Submit new application
        print('DEBUG: Submitting new application');
        applicationId = await _userService.submitClearanceApplication(application);
      }

      if (applicationId != null && mounted) {
        print('DEBUG: Application submission successful, ID: $applicationId');
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
              application: application.copyWith(id: applicationId!),
              initialLanguage: _selectedLanguage,
            ),
          ),
        );
      } else {
        print('DEBUG: Application submission failed - no ID returned');
        throw Exception('Failed to submit application');
      }
    } catch (e) {
      print('DEBUG: Error in _performSubmission: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        final firebaseError = e as FirebaseException;
        print('DEBUG: Firebase error code: ${firebaseError.code}');
        print('DEBUG: Firebase error message: ${firebaseError.message}');
      }
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
    final applicationType = widget.existingApplication?.type ?? widget.type;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(applicationType == ApplicationType.kedatangan ? _tr('arrival_title') : _tr('departure_title'),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: _buildStepper(),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentStep - 1,
                children: [
                  _buildFormStep(),
                  _buildUploadStep(),
                  _buildSubmitStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepIndicator(step: 1, label: _tr('step1'), isDone: _currentStep > 1),
        _buildStepDivider(),
        _buildStepIndicator(step: 2, label: _tr('step2'), isDone: _currentStep > 2),
        _buildStepDivider(),
        _buildStepIndicator(step: 3, label: _tr('step3'), isDone: false),
      ],
    );
  }

  Widget _buildStepIndicator({required int step, required String label, required bool isDone}) {
    bool isActive = _currentStep == step;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : (isDone ? Colors.white : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive || isDone ? Colors.blue : Colors.grey.shade300)
      ),
      child: Row(
        children: [
          if (isDone) const Icon(Icons.check_circle, color: Colors.blue, size: 18),
          if (isDone) const SizedBox(width: 4),
          Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildStepDivider() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Divider(color: Colors.grey.shade300, thickness: 1)
      ),
    );
  }

  Widget _buildFormStep() {
    final applicationType = widget.existingApplication?.type ?? widget.type;
    final bool isKedatangan = applicationType == ApplicationType.kedatangan;
    final String portLabel = isKedatangan ? _tr('last_port') : _tr('next_port');
    final String dateLabel = isKedatangan ? _tr('eta') : _tr('etd');

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Text(_tr('form_instruction'), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _buildTextField(label: _tr('ship_name'), controller: _shipNameController, hint: _tr('ship_name_hint')),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tr('flag'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedFlag,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _countryFlags.map((String country) {
                    return DropdownMenuItem<String>(value: country, child: Text(country));
                  }).toList(),
                  onChanged: (newValue) { setState(() { _selectedFlag = newValue; }); },
                  validator: (value) => value == null ? _tr('select_flag') : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tr('location'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLocation,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _locations.map((String location) {
                    return DropdownMenuItem<String>(value: location, child: Text(location));
                  }).toList(),
                  onChanged: (newValue) { setState(() { _selectedLocation = newValue; }); },
                  validator: (value) => value == null ? _tr('select_location') : null,
                ),
              ],
            ),
          ),
          _buildTextField(label: portLabel, controller: _portController, hint: "Tanjung Priok"),
          _buildTextField(label: dateLabel, controller: _dateController, hint: _tr('select_date'), isReadOnly: true, isDate: true),
          Row(
            children: [
              Expanded(child: _buildTextField(label: _tr('wni_crew'), controller: _wniCrewController, hint: "0", isNumeric: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(label: _tr('wna_crew'), controller: _wnaCrewController, hint: "0", isNumeric: true)),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _goToStep(2),
            child: Text(_tr('next')),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadStep() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Text(_tr('upload_instruction'), style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        _buildUploadCard(title: _tr('port_clearance'), subtitle: _tr('port_clearance_subtitle'), fileName: _portClearanceFile, onTap: () => _showImageSourceActionSheet('Port Clearance')),
        const SizedBox(height: 16),
        _buildUploadCard(title: _tr('crew_list'), subtitle: _tr('crew_list_subtitle'), fileName: _crewListFile, onTap: () => _showImageSourceActionSheet('Crew List')),
        const SizedBox(height: 16),
        _buildUploadCard(title: _tr('notification_letter'), subtitle: _tr('notification_letter_subtitle'), fileName: _notificationLetterFile, onTap: () => _showImageSourceActionSheet('Notification Letter')),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _goToStep(1),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16)
                ),
                child: Text(_tr('back'))
              )
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _goToStep(3),
                child: Text(_tr('next'))
              )
            ),
          ],
        )
      ],
    );
  }

  Widget _buildSubmitStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Text(_tr('review_confirm'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tr('vessel_details'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(height: 24),
                        _buildDetailRow(_tr('ship_name'), _shipNameController.text),
                        _buildDetailRow(_tr('flag'), _selectedFlag ?? '-'),
                        _buildDetailRow(_tr('crew_count'), "WNI: ${_wniCrewController.text}, WNA: ${_wnaCrewController.text}"),
                        _buildDetailRow(_tr('location'), _selectedLocation ?? '-'),
                        _buildDetailRow("Date", _dateController.text),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tr('required_docs'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(height: 24),
                        _buildDocumentRow(_tr('notification_letter'), _notificationLetterFile),
                        _buildDocumentRow(_tr('port_clearance'), _portClearanceFile),
                        _buildDocumentRow(_tr('crew_list'), _crewListFile),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _goToStep(2),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16)
                    ),
                    child: Text(_tr('back'))
                  )
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitApplication,
                    child: _isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Text(_tr('saving')),
                            ],
                          )
                        : Text(_tr('submit_application'))
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isReadOnly = false,
    bool isDate = false,
    bool isNumeric = false
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (label.isNotEmpty) const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            readOnly: isReadOnly,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: isReadOnly,
              fillColor: isReadOnly ? Colors.grey[200] : Colors.grey.shade50,
              suffixIcon: isDate ? const Icon(Icons.calendar_today_outlined) : null,
            ),
            validator: (v) => v!.isEmpty ? _tr('required_field') : null,
            onTap: isDate ? () => _selectDate(context) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard({required String title, required String subtitle, required String? fileName, required VoidCallback onTap}) {
    bool isUploaded = fileName != null;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            isUploaded
                ? Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(fileName!, style: const TextStyle(color: Colors.green), overflow: TextOverflow.ellipsis)),
                      IconButton(onPressed: onTap, icon: const Icon(Icons.edit, color: Colors.blueGrey))
                    ]
                  )
                : OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_tr('choose_file')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: Colors.blue),
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    )
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey))),
          const Text(" : "),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(String label, String? fileName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: Colors.grey.shade400),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(fileName ?? _tr('not_uploaded'), style: TextStyle(color: fileName != null ? Colors.blue : Colors.red, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
