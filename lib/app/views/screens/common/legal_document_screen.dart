import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/legal_document.dart';
import '../../../services/legal_content_service.dart';
import '../../../services/logging_service.dart';
import '../../widgets/bouncing_dots_loader.dart';
import '../../widgets/custom_app_bar.dart';

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.documentType});

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
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
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
            LoggingService().warning(
              'Failed updating legal document stream',
              error,
            );
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
    final locale =
        _activeLanguageCode ??
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
    final localeCode = localization.languageCode;
    final formattedUpdated = _document.updatedAt != null
        ? DateFormat.yMMMMd(
            localeCode,
          ).add_Hm().format(_document.updatedAt!.toLocal())
        : localization.get('legal.not_available');

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final contentWidgets = _buildContentWidgets(
      _document.content,
      textTheme,
      colorScheme,
    );

    return Scaffold(
      appBar: CustomAppBar(titleText: title, showBackButton: true),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _isLoading
            ? const Center(child: BouncingDotsLoader())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppTheme.spacing24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderCard(
                            context,
                            title,
                            updatedLabel,
                            formattedUpdated,
                            localeCode,
                            colorScheme,
                            textTheme,
                          ),
                          const SizedBox(height: AppTheme.spacing24),
                          if (contentWidgets.isEmpty)
                            _buildEmptyStateCard(
                              emptyLabel,
                              colorScheme,
                              textTheme,
                            )
                          else
                            _buildContentCard(contentWidgets, colorScheme),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    String title,
    String updatedLabel,
    String formattedUpdated,
    String localeCode,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isPrivacy = widget.documentType == LegalDocumentType.privacy;
    final highlightColor = isPrivacy
        ? colorScheme.secondary
        : colorScheme.primary;
    final iconData = isPrivacy
        ? Icons.privacy_tip_outlined
        : Icons.article_outlined;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_alpha(highlightColor, 0.15), _alpha(highlightColor, 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: _alpha(highlightColor, 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: _alpha(highlightColor, 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: 32, color: highlightColor),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  '$updatedLabel $formattedUpdated',
                  style: textTheme.bodyMedium?.copyWith(
                    color: _alpha(colorScheme.onSurface, 0.7),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing12),
                Wrap(
                  spacing: AppTheme.spacing12,
                  runSpacing: AppTheme.spacing12,
                  children: [
                    Chip(
                      label: Text(localeCode.toUpperCase()),
                      backgroundColor: colorScheme.surface,
                      side: BorderSide(color: _alpha(highlightColor, 0.5)),
                    ),
                    Chip(
                      label: Text(
                        widget.documentType == LegalDocumentType.privacy
                            ? AppLocalizations.of(
                                context,
                              ).get('legal.privacy_label')
                            : AppLocalizations.of(
                                context,
                              ).get('legal.terms_label'),
                      ),
                      backgroundColor: _alpha(highlightColor, 0.12),
                      labelStyle: textTheme.labelLarge?.copyWith(
                        color: highlightColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(
    List<Widget> contentWidgets,
    ColorScheme colorScheme,
  ) {
    final children = <Widget>[];
    for (var i = 0; i < contentWidgets.length; i++) {
      children.add(contentWidgets[i]);
      if (i != contentWidgets.length - 1) {
        children.add(const SizedBox(height: AppTheme.spacing20));
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: _alpha(colorScheme.outlineVariant, 0.6)),
        boxShadow: [
          BoxShadow(
            color: _alpha(colorScheme.shadow, 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildEmptyStateCard(
    String message,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        color: _alpha(colorScheme.surfaceContainerHighest, 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: _alpha(colorScheme.outlineVariant, 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: _alpha(colorScheme.onSurface, 0.8),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContentWidgets(
    String rawContent,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final normalized = _normalizeContent(rawContent);
    if (normalized.isEmpty) return const [];

    final blocks = _parseContentBlocks(normalized);
    if (blocks.isEmpty) return const [];

    final headlineColor = widget.documentType == LegalDocumentType.privacy
        ? colorScheme.secondary
        : colorScheme.primary;

    return blocks
        .map((block) {
          switch (block.type) {
            case _LegalBlockType.heading:
              return SelectableText.rich(
                _buildInlineSpan(
                  block.text,
                  _headingStyle(block.level, textTheme, headlineColor),
                ),
              );
            case _LegalBlockType.paragraph:
              return SelectableText.rich(
                _buildInlineSpan(
                  block.text,
                  textTheme.bodyLarge?.copyWith(height: 1.6) ??
                      TextStyle(color: colorScheme.onSurface, height: 1.6),
                ),
              );
            case _LegalBlockType.list:
              return _buildListBlock(block, textTheme, colorScheme);
            case _LegalBlockType.quote:
              return _buildQuoteBlock(block.text, textTheme, colorScheme);
          }
        })
        .toList(growable: false);
  }

  Widget _buildListBlock(
    _LegalContentBlock block,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final itemStyle =
        textTheme.bodyLarge?.copyWith(height: 1.5) ??
        TextStyle(color: colorScheme.onSurface, height: 1.5);
    final markerStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < block.items.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  block.isOrdered ? '${i + 1}.' : '•',
                  textAlign: TextAlign.center,
                  style: markerStyle,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: SelectableText.rich(
                  _buildInlineSpan(block.items[i], itemStyle),
                ),
              ),
            ],
          ),
          if (i != block.items.length - 1)
            const SizedBox(height: AppTheme.spacing12),
        ],
      ],
    );
  }

  Widget _buildQuoteBlock(
    String text,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final accentColor = widget.documentType == LegalDocumentType.privacy
        ? colorScheme.secondary
        : colorScheme.primary;

    final quoteStyle =
        textTheme.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
          height: 1.6,
        ) ??
        TextStyle(
          color: colorScheme.onSurface,
          fontStyle: FontStyle.italic,
          height: 1.6,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: _alpha(accentColor, 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: SelectableText.rich(_buildInlineSpan(text, quoteStyle)),
    );
  }

  Color _alpha(Color color, double opacity) {
    final clamped = opacity.clamp(0.0, 1.0);
    return color.withAlpha((clamped * 255).round());
  }

  TextStyle _headingStyle(
    int level,
    TextTheme textTheme,
    Color highlightColor,
  ) {
    switch (level) {
      case 1:
        return (textTheme.headlineSmall ??
                const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))
            .copyWith(
              fontWeight: FontWeight.w700,
              color: highlightColor,
              height: 1.2,
            );
      case 2:
        return (textTheme.titleLarge ??
                const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))
            .copyWith(
              fontWeight: FontWeight.w700,
              color: highlightColor,
              height: 1.3,
            );
      default:
        return (textTheme.titleMedium ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))
            .copyWith(
              fontWeight: FontWeight.w600,
              color: _alpha(highlightColor, 0.9),
              height: 1.4,
            );
    }
  }

  TextSpan _buildInlineSpan(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    int index = 0;

    void addText(String value, {TextStyle? style}) {
      if (value.isEmpty) return;
      spans.add(TextSpan(text: value, style: style ?? baseStyle));
    }

    while (index < text.length) {
      if (text.startsWith('**', index)) {
        final end = text.indexOf('**', index + 2);
        if (end != -1) {
          final boldText = text.substring(index + 2, end);
          addText(
            boldText,
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          );
          index = end + 2;
          continue;
        }
      }

      if (text.startsWith('_', index)) {
        final end = text.indexOf('_', index + 1);
        if (end != -1) {
          final italicText = text.substring(index + 1, end);
          addText(
            italicText,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          );
          index = end + 1;
          continue;
        }
      }

      final nextBold = text.indexOf('**', index);
      final nextItalic = text.indexOf('_', index);
      final candidates = [
        nextBold,
        nextItalic,
      ].where((value) => value >= 0).toList(growable: false);
      final nextMarker = candidates.isEmpty
          ? -1
          : candidates.reduce((a, b) => a < b ? a : b);

      if (nextMarker == -1) {
        addText(text.substring(index));
        break;
      } else {
        addText(text.substring(index, nextMarker));
        index = nextMarker;
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  String _normalizeContent(String content) {
    var normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Early exit after trimming
    if (normalized.trim().isEmpty) {
      return '';
    }

    normalized = normalized.replaceAll('&nbsp;', ' ');
    normalized = normalized.replaceAll('&amp;', '&');
    normalized = normalized.replaceAll('&lt;', '<');
    normalized = normalized.replaceAll('&gt;', '>');
    normalized = normalized.replaceAll('&quot;', '"');
    normalized = normalized.replaceAll('&#39;', "'");

    normalized = normalized.replaceAllMapped(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      (_) => '\n',
    );

    normalized = normalized.replaceAllMapped(
      RegExp(r'<ol[^>]*>(.*?)</ol>', caseSensitive: false, dotAll: true),
      (match) {
        final inner = match.group(1) ?? '';
        final itemMatches = RegExp(
          r'<li[^>]*>(.*?)</li>',
          caseSensitive: false,
          dotAll: true,
        ).allMatches(inner);
        final buffer = StringBuffer();
        var index = 1;
        for (final item in itemMatches) {
          buffer.writeln('$index. ${item.group(1)?.trim() ?? ''}');
          index++;
        }
        return '\n${buffer.toString().trim()}\n\n';
      },
    );

    normalized = normalized.replaceAllMapped(
      RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true),
      (match) {
        final inner = match.group(1) ?? '';
        final itemMatches = RegExp(
          r'<li[^>]*>(.*?)</li>',
          caseSensitive: false,
          dotAll: true,
        ).allMatches(inner);
        final buffer = StringBuffer();
        for (final item in itemMatches) {
          buffer.writeln('- ${item.group(1)?.trim() ?? ''}');
        }
        return '\n${buffer.toString().trim()}\n\n';
      },
    );

    normalized = normalized.replaceAllMapped(
      RegExp(r'<h([1-6])[^>]*>(.*?)</h\1>', caseSensitive: false, dotAll: true),
      (match) {
        final level = int.tryParse(match.group(1) ?? '1') ?? 1;
        final safeLevel = level.clamp(1, 6).toInt();
        final hashes = '#' * safeLevel;
        final text = match.group(2)?.trim() ?? '';
        return '\n$hashes $text\n\n';
      },
    );

    normalized = normalized.replaceAllMapped(
      RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
      (match) => '\n${match.group(1)?.trim() ?? ''}\n\n',
    );

    normalized = normalized.replaceAllMapped(
      RegExp(
        r'<strong[^>]*>(.*?)</strong>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '**${match.group(1)?.trim() ?? ''}**',
    );

    normalized = normalized.replaceAllMapped(
      RegExp(r'<b[^>]*>(.*?)</b>', caseSensitive: false, dotAll: true),
      (match) => '**${match.group(1)?.trim() ?? ''}**',
    );

    normalized = normalized.replaceAllMapped(
      RegExp(r'<em[^>]*>(.*?)</em>', caseSensitive: false, dotAll: true),
      (match) => '_${match.group(1)?.trim() ?? ''}_',
    );

    normalized = normalized.replaceAllMapped(
      RegExp(r'<i[^>]*>(.*?)</i>', caseSensitive: false, dotAll: true),
      (match) => '_${match.group(1)?.trim() ?? ''}_',
    );

    normalized = normalized.replaceAllMapped(
      RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
      (match) => '- ${match.group(1)?.trim() ?? ''}\n',
    );

    normalized = normalized.replaceAll(RegExp(r'<[^>]+>'), '');
    normalized = normalized.replaceAll('\t', ' ');
    normalized = normalized.replaceAll(RegExp(r' {2,}'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return normalized.trim();
  }

  List<_LegalContentBlock> _parseContentBlocks(String content) {
    final sections = content.split(RegExp(r'\n{2,}'));
    final blocks = <_LegalContentBlock>[];

    for (final rawSection in sections) {
      final section = rawSection.trim();
      if (section.isEmpty) continue;

      final headingMatch = RegExp(
        r'^(#{1,6})\s+(.*)$',
        multiLine: false,
      ).firstMatch(section);
      if (headingMatch != null) {
        final hashes = headingMatch.group(1) ?? '#';
        final text = headingMatch.group(2)?.trim() ?? '';
        blocks.add(
          _LegalContentBlock.heading(text: text, level: hashes.length),
        );
        final remainder = section.substring(headingMatch.end).trim();
        if (remainder.isNotEmpty) {
          blocks.addAll(_parseContentBlocks(remainder));
        }
        continue;
      }

      final isQuote = section.startsWith('>');
      if (isQuote) {
        final quote = section
            .split('\n')
            .map((line) => line.replaceFirst(RegExp(r'^>\s?'), '').trim())
            .join('\n')
            .trim();
        if (quote.isNotEmpty) {
          blocks.add(_LegalContentBlock.quote(text: quote));
        }
        continue;
      }

      final lines = section.split('\n');
      final trimmedLines = lines.map((line) => line.trim()).toList();
      final bulletCount = trimmedLines
          .where((line) => RegExp(r'^[-•]\s+').hasMatch(line))
          .length;
      final orderedCount = trimmedLines
          .where((line) => RegExp(r'^\d+[\.)]?\s+').hasMatch(line))
          .length;

      if (bulletCount == trimmedLines.length && bulletCount > 0) {
        final items = trimmedLines
            .map((line) => line.replaceFirst(RegExp(r'^[-•]\s+'), '').trim())
            .where((line) => line.isNotEmpty)
            .toList();
        if (items.isNotEmpty) {
          blocks.add(_LegalContentBlock.list(items: items, isOrdered: false));
        }
        continue;
      }

      if (orderedCount == trimmedLines.length && orderedCount > 0) {
        final items = trimmedLines
            .map(
              (line) => line.replaceFirst(RegExp(r'^\d+[\.)]?\s+'), '').trim(),
            )
            .where((line) => line.isNotEmpty)
            .toList();
        if (items.isNotEmpty) {
          blocks.add(_LegalContentBlock.list(items: items, isOrdered: true));
        }
        continue;
      }

      final paragraph = trimmedLines.join(' ').trim();
      if (paragraph.isNotEmpty) {
        blocks.add(_LegalContentBlock.paragraph(text: paragraph));
      }
    }

    return blocks;
  }
}

enum _LegalBlockType { heading, paragraph, list, quote }

class _LegalContentBlock {
  const _LegalContentBlock.heading({required this.text, required this.level})
    : type = _LegalBlockType.heading,
      items = const [],
      isOrdered = false;

  const _LegalContentBlock.paragraph({required this.text})
    : type = _LegalBlockType.paragraph,
      level = 0,
      items = const [],
      isOrdered = false;

  const _LegalContentBlock.list({required this.items, required this.isOrdered})
    : type = _LegalBlockType.list,
      text = '',
      level = 0;

  const _LegalContentBlock.quote({required this.text})
    : type = _LegalBlockType.quote,
      level = 0,
      items = const [],
      isOrdered = false;

  final _LegalBlockType type;
  final String text;
  final int level;
  final List<String> items;
  final bool isOrdered;
}
