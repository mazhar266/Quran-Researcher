import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';

import '../../data/research_repo.dart';
import 'widgets.dart';

final _topicQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class TopicsScreen extends ConsumerWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_topicQueryProvider);
    final topics = ref.watch(topicSearchProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Search topics…',
            border: InputBorder.none,
          ),
          onChanged: (v) => ref.read(_topicQueryProvider.notifier).state = v,
        ),
      ),
      body: topics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load topics.\n$e')),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) => _TopicTile(topic: list[i]),
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});

  final TopicInfo topic;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(topic.name),
      subtitle: Text([
        if (topic.arabicName?.isNotEmpty ?? false) topic.arabicName!,
        if (topic.ayahs.isNotEmpty) '${topic.ayahs.length} ayahs',
        if (topic.childCount > 0) '${topic.childCount} subtopics',
      ].join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/research/topic/${topic.id}'),
    );
  }
}

class TopicScreen extends ConsumerWidget {
  const TopicScreen({super.key, required this.topicId});

  final int topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topic = ref.watch(topicProvider(topicId));
    final children = ref.watch(topicChildrenProvider(topicId));
    return Scaffold(
      appBar: AppBar(
        title: Text(topic.valueOrNull?.name ?? 'Topic'),
      ),
      body: topic.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load topic.\n$e')),
        data: (t) {
          if (t == null) return const Center(child: Text('Topic not found.'));
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (t.arabicName?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(t.arabicName!,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                          fontFamily: 'UthmanicHafs', fontSize: 26)),
                ),
              if (t.description?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: HtmlWidget(
                    // <topic data-id="61">..</topic> cross-links -> tappable.
                    t.description!.replaceAllMapped(
                      RegExp(r'<topic data-id="(\d+)">(.*?)</topic>',
                          dotAll: true),
                      (m) => '<a href="topic:${m[1]}">${m[2]}</a>',
                    ),
                    textStyle: const TextStyle(fontSize: 15.5, height: 1.6),
                    onTapUrl: (url) {
                      if (url.startsWith('topic:')) {
                        context.push('/research/topic/${url.substring(6)}');
                        return true;
                      }
                      return false;
                    },
                  ),
                ),
              if (t.ayahs.isNotEmpty) ...[
                SectionLabel('Ayahs (${t.ayahs.length})'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final key in t.ayahs.take(60))
                        ActionChip(
                          label: Text(key),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            final p = key.split(':');
                            context.push('/surah/${p[0]}?ayah=${p[1]}');
                          },
                        ),
                      if (t.ayahs.length > 60)
                        Chip(label: Text('+${t.ayahs.length - 60} more')),
                    ],
                  ),
                ),
              ],
              children.maybeWhen(
                data: (kids) => kids.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionLabel('Subtopics (${kids.length})'),
                          for (final k in kids) _TopicTile(topic: k),
                        ],
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }
}
