import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show ByteData;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/cdn_catalog.dart';

/// The 604 QPC V4 page fonts come as one zip, downloaded on demand from the
/// Hikmah CDN (see downloads.dart). On native platforms it is extracted to
/// app storage once (~161 MB) so per-page loads are plain file reads and the
/// zip bytes don't stay in memory.
Future<ByteData> pageFontBytes(int page) async {
  final dir = await getApplicationSupportDirectory();
  final fontsDir = Directory(p.join(dir.path, 'mushaf_fonts_v4'));
  final file = File(p.join(fontsDir.path, 'p$page.ttf'));
  if (!file.existsSync()) {
    await _extractAll(dir, fontsDir);
  }
  final bytes = await file.readAsBytes();
  return ByteData.view(bytes.buffer);
}

Future<void> _extractAll(Directory supportDir, Directory fontsDir) async {
  final zip = File(p.join(supportDir.path, fontpackV4.fileName));
  if (!zip.existsSync()) {
    throw const ModuleNotDownloadedException('fontpack_v4.zip');
  }
  final archive =
      ZipDecoder().decodeBytes(await zip.readAsBytes());
  fontsDir.createSync(recursive: true);
  for (final f in archive.files) {
    if (f.isFile) {
      File(p.join(fontsDir.path, p.basename(f.name)))
          .writeAsBytesSync(f.content as List<int>);
    }
  }
}
