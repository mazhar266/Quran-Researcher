import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart';

import 'cdn_catalog.dart';
import 'cdn_fetch.dart';

/// Web: sqlite3 runs as WASM. Requires web/sqlite3.wasm and web/drift_worker.js
/// (from the sqlite3.dart / drift release artifacts). Each database persists
/// in OPFS/IndexedDB after first use. Bundled modules seed from the app
/// asset; on-demand modules (tafsirs, dictionary) seed by downloading from
/// the Hikmah CDN — which needs the bucket to send CORS headers.
Future<QueryExecutor> openModuleDb(String name) async {
  final result = await WasmDatabase.open(
    databaseName: name.replaceAll('.db', ''),
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
    initializeDatabase: () async {
      // On-demand modules seed from the CDN (needs bucket CORS headers);
      // bundled ones (core, audio timings) seed from the app asset.
      CdnModule? onDemand;
      for (final m in downloadableModules.values) {
        if (m.fileName == name) onDemand = m;
      }
      if (onDemand != null) return fetchCdnModuleBytes(onDemand);
      final data = await rootBundle.load('assets/db/$name');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    },
  );
  return result.resolvedExecutor;
}

Future<QueryExecutor> openCoreDb() => openModuleDb('core.db');
