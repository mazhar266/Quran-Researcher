import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cdn_catalog.dart';
import '../../data/cdn_fetch.dart' show formatModuleSize;
import '../../data/downloads.dart';
import '../../l10n/l10n.dart';

/// The download lifecycle UI for one on-demand module (a tafsir book, the
/// Arramooz dictionary, or the mushaf fontpack), shown wherever content is
/// requested before it has been downloaded.
///
/// [title] and [body] are pre-localized by the caller; this widget renders
/// the size, the download button, byte-accurate progress with cancel (native)
/// or an indeterminate spinner (web, where the seed fetch happens inside the
/// content provider), and failure with retry. A finished download invalidates
/// the content providers, so the surrounding screen refreshes on its own.
class ModuleDownloadView extends ConsumerWidget {
  const ModuleDownloadView({
    super.key,
    required this.moduleId,
    required this.title,
    required this.body,
  });

  final String moduleId;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final module = downloadableModules[moduleId]!;
    final status = ref.watch(moduleStatusProvider.select(
        (statuses) => statuses[moduleId] ?? const ModuleNotInstalled()));
    final notifier = ref.read(moduleStatusProvider.notifier);

    final Widget action;
    switch (status) {
      case ModuleDownloading(:final received, :final total):
        action = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: received == null ? null : received / total),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  received == null
                      ? formatModuleSize(total)
                      : l10n.downloadProgressOf(
                          formatModuleSize(received), formatModuleSize(total)),
                ),
                // Only the native download can actually be cancelled; on web
                // the fetch runs inside the content provider.
                if (!kIsWeb && received != null)
                  TextButton(
                    onPressed: () => notifier.cancel(moduleId),
                    child: Text(l10n.downloadCancel),
                  ),
              ],
            ),
          ],
        );
      case ModuleFailed(:final message):
        action = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.downloadFailed,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error, fontSize: 13)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => notifier.download(moduleId),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.downloadRetry),
            ),
          ],
        );
      case ModuleInstalled():
        action = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(l10n.downloadedLabel),
          ],
        );
      case ModuleNotInstalled():
        action = FilledButton.icon(
          onPressed: () => notifier.download(moduleId),
          icon: const Icon(Icons.cloud_download_outlined),
          label: Text('${l10n.downloadAction} · ${formatModuleSize(module.sizeBytes)}'),
        );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.cloud_download_outlined,
              size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
          const SizedBox(height: 16),
          action,
        ],
      ),
    );
  }
}
