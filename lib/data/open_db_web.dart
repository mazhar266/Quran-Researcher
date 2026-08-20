import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart';

/// Web: sqlite3 runs as WASM. Requires web/sqlite3.wasm and web/drift_worker.js
/// (from the sqlite3.dart / drift release artifacts). The bundled core.db asset
/// seeds the database on first visit; it persists in OPFS/IndexedDB after that.
Future<QueryExecutor> openCoreDb() async {
  final result = await WasmDatabase.open(
    databaseName: 'quran_core',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
    initializeDatabase: () async {
      final data = await rootBundle.load('assets/db/core.db');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    },
  );
  return result.resolvedExecutor;
}
