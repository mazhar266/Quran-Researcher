import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cdn_catalog.dart';
import '../../data/cdn_fetch.dart' show formatModuleSize;
import '../../data/downloads.dart';
import '../../data/tafsir_repo.dart' show tafsirBooks;
import '../../l10n/l10n.dart';

/// Settings → Content downloads: every on-demand module with its state,
/// download, and removal (frees disk space). On web, content seeds itself on
/// first use, so only an explanatory note is shown.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statuses = ref.watch(moduleStatusProvider);
    final notifier = ref.read(moduleStatusProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.downloadsTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l10n.downloadWebNote,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    Widget row(String id, String name, String? subtitle) {
      final module = downloadableModules[id]!;
      final status = statuses[id] ?? const ModuleNotInstalled();
      final Widget trailing;
      switch (status) {
        case ModuleDownloading(:final received, :final total):
          trailing = SizedBox(
            width: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LinearProgressIndicator(
                    value: received == null ? null : received / total),
                const SizedBox(height: 4),
                Text(
                  received == null
                      ? formatModuleSize(total)
                      : '${(received / total * 100).round()}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        case ModuleFailed():
          trailing = IconButton(
            tooltip: l10n.downloadRetry,
            icon: Icon(Icons.error_outline, color: scheme.error),
            onPressed: () => notifier.download(id),
          );
        case ModuleInstalled():
          trailing = IconButton(
            tooltip: l10n.downloadRemove,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmRemove(context, ref, id, name),
          );
        case ModuleNotInstalled():
          trailing = IconButton(
            tooltip: l10n.downloadAction,
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () => notifier.download(id),
          );
      }
      return ListTile(
        dense: true,
        title: Text(name),
        subtitle: Text(subtitle ?? formatModuleSize(module.sizeBytes)),
        trailing: trailing,
      );
    }

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloadsTitle)),
      body: ListView(
        children: [
          header(l10n.downloadsGroupTafsirEn),
          for (final b in tafsirBooks.where((b) => b.lang == 'en'))
            row('tafsir:${b.slug}', b.name, null),
          header(l10n.downloadsGroupTafsirBn),
          for (final b in tafsirBooks.where((b) => b.lang == 'bn'))
            row('tafsir:${b.slug}', b.name, null),
          header(l10n.downloadsGroupResearch),
          row(dictAr.id, l10n.dictModuleName, null),
          header(l10n.downloadsGroupMushaf),
          row(fontpackV4.id, l10n.fontsModuleName,
              '${formatModuleSize(fontpackV4.sizeBytes)} · ~160 MB'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.downloadRemoveConfirmTitle),
        content: Text('${l10n.downloadRemoveConfirmBody}\n\n$name'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.downloadCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.downloadRemove),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      try {
        await ref.read(moduleStatusProvider.notifier).delete(id);
      } on Exception catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${l10n.downloadFailed}: $e')));
        }
      }
    }
  }
}
