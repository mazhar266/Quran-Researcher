import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/research_repo.dart';

final _themeQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class ThemesScreen extends ConsumerWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_themeQueryProvider);
    final themes = ref.watch(themeSearchProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Search ayah themes…',
            border: InputBorder.none,
          ),
          onChanged: (v) => ref.read(_themeQueryProvider.notifier).state = v,
        ),
      ),
      body: themes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load themes.\n$e')),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final t = list[i];
            return ListTile(
              dense: true,
              leading: SizedBox(
                width: 64,
                child: Text('${t.surah}:${t.ayahFrom}–${t.ayahTo}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
              ),
              title: Text(t.theme),
              onTap: () => context.push('/surah/${t.surah}?ayah=${t.ayahFrom}'),
            );
          },
        ),
      ),
    );
  }
}
