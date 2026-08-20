import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _asset = 'assets/db/core.db';

/// Copies the bundled core.db to the app support dir on first launch (or when
/// the bundled version's size changes) and opens it there.
Future<QueryExecutor> openCoreDb() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'core.db'));
  final data = await rootBundle.load(_asset);
  if (!file.existsSync() || file.lengthSync() != data.lengthInBytes) {
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }
  return NativeDatabase.createInBackground(file);
}
