import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sarf.dart';
import 'widgets.dart';

/// Sarf (صرف) panel of the word sheet: word type, verb form and bab, sigah,
/// masdar, and the attached prefixes/suffixes. Anything the pipeline could not
/// establish is simply left out — never guessed.
class SarfSection extends ConsumerWidget {
  const SarfSection({super.key, required this.location, required this.bangla});

  final String location;
  final bool bangla;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sarf = ref.watch(wordSarfProvider(location));
    return sarf.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Grammar unavailable.\n$e'),
      ),
      data: (s) {
        if (s == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(bangla
                ? 'এই শব্দের সরফ বিশ্লেষণ নেই।'
                : 'No grammatical analysis for this word.'),
          );
        }
        final rows = <(String, String, String?)>[
          (bangla ? 'শব্দের প্রকার' : 'Word type', _posLabel(s, bangla), null),
          if (s.isVerb && s.formRoman != null)
            (bangla ? 'বাব / ওজন' : 'Bab (form)',
                s.babAr ?? '${bangla ? "বাব" : "Form"} ${s.formRoman}',
                'Form ${s.formRoman}'),
          if (s.sigahAr != null)
            (bangla ? 'সীগাহ' : 'Sigah', s.sigahAr!, _sigahLatin(s, bangla)),
          if (s.mood != null)
            (bangla ? 'ই‘রাব' : 'Mood', _moodAr(s.mood!), _moodLabel(s.mood!, bangla)),
          if (s.masdar != null)
            (bangla ? 'মাসদার' : 'Masdar', s.masdar!,
                s.masdarSource == 'pattern'
                    ? (bangla ? 'ওজন অনুযায়ী' : 'from the form pattern')
                    : (bangla ? 'অভিধান' : 'dictionary')),
          if (!s.isVerb && s.gcase != null)
            (bangla ? 'ই‘রাব' : 'Case', _caseAr(s.gcase!), _caseLabel(s.gcase!, bangla)),
          if (s.prefixes.isNotEmpty)
            (bangla ? 'উপসর্গ' : 'Prefixes', s.prefixes.join(' + '), null),
          if (s.suffixes.isNotEmpty)
            (bangla ? 'প্রত্যয়' : 'Suffixes', s.suffixes.join(' + '), null),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(bangla ? 'সরফ (রূপতত্ত্ব)' : 'Sarf (morphology)'),
            for (final (label, value, hint) in rows)
              _SarfRow(label: label, value: value, hint: hint),
          ],
        );
      },
    );
  }

  static String _posLabel(WordSarf s, bool bn) {
    if (s.special == 'ACT_PCPL') return bn ? 'اسم فاعل · ইসমে ফায়েল' : 'اسم فاعل · active participle';
    if (s.special == 'PASS_PCPL') return bn ? 'اسم مفعول · ইসমে মাফউল' : 'اسم مفعول · passive participle';
    if (s.special == 'VN') return bn ? 'مصدر · মাসদার' : 'مصدر · verbal noun';
    if (s.special == 'PN') return bn ? 'علم · নামবাচক' : 'علم · proper noun';
    return switch (s.posTag) {
      'V' => bn ? 'فعل · ফে‘ল (ক্রিয়া)' : 'فعل · verb',
      'N' => bn ? 'اسم · ইসম (নাম)' : 'اسم · noun',
      _ => bn ? 'حرف · হরফ (অব্যয়)' : 'حرف · particle',
    };
  }

  static String? _sigahLatin(WordSarf s, bool bn) {
    final tense = switch (s.aspect) {
      'PERF' => bn ? 'মাযী (অতীত)' : 'past',
      'IMPF' => bn ? 'মুযারি (বর্তমান/ভবিষ্যৎ)' : 'present/future',
      'IMPV' => bn ? 'আমর (আদেশ)' : 'imperative',
      _ => null,
    };
    if (tense == null) return null;
    final voice = s.voice == 'PASS'
        ? (bn ? 'মাজহুল' : 'passive')
        : (bn ? 'মা‘রূফ' : 'active');
    return '$tense · $voice${s.pgn == null ? '' : ' · ${s.pgn}'}';
  }

  static String _moodAr(String m) => switch (m) {
        'IND' => 'مَرْفُوع', 'SUBJ' => 'مَنْصُوب', 'JUS' => 'مَجْزُوم', _ => m,
      };

  static String _moodLabel(String m, bool bn) => switch (m) {
        'IND' => bn ? 'মারফূ‘' : 'indicative',
        'SUBJ' => bn ? 'মানসূব' : 'subjunctive',
        'JUS' => bn ? 'মাজযূম' : 'jussive',
        _ => m,
      };

  static String _caseAr(String c) => switch (c) {
        'NOM' => 'مَرْفُوع', 'ACC' => 'مَنْصُوب', 'GEN' => 'مَجْرُور', _ => c,
      };

  static String _caseLabel(String c, bool bn) => switch (c) {
        'NOM' => bn ? 'মারফূ‘' : 'nominative',
        'ACC' => bn ? 'মানসূব' : 'accusative',
        'GEN' => bn ? 'মাজরূর' : 'genitive',
        _ => c,
      };
}

class _SarfRow extends StatelessWidget {
  const _SarfRow({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        fontFamily: 'UthmanicHafs', fontSize: 19, height: 1.5)),
                if (hint != null)
                  Text(hint!,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
