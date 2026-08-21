import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart';

/// Web: sqlite3 runs as WASM. Requires web/sqlite3.wasm and web/drift_worker.js
/// (from the sqlite3.dart / drift release artifacts). The bundled asset seeds
/// each database on first use; it persists in OPFS/IndexedDB after that, so
/// module assets are only fetched over the network once.
Future<QueryExecutor> openModuleDb(String name) async {
  final result = await WasmDatabase.open(
    databaseName: name.replaceAll('.db', ''),
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
    initializeDatabase: () async {
      final data = await rootBundle.load('assets/db/$name');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    },
  );
  return result.resolvedExecutor;
}

Future<QueryExecutor> openCoreDb() => openModuleDb('core.db');
