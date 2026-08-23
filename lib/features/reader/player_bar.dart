import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_controller.dart';
import '../../data/audio_repo.dart';
import '../../l10n/l10n.dart';

/// Persistent bar at the bottom of the reader while audio is loaded.
class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(audioControllerProvider);
    final controller = ref.read(audioControllerProvider.notifier);
    if (playback.surah == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: playback.reciterId,
                      isDense: true,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final r in reciters)
                          DropdownMenuItem(value: r.id, child: Text(r.name)),
                      ],
                      onChanged: (id) {
                        if (id != null) controller.setReciter(id);
                      },
                    ),
                  ),
                  Text(context.l10n.ayahLabel(playback.currentVerseKey ?? ''),
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: switch (playback.repeat) {
                      RepeatSetting.off => context.l10n.repeatOff,
                      RepeatSetting.ayah => context.l10n.repeatAyah,
                      RepeatSetting.range => context.l10n.repeatRange,
                    },
                    icon: Icon(
                      switch (playback.repeat) {
                        RepeatSetting.off => Icons.repeat,
                        RepeatSetting.ayah => Icons.repeat_one,
                        RepeatSetting.range => Icons.repeat_on,
                      },
                      color: playback.repeat == RepeatSetting.off
                          ? null
                          : scheme.primary,
                    ),
                    onPressed: controller.cycleRepeat,
                  ),
                  if (playback.repeat == RepeatSetting.range) ...[
                    TextButton(
                      onPressed: controller.setRangeStart,
                      child: Text(playback.rangeStartAyah == null
                          ? context.l10n.setRangeA
                          : 'A:${playback.rangeStartAyah}'),
                    ),
                    TextButton(
                      onPressed: controller.setRangeEnd,
                      child: Text(playback.rangeEndAyah == null
                          ? context.l10n.setRangeB
                          : 'B:${playback.rangeEndAyah}'),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    tooltip: context.l10n.previousAyah,
                    onPressed: controller.previous,
                  ),
                  IconButton.filled(
                    icon: Icon(playback.playing ? Icons.pause : Icons.play_arrow),
                    tooltip: playback.playing ? context.l10n.pause : context.l10n.play,
                    onPressed: controller.togglePlay,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    tooltip: context.l10n.nextAyah,
                    onPressed: controller.next,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.stop,
                    onPressed: controller.stop,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
