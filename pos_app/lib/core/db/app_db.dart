import 'package:drift/drift.dart';

import 'open_db.dart';

part 'app_db.g.dart';

/// Cache toko dari server. Satu baris per `store_id` server.
class LocalStores extends Table {
  TextColumn get serverId => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {serverId};
}

/// Cache user pemilik dari server.
class LocalUsers extends Table {
  TextColumn get serverId => text()();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  TextColumn get email => text()();

  @override
  Set<Column> get primaryKey => {serverId};
}

@DriftDatabase(tables: [LocalStores, LocalUsers])
class AppDb extends _$AppDb {
  AppDb(super.executor);

  /// Membuka database file produksi (`pos.db`). Async karena
  /// [getApplicationDocumentsDirectory] butuh platform channel.
  static Future<AppDb> openFile() async => AppDb(await openFileDb());

  /// Database in-memory untuk test/widget (tidak menyentuh disk).
  static AppDb openMemory() => AppDb(openMemoryDb());

  @override
  int get schemaVersion => 1;

  Future<void> upsertStore(LocalStoresCompanion entry) =>
      into(localStores).insertOnConflictUpdate(entry);

  Future<LocalStore?> getStore(String serverId) =>
      (select(localStores)..where((t) => t.serverId.equals(serverId)))
          .getSingleOrNull();

  Future<void> upsertUser(LocalUsersCompanion entry) =>
      into(localUsers).insertOnConflictUpdate(entry);

  Future<LocalUser?> getUser(String serverId) =>
      (select(localUsers)..where((t) => t.serverId.equals(serverId)))
          .getSingleOrNull();
}
