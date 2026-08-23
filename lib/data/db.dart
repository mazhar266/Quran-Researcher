import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_db_native.dart' if (dart.library.js_interop) 'open_db_web.dart';

/// core.db is built by etl/build.py and shipped as an asset, so there are no
/// drift table definitions — all access goes through customSelect in the repo.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.e) {
    // Disable the warning about multiple instances since we intentionally
    // reuse this class for multiple read-only module databases.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) async {},
        onUpgrade: (_, _, _) async {},
        beforeOpen: (_) async {
          // All app databases are prebuilt by the ETL and never written at
          // runtime, so tune for read-only access:
          //  - query_only also guards against accidental writes
          //  - mmap serves pages straight from the OS page cache
          //  - a 16 MiB page cache covers hot tables (words, ayah_text, FTS)
          //  - temp_store keeps sort/FTS scratch space off disk
          // On web (WASM/OPFS) mmap is a harmless no-op; the rest applies.
          await customStatement('PRAGMA query_only = ON');
          await customStatement('PRAGMA mmap_size = 268435456');
          await customStatement('PRAGMA cache_size = -16384');
          await customStatement('PRAGMA temp_store = MEMORY');
        },
      );
}

final dbProvider = FutureProvider<AppDatabase>((ref) async {
  final executor = await openCoreDb();
  final db = AppDatabase(executor);
  ref.onDispose(db.close);
  return db;
});

/// Lazily opened module databases (tafsir books, reciter audio), keyed by
/// file name, e.g. 'tafsir_en-tafisr-ibn-kathir.db'. Kept open once used.
final moduleDbProvider =
    FutureProvider.family<AppDatabase, String>((ref, name) async {
  final db = AppDatabase(await openModuleDb(name));
  ref.onDispose(db.close);
  ref.keepAlive();
  return db;
});
