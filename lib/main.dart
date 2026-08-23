import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/libmpv_check_stub.dart'
    if (dart.library.ffi) 'audio/libmpv_check_native.dart';
import 'data/prefs.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // Lock-screen / notification controls and background playback on mobile.
    await JustAudioBackground.init(
      androidNotificationChannelId: 'research.quran.mazhar.fi.audio',
      androidNotificationChannelName: 'Recitation playback',
      androidNotificationOngoing: true,
    );
  }
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    // mpv-backed just_audio implementation for desktop. On Linux this needs
    // the system libmpv (sudo apt install libmpv-dev). Check BEFORE calling
    // ensureInitialized: it registers itself as the just_audio backend before
    // loading libmpv, so a failed init leaves a broken half-registered player.
    // Skipping registration entirely keeps the app usable without audio, and
    // the play button then explains what to install.
    if (Platform.isWindows || libmpvAvailable()) {
      try {
        JustAudioMediaKit.ensureInitialized();
      } catch (e) {
        debugPrint('Desktop audio unavailable: $e');
      }
    } else {
      debugPrint('libmpv not found — desktop audio disabled. '
          'Install it with: sudo apt install libmpv-dev');
    }
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const QuranApp(),
  ));
}

class QuranApp extends ConsumerWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider.select((s) => s.theme));
    final language = ref.watch(settingsProvider.select((s) => s.appLanguage));
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Quran Researcher',
      theme: AppTheme.of(theme),
      locale: language == 'system' ? null : Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
