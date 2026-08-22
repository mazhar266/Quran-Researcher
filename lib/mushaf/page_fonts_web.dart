import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;

Archive? _archive;

/// Web: no filesystem — fetch the zip asset once (browser-cached) and keep
/// the decoded index in memory; individual page fonts decompress on demand.
Future<ByteData> pageFontBytes(int page) async {
  if (_archive == null) {
    final data = await rootBundle.load('assets/fontpack_v1.zip');
    _archive = ZipDecoder().decodeBytes(Uint8List.view(
        data.buffer, data.offsetInBytes, data.lengthInBytes));
  }
  final file = _archive!.files.firstWhere(
    (f) => f.name == 'p$page.ttf',
    orElse: () => throw StateError('p$page.ttf missing from fontpack'),
  );
  final bytes = file.content as List<int>;
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}
