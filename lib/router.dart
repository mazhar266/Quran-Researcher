import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';

/// Deep-linkable paths (matter on web):
///   /                     home (surah / juz / bookmarks)
///   /surah/2?ayah=255     reader, optionally scrolled to an ayah
///   /search               full-text search
///   /settings             reading preferences
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/surah/:id',
      builder: (context, state) => ReaderScreen(
        surahId: int.parse(state.pathParameters['id']!),
        initialAyah: int.tryParse(state.uri.queryParameters['ayah'] ?? ''),
      ),
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(
        path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);
