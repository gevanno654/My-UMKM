import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_db.dart';
import '../auth/auth_provider.dart';
import '../products/products_api.dart';
import '../products/products_provider.dart';
import 'sale_model.dart';
import 'sales_api.dart';

final salesApiProvider = Provider<SalesApi>((ref) => SalesApi());

final salesProvider = NotifierProvider<SalesNotifier, SalesState>(
  SalesNotifier.new,
);

/// Status sinkronisasi manual ke cloud.
enum SyncStatus { idle, syncing, offline, error }

/// Baris keranjang: produk + qty (harga ikut katalog terkini saat bayar).
class CartLineView {
  const CartLineView({required this.productId, required this.qty});

  final String productId;
  final int qty;
}

/// State kasir: keranjang persist + total + riwayat + status sinkron.
class SalesState {
  const SalesState({
    this.cartLines = const [],
    this.catalog = const {},
    this.total = 0,
    this.history = const [],
    this.syncStatus = SyncStatus.idle,
    this.lastError,
  });

  final List<CartLineView> cartLines;
  final Map<String, Product> catalog;
  final int total;
  final List<SaleModel> history;
  final SyncStatus syncStatus;
  final String? lastError;

  SalesState copyWith({
    List<CartLineView>? cartLines,
    Map<String, Product>? catalog,
    int? total,
    List<SaleModel>? history,
    SyncStatus? syncStatus,
    String? Function()? lastError,
  }) => SalesState(
    cartLines: cartLines ?? this.cartLines,
    catalog: catalog ?? this.catalog,
    total: total ?? this.total,
    history: history ?? this.history,
    syncStatus: syncStatus ?? this.syncStatus,
    lastError: lastError == null ? this.lastError : lastError(),
  );
}

/// Orkestrasi kasir offline-first: Drift lokal sumber utama,
/// backend salinan per `store_id` via sinkron manual.
class SalesNotifier extends Notifier<SalesState> {
  static const _uuid = Uuid();

  late final SalesApi _api;
  late final ProductsApi _productsApi;
  late final AppDb _db;

  String _storeId = '';
  String _storeName = '';

  @override
  SalesState build() {
    _api = ref.watch(salesApiProvider);
    _productsApi = ref.watch(productsApiProvider);
    _db = ref.watch(appDbProvider);
    return const SalesState();
  }

  /// Muat keranjang + riwayat toko. Dipanggil sekali per sesi toko.
  Future<void> load(String storeId, {required String storeName}) async {
    _storeId = storeId;
    _storeName = storeName;
    if (_storeId.isEmpty) {
      state = state.copyWith(lastError: () => 'Sesi toko tidak ditemukan.');
      return;
    }
    await _refresh();
  }

  /// Tambah produk ke keranjang (qty +n). Menolak arsip/terhapus/stok kurang.
  Future<String?> addItem(String productId, int qty) =>
      setQty(productId, _qtyOf(productId) + qty);

  /// Ubah qty baris (qty 0 = hapus baris).
  Future<String?> setQty(String productId, int qty) async {
    if (qty < 0) return 'Jumlah tidak valid';
    final product = await _db.getProduct(productId);
    final problem = _problemOf(product);
    if (problem != null) {
      state = state.copyWith(lastError: () => problem);
      return problem;
    }
    if (qty > product!.stock) {
      const msg = 'Stok tidak cukup';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    if (qty == 0) {
      await _db.removeCartLine(_storeId, productId);
    } else {
      await _db.upsertCartLine(
        CartLinesCompanion.insert(
          storeId: _storeId,
          productId: productId,
          qty: qty,
        ),
      );
    }
    await _refresh();
    state = state.copyWith(lastError: () => null);
    return null;
  }

  /// Bayar: validasi ulang katalog, snapshot harga, checkout atomik.
  /// Non-tunai: paid otomatis = total. Mengembalikan null bila sukses.
  Future<String?> checkout({
    required int paid,
    required PayMethod method,
  }) async {
    final lines = state.cartLines;
    if (lines.isEmpty) return 'Keranjang masih kosong';
    // Validasi ulang tiap baris terhadap katalog terkini.
    var total = 0;
    final items = <SaleItemsCompanion>[];
    for (final line in lines) {
      final product = await _db.getProduct(line.productId);
      final problem = _problemOf(product);
      if (problem != null) {
        state = state.copyWith(lastError: () => problem);
        return problem;
      }
      if (line.qty > product!.stock) {
        final msg = '${product.name}: stok tidak cukup (sisa ${product.stock})';
        state = state.copyWith(lastError: () => msg);
        return msg;
      }
      final subtotal = product.sellPrice * line.qty;
      total += subtotal;
      items.add(
        SaleItemsCompanion.insert(
          id: _uuid.v4(),
          saleId: '', // diisi setelah id sale dibuat
          productId: Value(product.id),
          name: product.name,
          price: product.sellPrice,
          costPrice: Value(product.costPrice),
          qty: line.qty,
          subtotal: subtotal,
        ),
      );
    }
    final effectivePaid = method == PayMethod.tunai ? paid : total;
    if (method == PayMethod.tunai && effectivePaid < total) {
      const msg = 'Nominal bayar kurang dari total.';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    final now = DateTime.now();
    final seq = await _db.nextReceiptSeq(_storeId, _datePrefix(now));
    final number = formatReceipt(receiptInitials(_storeName), now, seq);
    final saleId = _uuid.v4();
    final fixedItems = items
        .map((i) => i.copyWith(saleId: Value(saleId)))
        .toList();
    try {
      await _db.checkoutSale(
        sale: SalesCompanion.insert(
          id: saleId,
          storeId: _storeId,
          number: number,
          total: total,
          paid: effectivePaid,
          change: Value(effectivePaid - total),
          method: method.name,
          createdAt: now.toUtc().millisecondsSinceEpoch,
        ),
        items: fixedItems,
      );
    } on StateError {
      const msg = 'Stok tidak cukup. Periksa kembali keranjang.';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    await _db.clearCart(_storeId);
    await _refresh();
    state = state.copyWith(lastError: () => null);
    return null;
  }

  /// Void beraudit: alasan wajib; stok dikembalikan atomik.
  Future<String?> voidSale(String id, String reason) async {
    if (reason.trim().isEmpty) {
      const msg = 'Alasan void wajib diisi';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    try {
      await _db.voidSale(
        id: id,
        reason: reason,
        nowMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } on ArgumentError {
      const msg = 'Alasan void wajib diisi';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    await _refresh();
    state = state.copyWith(lastError: () => null);
    return null;
  }

  /// Sinkron manual: push sale kotor lalu pull dari server.
  /// Void (server) menang atas ok lokal; nomor duplikat → pesan buat ulang.
  Future<void> syncNow({required String accessToken}) async {
    if (_storeId.isEmpty) {
      state = state.copyWith(lastError: () => 'Toko belum dimuat.');
      return;
    }
    state = state.copyWith(syncStatus: SyncStatus.syncing, lastError: () => null);
    String? firstError;
    try {
      await pushSales(accessToken, (e) => firstError ??= e);
      await pullSales(accessToken);
      state = state.copyWith(
        syncStatus: firstError == null ? SyncStatus.idle : SyncStatus.error,
        lastError: () => firstError,
      );
      await _refresh();
    } on DioException catch (e) {
      state = state.copyWith(
        syncStatus: e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionError
            ? SyncStatus.offline
            : SyncStatus.error,
        lastError: () => SalesApi.friendlyError(e),
      );
    } catch (_) {
      state = state.copyWith(
        syncStatus: SyncStatus.error,
        lastError: () => 'Sinkron gagal. Coba lagi.',
      );
    }
  }

  Future<void> pushSales(
    String accessToken,
    void Function(String) onRowError,
  ) async {
    final dirty = await _db.dirtySales(_storeId);
    for (final row in dirty) {
      await pushSingleSale(accessToken, row, onRowError);
    }
  }

  /// Push SATU sale (dipakai sinkron kronologis lintas tipe).
  /// Idempoten: 404 void = sukses, 409 = pesan per baris lalu lanjut.
  Future<void> pushSingleSale(
    String accessToken,
    Sale row,
    void Function(String) onRowError,
  ) async {
    try {
      // Baris voided: kirim pembatalan ke server, bukan POST ulang.
      // 404 (sale belum pernah terkirim) = anggap sukses.
      if (row.status == 'voided') {
        try {
          await _api.voidSale(
            accessToken: accessToken,
            id: row.id,
            reason: row.voidReason ?? 'dibatalkan',
          );
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
        }
        await _db.markSalesClean([row.id]);
        return;
      }
      // Sinkron kasir sekaligus sinkron produk: produk terkait di-push
      // DULU (stok cloud ikut terkini), baru sale di-POST sekali.
      await _pushMissingProducts(accessToken, row.id);
      await _postSale(accessToken, row);
      await _db.markSalesClean([row.id]);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        onRowError(SalesApi.friendlyError(e));
        return;
      }
      rethrow;
    }
  }

  /// POST satu sale kotor ke server.
  Future<void> _postSale(String accessToken, Sale row) async {
    final items = await _db.saleItemsOf(row.id);
    await _api.create(
      accessToken: accessToken,
      id: row.id,
      number: row.number,
      items: items
          .map(
            (i) => SaleItemModel(
              id: i.id,
              productId: i.productId,
              name: i.name,
              price: i.price,
              costPrice: i.costPrice,
              qty: i.qty,
            ),
          )
          .toList(),
      paid: row.paid,
      method: PayMethod.values.byName(row.method),
    );
  }

  /// Push produk-produk dalam sale yang masih dirty (belum ada di server),
  /// lalu tandai bersih. Pola sama dengan ProductsNotifier._push.
  Future<void> _pushMissingProducts(String accessToken, String saleId) async {
    final items = await _db.saleItemsOf(saleId);
    for (final item in items) {
      final productId = item.productId;
      if (productId == null) continue;
      final product = await _db.getProduct(productId);
      if (product == null || product.deletedAt != null) continue;
      final model = product.toModel();
      try {
        try {
          await _productsApi.update(accessToken, model);
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            await _productsApi.create(accessToken, model);
          } else {
            rethrow;
          }
        }
        await _db.markClean([productId]);
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) continue;
        rethrow;
      }
    }
  }

  Future<void> pullSales(String accessToken) async {
    final server = await _api.list(accessToken);
    for (final s in server) {
      final local = await _db.getSale(s.id);
      if (local == null) {
        await _db.upsertSaleFromServer(
          SalesCompanion.insert(
            id: s.id,
            storeId: _storeId,
            number: s.number,
            total: s.total,
            paid: s.paid,
            change: Value(s.change),
            method: s.method.name,
            status: Value(s.status),
            voidReason: Value(s.voidReason),
            createdAt: s.createdAt,
          ),
        );
        await _db.replaceSaleItems(
          s.id,
          s.items
              .map(
                (i) => SaleItemsCompanion.insert(
                  id: i.id,
                  saleId: s.id,
                  productId: Value(i.productId),
                  name: i.name,
                  price: i.price,
                  costPrice: Value(i.costPrice),
                  qty: i.qty,
                  subtotal: i.subtotal,
                ),
              )
              .toList(),
        );
        continue;
      }
      // Void server menang atas ok lokal.
      if (s.isVoided && local.status != 'voided') {
        await _db.upsertSaleFromServer(
          SalesCompanion.insert(
            id: s.id,
            storeId: _storeId,
            number: s.number,
            total: s.total,
            paid: s.paid,
            change: Value(s.change),
            method: s.method.name,
            status: const Value('voided'),
            voidReason: Value(s.voidReason),
            createdAt: local.createdAt,
          ),
        );
        await _db.markSalesClean([s.id]);
      }
    }
  }

  int _qtyOf(String productId) {
    for (final l in state.cartLines) {
      if (l.productId == productId) return l.qty;
    }
    return 0;
  }

  /// Masalah katalog untuk kasir: null/terhapus/arsip → pesan Indonesia.
  String? _problemOf(Product? product) {
    if (product == null || product.deletedAt != null) {
      return 'Produk tidak tersedia (dihapus). Hapus dari keranjang.';
    }
    if (product.isArchived) {
      return '${product.name} diarsipkan. Keluarkan dari keranjang.';
    }
    return null;
  }

  String _datePrefix(DateTime now) =>
      '${now.day.toString().padLeft(2, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.year.toString().padLeft(4, '0')}';

  Future<void> _refresh() async {
    if (_storeId.isEmpty) return;
    final lines = await _db.getCartLines(_storeId);
    final catalog = <String, Product>{};
    var total = 0;
    for (final l in lines) {
      final product = await _db.getProduct(l.productId);
      if (product != null) {
        catalog[l.productId] = product;
        total += product.sellPrice * l.qty;
      }
    }
    final sales = await _db.salesHistory(_storeId);
    final history = <SaleModel>[];
    for (final s in sales) {
      history.add(s.toModel(await _db.saleItemsOf(s.id)));
    }
    state = state.copyWith(
      cartLines: lines
          .map((l) => CartLineView(productId: l.productId, qty: l.qty))
          .toList(),
      catalog: catalog,
      total: total,
      history: history,
    );
  }
}
