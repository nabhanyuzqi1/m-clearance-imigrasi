import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../localization/app_localizations.dart';
import '../../services/logging_service.dart';

typedef AttachmentViewer =
    Future<void> Function(BuildContext context, String url);

class AttachmentStatusTile extends StatelessWidget {
  const AttachmentStatusTile({
    super.key,
    required this.label,
    this.fileUrls = const [],
    this.onViewFile,
    this.leading,
  });

  final String label;
  final List<String> fileUrls;
  final AttachmentViewer? onViewFile;
  final Widget? leading;

  bool get _hasFiles => fileUrls.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusLabel = l10n.get('attachments.status');
    final statusValue = l10n.get(
      _hasFiles ? 'attachments.uploaded' : 'attachments.not_uploaded',
    );
    final description = l10n.get(
      _hasFiles ? 'attachments.attached' : 'attachments.not_attached',
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: theme.brightness == Brightness.light
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withAlpha(20),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading ??
              Icon(
                Icons.insert_drive_file_outlined,
                color: _hasFiles
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withAlpha(100),
                size: 22,
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$statusLabel: $statusValue',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: AppTheme.fontSizeSmall,
                    color: _hasFiles
                        ? colorScheme.secondary
                        : colorScheme.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: AppTheme.fontSizeSmall,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _hasFiles ? l10n.get('attachments.view') : null,
            icon: Icon(
              Icons.remove_red_eye_outlined,
              color: _hasFiles
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withAlpha(100),
            ),
            onPressed: _hasFiles ? () => _handleView(context) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _handleView(BuildContext context) async {
    final viewer = onViewFile;
    if (viewer == null) {
      LoggingService().warning(
        'AttachmentStatusTile for "$label" has no viewer callback.',
      );
      return;
    }

    if (fileUrls.length <= 1) {
      await viewer(context, fileUrls.first);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: AppTheme.fontSizeMedium,
                ),
              ),
              const SizedBox(height: 12),
              ...fileUrls.asMap().entries.map((entry) {
                final displayName = _resolveDisplayName(entry.value);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ),
                  title: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    l10n.get('attachments.view'),
                    style: const TextStyle(fontSize: AppTheme.fontSizeSmall),
                  ),
                  trailing: Icon(
                    Icons.remove_red_eye_outlined,
                    color: colorScheme.primary,
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await viewer(context, entry.value);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  String _resolveDisplayName(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last.split('?').first;
      }
    } catch (_) {
      // ignore parsing errors and fall back to raw handling
    }
    final raw = url.split('/').last;
    return raw.split('?').first;
  }
}
