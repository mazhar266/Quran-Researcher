import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies a bundled module database to the app support dir on first use (or
/// when the bundled version's size changes) and opens it there.
Future<QueryExecutor> openModuleDb(String name) async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, name));
  final data = await rootBundle.load('assets/db/$name');
  if (!file.existsSync() || file.lengthSync() != data.lengthInBytes) {
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }
  return NativeDatabase.createInBackground(file);
}

Future<QueryExecutor> openCoreDb() => openModuleDb('core.db');
