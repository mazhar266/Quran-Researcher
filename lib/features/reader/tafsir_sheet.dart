import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../data/prefs.dart';
import '../../data/tafsir_repo.dart';

void showTafsirSheet(BuildContext context, String verseKey) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) =>
          _TafsirContent(verseKey: verseKey, scrollController: scrollController),
    ),
  );
}

class _TafsirContent extends ConsumerWidget {
  const _TafsirContent({required this.verseKey, required this.scrollController});

  final String verseKey;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookSlug = ref.watch(settingsProvider.select((s) => s.tafsirBookSlug));
    final entry =
        ref.watch(tafsirEntryProvider((verseKey: verseKey, bookSlug: bookSlug)));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('Tafsir · $verseKey',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButton<String>(
            value: bookSlug,
            isExpanded: true,
            items: [
              for (final b in tafsirBooks)
                DropdownMenuItem(
                  value: b.slug,
                  child: Text('${b.lang == 'en' ? '🇬🇧' : '🇧🇩'}  ${b.name}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (slug) {
              if (slug != null) {
                ref
                    .read(settingsProvider.notifier)
                    .update((s) => s.copyWith(tafsirBookSlug: slug));
              }
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: entry.when(
            loading: () => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Preparing tafsir…'),
                ],
              ),
            ),
            error: (e, _) => Center(child: Text('Could not load tafsir.\n$e')),
            data: (t) {
              if (t == null) {
                return const Center(
                    child: Text('No tafsir for this ayah in the selected book.'));
              }
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.groupKey != verseKey)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Covered together with ayah ${t.groupKey}',
                            style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic)),
                      ),
                    HtmlWidget(
                      t.html,
                      textStyle: const TextStyle(fontSize: 15.5, height: 1.6),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
