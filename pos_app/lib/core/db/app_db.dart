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

/// Produk warung (offline-first, SQLite HP sumber utama).
///
/// - `id`: UUID v4 lokal, juga dipakai sebagai PK server (tanpa serverId).
/// - `barcode` NULL = tanpa barcode; unik per `(storeId, barcode)` bila
///   non-null (SQLite mengizinkan banyak NULL dalam UNIQUE index).
/// - Uang = INTEGER rupiah. Waktu = millis UTC epoch.
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  IntColumn get costPrice => integer()();
  IntColumn get sellPrice => integer()();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get photoPath => text().withDefault(const Constant(''))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get dirty => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {storeId, barcode},
  ];
}

@DriftDatabase(tables: [LocalStores, LocalUsers, Products])
class AppDb extends _$AppDb {
  AppDb(super.executor);

  /// Membuka database file produksi (`pos.db`). Async karena
  /// [getApplicationDocumentsDirectory] butuh platform channel.
  static Future<AppDb> openFile() async => AppDb(await openFileDb());

  /// Database in-memory untuk test/widget (tidak menyentuh disk).
  static AppDb openMemory() => AppDb(openMemoryDb());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v1 → v2: tambah tabel products (data auth dipertahankan).
      if (from == 1) {
        await m.createTable(products);
      }
    },
  );

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

  // ------------------------------------------------------------------
  // Produk (offline CRUD lokal).
  // ------------------------------------------------------------------

  /// Insert/update baris produk. Barcode '' dinormalisasi ke NULL agar tidak
  /// bentrok unique `(storeId, barcode)`. Setiap tulis lokal → `dirty = 1`.
  Future<void> upsertProduct(ProductsCompanion entry) {
    final normalized = entry.copyWith(
      barcode: entry.barcode.present
          ? Value(_normalizeBarcode(entry.barcode.value))
          : const Value.absent(),
      dirty: const Value(1),
    );
    return into(products).insertOnConflictUpdate(normalized);
  }

  Future<Product?> getProduct(String id) =>
      (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Daftar aktif: tanpa soft-delete + tanpa arsip, `updatedAt DESC`.
  Stream<List<Product>> watchActiveProducts(String storeId) {
    final query = select(products)
      ..where(
        (t) =>
            t.storeId.equals(storeId) &
            t.deletedAt.isNull() &
            t.isArchived.equals(false),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
  }

  /// Daftar arsip: tanpa soft-delete + hanya arsip, `updatedAt DESC`.
  Stream<List<Product>> watchArchivedProducts(String storeId) {
    final query = select(products)
      ..where(
        (t) =>
            t.storeId.equals(storeId) &
            t.deletedAt.isNull() &
            t.isArchived.equals(true),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
  }

  /// Cari di satu toko: nama LIKE (case-insensitive) ATAU barcode exact.
  /// Baris soft-delete selalu disembunyikan.
  Future<List<Product>> searchProducts(String storeId, String query) {
    final q = query.trim();
    if (q.isEmpty) return Future.value(const []);
    final lowered = '%${q.toLowerCase()}%';
    return (select(products)..where(
          (t) =>
              t.storeId.equals(storeId) &
              t.deletedAt.isNull() &
              (t.name.lower().like(lowered) | t.barcode.equals(q)),
        ))
        .get();
  }

  /// Soft delete: set `deletedAt` + `dirty = 1` (tersinkron ke server).
  Future<void> softDeleteProduct(String id, int nowMillis) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(
          deletedAt: Value(nowMillis),
          updatedAt: Value(nowMillis),
          dirty: const Value(1),
        ),
      );

  /// Arsip / kembalikan dari arsip + `dirty = 1`.
  Future<void> archiveProduct(String id, bool archived) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(
          isArchived: Value(archived),
          updatedAt: Value(
            DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
          dirty: const Value(1),
        ),
      );

  /// Tandai baris sudah tersinkron (push sukses).
  Future<void> markClean(List<String> ids) =>
      (update(products)..where((t) => t.id.isIn(ids))).write(
        const ProductsCompanion(dirty: Value(0)),
      );

  /// Baris kotor milik toko (belum ter-push ke server), `updatedAt` menanjak.
  Future<List<Product>> dirtyProducts(String storeId) =>
      (select(products)
            ..where(
              (t) => t.storeId.equals(storeId) & t.dirty.equals(1),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]))
          .get();
}

/// Barcode ''/blank → NULL (kolom nullable, bukan Value.absent).
String? _normalizeBarcode(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}
