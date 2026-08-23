import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/audio_repo.dart';
import '../data/prefs.dart';

enum RepeatSetting { off, ayah, range }

class PlaybackState {
  /// Surah currently loaded in the player, or null when idle.
  final int? surah;
  final String reciterId;
  final bool playing;

  /// 0-based index into the surah's ayah list.
  final int currentIndex;
  final RepeatSetting repeat;
  final int? rangeStartAyah;
  final int? rangeEndAyah;

  const PlaybackState({
    this.surah,
    this.reciterId = '953',
    this.playing = false,
    this.currentIndex = 0,
    this.repeat = RepeatSetting.off,
    this.rangeStartAyah,
    this.rangeEndAyah,
  });

  int? get currentAyah => surah == null ? null : currentIndex + 1;
  String? get currentVerseKey => surah == null ? null : '$surah:${currentIndex + 1}';

  PlaybackState copyWith({
    int? surah,
    String? reciterId,
    bool? playing,
    int? currentIndex,
    RepeatSetting? repeat,
    int? Function()? rangeStartAyah,
    int? Function()? rangeEndAyah,
  }) =>
      PlaybackState(
        surah: surah ?? this.surah,
        reciterId: reciterId ?? this.reciterId,
        playing: playing ?? this.playing,
        currentIndex: currentIndex ?? this.currentIndex,
        repeat: repeat ?? this.repeat,
        rangeStartAyah:
            rangeStartAyah != null ? rangeStartAyah() : this.rangeStartAyah,
        rangeEndAyah: rangeEndAyah != null ? rangeEndAyah() : this.rangeEndAyah,
      );
}

/// (verseKey, wordPos) currently being recited — drives word highlighting.
final activeWordProvider = StateProvider<(String, int)?>((ref) => null);

final audioControllerProvider =
    NotifierProvider<AudioController, PlaybackState>(AudioController.new);

class AudioController extends Notifier<PlaybackState> {
  late final AudioPlayer _player;
  List<AyahAudio> _ayahs = const [];

  @override
  PlaybackState build() {
    // Adding a User-Agent helps prevent "(0) source error" from servers that
    // block generic requests (like everyayah.com).
    _player = AudioPlayer(
      userAgent: 'QuranResearcher/1.0 (https://github.com/masrafianam/Quran-Researcher)',
    );
    ref.onDispose(_player.dispose);

    _player.playingStream.listen((playing) {
      state = state.copyWith(playing: playing);
    });
    _player.currentIndexStream.listen(_onIndexChanged);
    _player.positionStream.listen(_onPosition);
    _player.processingStateStream.listen((ps) {
      if (ps == ProcessingState.completed) _onPlaylistCompleted();
    });

    return PlaybackState(reciterId: ref.read(settingsProvider).reciterId);
  }

  /// Throws with a readable message when playback can't start (no platform
  /// audio backend, no network for the CDN stream, ...). UI shows it.
  Future<void> playAyah(int surah, int ayah) async {
    try {
      if (state.surah != surah || _ayahs.isEmpty) {
        await _loadSurah(surah, initialAyah: ayah);
      } else {
        await _player.seek(Duration.zero, index: ayah - 1);
      }
      _player.play();
    } catch (e) {
      final s = '$e';
      if (e is MissingPluginException ||
          s.contains('MediaKit') ||
          s.contains('libmpv')) {
        try {
          await stop();
        } catch (_) {
          // the broken backend may refuse even stop(); state reset below
        }
        _ayahs = const [];
        state = PlaybackState(reciterId: state.reciterId);
        throw Exception(
            'Audio backend unavailable. On Linux, install libmpv first:\n'
            'sudo apt install libmpv-dev   (then fully restart the app)');
      }
      rethrow;
    }
  }

  Future<void> _loadSurah(int surah, {required int initialAyah}) async {
    final reciterId = state.reciterId;
    _ayahs = await ref
        .read(surahAudioProvider((surah: surah, reciterId: reciterId)).future);
    final reciterName =
        reciters.firstWhere((r) => r.id == reciterId, orElse: () => reciters[0]).name;
    final sources = [
      for (final a in _ayahs)
        _source(a, MediaItem(
          id: '${a.verseKey}@$reciterId',
          title: 'Ayah ${a.verseKey}',
          artist: reciterName,
        )),
    ];
    state = state.copyWith(
      surah: surah,
      currentIndex: initialAyah - 1,
      rangeStartAyah: () => null,
      rangeEndAyah: () => null,
    );
    await _player.setAudioSources(sources,
        initialIndex: initialAyah - 1, initialPosition: Duration.zero);
  }

  AudioSource _source(AyahAudio a, MediaItem tag) {
    // Switched to standard AudioSource.uri as LockCachingAudioSource often
    // triggers "(0) source error" if the server's Range support is non-ideal.
    return AudioSource.uri(Uri.parse(a.url), tag: tag);
  }

  void togglePlay() => state.playing ? _player.pause() : _player.play();

  Future<void> stop() async {
    await _player.stop();
    _ayahs = const [];
    state = PlaybackState(reciterId: state.reciterId);
    ref.read(activeWordProvider.notifier).state = null;
  }

  Future<void> next() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  Future<void> previous() async {
    if (_player.hasPrevious) await _player.seekToPrevious();
  }

  Future<void> setReciter(String id) async {
    if (id == state.reciterId) return;
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(reciterId: id));
    final surah = state.surah;
    final ayah = state.currentAyah;
    final wasPlaying = state.playing;
    state = state.copyWith(reciterId: id);
    if (surah != null) {
      _ayahs = const [];
      await _loadSurah(surah, initialAyah: ayah ?? 1);
      if (wasPlaying) _player.play();
    }
  }

  void cycleRepeat() {
    final next = RepeatSetting
        .values[(state.repeat.index + 1) % RepeatSetting.values.length];
    state = state.copyWith(repeat: next);
    _player.setLoopMode(next == RepeatSetting.ayah ? LoopMode.one : LoopMode.off);
    if (next != RepeatSetting.range) {
      state = state.copyWith(rangeStartAyah: () => null, rangeEndAyah: () => null);
    }
  }

  void setRangeStart() =>
      state = state.copyWith(rangeStartAyah: () => state.currentAyah);

  void setRangeEnd() =>
      state = state.copyWith(rangeEndAyah: () => state.currentAyah);

  void _onIndexChanged(int? index) {
    if (index == null || _ayahs.isEmpty) return;
    // Range repeat: passing the end loops back to the start.
    final start = state.rangeStartAyah;
    final end = state.rangeEndAyah;
    if (state.repeat == RepeatSetting.range &&
        start != null &&
        end != null &&
        index > end - 1) {
      _player.seek(Duration.zero, index: start - 1);
      return;
    }
    state = state.copyWith(currentIndex: index);
  }

  void _onPlaylistCompleted() {
    final start = state.rangeStartAyah;
    if (state.repeat == RepeatSetting.range && start != null) {
      _player.seek(Duration.zero, index: start - 1);
      _player.play();
    } else {
      _player.pause();
    }
  }

  void _onPosition(Duration position) {
    final index = _player.currentIndex;
    if (index == null || index >= _ayahs.length || !state.playing) return;
    final a = _ayahs[index];
    final word = a.wordAt(position.inMilliseconds);
    final next = word == null ? null : (a.verseKey, word);
    final holder = ref.read(activeWordProvider.notifier);
    if (holder.state != next) holder.state = next;
  }
}
