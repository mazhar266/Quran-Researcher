import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_db_native.dart' if (dart.library.js_interop) 'open_db_web.dart';

/// core.db is built by etl/build.py and shipped as an asset, so there are no
/// drift table definitions — all access goes through customSelect in the repo.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.e);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (_) async {}, onUpgrade: (_, _, _) async {});
}

final dbProvider = FutureProvider<AppDatabase>((ref) async {
  final executor = await openCoreDb();
  final db = AppDatabase(executor);
  ref.onDispose(db.close);
  return db;
});
