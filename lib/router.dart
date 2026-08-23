import 'package:go_router/go_router.dart';

import 'features/about/about_screen.dart';
import 'features/home/home_screen.dart';
import 'features/mushaf/mushaf_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/research/phrases_screen.dart';
import 'features/research/roots_screen.dart';
import 'features/research/themes_screen.dart';
import 'features/research/topics_screen.dart';
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
    GoRoute(
      path: '/mushaf/:page',
      builder: (context, state) => MushafScreen(
        initialPage: int.tryParse(state.pathParameters['page'] ?? '') ?? 1,
      ),
    ),
    GoRoute(
        path: '/research/roots',
        builder: (context, state) => const RootsScreen()),
    GoRoute(
      path: '/research/root/:id',
      builder: (context, state) =>
          RootScreen(rootId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
        path: '/research/phrases',
        builder: (context, state) => const PhrasesScreen()),
    GoRoute(
      path: '/research/phrase/:id',
      builder: (context, state) =>
          PhraseScreen(phraseId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
        path: '/research/themes',
        builder: (context, state) => const ThemesScreen()),
    GoRoute(
        path: '/research/topics',
        builder: (context, state) => const TopicsScreen()),
    GoRoute(
      path: '/research/topic/:id',
      builder: (context, state) =>
          TopicScreen(topicId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(
        path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
  ],
);
