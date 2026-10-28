import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/cdn_catalog.dart';
import 'package:quran_app/data/tafsir_repo.dart';

/// The catalog is the contract between the app and the S3 bucket. These
/// checks fail when etl/build.py output is re-uploaded but cdn_catalog.dart
/// is forgotten, or when a tafsir book is added/renamed without a catalog
/// entry.
void main() {
  test('every tafsir book has a downloadable module', () {
    for (final book in tafsirBooks) {
      final module = tafsirModule(book.slug);
      expect(module.fileName, 'tafsir_${book.slug}.db',
          reason: 'slug "${book.slug}" must map to tafsir_${book.slug}.db');
      expect(module.sizeBytes, greaterThan(0));
    }
  });

  test('catalog has 10 tafsirs, the dictionary and the fontpack', () {
    expect(tafsirModules.length, 10);
    expect(downloadableModules.length, 12);
    expect(downloadableModules.containsKey(dictAr.id), isTrue);
    expect(downloadableModules.containsKey(fontpackV4.id), isTrue);
  });

  test('module ids and file names are unique', () {
    expect(
      downloadableModules.values.map((m) => m.id).toSet().length,
      downloadableModules.length,
    );
    expect(
      downloadableModules.values.map((m) => m.fileName).toSet().length,
      downloadableModules.length,
    );
  });

  test('catalog matches the files in assets/ when the repo checkout has them',
      () {
    // The optional files are not bundled anymore, but they still live in the
    // repo so the ETL output can be re-uploaded to the CDN. When present,
    // their size and digest must equal the catalog (and therefore the CDN).
    for (final module in downloadableModules.values) {
      final file = File('assets/${module.path}');
      if (!file.existsSync()) continue; // CI sparse checkout
      expect(file.lengthSync(), module.sizeBytes,
          reason: '${module.fileName}: size differs from cdn_catalog.dart — '
              'the CDN files were updated; refresh the catalog.');
    }
  });

  test('bundled modules are excluded from the downloadable set', () {
    expect(downloadableModules.containsKey(coreDb.id), isFalse);
    expect(downloadableModules.containsKey(audioDb953.id), isFalse);
    expect(downloadableModules.containsKey(audioDb957.id), isFalse);
  });
}
