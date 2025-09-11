import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:m_clearance_imigrasi/app/utils/image_utils.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../models/clearance_application.dart';
import '../../../services/user_service.dart';
import '../../../services/network_utils.dart';
import 'clearance_result_screen.dart';
import 'document_view_screen.dart';

class ClearanceFormScreen extends StatefulWidget {
  final ApplicationType type;
  final String agentName;
  final ClearanceApplication? existingApplication;

  final String initialLanguage;
  const ClearanceFormScreen({
    super.key,
    required this.type,
    required this.agentName,
    this.existingApplication,
    required this.initialLanguage,
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

  // File data storage
  Uint8List? _portClearanceFileData;
  Uint8List? _crewListFileData;
  Uint8List? _notificationLetterFileData;
  String? _portClearanceFileName, _crewListFileName, _notificationLetterFileName;

  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;

  // Cached translations to prevent rebuilds
  late String _arrivalTitle;
  late String _departureTitle;
  late String _formInstruction;
  late String _shipNameHint;
  late String _selectDateHint;
  late String _uploadInstruction;
  late String _next;
  late String _back;
  late String _submitApplicationText;
  late String _saving;

  String _tr(String key) => AppStrings.tr(
        context: context,
        screenKey: 'clearanceForm',
        stringKey: key,
        langCode: widget.initialLanguage,
      );

  void _cacheTranslations() {
    _arrivalTitle = _tr('arrival_title');
    _departureTitle = _tr('departure_title');
    _formInstruction = _tr('form_instruction');
    _shipNameHint = _tr('ship_name_hint');
    _selectDateHint = _tr('select_date');
    _uploadInstruction = _tr('upload_instruction');
    _next = _tr('next');
    _back = _tr('back');
    _submitApplicationText = _tr('submit_application');
    _saving = _tr('saving');
  }

  @override
  void initState() {
    super.initState();
    _cacheTranslations();

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
      // For existing applications, we don't have file data, only names
      _portClearanceFileName = app.portClearanceFile;
      _crewListFileName = app.crewListFile;
      _notificationLetterFileName = app.notificationLetterFile;
    } else {
      _agentNameController.text = widget.agentName;
      _selectedLocation = _locations.first;
      _selectedFlag = _tr('indonesia');
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

  Future<bool> _requestPermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isGranted) {
        return true;
      } else if (cameraStatus.isPermanentlyDenied) {
        // Show dialog to open app settings
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(_tr('permission_required')),
                content: Text(_tr('camera_permission_message')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_tr('cancel')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: Text(_tr('open_settings')),
                  ),
                ],
              );
            },
          );
        }
        return false;
      } else {
        return false;
      }
    } else {
      // For gallery, request storage permissions
      final storageStatus = await Permission.photos.request();
      if (storageStatus.isGranted) {
        return true;
      } else if (storageStatus.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(_tr('permission_required')),
                content: Text(_tr('storage_permission_message')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_tr('cancel')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: Text(_tr('open_settings')),
                  ),
                ],
              );
            },
          );
        }
        return false;
      } else {
        return false;
      }
    }
  }

  Future<String?> _uploadDocumentToStorage(Uint8List fileData, String fileName, String userId) async {
    return NetworkUtils.executeWithRetry(
      () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileExtension = fileName.split('.').last;
        final baseName = fileName.split('.').first;
        final uniqueFileName = '${baseName}_${timestamp}_${userId.substring(0, 8)}.$fileExtension';

        final storageRef = FirebaseStorage.instance.ref();
        final documentRef = storageRef.child('applications/$userId/documents/$uniqueFileName');

        final uploadTask = documentRef.putData(fileData);
        final snapshot = await NetworkUtils.withTimeout(
          uploadTask.whenComplete(() => null),
          const Duration(seconds: 15),
        );

        if (snapshot.state == TaskState.success) {
          final downloadUrl = await NetworkUtils.withTimeout(
            documentRef.getDownloadURL(),
            const Duration(seconds: 5),
          );
          return downloadUrl;
        } else {
          throw NetworkException(_tr('upload_failed'), isRetryable: true);
        }
      },
      shouldRetry: NetworkUtils.isRetryableError,
    ).catchError((e) {
      print(_tr('upload_error'));
      return '';
    });
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
                onTap: () async {
                  Navigator.of(context).pop();
                  final hasPermission = await _requestPermissions(ImageSource.gallery);
                  if (hasPermission) {
                    _pickImageFile(ImageSource.gallery, docType);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(_tr('camera')),
                onTap: () async {
                  Navigator.of(context).pop();
                  final hasPermission = await _requestPermissions(ImageSource.camera);
                  if (hasPermission) {
                    _pickImageFile(ImageSource.camera, docType);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_present),
                title: Text(_tr('file_picker')),
                onTap: () async {
                  Navigator.of(context).pop();
                  _pickDocumentFile(docType);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFile(ImageSource source, String documentType) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (!context.mounted) return;
    if (pickedFile != null) {
      final minifiedFile = await minifyImage(File(pickedFile.path));
      final bytes = await minifiedFile.readAsBytes();
      setState(() {
        final fileName = pickedFile.name;
        if (documentType == _tr('port_clearance')) {
          _portClearanceFileData = bytes;
          _portClearanceFileName = fileName;
        }
        if (documentType == _tr('crew_list')) {
          _crewListFileData = bytes;
          _crewListFileName = fileName;
        }
        if (documentType == _tr('notification_letter')) {
          _notificationLetterFileData = bytes;
          _notificationLetterFileName = fileName;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_tr('upload_success')}: ${pickedFile.name}'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _pickDocumentFile(String documentType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: AppTheme.errorColor),
        );
        return;
      }

      final picked = result.files.single;
      if (picked.bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: AppTheme.errorColor),
        );
        return;
      }

      final name = picked.name.isNotEmpty ? picked.name : 'document.pdf';
      setState(() {
        if (documentType == _tr('port_clearance')) {
          _portClearanceFileData = picked.bytes;
          _portClearanceFileName = name;
        }
        if (documentType == _tr('crew_list')) {
          _crewListFileData = picked.bytes;
          _crewListFileName = name;
        }
        if (documentType == _tr('notification_letter')) {
          _notificationLetterFileData = picked.bytes;
          _notificationLetterFileName = name;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_tr('upload_success')}: $name'), backgroundColor: AppTheme.successColor),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  void _submitApplication() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_portClearanceFileData == null || _crewListFileData == null || _notificationLetterFileData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('upload_all_docs')),
          backgroundColor: AppTheme.errorColor,
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
          title: Center(child: Text(_tr('submit_dialog_title'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenWidth * 0.045))),
          content: Text(_tr('submit_dialog_content'), textAlign: TextAlign.center, style: TextStyle(fontSize: screenWidth * 0.04)),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08, vertical: screenWidth * 0.03)
              ),
              child: Text(_tr('cancel'), style: TextStyle(color: AppTheme.primaryColor, fontSize: screenWidth * 0.04)),
              onPressed: () { Navigator.of(context).pop(); },
            ),
            SizedBox(width: screenWidth * 0.02),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08, vertical: screenWidth * 0.03)
              ),
              child: Text(_tr('send'), style: TextStyle(fontSize: screenWidth * 0.04)),
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

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception(_tr('auth_error'));
      }

      // Upload files to Firebase Storage in parallel

      final uploadTasks = <Future<String?>>[];

      if (_portClearanceFileData != null && _portClearanceFileName != null) {
        uploadTasks.add(_uploadDocumentToStorage(_portClearanceFileData!, _portClearanceFileName!, user.uid));
      } else {
        uploadTasks.add(Future.value(null));
      }

      if (_crewListFileData != null && _crewListFileName != null) {
        uploadTasks.add(_uploadDocumentToStorage(_crewListFileData!, _crewListFileName!, user.uid));
      } else {
        uploadTasks.add(Future.value(null));
      }

      if (_notificationLetterFileData != null && _notificationLetterFileName != null) {
        uploadTasks.add(_uploadDocumentToStorage(_notificationLetterFileData!, _notificationLetterFileName!, user.uid));
      } else {
        uploadTasks.add(Future.value(null));
      }

      final uploadResults = await Future.wait(uploadTasks);
      final portClearanceUrl = uploadTasks.isNotEmpty ? uploadResults[0] : null;
      final crewListUrl = uploadTasks.length > 1 ? uploadResults[1] : null;
      final notificationLetterUrl = uploadTasks.length > 2 ? uploadResults[2] : null;

      // Files uploaded successfully

      final application = ClearanceApplication(
        id: widget.existingApplication?.id ?? '',
        shipName: _shipNameController.text.trim(),
        flag: _selectedFlag ?? _tr('indonesia'),
        agentName: _agentNameController.text,
        agentUid: '', // Will be set by the service
        type: widget.type,
        port: _portController.text.trim().isEmpty ? null : _portController.text.trim(),
        date: _dateController.text.trim().isEmpty ? null : _dateController.text.trim(),
        wniCrew: _wniCrewController.text.trim().isEmpty ? null : _wniCrewController.text.trim(),
        wnaCrew: _wnaCrewController.text.trim().isEmpty ? null : _wnaCrewController.text.trim(),
        portClearanceFile: portClearanceUrl ?? _portClearanceFileName,
        crewListFile: crewListUrl ?? _crewListFileName,
        notificationLetterFile: notificationLetterUrl ?? _notificationLetterFileName,
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
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Navigate to result screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClearanceResultScreen(
              application: application.copyWith(id: applicationId!),
              initialLanguage: widget.initialLanguage,
            ),
          ),
        );
      } else {
        print('DEBUG: Application submission failed - no ID returned');
        throw Exception(_tr('submit_error'));
      }
    } catch (e) {
      print('DEBUG: Error in _performSubmission: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        final firebaseError = e;
        print('DEBUG: Firebase error code: ${firebaseError.code}');
        print('DEBUG: Firebase error message: ${firebaseError.message}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('error_message')),
            backgroundColor: AppTheme.errorColor,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenWidth * 0.06; // 6% of screen width
    final verticalPadding = screenHeight * 0.02; // 2% of screen height

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(applicationType == ApplicationType.kedatangan ? _arrivalTitle : _departureTitle,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: screenWidth * 0.045)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
              child: _buildStepper(),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentStep - 1,
                children: [
                  _buildFormStep(key: const ValueKey('form_step')),
                  _buildUploadStep(key: const ValueKey('upload_step')),
                  _buildSubmitStep(key: const ValueKey('submit_step')),
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
        color: isActive ? AppTheme.primaryColor : (isDone ? Colors.white : AppTheme.greyShade200),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive || isDone ? AppTheme.primaryColor : AppTheme.greyShade300)
      ),
      child: Row(
        key: ValueKey('step_$step'),
        children: [
          if (isDone) const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 18),
          if (isDone) const SizedBox(width: 4),
          Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildStepDivider() {
    return const Flexible(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: Divider(color: AppTheme.greyShade500, thickness: 1),
      ),
    );
  }

  Widget _buildFormStep({Key? key}) {
    final applicationType = widget.existingApplication?.type ?? widget.type;
    final bool isKedatangan = applicationType == ApplicationType.kedatangan;
    final String portLabel = isKedatangan ? _tr('last_port') : _tr('next_port');
    final String dateLabel = isKedatangan ? _tr('eta') : _tr('etd');
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.03;

    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.all(horizontalPadding),
        children: [
          Text(_formInstruction, style: TextStyle(color: AppTheme.greyShade500, fontSize: screenWidth * 0.035)),
          SizedBox(height: verticalSpacing),
          _buildTextField(label: _tr('ship_name'), controller: _shipNameController, hint: _shipNameHint, key: const ValueKey('ship_name_field')),
          Padding(
            key: const ValueKey('flag_dropdown'),
            padding: EdgeInsets.only(bottom: verticalSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tr('flag'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenWidth * 0.04)),
                SizedBox(height: screenWidth * 0.02),
                DropdownButtonFormField<String>(
                  key: const ValueKey('flag_selector'),
                  initialValue: _selectedFlag,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppTheme.greyShade50,
                  ),
                  items: _countryFlags.map((String country) {
                    return DropdownMenuItem<String>(value: country, child: Text(country, style: TextStyle(fontSize: screenWidth * 0.035)));
                  }).toList(),
                  onChanged: (newValue) { setState(() { _selectedFlag = newValue; }); },
                  validator: (value) => value == null ? _tr('select_flag') : null,
                ),
              ],
            ),
          ),
          Padding(
            key: const ValueKey('location_dropdown'),
            padding: EdgeInsets.only(bottom: verticalSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tr('location'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenWidth * 0.04)),
                SizedBox(height: screenWidth * 0.02),
                DropdownButtonFormField<String>(
                  key: const ValueKey('location_selector'),
                  initialValue: _selectedLocation,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppTheme.greyShade50,
                  ),
                  items: _locations.map((String location) {
                    return DropdownMenuItem<String>(value: location, child: Text(location, style: TextStyle(fontSize: screenWidth * 0.035)));
                  }).toList(),
                  onChanged: (newValue) { setState(() { _selectedLocation = newValue; }); },
                  validator: (value) => value == null ? _tr('select_location') : null,
                ),
              ],
            ),
          ),
          _buildTextField(label: portLabel, controller: _portController, hint: _tr('tanjung_priok'), key: const ValueKey('port_field')),
          _buildTextField(label: dateLabel, controller: _dateController, hint: _selectDateHint, isReadOnly: true, isDate: true, key: const ValueKey('date_field')),
          Row(
            key: const ValueKey('crew_row'),
            children: [
              Expanded(child: _buildTextField(label: _tr('wni_crew'), controller: _wniCrewController, hint: "0", isNumeric: true, key: const ValueKey('wni_crew_field'))),
              SizedBox(width: screenWidth * 0.04),
              Expanded(child: _buildTextField(label: _tr('wna_crew'), controller: _wnaCrewController, hint: "0", isNumeric: true, key: const ValueKey('wna_crew_field'))),
            ],
          ),
          SizedBox(height: verticalSpacing),
          ElevatedButton(
            onPressed: () => _goToStep(2),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
              textStyle: TextStyle(fontSize: screenWidth * 0.04),
            ),
            child: Text(_next),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadStep({Key? key}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.03;

    return ListView(
      key: key,
      shrinkWrap: true,
      padding: EdgeInsets.all(horizontalPadding),
      children: [
        Text(_uploadInstruction, style: TextStyle(color: AppTheme.greyShade500, fontSize: screenWidth * 0.035)),
        SizedBox(height: verticalSpacing),
        _buildUploadCard(title: _tr('port_clearance'), subtitle: _tr('port_clearance_subtitle'), fileName: _portClearanceFileName, onTap: () => _showImageSourceActionSheet(_tr('port_clearance')), key: const ValueKey('port_clearance_card')),
        SizedBox(height: verticalSpacing),
        _buildUploadCard(title: _tr('crew_list'), subtitle: _tr('crew_list_subtitle'), fileName: _crewListFileName, onTap: () => _showImageSourceActionSheet(_tr('crew_list')), key: const ValueKey('crew_list_card')),
        SizedBox(height: verticalSpacing),
        _buildUploadCard(title: _tr('notification_letter'), subtitle: _tr('notification_letter_subtitle'), fileName: _notificationLetterFileName, onTap: () => _showImageSourceActionSheet(_tr('notification_letter')), key: const ValueKey('notification_letter_card')),
        SizedBox(height: verticalSpacing),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _goToStep(1),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryColor),
                  foregroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04)
                ),
                child: Text(_back, style: TextStyle(fontSize: screenWidth * 0.04))
              )
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _goToStep(3),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                  textStyle: TextStyle(fontSize: screenWidth * 0.04),
                ),
                child: Text(_next)
              )
            ),
          ],
        )
      ],
    );
  }

  Widget _buildSubmitStep({Key? key}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.03;

    return Padding(
      key: key,
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(_tr('review_confirm'), style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold)),
                SizedBox(height: verticalSpacing),
                Card(
                  elevation: 0,
                  color: AppTheme.greyShade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tr('vessel_details'), style: TextStyle(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold)),
                        Divider(height: verticalSpacing * 2),
                        _buildDetailRow(_tr('ship_name'), _shipNameController.text),
                        _buildDetailRow(_tr('flag'), _selectedFlag ?? '-'),
                        _buildDetailRow(_tr('crew_count'), "${_tr('wni_label')}: ${_wniCrewController.text}, ${_tr('wna_label')}: ${_wnaCrewController.text}"),
                        _buildDetailRow(_tr('location'), _selectedLocation ?? '-'),
                        _buildDetailRow(_tr('date_label'), _dateController.text),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: verticalSpacing * 2),
                Card(
                  elevation: 0,
                  color: AppTheme.greyShade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tr('required_docs'), style: TextStyle(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold)),
                        Divider(height: verticalSpacing * 2),
                        _buildDocumentRow(_tr('notification_letter'), _notificationLetterFileName),
                        _buildDocumentRow(_tr('port_clearance'), _portClearanceFileName),
                        _buildDocumentRow(_tr('crew_list'), _crewListFileName),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: verticalSpacing * 2),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _goToStep(2),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      foregroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04)
                    ),
                    child: Text(_back, style: TextStyle(fontSize: screenWidth * 0.04))
                  )
                ),
                SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                      textStyle: TextStyle(fontSize: screenWidth * 0.04),
                    ),
                    child: _isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: screenWidth * 0.05,
                                height: screenWidth * 0.05,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Text(_saving),
                            ],
                          )
                        : Text(_submitApplicationText)
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
    bool isNumeric = false,
    Key? key,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final verticalSpacing = screenWidth * 0.03;

    return Padding(
      key: key,
      padding: EdgeInsets.only(bottom: verticalSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenWidth * 0.04)),
          if (label.isNotEmpty) SizedBox(height: screenWidth * 0.02),
          TextFormField(
            key: ValueKey('${label}_field'),
            controller: controller,
            readOnly: isReadOnly,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            style: TextStyle(fontSize: screenWidth * 0.04),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: screenWidth * 0.035),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: isReadOnly,
              fillColor: isReadOnly ? AppTheme.greyShade200 : AppTheme.greyShade50,
              suffixIcon: isDate ? const Icon(Icons.calendar_today_outlined) : null,
              contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenWidth * 0.03),
            ),
            validator: (v) => v!.isEmpty ? _tr('required_field') : null,
            onTap: isDate ? () => _selectDate(context) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard({required String title, required String subtitle, required String? fileName, required VoidCallback onTap, Key? key}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04;
    final verticalSpacing = screenWidth * 0.03;

    bool isUploaded = fileName != null;
    return Card(
      key: key,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold)),
            Text(subtitle, style: TextStyle(fontSize: screenWidth * 0.03, color: AppTheme.greyShade600)),
            SizedBox(height: verticalSpacing),
            isUploaded
                ? Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.successColor),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(child: Text(fileName, style: TextStyle(color: AppTheme.successColor, fontSize: screenWidth * 0.035), overflow: TextOverflow.ellipsis)),
                      IconButton(
                        onPressed: () {
                          Uint8List? fileData;
                          if (title == _tr('port_clearance')) {
                            fileData = _portClearanceFileData;
                          } else if (title == _tr('crew_list')) {
                            fileData = _crewListFileData;
                          } else if (title == _tr('notification_letter')) {
                            fileData = _notificationLetterFileData;
                          }
                          if (fileData != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DocumentViewScreen(
                                  fileData: fileData as Uint8List,
                                  fileName: fileName,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.visibility, color: AppTheme.greyShade600),
                      ),
                      IconButton(onPressed: onTap, icon: const Icon(Icons.edit, color: AppTheme.greyShade600))
                    ]
                  )
                : OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_tr('choose_file'), style: TextStyle(fontSize: screenWidth * 0.04)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, screenWidth * 0.12),
                      side: const BorderSide(color: AppTheme.primaryColor),
                      foregroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                    )
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final verticalPadding = screenWidth * 0.02;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(color: AppTheme.greyShade500, fontSize: screenWidth * 0.035))),
          Text(_tr('separator'), style: TextStyle(fontSize: screenWidth * 0.035)),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, height: 1.4, fontSize: screenWidth * 0.035))),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(String label, String? fileName) {
    final screenWidth = MediaQuery.of(context).size.width;
    final verticalPadding = screenWidth * 0.02;
    final horizontalSpacing = screenWidth * 0.04;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: AppTheme.greyShade400, size: screenWidth * 0.05),
          SizedBox(width: horizontalSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenWidth * 0.04)),
                Text(fileName ?? _tr('not_uploaded'), style: TextStyle(color: fileName != null ? AppTheme.primaryColor : AppTheme.errorColor, fontSize: screenWidth * 0.03)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
