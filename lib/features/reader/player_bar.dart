import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_controller.dart';
import '../../data/audio_repo.dart';

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
                  Text('Ayah ${playback.currentVerseKey ?? ''}',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: switch (playback.repeat) {
                      RepeatSetting.off => 'Repeat: off',
                      RepeatSetting.ayah => 'Repeat: this ayah',
                      RepeatSetting.range => 'Repeat: range',
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
                          ? 'Set A'
                          : 'A:${playback.rangeStartAyah}'),
                    ),
                    TextButton(
                      onPressed: controller.setRangeEnd,
                      child: Text(playback.rangeEndAyah == null
                          ? 'Set B'
                          : 'B:${playback.rangeEndAyah}'),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    tooltip: 'Previous ayah',
                    onPressed: controller.previous,
                  ),
                  IconButton.filled(
                    icon: Icon(playback.playing ? Icons.pause : Icons.play_arrow),
                    tooltip: playback.playing ? 'Pause' : 'Play',
                    onPressed: controller.togglePlay,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    tooltip: 'Next ayah',
                    onPressed: controller.next,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Stop',
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
