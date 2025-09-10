import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/clearance_application.dart';
import 'verification_loading_screen.dart';

class ClearanceFormScreen extends StatefulWidget {
  final ApplicationType? type;
  final String? agentName;
  final ClearanceApplication? existingApplication;
  final String initialLanguage;

  const ClearanceFormScreen({
    super.key,
    this.type,
    this.agentName,
    this.existingApplication,
    this.initialLanguage = 'EN',
  }) : assert(existingApplication != null || (type != null && agentName != null));

  @override
  State<ClearanceFormScreen> createState() => _ClearanceFormScreenState();
}

class _ClearanceFormScreenState extends State<ClearanceFormScreen> {
  int _currentStep = 1;
  final _formKey = GlobalKey<FormState>();

  final _shipNameController = TextEditingController();
  late TextEditingController _agentNameController;
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

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'arrival_title': 'Arrival Details',
      'departure_title': 'Departure Details',
      'step1': 'Details',
      'step2': 'Documents',
      'step3': 'Submit',
      'form_instruction': 'Please fill the information before proceeding',
      'ship_name': 'Ship Name',
      'ship_name_hint': 'Ex: KM. Bahari Indah',
      'flag': 'Flag',
      'select_flag': 'Select ship flag',
      'location': 'Location',
      'select_location': 'Select location',
      'last_port': 'Last Port',
      'next_port': 'Next Port',
      'eta': 'ETA (Arrival Date)',
      'etd': 'ETD (Departure Date)',
      'select_date': 'Select Date',
      'wni_crew': 'WNI Crew',
      'wna_crew': 'WNA Crew',
      'required_field': 'This field is required',
      'next': 'Next',
      'back': 'Back',
      'upload_instruction': 'Please upload the required documents',
      'port_clearance': 'Port Clearance',
      'port_clearance_subtitle': 'Upload Port Clearance from previous port',
      'crew_list': 'Crew List',
      'crew_list_subtitle': 'Upload valid crew list document',
      'notification_letter': 'Notification Letter',
      'notification_letter_subtitle': 'Upload notification letter',
      'choose_file': 'Choose File',
      'file_uploaded': 'uploaded successfully',
      'edit': 'Edit',
      'upload_all_docs': 'Please upload all required documents.',
      'review_confirm': 'Review & Confirm',
      'vessel_details': 'Vessel Details',
      'crew_count': 'Crew Count',
      'required_docs': 'Required Documents',
      'not_uploaded': 'Not uploaded',
      'submit_application': 'Submit Application',
      'submit_dialog_title': 'Submit',
      'submit_dialog_content': 'Are you sure your application data is correct? Send to Proceed. We will review your application immediately.',
      'cancel': 'Cancel',
      'send': 'Send',
      'gallery': 'Choose from Gallery',
      'camera': 'Take a Picture',
    },
    'ID': {
      'arrival_title': 'Detail Kedatangan',
      'departure_title': 'Detail Keberangkatan',
      'step1': 'Detail',
      'step2': 'Dokumen',
      'step3': 'Kirim',
      'form_instruction': 'Mohon isi informasi sebelum melanjutkan',
      'ship_name': 'Nama Kapal',
      'ship_name_hint': 'Contoh: KM. Bahari Indah',
      'flag': 'Bendera',
      'select_flag': 'Pilih bendera kapal',
      'location': 'Lokasi',
      'select_location': 'Pilih lokasi',
      'last_port': 'Pelabuhan Asal',
      'next_port': 'Pelabuhan Tujuan',
      'eta': 'ETA (Tanggal Tiba)',
      'etd': 'ETD (Tanggal Berangkat)',
      'select_date': 'Pilih Tanggal',
      'wni_crew': 'Kru WNI',
      'wna_crew': 'Kru WNA',
      'required_field': 'Kolom ini harus diisi',
      'next': 'Lanjut',
      'back': 'Kembali',
      'upload_instruction': 'Mohon unggah dokumen yang diperlukan',
      'port_clearance': 'Port Clearance',
      'port_clearance_subtitle': 'Unggah Port Clearance dari pelabuhan sebelumnya',
      'crew_list': 'Daftar Kru',
      'crew_list_subtitle': 'Unggah dokumen daftar kru yang valid',
      'notification_letter': 'Surat Pemberitahuan',
      'notification_letter_subtitle': 'Unggah surat pemberitahuan',
      'choose_file': 'Pilih File',
      'file_uploaded': 'berhasil diunggah',
      'edit': 'Ubah',
      'upload_all_docs': 'Mohon unggah semua dokumen yang diperlukan.',
      'review_confirm': 'Tinjau & Konfirmasi',
      'vessel_details': 'Detail Kapal',
      'crew_count': 'Jumlah Kru',
      'required_docs': 'Dokumen yang Diperlukan',
      'not_uploaded': 'Belum diunggah',
      'submit_application': 'Kirim Pengajuan',
      'submit_dialog_title': 'Kirim',
      'submit_dialog_content': 'Apakah Anda yakin data pengajuan Anda sudah benar? Kirim untuk melanjutkan. Kami akan segera meninjau pengajuan Anda.',
      'cancel': 'Batal',
      'send': 'Kirim',
      'gallery': 'Pilih dari Galeri',
      'camera': 'Ambil Gambar via Kamera',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    
    if (widget.existingApplication != null) {
      final app = widget.existingApplication!;
      _shipNameController.text = app.shipName;
      _selectedFlag = app.flag;
      _agentNameController = TextEditingController(text: app.agentName);
      _portController.text = app.port ?? '';
      _dateController.text = app.date ?? '';
      _wniCrewController.text = app.wniCrew ?? '';
      _wnaCrewController.text = app.wnaCrew ?? '';
      _selectedLocation = app.location ?? _locations.first;
      _portClearanceFile = "port_clearance_existing.pdf";
      _crewListFile = "crew_list_existing.pdf";
      _notificationLetterFile = "notification_letter_existing.pdf";
    } else {
      _agentNameController = TextEditingController(text: widget.agentName!);
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
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) {
      setState(() { _dateController.text = DateFormat('dd MMMM yyyy').format(picked); });
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
        if (documentType == 'Surat Pemberitahuan') _notificationLetterFile = fileName;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$documentType ${_tr('file_uploaded')}: ${pickedFile.name}'), backgroundColor: Colors.green));
    }
  }

  void _submitApplication() {
    final applicationData = ClearanceApplication(
      shipName: _shipNameController.text,
      flag: _selectedFlag ?? "Indonesia",
      agentName: _agentNameController.text,
      type: widget.existingApplication?.type ?? widget.type!,
      port: _portController.text,
      date: _dateController.text,
      wniCrew: _wniCrewController.text,
      wnaCrew: _wnaCrewController.text,
      status: ApplicationStatus.waiting,
      location: _selectedLocation,
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => VerificationLoadingScreen(application: applicationData, initialLanguage: _selectedLanguage,)),
      (route) => false,
    );
  }

  void _showConfirmationDialog() {
    if (_portClearanceFile == null || _crewListFile == null || _notificationLetterFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr('upload_all_docs')), backgroundColor: Colors.red));
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
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.blue.shade200), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: Text(_tr('cancel'), style: const TextStyle(color: Colors.blue)),
              onPressed: () { Navigator.of(context).pop(); },
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: Text(_tr('send')),
              onPressed: () {
                Navigator.of(context).pop();
                _submitApplication();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final applicationType = widget.existingApplication?.type ?? widget.type!;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(applicationType == ApplicationType.kedatangan ? _tr('arrival_title') : _tr('departure_title'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
      decoration: BoxDecoration(color: isActive ? Colors.blue : (isDone ? Colors.white : Colors.grey.shade200), borderRadius: BorderRadius.circular(20), border: Border.all(color: isActive || isDone ? Colors.blue : Colors.grey.shade300)),
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
    return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Divider(color: Colors.grey.shade300, thickness: 1)));
  }

  Widget _buildFormStep() {
    final applicationType = widget.existingApplication?.type ?? widget.type!;
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
                  value: _selectedFlag,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: _countryFlags.map((String country) { return DropdownMenuItem<String>(value: country, child: Text(country)); }).toList(),
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
                  value: _selectedLocation,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: _locations.map((String location) { return DropdownMenuItem<String>(value: location, child: Text(location)); }).toList(),
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
        _buildUploadCard(title: _tr('notification_letter'), subtitle: _tr('notification_letter_subtitle'), fileName: _notificationLetterFile, onTap: () => _showImageSourceActionSheet('Surat Pemberitahuan')),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => _goToStep(1), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue), foregroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(_tr('back')))),
            const SizedBox(width: 16),
            Expanded(child: ElevatedButton(onPressed: () => _goToStep(3), child: Text(_tr('next')))),
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
                Expanded(child: OutlinedButton(onPressed: () => _goToStep(2), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue), foregroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(_tr('back')))),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(onPressed: _showConfirmationDialog, child: Text(_tr('submit_application')))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({String? label, required TextEditingController controller, required String hint, bool isReadOnly = false, bool isDate = false, bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (label != null) const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            readOnly: isReadOnly,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: isReadOnly,
              fillColor: isReadOnly ? Colors.grey[200] : null,
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
                ? Row(children: [const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(fileName!, style: const TextStyle(color: Colors.green), overflow: TextOverflow.ellipsis)), IconButton(onPressed: onTap, icon: const Icon(Icons.edit, color: Colors.blueGrey))])
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
