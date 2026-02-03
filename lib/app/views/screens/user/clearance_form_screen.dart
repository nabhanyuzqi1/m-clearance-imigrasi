import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shimmer/shimmer.dart' as shimmer;
import 'package:m_clearance_imigrasi/app/utils/image_utils.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/clearance_application.dart';
import '../../../services/user_service.dart';
import '../../../services/network_utils.dart';
import '../../../services/logging_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/file_utils.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bouncing_dots_loader.dart';
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _userService = UserService();

  // Form controllers
  final _shipNameController = TextEditingController();
  final _agentNameController = TextEditingController();
  final _portController = TextEditingController();
  final _dateController = TextEditingController();
  final _wniCrewController = TextEditingController();
  final _wnaCrewController = TextEditingController();

  String? _selectedFlag;
  String? _selectedLocation;
  static const String _otherLocationKey = 'Other Location';
  List<String> _countryFlags = [];
  final List<String> _locations = [_otherLocationKey];
  final TextEditingController _otherLocationController =
      TextEditingController();
  StreamSubscription<DatabaseEvent>? _flagsSubscription;
  StreamSubscription<DatabaseEvent>? _portsSubscription;

  // File data storage
  Uint8List? _portClearanceFileData;
  Uint8List? _notificationLetterFileData;
  String? _portClearanceFileName, _notificationLetterFileName;
  String? _portClearanceFileUrl, _notificationLetterFileUrl;
  final List<_PendingCrewFile> _pendingCrewListFiles = [];
  List<String> _existingCrewListFiles = [];

  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;
  bool get _isCustomLocation {
    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      return false;
    }
    if (_selectedLocation == _otherLocationKey) {
      return true;
    }
    return !_locations.contains(_selectedLocation);
  }

  // Cached translations to prevent rebuilds
  late String _formInstruction;
  late String _shipNameHint;
  late String _selectDateHint;
  late String _uploadInstruction;
  late String _next;
  late String _back;
  late String _submitApplicationText;
  late String _saving;

  String _tr(String key) =>
      AppLocalizations.of(context).get('clearanceForm.$key');

  void _cacheTranslations() {
    _formInstruction = _tr('form_instruction');
    _shipNameHint = _tr('ship_name_hint');
    _selectDateHint = _tr('select_date');
    _uploadInstruction = _tr('upload_instruction');
    _next = _tr('next');
    _back = _tr('back');
    _submitApplicationText = _tr('submit_application');
    _saving = _tr('saving');
  }

  void _loadDynamicLookups() {
    final flagsRef = FirebaseDatabase.instance.ref('lookups/flags');
    final portsRef = FirebaseDatabase.instance.ref('lookups/ports');

    _flagsSubscription = flagsRef.onValue.listen(
      (event) {
        final remote = _extractStringList(event.snapshot.value);
        if (!mounted) return;
        if (remote.isEmpty) {
          LoggingService().warning(
            'Flag lookup snapshot returned empty; keeping existing values',
          );
          return;
        }
        setState(() {
          final nextFlags = List<String>.from(remote);
          if (_selectedFlag != null && _selectedFlag!.trim().isNotEmpty) {
            if (!nextFlags.contains(_selectedFlag)) {
              nextFlags.add(_selectedFlag!);
            }
          }
          nextFlags.sort();
          _countryFlags = nextFlags;
          if (_selectedFlag == null && _countryFlags.isNotEmpty) {
            _selectedFlag = _countryFlags.first;
          }
        });
      },
      onError: (error) {
        LoggingService().error('Failed loading flag list from RTDB', error);
      },
    );

    _portsSubscription = portsRef.onValue.listen(
      (event) {
        final remote = _extractStringList(event.snapshot.value);
        if (!mounted) return;
        if (remote.isEmpty) {
          LoggingService().warning(
            'Port lookup snapshot returned empty; keeping existing values',
          );
          return;
        }
        final nextLocations = List<String>.from(remote);
        if (!nextLocations.contains(_otherLocationKey)) {
          nextLocations.add(_otherLocationKey);
        }
        if (_locationsEquals(nextLocations, _locations)) {
          if (_isCustomLocation &&
              _otherLocationController.text.trim().isEmpty &&
              _selectedLocation != _otherLocationKey &&
              _selectedLocation != null) {
            setState(() {
              _otherLocationController.text = _selectedLocation!.trim();
              _selectedLocation = _otherLocationKey;
            });
          }
          return;
        }
        setState(() {
          _locations
            ..clear()
            ..addAll(nextLocations);
          if (_isCustomLocation) {
            if (_selectedLocation != _otherLocationKey &&
                _selectedLocation != null &&
                _otherLocationController.text.trim().isEmpty) {
              _otherLocationController.text = _selectedLocation!.trim();
              _selectedLocation = _otherLocationKey;
            }
            return;
          }
          if (_selectedLocation != null &&
              !_locations.contains(_selectedLocation)) {
            _otherLocationController.text = _selectedLocation!.trim();
            _selectedLocation = _otherLocationKey;
          } else if ((_selectedLocation == null ||
                  _selectedLocation!.isEmpty) &&
              remote.isNotEmpty) {
            _selectedLocation = remote.first;
          }
        });
      },
      onError: (error) {
        LoggingService().error('Failed loading port list from RTDB', error);
      },
    );
  }

  List<String> _extractStringList(Object? value) {
    final results = <String>{};
    if (value is List) {
      for (final entry in value) {
        if (entry is String && entry.trim().isNotEmpty) {
          results.add(entry.trim());
        }
      }
    } else if (value is Map) {
      for (final entry in value.values) {
        if (entry is String && entry.trim().isNotEmpty) {
          results.add(entry.trim());
        }
      }
    } else if (value is String && value.trim().isNotEmpty) {
      results.add(value.trim());
    }
    final list = results.toList()..sort();
    return list;
  }

  bool _locationsEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String? _resolvedLocation() {
    if (_isCustomLocation) {
      final manual = _otherLocationController.text.trim();
      return manual.isNotEmpty ? manual : null;
    }
    return _selectedLocation;
  }

  @override
  void initState() {
    super.initState();
    LoggingService().info('ClearanceFormScreen initialized for ${widget.type}');

    if (widget.existingApplication != null) {
      final app = widget.existingApplication!;
      LoggingService().debug('Loading existing application: ${app.id}');
      _shipNameController.text = app.shipName;
      _portController.text = app.port ?? '';
      _dateController.text = app.date ?? '';
      _wniCrewController.text = app.wniCrew ?? '';
      _wnaCrewController.text = app.wnaCrew ?? '';
      _agentNameController.text = app.agentName;

      if (app.flag.isNotEmpty) {
        _selectedFlag = app.flag;
      }

      final existingLocation = app.location?.trim();
      if (existingLocation != null && existingLocation.isNotEmpty) {
        _selectedLocation = existingLocation;
        if (!_locations.contains(existingLocation)) {
          _otherLocationController.text = existingLocation;
        }
      }

      // For existing applications, preserve remote references
      _portClearanceFileName = _friendlyFileName(app.portClearanceFile);
      _portClearanceFileUrl = app.portClearanceFile;
      _existingCrewListFiles = List<String>.from(app.crewListFiles);
      _notificationLetterFileName = _friendlyFileName(
        app.notificationLetterFile,
      );
      _notificationLetterFileUrl = app.notificationLetterFile;
    } else {
      LoggingService().debug('Creating new application form');
      _agentNameController.text = widget.agentName;
      _selectedLocation = null;
      _selectedFlag = null;
      _otherLocationController.clear();
      _dateController.text = DateFormat('dd MMMM yyyy').format(DateTime.now());
    }

    _loadDynamicLookups();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheTranslations();
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing ClearanceFormScreen resources');
    _shipNameController.dispose();
    _agentNameController.dispose();
    _portController.dispose();
    _dateController.dispose();
    _wniCrewController.dispose();
    _wnaCrewController.dispose();
    _otherLocationController.dispose();
    _flagsSubscription?.cancel();
    _portsSubscription?.cancel();
    super.dispose();
  }

  void _goToStep(int step) {
    final formState = _formKey.currentState;
    if (step > 1 && formState != null && !formState.validate()) {
      LoggingService().warning(
        'Form validation failed, cannot proceed to step $step',
      );
      return;
    }
    LoggingService().debug('Navigating to step $step');
    setState(() {
      _currentStep = step;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd MMMM yyyy').format(picked);
      });
    }
  }

  Future<bool> _requestPermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        return true;
      }
      if (status.isPermanentlyDenied && mounted) {
        _showPermissionDialog(_tr('camera_permission_message'));
      }
      return false;
    }

    return _requestGalleryPermission();
  }

  Future<bool> _requestGalleryPermission() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.photos.request();
      if (status.isDenied || status.isRestricted) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied && mounted) {
      _showPermissionDialog(_tr('storage_permission_message'));
    }

    return false;
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_tr('permission_required')),
          content: Text(message),
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

  Future<String?> _uploadDocumentToStorage(
    Uint8List fileData,
    String fileName,
    String userId,
    String docType,
  ) async {
    return NetworkUtils.executeWithRetry(() async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalName = fileName.split('/').last;
      final extensionIndex = originalName.lastIndexOf('.');
      final fileExtension = extensionIndex != -1
          ? originalName.substring(extensionIndex + 1)
          : '';
      final baseName = extensionIndex != -1
          ? originalName.substring(0, extensionIndex)
          : originalName;
      final sanitizedBaseName = baseName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final sanitizedDocType = docType
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      final baseSegment = sanitizedBaseName.isNotEmpty
          ? sanitizedBaseName
          : 'document';
      final extensionPart = fileExtension.isNotEmpty
          ? '.${fileExtension.toLowerCase()}'
          : '';
      final uniqueFileName =
          '${sanitizedDocType}_${baseSegment}_$timestamp$extensionPart';

      final storageRef = FirebaseStorage.instance.ref();
      final documentRef = storageRef.child(
        'applications/$userId/documents/$uniqueFileName',
      );

      final uploadTask = documentRef.putData(fileData);
      final snapshot = await NetworkUtils.withTimeout(
        uploadTask.whenComplete(() => null),
        const Duration(seconds: 90),
      );

      if (snapshot.state == TaskState.success) {
        try {
          final downloadUrl = await NetworkUtils.withTimeout(
            documentRef.getDownloadURL(),
            const Duration(seconds: 15),
          );
          return downloadUrl;
        } catch (e) {
          LoggingService().error(
            'Failed to get download URL, returning storage path',
            e,
          );
          return documentRef.fullPath;
        }
      } else {
        throw NetworkException(_tr('upload_failed'), isRetryable: true);
      }
    }, shouldRetry: NetworkUtils.isRetryableError).catchError((e) {
      LoggingService().error(_tr('upload_error'), e);
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
                leading: const Icon(Icons.photo_camera),
                title: Text(_tr('camera')),
                onTap: () async {
                  Navigator.of(context).pop();
                  final hasPermission = await _requestPermissions(
                    ImageSource.camera,
                  );
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
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final extension = _extensionFromName(pickedFile.name).isNotEmpty
          ? _extensionFromName(pickedFile.name)
          : 'jpg';
      final processedBytes = await minifyImageData(
        bytes,
        fileExtension: extension,
      );
      if (!context.mounted) return;
      setState(() {
        final fileName = _ensureExtension(
          pickedFile.name.isNotEmpty ? pickedFile.name : 'document.$extension',
          extension,
        );
        if (documentType == _tr('port_clearance')) {
          _portClearanceFileData = processedBytes;
          _portClearanceFileName = fileName;
          _portClearanceFileUrl = null;
        }
        if (documentType == _tr('crew_list')) {
          _pendingCrewListFiles.add(
            _PendingCrewFile(name: fileName, bytes: processedBytes),
          );
        }
        if (documentType == _tr('notification_letter')) {
          _notificationLetterFileData = processedBytes;
          _notificationLetterFileName = fileName;
          _notificationLetterFileUrl = null;
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
      final allowMultiple = documentType == _tr('crew_list');
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('select_file_failed')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final files = allowMultiple ? result.files : [result.files.first];
      final newCrewFiles = <_PendingCrewFile>[];
      Uint8List? portData;
      String? portName;
      Uint8List? notificationData;
      String? notificationName;

      for (final picked in files) {
        if (picked.bytes == null) {
          continue;
        }

        final extension = _extensionFromName(picked.name).isNotEmpty
            ? _extensionFromName(picked.name)
            : _extensionFromName('document.pdf');
        final processedBytes = _isImageExtension(extension)
            ? await minifyImageData(picked.bytes!, fileExtension: extension)
            : picked.bytes!;
        final resolvedName = _ensureExtension(
          picked.name.isNotEmpty ? picked.name : 'document.$extension',
          extension,
        );

        if (documentType == _tr('port_clearance')) {
          portData = processedBytes;
          portName = resolvedName;
        } else if (documentType == _tr('crew_list')) {
          final alreadySelected = _pendingCrewListFiles.any(
            (file) => file.name == resolvedName,
          );
          if (!alreadySelected) {
            newCrewFiles.add(
              _PendingCrewFile(name: resolvedName, bytes: processedBytes),
            );
          }
        } else if (documentType == _tr('notification_letter')) {
          notificationData = processedBytes;
          notificationName = resolvedName;
        }
      }

      setState(() {
        if (documentType == _tr('port_clearance')) {
          _portClearanceFileData = portData;
          _portClearanceFileName = portName;
          _portClearanceFileUrl = null;
        } else if (documentType == _tr('crew_list') &&
            newCrewFiles.isNotEmpty) {
          _pendingCrewListFiles.addAll(newCrewFiles);
        } else if (documentType == _tr('notification_letter')) {
          _notificationLetterFileData = notificationData;
          _notificationLetterFileName = notificationName;
          _notificationLetterFileUrl = null;
        }
      });

      if (documentType == _tr('crew_list')) {
        final addedCount = newCrewFiles.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              addedCount == 0
                  ? _tr('duplicate_file_warning')
                  : addedCount == 1
                  ? '${_tr('upload_success')}: ${newCrewFiles.first.name}'
                  : _tr(
                      'multiple_files_selected',
                    ).replaceFirst('{count}', addedCount.toString()),
            ),
            backgroundColor: addedCount > 0
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        final nameToShow = portName ?? notificationName;
        if (nameToShow != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_tr('upload_success')}: $nameToShow'),
              backgroundColor: Theme.of(context).colorScheme.tertiary,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('select_file_failed')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _extensionFromName(String name) {
    final index = name.lastIndexOf('.');
    if (index == -1 || index == name.length - 1) {
      return '';
    }
    return name.substring(index + 1).toLowerCase();
  }

  bool _isImageExtension(String extension) {
    final normalized = extension.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(normalized);
  }

  String _ensureExtension(String name, String extension) {
    if (extension.isEmpty) return name;
    if (name.toLowerCase().endsWith('.$extension')) {
      return name;
    }
    final index = name.lastIndexOf('.');
    final baseName = index == -1 ? name : name.substring(0, index);
    return '$baseName.$extension';
  }

  void _submitApplication() {
    final screenWidth = MediaQuery.of(context).size.width;

    LoggingService().info('Submit application button pressed');

    final applicationType = widget.existingApplication?.type ?? widget.type;
    final requiresPortClearance =
        applicationType == ApplicationType.kedatangan;

    final existingPortFiles =
        widget.existingApplication?.portClearanceFiles ?? const [];
    final hasStoredPortFile =
        (_portClearanceFileUrl != null && _portClearanceFileUrl!.trim().isNotEmpty) ||
        existingPortFiles.any((url) => url.trim().isNotEmpty);
    final hasPortClearance =
        _portClearanceFileData != null ||
        (_portClearanceFileName != null &&
            _portClearanceFileName!.trim().isNotEmpty) ||
        hasStoredPortFile;
    final hasCrewList =
        _pendingCrewListFiles.isNotEmpty || _existingCrewListFiles.isNotEmpty;
    final hasNotification =
        (_notificationLetterFileData != null &&
            _notificationLetterFileName != null) ||
        (_notificationLetterFileUrl != null &&
            _notificationLetterFileUrl!.trim().isNotEmpty) ||
        ((widget.existingApplication?.notificationLetterFiles ?? const [])
            .any((url) => url.trim().isNotEmpty));

    if ((requiresPortClearance && !hasPortClearance) ||
        !hasCrewList ||
        !hasNotification) {
      LoggingService().warning(
        'Missing required documents, redirecting to upload step',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('upload_all_docs')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      _goToStep(2);
      return;
    }

    final isTablet = screenWidth > 600;
    final maxWidth = isTablet ? 400.0 : double.infinity;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Center(
              child: Text(
                _tr('submit_dialog_title'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.045,
                ),
              ),
            ),
            content: Text(
              _tr('submit_dialog_content'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: screenWidth * 0.04),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withAlpha(51),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.08,
                    vertical: screenWidth * 0.03,
                  ),
                ),
                child: Text(
                  _tr('cancel'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              SizedBox(width: screenWidth * 0.02),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.08,
                    vertical: screenWidth * 0.03,
                  ),
                ),
                child: Text(
                  _tr('send'),
                  style: TextStyle(fontSize: screenWidth * 0.04),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _performSubmission();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _performSubmission() async {
    setState(() => _isSubmitting = true);

    try {
      LoggingService().info('Starting application submission process');
      LoggingService().debug('Application type: ${widget.type}');
      LoggingService().debug(
        'Existing application: ${widget.existingApplication?.id}',
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        LoggingService().error('No authenticated user found during submission');
        throw Exception(_tr('auth_error'));
      }

      // Upload files to Firebase Storage in parallel
      LoggingService().debug('Starting file uploads to Firebase Storage');

      final uploadTasks = <Future<String?>>[];

      final portUploadPlanned =
          _portClearanceFileData != null && _portClearanceFileName != null;
      final crewUploadPlanned = _pendingCrewListFiles.isNotEmpty;
      final notificationUploadPlanned =
          _notificationLetterFileData != null &&
          _notificationLetterFileName != null;

      if (portUploadPlanned) {
        uploadTasks.add(
          _uploadDocumentToStorage(
            _portClearanceFileData!,
            _portClearanceFileName!,
            user.uid,
            'port_clearance',
          ),
        );
      }

      if (crewUploadPlanned) {
        for (final file in _pendingCrewListFiles) {
          uploadTasks.add(
            _uploadDocumentToStorage(
              file.bytes,
              file.name,
              user.uid,
              'crew_list',
            ),
          );
        }
      }

      if (notificationUploadPlanned) {
        uploadTasks.add(
          _uploadDocumentToStorage(
            _notificationLetterFileData!,
            _notificationLetterFileName!,
            user.uid,
            'notification_letter',
          ),
        );
      }

      final uploadResults = await Future.wait(uploadTasks);
      int resultIndex = 0;

      String? portClearanceUrl;
      if (portUploadPlanned) {
        portClearanceUrl = uploadResults[resultIndex++];
        if (portClearanceUrl == null || portClearanceUrl.isEmpty) {
          throw Exception(_tr('upload_failed'));
        }
      }

      final newCrewListUrls = <String>[];
      if (crewUploadPlanned) {
        for (var i = 0; i < _pendingCrewListFiles.length; i++) {
          final uploadedUrl = uploadResults[resultIndex++];
          if (uploadedUrl == null || uploadedUrl.isEmpty) {
            throw Exception(_tr('upload_failed'));
          }
          newCrewListUrls.add(uploadedUrl);
        }
      }

      String? notificationLetterUrl;
      if (notificationUploadPlanned) {
        notificationLetterUrl = uploadResults[resultIndex++];
        if (notificationLetterUrl == null || notificationLetterUrl.isEmpty) {
          throw Exception(_tr('upload_failed'));
        }
      }

      LoggingService().info('File uploads completed successfully');

      final combinedCrewListFiles = <String>{
        ..._existingCrewListFiles.where((url) => url.trim().isNotEmpty),
        ...newCrewListUrls,
      }.toList();

      final existingPortFiles =
          widget.existingApplication?.portClearanceFiles ?? const [];
      final finalPortFiles =
          (portClearanceUrl != null && portClearanceUrl.isNotEmpty)
          ? [portClearanceUrl]
          : (_portClearanceFileUrl != null && _portClearanceFileUrl!.isNotEmpty)
          ? [_portClearanceFileUrl!]
          : List<String>.from(existingPortFiles);

      final existingNotificationFiles =
          widget.existingApplication?.notificationLetterFiles ?? const [];
      final finalNotificationFiles =
          (notificationLetterUrl != null && notificationLetterUrl.isNotEmpty)
          ? [notificationLetterUrl]
          : (_notificationLetterFileUrl != null &&
                _notificationLetterFileUrl!.isNotEmpty)
          ? [_notificationLetterFileUrl!]
          : List<String>.from(existingNotificationFiles);

      final application = ClearanceApplication(
        id: widget.existingApplication?.id ?? '',
        shipName: _shipNameController.text.trim(),
        flag: _selectedFlag?.trim() ?? '',
        agentName: _agentNameController.text,
        agentUid: '', // Will be set by the service
        type: widget.type,
        location: _resolvedLocation(),
        port: _portController.text.trim().isEmpty
            ? null
            : _portController.text.trim(),
        date: _dateController.text.trim().isEmpty
            ? null
            : _dateController.text.trim(),
        wniCrew: _wniCrewController.text.trim().isEmpty
            ? null
            : _wniCrewController.text.trim(),
        wnaCrew: _wnaCrewController.text.trim().isEmpty
            ? null
            : _wnaCrewController.text.trim(),
        portClearanceFiles: finalPortFiles,
        crewListFiles: combinedCrewListFiles,
        notificationLetterFiles: finalNotificationFiles,
      );

      LoggingService().debug(
        'Created ClearanceApplication object: ${application.shipName}',
      );

      String? applicationId;
      if (widget.existingApplication != null) {
        // Update existing application
        LoggingService().info('Updating existing application');
        final success = await _userService.updateApplication(
          widget.existingApplication!.id,
          application,
        );
        if (success) {
          applicationId = widget.existingApplication!.id;
        }
      } else {
        // Submit new application
        LoggingService().info('Submitting new application');
        applicationId = await _userService.submitClearanceApplication(
          application,
        );
      }

      if (applicationId != null && mounted) {
        LoggingService().info(
          'Application submission successful, ID: $applicationId',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('success_message')),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
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
        LoggingService().error(
          'Application submission failed - no ID returned',
        );
        throw Exception(_tr('submit_error'));
      }
    } catch (e) {
      LoggingService().error('Error in _performSubmission: $e', e);
      LoggingService().debug('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        final firebaseError = e;
        LoggingService().debug('Firebase error code: ${firebaseError.code}');
        LoggingService().debug(
          'Firebase error message: ${firebaseError.message}',
        );
      }
      if (mounted) {
        String errorMessage = _tr('error_message');
        final errorText = e.toString();
        if (errorText.isNotEmpty) {
          errorMessage = errorText.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenWidth * 0.06; // 6% of screen width
    final verticalPadding = screenHeight * 0.02; // 2% of screen height

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(
        titleText: AppLocalizations.of(context).get(
          widget.type == ApplicationType.kedatangan
              ? 'clearanceForm.arrival_title'
              : 'clearanceForm.departure_title',
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: _buildStepper(),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildStepContent(),
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
        _buildStepIndicator(
          step: 1,
          label: _tr('step1'),
          isDone: _currentStep > 1,
        ),
        _buildStepDivider(),
        _buildStepIndicator(
          step: 2,
          label: _tr('step2'),
          isDone: _currentStep > 2,
        ),
        _buildStepDivider(),
        _buildStepIndicator(step: 3, label: _tr('step3'), isDone: false),
      ],
    );
  }

  Widget _buildStepIndicator({
    required int step,
    required String label,
    required bool isDone,
  }) {
    bool isActive = _currentStep == step;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : (isDone
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive || isDone
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        key: ValueKey('step_$step'),
        children: [
          if (isDone)
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
          if (isDone) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider() {
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Divider(
          color: Theme.of(context).colorScheme.outlineVariant,
          thickness: 1,
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return Form(
          key: _formKey,
          child: _buildFormStepContent(key: const ValueKey('form_step')),
        );
      case 2:
        return _buildUploadStep(key: const ValueKey('upload_step'));
      case 3:
      default:
        return _buildSubmitStep(key: const ValueKey('submit_step'));
    }
  }

  Widget _buildFormStepContent({Key? key}) {
    final applicationType = widget.existingApplication?.type ?? widget.type;
    final bool isKedatangan = applicationType == ApplicationType.kedatangan;
    final String portLabel = isKedatangan ? _tr('last_port') : _tr('next_port');
    final String dateLabel = isKedatangan ? _tr('eta') : _tr('etd');
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.03;

    return ListView(
      key: key,
      shrinkWrap: true,
      padding: EdgeInsets.all(horizontalPadding),
      children: [
        Text(
          _formInstruction,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: screenWidth * 0.035,
          ),
        ),
        SizedBox(height: verticalSpacing),
        _buildTextField(
          label: _tr('ship_name'),
          controller: _shipNameController,
          hint: _shipNameHint,
          key: const ValueKey('ship_name_field'),
        ),
        Padding(
          key: const ValueKey('flag_dropdown'),
          padding: EdgeInsets.only(bottom: verticalSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr('flag'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.04,
                ),
              ),
              SizedBox(height: screenWidth * 0.02),
              DropdownButtonFormField<String>(
                key: const ValueKey('flag_selector'),
                initialValue: _countryFlags.contains(_selectedFlag)
                    ? _selectedFlag
                    : (_selectedFlag != null && _selectedFlag!.trim().isNotEmpty
                          ? _selectedFlag
                          : null),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                items: () {
                  final flags = List<String>.from(_countryFlags);
                  if (_selectedFlag != null &&
                      _selectedFlag!.trim().isNotEmpty &&
                      !flags.contains(_selectedFlag)) {
                    flags.add(_selectedFlag!);
                  }
                  flags.sort();
                  return flags.map((String country) {
                    return DropdownMenuItem<String>(
                      value: country,
                      child: Text(
                        country,
                        style: TextStyle(fontSize: screenWidth * 0.035),
                      ),
                    );
                  }).toList();
                }(),
                onChanged: (newValue) {
                  if (newValue == null) return;
                  setState(() {
                    _selectedFlag = newValue;
                  });
                },
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
              Text(
                _tr('location'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.04,
                ),
              ),
              SizedBox(height: screenWidth * 0.02),
              DropdownButtonFormField<String>(
                key: const ValueKey('location_selector'),
                initialValue: () {
                  if (_selectedLocation == null || _selectedLocation!.isEmpty) {
                    return null;
                  }
                  final locations = List<String>.from(_locations);
                  if (!locations.contains(_otherLocationKey)) {
                    locations.add(_otherLocationKey);
                  }
                  return locations.contains(_selectedLocation)
                      ? _selectedLocation
                      : _otherLocationKey;
                }(),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                items: () {
                  final locations = List<String>.from(_locations);
                  if (!locations.contains(_otherLocationKey)) {
                    locations.add(_otherLocationKey);
                  }
                  return locations.map((String location) {
                    return DropdownMenuItem<String>(
                      value: location,
                      child: Text(
                        location == _otherLocationKey
                            ? _tr('other_location')
                            : location,
                        style: TextStyle(fontSize: screenWidth * 0.035),
                      ),
                    );
                  }).toList();
                }(),
                onChanged: (newValue) {
                  if (newValue == null) return;
                  setState(() {
                    _selectedLocation = newValue;
                    if (newValue != _otherLocationKey) {
                      _otherLocationController.clear();
                    }
                  });
                },
                validator: (value) => value == null
                    ? _tr('select_location')
                    : (value == _otherLocationKey &&
                              _otherLocationController.text.trim().isEmpty
                          ? _tr('enter_location')
                          : null),
              ),
              if (_isCustomLocation) ...[
                SizedBox(height: screenWidth * 0.02),
                TextFormField(
                  controller: _otherLocationController,
                  decoration: InputDecoration(
                    labelText: _tr('other_location'),
                    hintText: _tr('enter_location'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  validator: (value) {
                    if (!_isCustomLocation) return null;
                    if (value == null || value.trim().isEmpty) {
                      return _tr('enter_location');
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
        _buildTextField(
          label: portLabel,
          controller: _portController,
          hint: _tr('tanjung_priok'),
          key: const ValueKey('port_field'),
        ),
        _buildTextField(
          label: dateLabel,
          controller: _dateController,
          hint: _selectDateHint,
          isReadOnly: true,
          isDate: true,
          key: const ValueKey('date_field'),
        ),
        Row(
          key: const ValueKey('crew_row'),
          children: [
            Expanded(
              child: _buildTextField(
                label: _tr('wni_crew'),
                controller: _wniCrewController,
                hint: "0",
                isNumeric: true,
                key: const ValueKey('wni_crew_field'),
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: _buildTextField(
                label: _tr('wna_crew'),
                controller: _wnaCrewController,
                hint: "0",
                isNumeric: true,
                key: const ValueKey('wna_crew_field'),
              ),
            ),
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
        Text(
          _uploadInstruction,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: screenWidth * 0.035,
          ),
        ),
        SizedBox(height: verticalSpacing),
        _buildUploadCard(
          title: _tr('port_clearance'),
          subtitle: _tr('port_clearance_subtitle'),
          fileName: _portClearanceFileName,
          onTap: () => _showImageSourceActionSheet(_tr('port_clearance')),
          fileUrl: _portClearanceFileUrl,
          key: const ValueKey('port_clearance_card'),
        ),
        SizedBox(height: verticalSpacing),
        _buildCrewListUploadCard(
          title: _tr('crew_list'),
          subtitle: _tr('crew_list_subtitle'),
          key: const ValueKey('crew_list_card'),
        ),
        SizedBox(height: verticalSpacing),
        _buildUploadCard(
          title: _tr('notification_letter'),
          subtitle: _tr('notification_letter_subtitle'),
          fileName: _notificationLetterFileName,
          onTap: () => _showImageSourceActionSheet(_tr('notification_letter')),
          fileUrl: _notificationLetterFileUrl,
          key: const ValueKey('notification_letter_card'),
        ),
        SizedBox(height: verticalSpacing),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _goToStep(1),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                ),
                child: Text(
                  _back,
                  style: TextStyle(fontSize: screenWidth * 0.04),
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _goToStep(3),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                  textStyle: TextStyle(fontSize: screenWidth * 0.04),
                ),
                child: Text(_next),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitStep({Key? key}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.03;
    final reviewCrewFiles = <String>[
      ..._existingCrewListFiles.map((url) {
        final parsed = _friendlyFileName(url);
        return parsed ?? url;
      }),
      ..._pendingCrewListFiles.map((file) => file.name),
    ];

    if (_isSubmitting) {
      return _buildShimmerLoading();
    }

    return Padding(
      key: key,
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Text(
                  _tr('review_confirm'),
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: verticalSpacing),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr('vessel_details'),
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Divider(height: verticalSpacing * 2),
                        _buildDetailRow(
                          _tr('ship_name'),
                          _shipNameController.text,
                        ),
                        _buildDetailRow(_tr('flag'), _selectedFlag ?? '-'),
                        _buildDetailRow(
                          _tr('crew_count'),
                          "${_tr('wni_label')}: ${_wniCrewController.text}, ${_tr('wna_label')}: ${_wnaCrewController.text}",
                        ),
                        _buildDetailRow(
                          _tr('location'),
                          _resolvedLocation() ?? '-',
                        ),
                        _buildDetailRow(
                          _tr('date_label'),
                          _dateController.text,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: verticalSpacing * 2),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr('required_docs'),
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Divider(height: verticalSpacing * 2),
                        _buildDocumentRow(
                          _tr('notification_letter'),
                          _notificationLetterFileName,
                        ),
                        _buildDocumentRow(
                          _tr('port_clearance'),
                          _portClearanceFileName,
                        ),
                        _buildDocumentRowList(
                          _tr('crew_list'),
                          reviewCrewFiles,
                        ),
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
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: screenWidth * 0.04,
                      ),
                    ),
                    child: Text(
                      _back,
                      style: TextStyle(fontSize: screenWidth * 0.04),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: screenWidth * 0.04,
                      ),
                      textStyle: TextStyle(fontSize: screenWidth * 0.04),
                    ),
                    child: _isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const BouncingDotsLoader(),
                              SizedBox(width: screenWidth * 0.03),
                              Text(_saving),
                            ],
                          )
                        : Text(_submitApplicationText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.03;

    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: shimmer.Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        highlightColor: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // Title shimmer
                  Container(
                    height: screenWidth * 0.06,
                    width: screenWidth * 0.4,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  SizedBox(height: verticalSpacing),

                  // Vessel details card shimmer
                  Container(
                    height: screenWidth * 0.8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  SizedBox(height: verticalSpacing * 2),

                  // Documents card shimmer
                  Container(
                    height: screenWidth * 0.6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),

            // Submit button shimmer
            Padding(
              padding: EdgeInsets.symmetric(vertical: verticalSpacing * 2),
              child: Container(
                height: screenWidth * 0.12,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
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
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.04,
              ),
            ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: isReadOnly,
              fillColor: isReadOnly
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              suffixIcon: isDate
                  ? const Icon(Icons.calendar_today_outlined)
                  : null,
              contentPadding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenWidth * 0.03,
              ),
            ),
            validator: (v) => v!.isEmpty ? _tr('required_field') : null,
            onTap: isDate ? () => _selectDate(context) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required String? fileName,
    required VoidCallback onTap,
    String? fileUrl,
    Key? key,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04;
    final remoteUrl = fileUrl ?? '';
    final hasRemoteFile = remoteUrl.isNotEmpty;

    Uint8List? fileData;
    if (title == _tr('port_clearance')) {
      fileData = _portClearanceFileData;
    } else if (title == _tr('notification_letter')) {
      fileData = _notificationLetterFileData;
    }

    final bool isUploaded =
        (fileData != null) ||
        (fileName != null && fileName.isNotEmpty) ||
        hasRemoteFile;
    final displayName =
        _friendlyFileName(fileName) ??
        (hasRemoteFile ? _friendlyFileName(fileUrl) : null);
    final statusColor = isUploaded
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.error;
    final statusText = isUploaded ? _tr('file_attached') : _tr('not_uploaded');

    return Card(
      key: key,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: screenWidth * 0.01),
            Text(
              displayName ?? subtitle,
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: screenWidth * 0.007),
            Text(
              statusText,
              style: TextStyle(
                fontSize: screenWidth * 0.032,
                color: statusColor,
              ),
            ),
            SizedBox(height: screenWidth * 0.02),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _tr('choose_file'),
                    style: TextStyle(fontSize: screenWidth * 0.035),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _tr('view_file'),
                  icon: Icon(
                    Icons.visibility_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: !isUploaded
                      ? null
                      : () {
                          final resolvedName = displayName ?? title;
                          final data = fileData;
                          if (data != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DocumentViewScreen(
                                  fileData: data,
                                  fileName: resolvedName,
                                ),
                              ),
                            );
                          } else if (hasRemoteFile) {
                            _viewStoredDocument(remoteUrl, resolvedName);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_tr('file_not_available')),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrewListUploadCard({
    required String title,
    required String subtitle,
    Key? key,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04;
    final verticalSpacing = screenWidth * 0.03;

    final items = <Widget>[];
    for (final entry in _existingCrewListFiles.asMap().entries) {
      final index = entry.key;
      final url = entry.value;
      final displayName =
          _friendlyFileName(url) ?? 'crew_list_${index + 1}'.toUpperCase();
      items.add(
        _buildCrewListRow(
          name: displayName,
          statusText: _tr('file_attached'),
          icon: Icons.cloud_done_rounded,
          onView: () => _viewStoredDocument(url, displayName),
          onRemove: () => _removeExistingCrewDocument(index),
        ),
      );
    }
    for (final entry in _pendingCrewListFiles.asMap().entries) {
      final index = entry.key;
      final file = entry.value;
      items.add(
        _buildCrewListRow(
          name: file.name,
          statusText: _tr('file_attached'),
          icon: Icons.upload_file,
          onView: () => _openPendingCrewDocument(file),
          onRemove: () => _removePendingCrewDocument(index),
        ),
      );
    }

    final hasDocs = items.isNotEmpty;
    final statusText = hasDocs ? _tr('file_attached') : _tr('not_uploaded');
    final statusColor = hasDocs
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.error;

    return Card(
      key: key,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: screenWidth * 0.01),
            Text(
              statusText,
              style: TextStyle(
                fontSize: screenWidth * 0.032,
                color: statusColor,
              ),
            ),
            SizedBox(height: verticalSpacing),
            OutlinedButton.icon(
              onPressed: () => _showImageSourceActionSheet(_tr('crew_list')),
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                _tr('add_more_documents'),
                style: TextStyle(fontSize: screenWidth * 0.035),
              ),
            ),
            SizedBox(height: verticalSpacing),
            if (items.isEmpty)
              Text(
                _tr('crew_list_empty'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: screenWidth * 0.035,
                ),
              )
            else
              ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildCrewListRow({
    required String name,
    required String statusText,
    required IconData icon,
    required VoidCallback onRemove,
    VoidCallback? onView,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.only(top: screenWidth * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: screenWidth * 0.01),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: screenWidth * 0.03,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
          if (onView != null)
            IconButton(
              tooltip: _tr('view_file'),
              icon: Icon(
                Icons.visibility_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: onView,
            ),
          IconButton(
            tooltip: _tr('remove_file'),
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  void _removeExistingCrewDocument(int index) {
    setState(() {
      _existingCrewListFiles.removeAt(index);
    });
  }

  void _removePendingCrewDocument(int index) {
    setState(() {
      _pendingCrewListFiles.removeAt(index);
    });
  }

  Future<void> _openPendingCrewDocument(_PendingCrewFile file) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DocumentViewScreen(fileData: file.bytes, fileName: file.name),
      ),
    );
  }

  Future<void> _viewStoredDocument(String url, String fileName) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_tr('download_start'))));
    try {
      final authService = AuthService();
      final data = await authService.downloadFileData(url);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (data == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_tr('download_failed'))));
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DocumentViewScreen(fileData: data, fileName: fileName),
        ),
      );
    } catch (e) {
      LoggingService().error('Error viewing stored crew document', e);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tr('download_failed'))));
    }
  }

  String? _friendlyFileName(String? reference) {
    if (reference == null || reference.isEmpty) {
      return null;
    }
    final parsed = getFileNameFromUrl(reference);
    return parsed.isNotEmpty ? parsed : reference;
  }

  Widget _buildDetailRow(String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final verticalPadding = screenWidth * 0.02;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: screenWidth * 0.035,
              ),
            ),
          ),
          Text(
            _tr('separator'),
            style: TextStyle(fontSize: screenWidth * 0.035),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.4,
                fontSize: screenWidth * 0.035,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(String label, String? fileName) {
    final screenWidth = MediaQuery.of(context).size.width;
    final verticalPadding = screenWidth * 0.02;
    final horizontalSpacing = screenWidth * 0.04;

    final resolvedName = _friendlyFileName(fileName);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: screenWidth * 0.05,
          ),
          SizedBox(width: horizontalSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
                Text(
                  resolvedName ?? _tr('not_uploaded'),
                  style: TextStyle(
                    color: resolvedName != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    fontSize: screenWidth * 0.03,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRowList(String label, List<String> fileNames) {
    final screenWidth = MediaQuery.of(context).size.width;
    final verticalPadding = screenWidth * 0.02;
    final horizontalSpacing = screenWidth * 0.04;
    final hasFiles = fileNames.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: screenWidth * 0.05,
          ),
          SizedBox(width: horizontalSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
                if (!hasFiles)
                  Text(
                    _tr('not_uploaded'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: screenWidth * 0.03,
                    ),
                  )
                else
                  ...fileNames.map(
                    (name) => Padding(
                      padding: EdgeInsets.only(top: screenWidth * 0.01),
                      child: Text(
                        '• $name',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: screenWidth * 0.03,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCrewFile {
  _PendingCrewFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
