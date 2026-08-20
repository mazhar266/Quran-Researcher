import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/repo.dart';

final _queryProvider = StateProvider<String>((ref) => '');

final _resultsProvider = FutureProvider<List<SearchHit>>((ref) async {
  final query = ref.watch(_queryProvider);
  if (query.trim().length < 2) return const [];
  final repo = await ref.watch(repoProvider.future);
  return repo.search(query);
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(_queryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(_resultsProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search Arabic, English, Bangla, transliteration…',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Search failed.\n$e')),
        data: (hits) {
          if (hits.isEmpty) {
            return const Center(child: Text('Type at least two characters to search.'));
          }
          return ListView.builder(
            itemCount: hits.length,
            itemBuilder: (context, i) {
              final h = hits[i];
              return ListTile(
                leading: CircleAvatar(child: Text('${h.surah}')),
                title: Text(h.snippet, maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text(h.verseKey),
                onTap: () => context.push('/surah/${h.surah}?ayah=${h.ayah}'),
              );
            },
          );
        },
      ),
    );
  }
}
