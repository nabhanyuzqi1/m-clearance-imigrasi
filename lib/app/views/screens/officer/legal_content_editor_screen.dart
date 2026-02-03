import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/legal_document.dart';
import '../../../services/legal_content_service.dart';
import '../../../services/logging_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bouncing_dots_loader.dart';

class LegalContentEditorScreen extends StatefulWidget {
  const LegalContentEditorScreen({super.key});

  @override
  State<LegalContentEditorScreen> createState() =>
      _LegalContentEditorScreenState();
}

class _LegalContentEditorScreenState extends State<LegalContentEditorScreen> {
  final LegalContentService _service = LegalContentService();
  final TextEditingController _controller = TextEditingController();

  static const List<String> _languages = ['en', 'id'];

  LegalDocumentType _selectedType = LegalDocumentType.terms;
  String _selectedLanguage = _languages.first;
  bool _isLoading = true;
  bool _isSaving = false;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    try {
      final document = await _service.fetchDocument(
        _selectedType,
        languageCode: _selectedLanguage,
      );
      if (!mounted) return;
      setState(() {
        _controller
          ..text = document.content
          ..selection = TextSelection.collapsed(
            offset: document.content.length,
          );
        _lastUpdated = document.updatedAt;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      LoggingService().error('Failed to load legal content', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _controller.clear();
        _lastUpdated = null;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).get('legalEditor.error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _saveContent() async {
    if (_isSaving) return;
    final content = _controller.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).get('legalEditor.empty_state'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service.updateDocument(
        _selectedType,
        languageCode: _selectedLanguage,
        content: content,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).get('legalEditor.success'),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      await _loadContent();
    } catch (error, stackTrace) {
      LoggingService().error('Failed to save legal content', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).get('legalEditor.error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onTypeChanged(LegalDocumentType? type) {
    if (type == null || type == _selectedType) return;
    setState(() => _selectedType = type);
    _loadContent();
  }

  void _onLanguageChanged(String? language) {
    if (language == null || language == _selectedLanguage) return;
    setState(() => _selectedLanguage = language);
    _loadContent();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final typeLabel = _selectedType == LegalDocumentType.terms
        ? localization.get('legalEditor.terms')
        : localization.get('legalEditor.privacy');
    final lastUpdatedLabel = _lastUpdated != null
        ? '${localization.get('legalEditor.last_updated')} '
              '${_lastUpdated!.toLocal()}'
        : localization.get('legalEditor.empty_state');

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        titleText: localization.get('legalEditor.title'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localization.get('legalEditor.subtitle'),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
              Row(
                children: [
                  Expanded(
                    child: _DropdownCard<LegalDocumentType>(
                      label: localization.get('legalEditor.document_type'),
                      value: _selectedType,
                      items: LegalDocumentType.values
                          .map(
                            (type) => DropdownMenuItem<LegalDocumentType>(
                              value: type,
                              child: Text(
                                type == LegalDocumentType.terms
                                    ? localization.get('legalEditor.terms')
                                    : localization.get('legalEditor.privacy'),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _onTypeChanged,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: _DropdownCard<String>(
                      label: localization.get('legalEditor.language'),
                      value: _selectedLanguage,
                      items: _languages
                          .map(
                            (code) => DropdownMenuItem<String>(
                              value: code,
                              child: Text(
                                code == 'en'
                                    ? localization.get(
                                        'legalEditor.language_en',
                                      )
                                    : localization.get(
                                        'legalEditor.language_id',
                                      ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _onLanguageChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                lastUpdatedLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Expanded(
                child: _isLoading
                    ? const Center(child: BouncingDotsLoader())
                    : TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          labelText: typeLabel,
                          alignLabelWithHint: true,
                          hintText: localization.get(
                            'legalEditor.content_hint',
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: AppTheme.spacing24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading || _isSaving ? null : _saveContent,
                  icon: _isSaving
                      ? const BouncingDotsLoader()
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving
                        ? localization.get('legalEditor.saving')
                        : localization.get('legalEditor.save'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownCard<T> extends StatelessWidget {
  const _DropdownCard({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}
