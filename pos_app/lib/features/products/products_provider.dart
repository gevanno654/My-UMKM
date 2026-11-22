import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_db.dart';
import '../auth/auth_provider.dart';
import 'product_model.dart';
import 'products_api.dart';

final productsApiProvider = Provider<ProductsApi>((ref) => ProductsApi());

final productsProvider =
    NotifierProvider<ProductsNotifier, ProductsState>(ProductsNotifier.new);

/// Status sinkronisasi manual ke cloud.
enum SyncStatus { idle, syncing, offline, error }

/// State daftar produk: hasil query lokal + status sinkron.
class ProductsState {
  const ProductsState({
    this.products = const [],
    this.query = '',
    this.showArchived = false,
    this.loading = false,
    this.syncStatus = SyncStatus.idle,
    this.lastError,
  });

  final List<ProductModel> products;
  final String query;
  final bool showArchived;
  final bool loading;
  final SyncStatus syncStatus;
  final String? lastError;

  bool get isLoading => loading || syncStatus == SyncStatus.syncing;

  ProductsState copyWith({
    List<ProductModel>? products,
    String? query,
    bool? showArchived,
    bool? loading,
    SyncStatus? syncStatus,
    String? Function()? lastError,
  }) =>
      ProductsState(
        products: products ?? this.products,
        query: query ?? this.query,
        showArchived: showArchived ?? this.showArchived,
        loading: loading ?? this.loading,
        syncStatus: syncStatus ?? this.syncStatus,
        lastError: lastError == null ? this.lastError : lastError(),
      );
}

/// Orkestrasi produk offline-first: Drift lokal sebagai sumber utama,
/// backend sebagai salinan per `store_id` via sinkron manual.
class ProductsNotifier extends Notifier<ProductsState> {
  static const _uuid = Uuid();

  late final ProductsApi _api;
  late final AppDb _db;

  String _storeId = '';

  @override
  ProductsState build() {
    _api = ref.watch(productsApiProvider);
    _db = ref.watch(appDbProvider);
    return const ProductsState();
  }

  /// Muat daftar awal untuk toko. Dipanggil sekali per sesi toko.
  Future<void> load(String storeId) async {
    _storeId = storeId;
    if (_storeId.isEmpty) {
      state = state.copyWith(
        loading: false,
        lastError: () => 'Sesi toko tidak ditemukan. Login ulang.',
      );
      return;
    }
    state = state.copyWith(loading: true, lastError: () => null);
    try {
      await _refreshList();
      state = state.copyWith(loading: false);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        lastError: () => 'Gagal memuat produk. Coba lagi.',
      );
    }
  }

  Future<void> setQuery(String query) async {
    state = state.copyWith(query: query);
    await _refreshList();
  }

  Future<void> toggleArchived(bool show) async {
    state = state.copyWith(showArchived: show);
    await _refreshList();
  }

  /// Simpan (insert/update) produk secara lokal + validasi.
  /// Mengembalikan null bila sukses, atau pesan error.
  Future<String?> saveProduct(ProductModel p) async {
    final error = ProductModel.validate(
      name: p.name,
      costPrice: p.costPrice,
      sellPrice: p.sellPrice,
      stock: p.stock,
      category: p.category,
    );
    if (error != null) {
      state = state.copyWith(lastError: () => error);
      return error;
    }
    try {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final existing = await _db.getProduct(p.id);
      if (existing == null) {
        await _db.upsertProduct(
          p.toInsertCompanion().copyWith(
                storeId: Value(p.storeId.isEmpty ? _storeId : p.storeId),
              ),
        );
      } else {
        await _db.upsertProduct(
          ProductsCompanion(
            id: Value(p.id),
            storeId: Value(p.storeId.isEmpty ? _storeId : p.storeId),
            name: Value(p.name),
            barcode: Value(ProductModel.normalizeBarcode(p.barcode)),
            costPrice: Value(p.costPrice),
            sellPrice: Value(p.sellPrice),
            stock: Value(p.stock),
            category: Value(p.category),
            photoPath: Value(p.photoPath),
            isArchived: Value(p.isArchived),
            createdAt: Value(existing.createdAt),
            updatedAt: Value(now),
            dirty: const Value(1),
          ),
        );
      }
      await _refreshList();
      state = state.copyWith(lastError: () => null);
      return null;
    } on InvalidDataException catch (e) {
      // Bentrok unique (storeId, barcode) SQLite → pesan ramah.
      final msg = e.toString().contains('UNIQUE')
          ? 'Barcode sudah dipakai produk lain'
          : 'Gagal menyimpan produk. Coba lagi.';
      state = state.copyWith(lastError: () => msg);
      return msg;
    } catch (_) {
      const msg = 'Gagal menyimpan produk. Coba lagi.';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
  }

  /// Buat model baru dengan UUID lokal (dipakai form tambah).
  ProductModel newProduct({
    required String name,
    String? barcode,
    int costPrice = 0,
    int sellPrice = 0,
    int stock = 0,
    String category = '',
    String photoPath = '',
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return ProductModel(
      id: _uuid.v4(),
      storeId: _storeId,
      name: name,
      barcode: ProductModel.normalizeBarcode(barcode),
      costPrice: costPrice,
      sellPrice: sellPrice,
      stock: stock,
      category: category,
      photoPath: photoPath,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Arsipkan/kembalikan produk (aturan kasir: arsip tidak bisa dijual).
  Future<void> archiveProduct(String id, bool archived) async {
    try {
      await _db.archiveProduct(id, archived);
      await _refreshList();
    } catch (_) {
      state = state.copyWith(
        lastError: () => 'Gagal mengubah arsip. Coba lagi.',
      );
    }
  }

  /// Hapus permanen (UX) = soft delete + dirty agar tersinkron.
  Future<void> deleteProduct(String id) async {
    try {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _db.softDeleteProduct(id, now);
      await _refreshList();
    } catch (_) {
      state = state.copyWith(
        lastError: () => 'Gagal menghapus produk. Coba lagi.',
      );
    }
  }

  /// Sinkron manual: push baris dirty lalu pull dari server (LWW per baris,
  /// delete selalu menang). Token access dari pemanggil (punya refresh flow).
  Future<void> syncNow({required String accessToken}) async {
    if (_storeId.isEmpty) {
      state = state.copyWith(
        lastError: () => 'Toko belum dimuat. Tutup lalu buka lagi.',
      );
      return;
    }
    state = state.copyWith(
      syncStatus: SyncStatus.syncing,
      lastError: () => null,
    );
    String? firstError;
    try {
      await pushCatalog(accessToken, (e) => firstError ??= e);
      await pullCatalog(accessToken);
      state = state.copyWith(
        syncStatus: firstError == null ? SyncStatus.idle : SyncStatus.error,
        lastError: () => firstError,
      );
      await _refreshList();
    } on DioException catch (e) {
      state = state.copyWith(
        syncStatus: e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionError
            ? SyncStatus.offline
            : SyncStatus.error,
        lastError: () => ProductsApi.friendlyError(e),
      );
    } catch (_) {
      state = state.copyWith(
        syncStatus: SyncStatus.error,
        lastError: () => 'Sinkron gagal. Coba lagi.',
      );
    }
  }

  Future<void> pushCatalog(
    String accessToken,
    void Function(String) onRowError,
  ) async {
    final dirty = await _db.dirtyProducts(_storeId);
    for (final row in dirty) {
      final p = row.toModel();
      try {
        if (p.deletedAt != null) {
          try {
            await _api.remove(accessToken, p.id);
          } on DioException catch (e) {
            if (e.response?.statusCode != 404) rethrow;
          }
        } else {
          try {
            await _api.update(accessToken, p);
          } on DioException catch (e) {
            if (e.response?.statusCode == 404) {
              await _api.create(accessToken, p);
            } else {
              rethrow;
            }
          }
        }
        await _db.markClean([p.id]);
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          onRowError(ProductsApi.friendlyError(e));
          continue; // baris lain tetap jalan
        }
        rethrow;
      }
    }
  }

  Future<void> pullCatalog(String accessToken) async {
    final server = await _api.list(accessToken, _storeId);
    for (final s in server) {
      final local = await _db.getProduct(s.id);
      if (local == null) {
        await _db.upsertProduct(
          ProductsCompanion.insert(
            id: s.id,
            storeId: _storeId,
            name: s.name,
            barcode: Value(s.barcode),
            costPrice: s.costPrice,
            sellPrice: s.sellPrice,
            stock: Value(s.stock),
            category: Value(s.category),
            photoPath: Value(s.photoPath),
            createdAt: s.createdAt,
            updatedAt: s.updatedAt,
            dirty: const Value(0),
          ),
        );
        // Baris dari server: pastikan bersih (upsertProduct menandai dirty).
        await _db.markClean([s.id]);
        continue;
      }
      final localModel = local.toModel();
      // Delete selalu menang atas edit lokal.
      if (s.deletedAt != null) {
        if (localModel.deletedAt == null ||
            s.deletedAt! > localModel.deletedAt!) {
          await _db.softDeleteProduct(s.id, s.deletedAt!);
          await _db.markClean([s.id]);
        }
        continue;
      }
      // LWW: server menang bila lebih baru.
      if (s.updatedAt > localModel.updatedAt) {
        await _db.upsertProduct(
          ProductsCompanion.insert(
            id: s.id,
            storeId: _storeId,
            name: s.name,
            barcode: Value(s.barcode),
            costPrice: s.costPrice,
            sellPrice: s.sellPrice,
            stock: Value(s.stock),
            category: Value(s.category),
            photoPath: Value(s.photoPath),
            isArchived: Value(localModel.isArchived),
            createdAt: localModel.createdAt,
            updatedAt: s.updatedAt,
            dirty: const Value(0),
          ),
        );
        // upsertProduct selalu menandai dirty=1; baris dari server bersih.
        await _db.markClean([s.id]);
      }
    }
  }

  Future<void> _refreshList() async {
    if (_storeId.isEmpty) return;
    final q = state.query.trim();
    List<Product> rows;
    if (q.isNotEmpty) {
      rows = await _db.searchProducts(_storeId, q);
    } else if (state.showArchived) {
      rows = await _db.watchArchivedProducts(_storeId).first;
    } else {
      rows = await _db.watchActiveProducts(_storeId).first;
    }
    state = state.copyWith(products: rows.map((e) => e.toModel()).toList());
  }

  /// Baca ulang satu produk dari DB (future biasa, tanpa stream) lalu
  /// ganti barisnya di state. Dipakai setelah opname agar stok di layar
  /// langsung ikut angka baru tanpa menunggu stream watch.
  Future<void> refreshProduct(String id) async {
    final row = await _db.getProduct(id);
    if (row == null) return;
    final model = row.toModel();
    state = state.copyWith(
      products: [
        for (final p in state.products)
          if (p.id == id) model else p,
      ],
    );
  }
}
