import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/legal_document.dart';
import '../../../services/legal_content_service.dart';
import '../../../services/logging_service.dart';
import '../../widgets/custom_app_bar.dart';

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.documentType,
  });

  final LegalDocumentType documentType;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final LegalContentService _service;
  StreamSubscription<LegalDocument>? _subscription;
  LegalDocument _document = LegalDocument.empty;
  bool _isLoading = true;
  String? _activeLanguageCode;

  @override
  void initState() {
    super.initState();
    _service = LegalContentService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode =
        Localizations.localeOf(context).languageCode.toLowerCase();
    if (_activeLanguageCode == languageCode) return;
    _activeLanguageCode = languageCode;
    _observeDocument(languageCode);
  }

  void _observeDocument(String languageCode) {
    _subscription?.cancel();
    setState(() => _isLoading = true);

    _subscription = _service
        .watchDocument(widget.documentType, languageCode: languageCode)
        .listen(
      (doc) {
        if (!mounted) return;
        setState(() {
          _document = doc;
          _isLoading = false;
        });
      },
      onError: (error) {
        LoggingService().warning('Failed updating legal document stream', error);
        if (!mounted) return;
        setState(() {
          _document = LegalDocument.empty;
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final locale = _activeLanguageCode ??
        Localizations.localeOf(context).languageCode.toLowerCase();
    final doc = await _service.fetchDocument(
      widget.documentType,
      languageCode: locale,
    );
    if (!mounted) return;
    setState(() {
      _document = doc;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final title = localization.get(widget.documentType.localizationKey());
    final updatedLabel = localization.get('legal.last_updated');
    final emptyLabel = localization.get('legal.empty_state');
    final localeName = localization.languageCode;
    final formattedUpdated = _document.updatedAt != null
        ? DateFormat.yMMMMd(localeName)
            .add_Hm()
            .format(_document.updatedAt!.toLocal())
        : localization.get('legal.not_available');

    final content = _document.content.trim().isEmpty
        ? emptyLabel
        : _document.content;

    return Scaffold(
      appBar: CustomAppBar(
        titleText: title,
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$updatedLabel $formattedUpdated',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(150),
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    SelectableText(
                      content,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
