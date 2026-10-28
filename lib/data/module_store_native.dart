import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cdn_catalog.dart';
import 'cdn_fetch.dart';

/// Native storage for on-demand modules. Everything lives in the app support
/// directory — the same place `openModuleDb` copies bundled databases to — so
/// a downloaded module is simply "already there" when a module db is opened.

Future<Directory> _supportDir() async => getApplicationSupportDirectory();

Future<File> moduleFile(String fileName) async =>
    File(p.join((await _supportDir()).path, fileName));

/// The directory the fontpack zip extracts to (see page_fonts_native.dart).
Future<Directory> fontpackExtractDir() async =>
    Directory(p.join((await _supportDir()).path, 'mushaf_fonts_v4'));

/// Maps fileName → byte size for every catalog module already on disk.
Future<Map<String, int>> scanInstalledModules() async {
  final result = <String, int>{};
  for (final m in downloadableModules.values) {
    final file = await moduleFile(m.fileName);
    if (await file.exists()) result[m.fileName] = await file.length();
  }
  return result;
}

/// Streams [module] to `<file>.part`, verifies it, then atomically renames.
/// [isCancelled] is polled between chunks — see downloads.dart's cancel.
Future<void> downloadModuleToFile(
  CdnModule module, {
  void Function(int received, int total)? onProgress,
  bool Function()? isCancelled,
}) async {
  final target = await moduleFile(module.fileName);
  final part = File('${target.path}.part');
  final sink = part.openWrite();
  try {
    await streamCdnModule(
      module,
      onChunk: sink.add,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    await sink.flush();
    await sink.close();
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
  } catch (_) {
    // Leave no partial file behind on cancel or failure.
    await sink.close().catchError((_) {});
    if (await part.exists()) await part.delete();
    rethrow;
  }
}

Future<void> deleteModuleFiles(CdnModule module) async {
  final target = await moduleFile(module.fileName);
  if (await target.exists()) await target.delete();
  final part = File('${target.path}.part');
  if (await part.exists()) await part.delete();
  if (module.id == fontpackV4.id) {
    final dir = await fontpackExtractDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
