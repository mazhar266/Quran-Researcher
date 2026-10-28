import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/cdn_catalog.dart';
import '../data/cdn_fetch.dart';

Archive? _archive;

/// Web: no filesystem — fetch the fontpack zip from the CDN once (68 MB,
/// browser-cached) and keep the decoded index in memory; individual page
/// fonts decompress on demand.
Future<ByteData> pageFontBytes(int page) async {
  if (_archive == null) {
    final bytes = await fetchCdnModuleBytes(fontpackV4);
    _archive = ZipDecoder().decodeBytes(bytes);
  }
  final file = _archive!.files.firstWhere(
    (f) => f.name == 'p$page.ttf',
    orElse: () => throw StateError('p$page.ttf missing from fontpack'),
  );
  final bytes = file.content as List<int>;
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}
