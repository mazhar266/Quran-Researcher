import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cdn_catalog.dart';

/// Bundled modules (core.db, the two audio-timing DBs) ship inside the app
/// and are copied to the app support dir on first use, or when the bundled
/// version's size changes. Every other module in the catalog is downloaded
/// on demand and opened straight from its downloaded file — or, if it hasn't
/// been downloaded yet, throws [ModuleNotDownloadedException], which the UI
/// turns into the download prompt.
Future<QueryExecutor> openModuleDb(String name) async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, name));

  final bundled = name == coreDb.fileName ||
      name == audioDb953.fileName ||
      name == audioDb957.fileName;

  if (bundled) {
    final data = await rootBundle.load('assets/db/$name');
    if (!file.existsSync() || file.lengthSync() != data.lengthInBytes) {
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
  } else if (!file.existsSync()) {
    throw ModuleNotDownloadedException(name);
  }
  return NativeDatabase.createInBackground(file);
}

Future<QueryExecutor> openCoreDb() => openModuleDb('core.db');
