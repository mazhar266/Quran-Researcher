import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../data/research_repo.dart';

/// Long-form surah introduction (name, revelation period, themes).
void showSurahInfoSheet(BuildContext context, int surah, String surahName) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Consumer(
        builder: (context, ref, _) {
          final info = ref.watch(surahInfoProvider(surah));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text('About $surahName',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: info.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Could not load surah info.\n$e')),
                  data: (html) => html == null
                      ? const Center(child: Text('No introduction available.'))
                      : SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: HtmlWidget(html,
                              textStyle:
                                  const TextStyle(fontSize: 15.5, height: 1.6)),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
