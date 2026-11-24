import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_db.dart';
import '../auth/auth_provider.dart';
import 'photo_store.dart';
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
            photoHash: Value(p.photoHash),
            photoSize: Value(p.photoSize),
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
    String photoHash = '',
    int photoSize = 0,
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
      photoHash: photoHash,
      photoSize: photoSize,
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

  /// Fase foto sinkron global: bandingkan hash lokal vs manifest server,
  /// upload hanya yang beda + unduh hanya yang kurang. Stok tidak disentuh;
  /// hanya kolom foto + file. Per-file gagal → [onFileError], lanjut.
  /// Offline (timeout/koneksi) → return diam-diam, bukan error.
  Future<void> syncPhotos(
    String accessToken, {
    PhotoStore? photoStore,
    void Function(String)? onFileError,
  }) async {
    if (_storeId.isEmpty) return;    Map<String, String> manifest;
    try {
      manifest = await _api.photoManifest(accessToken);
    } on DioException catch (e) {
      if (_isOffline(e)) return;
      rethrow;
    }
    final PhotoStore fileStore = photoStore ?? ref.read(photoStoreProvider);
    final rows = await _db.watchActiveProducts(_storeId).first;
    final archived = await _db.watchArchivedProducts(_storeId).first;
    final byId = {
      for (final m in [...rows, ...archived].map((r) => r.toModel())) m.id: m,
    };

    // Upload: file lokal ada + hash beda dari server ('' = server kosong).
    for (final m in byId.values) {
      if (m.deletedAt != null || m.photoPath.isEmpty) continue;
      File file;
      try {
        file = await fileStore.resolve(m.photoPath);
      } catch (_) {
        continue;
      }
      if (!await file.exists()) continue;
      final serverHash = manifest[m.id] ?? '';
      String localHash = m.photoHash;
      try {
        if (localHash.isEmpty) localHash = await fileStore.sha256Of(file);
      } catch (_) {
        continue;
      }
      if (localHash == serverHash && serverHash.isNotEmpty) continue;
      try {
        final up = await _api.uploadPhoto(
          accessToken: accessToken,
          productId: m.id,
          file: file,
        );
        await _db.setProductPhoto(
          m.id,
          photoPath: m.photoPath,
          photoHash: up.photoHash,
          photoSize: up.photoSize,
        );
        // Hash otoritatif sudah di server; tanpa dirty (PUT abaikan foto).
      } on DioException catch (e) {
        onFileError?.call('${m.name}: ${ProductsApi.friendlyError(e)}');
      }
    }

    // Unduh: hash server non-kosong + (beda dari lokal || file lokal hilang).
    for (final entry in manifest.entries) {
      final serverHash = entry.value;
      if (serverHash.isEmpty) continue;
      final m = byId[entry.key];
      final oldPath = m?.photoPath ?? '';
      if (m != null && m.photoHash == serverHash && m.photoPath.isNotEmpty) {
        try {
          if (await (await fileStore.resolve(m.photoPath)).exists()) continue;
        } catch (_) {
          // resolve gagal → unduh ulang di bawah.
        }
      }
      try {
        final bytes = await _api.downloadPhoto(
          accessToken: accessToken,
          hash: serverHash,
        );
        final rel = 'product_photos/$serverHash.jpg';
        final dest = await fileStore.resolve(rel);
        await dest.parent.create(recursive: true);
        await File(dest.path).writeAsBytes(bytes);
        final size = await File(dest.path).length();
        if (m != null) {
          await _db.setProductPhoto(
            m.id,
            photoPath: rel,
            photoHash: serverHash,
            photoSize: size,
          );
        }
        if (oldPath.isNotEmpty && oldPath != rel) {
          await fileStore.deleteFile(oldPath);
        }
      } on DioException catch (e) {
        onFileError?.call(
          '${m?.name ?? entry.key}: ${ProductsApi.friendlyError(e)}',
        );
      }
    }
  }

  bool _isOffline(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError;

  /// Push SATU produk dirty dengan rekonsiliasi ID otomatis.
  ///
  /// Dipakai pushCatalog maupun push dokumen (sale/restock/adjustment):
  /// update → 404 → create → 409+conflictWith → adopsi ID server → retry
  /// update sekali. Konflik tanpa info (backend lama / tanpa barcode)
  /// dilempar sebagai DioException 409 standar agar semua pemanggil cukup
  /// menangani DioException. Stok tidak tersentuh (PUT abaikan stok).
  ///
  /// Mengembalikan model ber-ID final (server bila rekonsiliasi).
  Future<ProductModel> pushOne(String accessToken, ProductModel p) async {
    try {
      await _api.update(accessToken, p);
      await _db.markClean([p.id]);
      return p;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
      return _reconcileOrCreate(accessToken, p);
    } on ProductConflictException catch (e) {
      final server = e.conflictWith;
      if (server == null || p.barcode == null) {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/products'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/products'),
            statusCode: 409,
            data: const {'error': 'barcode taken'},
          ),
          type: DioExceptionType.badResponse,
        );
      }
      await _db.adoptProductId(
        oldId: p.id,
        server: server.toAdoptCompanion(),
      );
      await _api.update(accessToken, server);
      await _db.markClean([server.id]);
      return server;
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
          // Purge file cloud (best-effort): baris dihapus → foto yatim
          // dibersihkan di server. 404 = tidak ada foto, abaikan.
          try {
            await _api.deletePhoto(accessToken: accessToken, productId: p.id);
          } on DioException catch (e) {
            if (e.response?.statusCode != 404) rethrow;
          }
          await _db.markClean([p.id]);
        } else {
          await pushOne(accessToken, p);
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          onRowError(ProductsApi.friendlyError(e));
          continue; // baris lain tetap jalan
        }
        rethrow;
      }
    }
  }

  /// POST fallback saat PUT 404 (ID lokal asing). 409 + conflictWith →
  /// adopsi ID server + retry update sekali, kembalikan model ber-ID
  /// server; selain itu perilaku lama (create lalu model asal).
  Future<ProductModel> _reconcileOrCreate(
    String accessToken,
    ProductModel p,
  ) async {
    try {
      await _api.create(accessToken, p);
      await _db.markClean([p.id]);
      return p;
    } on ProductConflictException catch (e) {
      final server = e.conflictWith;
      if (server == null || p.barcode == null) {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/products'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/products'),
            statusCode: 409,
            data: const {'error': 'barcode taken'},
          ),
          type: DioExceptionType.badResponse,
        );
      }
      await _db.adoptProductId(
        oldId: p.id,
        server: server.toAdoptCompanion(),
      );
      await _api.update(accessToken, server);
      await _db.markClean([server.id]);
      return server;
    }
  }

  /// Pull katalog = backup metadata: nama/harga/foto/delete boleh masuk
  /// dari server (LWW), tetapi STOK LOKAL TIDAK PERNAH DITIMPA angka
  /// server. HP adalah otoritas stok; sinkron hanya menitipkan data ke
  /// cloud, bukan mengambil alih angka aplikasi.
  Future<void> pullCatalog(String accessToken) async {
    final server = await _api.list(accessToken, _storeId);
    for (final s in server) {
      final local = await _db.getProduct(s.id);
      // Identitas foto = hash, bukan path: path lokal dipertahankan
      // (file milik HP ini), hanya hash/size yang ikut server.
      final localModel = local?.toModel();
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
            photoPath: Value(localModel?.photoPath ?? ''),
            photoHash: Value(s.photoHash),
            photoSize: Value(s.photoSize),
            createdAt: s.createdAt,
            updatedAt: s.updatedAt,
            dirty: const Value(0),
          ),
        );
        // Baris dari server: pastikan bersih (upsertProduct menandai dirty).
        await _db.markClean([s.id]);
        continue;
      }
      // Delete selalu menang atas edit lokal.
      if (s.deletedAt != null) {
        if (localModel!.deletedAt == null ||
            s.deletedAt! > localModel.deletedAt!) {
          await _db.softDeleteProduct(s.id, s.deletedAt!);
          await _db.markClean([s.id]);
        }
        continue;
      }
      // LWW metadata: kolom katalog ikut server, stok tetap milik lokal.
      if (s.updatedAt > localModel!.updatedAt) {
        await _db.upsertProduct(
          ProductsCompanion.insert(
            id: s.id,
            storeId: _storeId,
            name: s.name,
            barcode: Value(s.barcode),
            costPrice: s.costPrice,
            sellPrice: s.sellPrice,
            stock: Value(localModel.stock),
            category: Value(s.category),
            photoPath: Value(localModel.photoPath),
            photoHash: Value(s.photoHash),
            photoSize: Value(s.photoSize),
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
