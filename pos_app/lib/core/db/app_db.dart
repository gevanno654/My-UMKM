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

/// Transaksi penjualan (offline-first, sumber utama HP).
///
/// - `number`: nomor struk `<INISIAL><DDMMYYYY><NNNN>`, unik per
///   `(storeId, number)` — server menegakkan hal yang sama.
/// - Harga tercatat snapshot di [SaleItems]; edit harga produk tidak
///   mengubah riwayat.
/// - `status`: 'ok' | 'voided'; void butuh `voidReason`.
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get number => text()();
  IntColumn get total => integer()();
  IntColumn get paid => integer()();
  IntColumn get change => integer().withDefault(const Constant(0))();
  TextColumn get method => text()();
  TextColumn get status => text().withDefault(const Constant('ok'))();
  TextColumn get voidReason => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer().nullable()();
  IntColumn get voidedAt => integer().nullable()();
  IntColumn get dirty => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {storeId, number},
  ];
}

/// Baris item transaksi: snapshot nama + harga saat jual.
class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get price => integer()();
  IntColumn get qty => integer()();
  IntColumn get subtotal => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Keranjang belanja persist (tahan pindah layar + restart HP).
/// Satu baris per (storeId, productId).
class CartLines extends Table {
  TextColumn get storeId => text()();
  TextColumn get productId => text()();
  IntColumn get qty => integer()();

  @override
  Set<Column> get primaryKey => {storeId, productId};
}

@DriftDatabase(tables: [LocalStores, LocalUsers, Products, Sales, SaleItems, CartLines])
class AppDb extends _$AppDb {
  AppDb(super.executor);

  /// Membuka database file produksi (`pos.db`). Async karena
  /// [getApplicationDocumentsDirectory] butuh platform channel.
  static Future<AppDb> openFile() async => AppDb(await openFileDb());

  /// Database in-memory untuk test/widget (tidak menyentuh disk).
  static AppDb openMemory() => AppDb(openMemoryDb());

  @override
  int get schemaVersion => 3;

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
      // v2 → v3: tambah tabel kasir (sales, sale_items, cart_lines).
      if (from <= 2) {
        await m.createTable(sales);
        await m.createTable(saleItems);
        await m.createTable(cartLines);
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

  // ------------------------------------------------------------------
  // Kasir (checkout atomik, void beraudit, keranjang persist, sinkron).
  // ------------------------------------------------------------------

  /// Checkout atomik: insert sale + items, decrement stok tiap produk.
  /// Throw [StateError] bila stok kurang (tidak ada yang berubah).
  Future<void> checkoutSale({
    required SalesCompanion sale,
    required List<SaleItemsCompanion> items,
  }) {
    return transaction(() async {
      for (final item in items) {
        final productId = item.productId.value;
        if (productId == null) continue; // item manual tanpa produk
        final product = await getProduct(productId);
        final qty = item.qty.value;
        if (product == null || product.stock < qty) {
          throw StateError('insufficient stock');
        }
        await (update(products)..where((t) => t.id.equals(productId))).write(
          ProductsCompanion(
            stock: Value(product.stock - qty),
            updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
            dirty: const Value(1),
          ),
        );
      }
      await into(sales).insert(sale.copyWith(dirty: const Value(1)));
      for (final item in items) {
        await into(saleItems).insert(item);
      }
    });
  }

  Future<Sale?> getSale(String id) =>
      (select(sales)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Riwayat transaksi toko, terbaru dulu.
  Future<List<Sale>> salesHistory(String storeId) =>
      (select(sales)
            ..where((t) => t.storeId.equals(storeId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<List<SaleItem>> saleItemsOf(String saleId) =>
      (select(saleItems)..where((t) => t.saleId.equals(saleId))).get();

  /// Void beraudit: status → voided + alasan wajib, stok dikembalikan.
  /// Throw [ArgumentError] bila alasan kosong.
  Future<void> voidSale({
    required String id,
    required String reason,
    required int nowMillis,
  }) {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Alasan void wajib diisi');
    }
    return transaction(() async {
      await (update(sales)..where((t) => t.id.equals(id))).write(
        SalesCompanion(
          status: const Value('voided'),
          voidReason: Value(reason.trim()),
          voidedAt: Value(nowMillis),
          updatedAt: Value(nowMillis),
          dirty: const Value(1),
        ),
      );
      final items = await saleItemsOf(id);
      for (final item in items) {
        final productId = item.productId;
        if (productId == null) continue;
        final product = await getProduct(productId);
        if (product == null) continue; // produk terhapus: stok tak kembali
        await (update(products)..where((t) => t.id.equals(productId))).write(
          ProductsCompanion(
            stock: Value(product.stock + item.qty),
            updatedAt: Value(nowMillis),
            dirty: const Value(1),
          ),
        );
      }
    });
  }

  /// Urutan berikutnya untuk nomor struk pada tanggal `datePrefix`
  /// (format DDMMYYYY): hitung nomor bernomor tsb + 1 (reset harian).
  Future<int> nextReceiptSeq(String storeId, String datePrefix) async {
    final rows = await (select(sales)
          ..where(
            (t) =>
                t.storeId.equals(storeId) &
                t.number.like('%-$datePrefix-%') |
                t.storeId.equals(storeId) & t.number.like('%$datePrefix%'),
          ))
        .get();
    final pattern = RegExp(RegExp.escape(datePrefix) + r'(\d+)$');
    var max = 0;
    for (final row in rows) {
      final m = pattern.firstMatch(row.number);
      if (m != null) {
        final seq = int.tryParse(m.group(1)!) ?? 0;
        if (seq > max) max = seq;
      }
    }
    return max + 1;
  }

  /// Tandai sale sudah tersinkron (push sukses).
  Future<void> markSalesClean(List<String> ids) =>
      (update(sales)..where((t) => t.id.isIn(ids))).write(
        const SalesCompanion(dirty: Value(0)),
      );

  /// Sale kotor milik toko (belum ter-push ke server).
  Future<List<Sale>> dirtySales(String storeId) =>
      (select(sales)
            ..where((t) => t.storeId.equals(storeId) & t.dirty.equals(1))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// Upsert sale dari server (pull): baris server selalu bersih.
  /// Status voided server menang atas ok lokal.
  Future<void> upsertSaleFromServer(SalesCompanion entry) =>
      into(sales).insertOnConflictUpdate(
        entry.copyWith(dirty: const Value(0)),
      );

  Future<void> replaceSaleItems(
    String saleId,
    List<SaleItemsCompanion> items,
  ) {
    return transaction(() async {
      await (delete(saleItems)..where((t) => t.saleId.equals(saleId))).go();
      for (final item in items) {
        await into(saleItems).insert(item);
      }
    });
  }

  // -- Keranjang persist --

  Future<List<CartLine>> getCartLines(String storeId) =>
      (select(cartLines)..where((t) => t.storeId.equals(storeId))).get();

  Future<void> upsertCartLine(CartLinesCompanion entry) =>
      into(cartLines).insertOnConflictUpdate(entry);

  Future<void> removeCartLine(String storeId, String productId) =>
      (delete(cartLines)..where(
            (t) =>
                t.storeId.equals(storeId) & t.productId.equals(productId),
          ))
          .go();

  Future<void> clearCart(String storeId) =>
      (delete(cartLines)..where((t) => t.storeId.equals(storeId))).go();
}

/// Barcode ''/blank → NULL (kolom nullable, bukan Value.absent).
String? _normalizeBarcode(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}
