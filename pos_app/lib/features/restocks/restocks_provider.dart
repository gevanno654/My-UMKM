import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_db.dart';
import '../auth/auth_provider.dart';
import '../products/products_api.dart';
import '../products/products_provider.dart';
import 'restocks_api.dart';

export '../products/products_api.dart' show ProductRowX;final restocksApiProvider = Provider<RestocksApi>((ref) => RestocksApi());

final restocksProvider =
    NotifierProvider<RestocksNotifier, RestocksState>(RestocksNotifier.new);

/// Model domain restock (penerimaan kulakan).
///
/// Uang = INTEGER rupiah. Waktu = millis UTC epoch.
class RestockModel {
  const RestockModel({
    required this.id,
    required this.storeId,
    required this.total,
    this.status = 'ok',
    this.voidReason,
    required this.createdAt,
    this.items = const [],
  });

  final String id;
  final String storeId;
  final int total;
  final String status;
  final String? voidReason;
  final int createdAt;
  final List<RestockItemModel> items;

  bool get isVoided => status == 'voided';
}

/// Baris item penerimaan: snapshot nama + harga beli saat kulakan.
/// `sellPrice` null = harga jual katalog tidak diubah.
class RestockItemModel {
  const RestockItemModel({
    required this.id,
    this.productId,
    required this.name,
    required this.qty,
    required this.costPrice,
    this.sellPrice,
  });

  final String id;
  final String? productId;
  final String name;
  final int qty;
  final int costPrice;
  final int? sellPrice;

  int get subtotal => qty * costPrice;
}

/// Status sinkronisasi manual ke cloud.
enum SyncStatus { idle, syncing, offline, error }

/// Satu baris draft kulakan di memori (belum disimpan).
/// v1: qty + harga beli saja. Opsi ubah harga jual dihapus sementara
/// (harga jual diubah via Kelola Produk); batch/FIFO direncanakan v2.
class RestockDraftLine {
  const RestockDraftLine({
    required this.productId,
    required this.qty,
    required this.costPrice,
  });

  final String productId;
  final int qty;
  final int costPrice;

  int get subtotal => qty * costPrice;

  RestockDraftLine copyWith({
    int? qty,
    int? costPrice,
  }) =>
      RestockDraftLine(
        productId: productId,
        qty: qty ?? this.qty,
        costPrice: costPrice ?? this.costPrice,
      );
}

/// State restock: draft di memori + riwayat + status sinkron.
class RestocksState {
  const RestocksState({
    this.draftLines = const [],
    this.draftTotalModal = 0,
    this.history = const [],
    this.syncStatus = SyncStatus.idle,
    this.lastError,
  });

  final List<RestockDraftLine> draftLines;
  final int draftTotalModal;
  final List<RestockModel> history;
  final SyncStatus syncStatus;
  final String? lastError;

  RestocksState copyWith({
    List<RestockDraftLine>? draftLines,
    int? draftTotalModal,
    List<RestockModel>? history,
    SyncStatus? syncStatus,
    String? Function()? lastError,
  }) =>
      RestocksState(
        draftLines: draftLines ?? this.draftLines,
        draftTotalModal: draftTotalModal ?? this.draftTotalModal,
        history: history ?? this.history,
        syncStatus: syncStatus ?? this.syncStatus,
        lastError: lastError == null ? this.lastError : lastError(),
      );
}

/// Orkestrasi restock offline-first: draft di memori, simpan atomik via
/// `AppDb.saveRestockFull` (DB yang update stok + harga katalog),
/// backend salinan per `store_id` via sinkron manual.
class RestocksNotifier extends Notifier<RestocksState> {
  static const _uuid = Uuid();

  late final RestocksApi _api;
  late final ProductsApi _productsApi;
  late final AppDb _db;

  String _storeId = '';

  @override
  RestocksState build() {
    _api = ref.watch(restocksApiProvider);
    _productsApi = ref.watch(productsApiProvider);
    _db = ref.watch(appDbProvider);
    return const RestocksState();
  }

  /// Muat riwayat toko. Dipanggil sekali per sesi toko.
  Future<void> load(String storeId) async {
    _storeId = storeId;
    if (_storeId.isEmpty) {
      state = state.copyWith(lastError: () => 'Sesi toko tidak ditemukan.');
      return;
    }
    await _refresh();
  }

  /// Tambah produk ke draft (produk sama → gabung: qty dijumlah,
  /// harga terakhir menang).
  Future<String?> addToDraft(String productId, {int qty = 1}) async {
    if (qty < 1) return 'Jumlah minimal 1';
    final product = await _db.getProduct(productId);
    final problem = _problemOf(product);
    if (problem != null) {
      state = state.copyWith(lastError: () => problem);
      return problem;
    }
    final existing = _lineOf(productId);
    final lines = List<RestockDraftLine>.from(state.draftLines);
    if (existing == null) {
      lines.add(
        RestockDraftLine(
          productId: productId,
          qty: qty,
          costPrice: product!.costPrice,
        ),
      );
    } else {
      lines[lines.indexOf(existing)] = existing.copyWith(
        qty: existing.qty + qty,
        costPrice: product!.costPrice,
      );
    }
    _setDraft(lines);
    state = state.copyWith(lastError: () => null);
    return null;
  }

  /// Ubah qty baris draft (qty 0 = hapus baris).
  Future<String?> setDraftQty(String productId, int qty) async {
    if (qty < 0) return 'Jumlah tidak valid';
    final existing = _lineOf(productId);
    if (existing == null) return 'Baris tidak ada di draft';
    final lines = List<RestockDraftLine>.from(state.draftLines);
    if (qty == 0) {
      lines.remove(existing);
    } else {
      lines[lines.indexOf(existing)] = existing.copyWith(qty: qty);
    }
    _setDraft(lines);
    state = state.copyWith(lastError: () => null);
    return null;
  }

  /// Ubah harga beli baris draft. Dipanggil live dari UI (`onChanged`),
  /// jadi nilai selalu masuk state walau user tidak menekan enter.
  Future<String?> setDraftPrices(
    String productId, {
    int? costPrice,
  }) async {
    if (costPrice != null && (costPrice < 0 || costPrice > 999999999)) {
      return 'Harga beli harus angka 0..999999999';
    }
    final existing = _lineOf(productId);
    if (existing == null) return 'Baris tidak ada di draft';
    final lines = List<RestockDraftLine>.from(state.draftLines);
    lines[lines.indexOf(existing)] = existing.copyWith(
      costPrice: costPrice,
    );
    _setDraft(lines);
    state = state.copyWith(lastError: () => null);
    return null;
  }

  Future<void> removeFromDraft(String productId) async {
    final existing = _lineOf(productId);
    if (existing == null) return;
    final lines = List<RestockDraftLine>.from(state.draftLines)
      ..remove(existing);
    _setDraft(lines);
  }

  void clearDraft() {
    state = state.copyWith(draftLines: [], draftTotalModal: 0);
  }

  /// Simpan draft sebagai penerimaan: validasi ulang katalog, tulis atomik.
  /// Mengembalikan null bila sukses, pesan error bila gagal.
  Future<String?> saveRestock() async {
    final lines = state.draftLines;
    if (lines.isEmpty) {
      const msg = 'Draft masih kosong. Tambah produk dulu.';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    for (final line in lines) {
      final product = await _db.getProduct(line.productId);
      final problem = _problemOf(product);
      if (problem != null) {
        state = state.copyWith(lastError: () => problem);
        return problem;
      }
      if (line.qty < 1) {
        const msg = 'Jumlah minimal 1';
        state = state.copyWith(lastError: () => msg);
        return msg;
      }
      if (line.costPrice < 0 || line.costPrice > 999999999) {
        const msg = 'Harga beli harus angka 0..999999999';
        state = state.copyWith(lastError: () => msg);
        return msg;
      }
    }
    final restockId = _uuid.v4();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final items = <RestockItemsCompanion>[];
    var total = 0;
    for (final line in lines) {
      final product = (await _db.getProduct(line.productId))!;
      final subtotal = line.qty * line.costPrice;
      total += subtotal;
      items.add(
        RestockItemsCompanion.insert(
          id: _uuid.v4(),
          restockId: restockId,
          productId: Value(line.productId),
          name: product.name,
          qty: line.qty,
          costPrice: line.costPrice,
          sellPrice: const Value.absent(),
          subtotal: subtotal,
        ),
      );
    }
    try {
      await _db.saveRestockFull(
        restock: RestocksCompanion.insert(
          id: restockId,
          storeId: _storeId,
          total: total,
          createdAt: now,
        ),
        items: items,
      );
    } on StateError {
      const msg = 'Produk tidak tersedia. Periksa kembali draft.';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    clearDraft();
    await _refresh();
    state = state.copyWith(lastError: () => null);
    return null;
  }

  /// Batal beraudit: alasan wajib; stok dikembalikan atomik.
  Future<String?> voidRestock(String id, String reason) async {
    if (reason.trim().isEmpty) {
      const msg = 'Alasan batal wajib diisi';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    try {
      await _db.voidRestock(
        id: id,
        reason: reason,
        nowMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } on ArgumentError {
      const msg = 'Alasan batal wajib diisi';
      state = state.copyWith(lastError: () => msg);
      return msg;
    } on StateError {
      const msg = 'Stok tidak cukup untuk membatalkan (sudah terjual).';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    await _refresh();
    state = state.copyWith(lastError: () => null);
    return null;
  }

  /// Sinkron manual: push restock kotor lalu pull dari server.
  /// Void (server) menang atas ok lokal.
  Future<void> syncNow({required String accessToken}) async {
    if (_storeId.isEmpty) {
      state = state.copyWith(lastError: () => 'Toko belum dimuat.');
      return;
    }
    state = state.copyWith(
      syncStatus: SyncStatus.syncing,
      lastError: () => null,
    );
    String? firstError;
    try {
      await _push(accessToken, (e) => firstError ??= e);
      await _pull(accessToken);
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
        lastError: () => RestocksApi.friendlyError(e),
      );
    } catch (_) {
      state = state.copyWith(
        syncStatus: SyncStatus.error,
        lastError: () => 'Sinkron gagal. Coba lagi.',
      );
    }
  }

  Future<void> _push(
    String accessToken,
    void Function(String) onRowError,
  ) async {
    final dirty = await _db.dirtyRestocks(_storeId);
    for (final row in dirty) {
      try {
        // Baris voided: kirim pembatalan ke server, bukan POST ulang dokumen.
        // 404 (restock belum pernah terkirim) = anggap sukses; 409 stok
        // kurang di server = pesan jelas.
        if (row.status == 'voided') {
          try {
            await _api.voidRestock(
              accessToken: accessToken,
              id: row.id,
              reason: row.voidReason ?? 'dibatalkan',
            );
          } on DioException catch (e) {
            if (e.response?.statusCode == 404) {
              // Belum pernah terkirim: tidak ada yang perlu dibatalkan.
            } else {
              rethrow;
            }
          }
          await _db.markRestocksClean([row.id]);
          continue;
        }
        // Sinkron restock sekaligus sinkron produk: produk terkait di-push
        // DULU (stok cloud ikut terkini), baru restock di-POST sekali.
        // Bila ada produk gagal push (mis. barcode bentrok), restock tidak
        // dipaksa terkirim — user perbaiki dulu di Kelola Produk.
        final productError = await _pushMissingProducts(accessToken, row.id);
        if (productError != null) {
          onRowError(productError);
          continue;
        }
        await _postRestock(accessToken, row.id);
        await _db.markRestocksClean([row.id]);
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          onRowError(RestocksApi.friendlyError(e));
          continue;
        }
        rethrow;
      }
    }
  }

  /// POST satu restock kotor ke server.
  Future<void> _postRestock(String accessToken, String restockId) async {
    final items = await _db.restockItemsOf(restockId);
    await _api.create(
      accessToken: accessToken,
      id: restockId,
      items: items
          .map(
            (i) => RestockItemModel(
              id: i.id,
              productId: i.productId,
              name: i.name,
              qty: i.qty,
              costPrice: i.costPrice,
              sellPrice: i.sellPrice,
            ),
          )
          .toList(),
    );
  }

  /// Push produk-produk dalam restock yang dirty, lalu tandai bersih.
  /// Mengembalikan pesan error Indonesia bila ada produk gagal push
  /// (null bila semua ok / tidak ada yang perlu di-push).
  /// Pola sama dengan SalesNotifier._pushMissingProducts.
  Future<String?> _pushMissingProducts(
    String accessToken,
    String restockId,
  ) async {
    final items = await _db.restockItemsOf(restockId);
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
        if (e.response?.statusCode == 409) {
          return ProductsApi.friendlyError(e);
        }
        rethrow;
      }
    }
    return null;
  }

  Future<void> _pull(String accessToken) async {
    final server = await _api.list(accessToken);
    for (final s in server) {
      final local = await _db.getRestock(s.id);
      if (local == null) {
        await _db.upsertRestockFromServer(
          RestocksCompanion.insert(
            id: s.id,
            storeId: _storeId,
            total: s.total,
            status: Value(s.status),
            voidReason: Value(s.voidReason),
            createdAt: s.createdAt,
          ),
        );
        await _db.replaceRestockItems(
          s.id,
          s.items
              .map(
                (i) => RestockItemsCompanion.insert(
                  id: i.id,
                  restockId: s.id,
                  productId: Value(i.productId),
                  name: i.name,
                  qty: i.qty,
                  costPrice: i.costPrice,
                  sellPrice: Value(i.sellPrice),
                  subtotal: i.qty * i.costPrice,
                ),
              )
              .toList(),
        );
        continue;
      }
      // Void server menang atas ok lokal.
      if (s.status == 'voided' && local.status != 'voided') {
        await _db.upsertRestockFromServer(
          RestocksCompanion.insert(
            id: s.id,
            storeId: _storeId,
            total: local.total,
            status: const Value('voided'),
            voidReason: Value(s.voidReason),
            createdAt: local.createdAt,
          ),
        );
        await _db.markRestocksClean([s.id]);
      }
    }
  }

  RestockDraftLine? _lineOf(String productId) {
    for (final l in state.draftLines) {
      if (l.productId == productId) return l;
    }
    return null;
  }

  void _setDraft(List<RestockDraftLine> lines) {
    final total = lines.fold<int>(0, (sum, l) => sum + l.subtotal);
    state = state.copyWith(draftLines: lines, draftTotalModal: total);
  }

  /// Masalah katalog untuk restock: null/terhapus/arsip → pesan Indonesia.
  String? _problemOf(Product? product) {
    if (product == null || product.deletedAt != null) {
      return 'Produk tidak tersedia (dihapus). Hapus dari draft.';
    }
    if (product.isArchived) {
      return '${product.name} diarsipkan. Keluarkan dari draft.';
    }
    return null;
  }

  Future<void> _refresh() async {
    if (_storeId.isEmpty) return;
    final rows = await _db.restocksHistory(_storeId);
    final history = <RestockModel>[];
    for (final r in rows) {
      history.add(
        RestockModel(
          id: r.id,
          storeId: r.storeId,
          total: r.total,
          status: r.status,
          voidReason: r.voidReason,
          createdAt: r.createdAt,
          items: (await _db.restockItemsOf(r.id))
              .map(
                (i) => RestockItemModel(
                  id: i.id,
                  productId: i.productId,
                  name: i.name,
                  qty: i.qty,
                  costPrice: i.costPrice,
                  sellPrice: i.sellPrice,
                ),
              )
              .toList(),
        ),
      );
    }
    state = state.copyWith(history: history);
  }
}
