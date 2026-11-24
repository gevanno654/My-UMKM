import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_db.dart';
import '../auth/auth_provider.dart';
import '../products/products_api.dart';
import '../products/products_provider.dart';
import 'adjustments_api.dart';

final adjustmentsApiProvider =
    Provider<AdjustmentsApi>((ref) => AdjustmentsApi());

final adjustmentsProvider =
    NotifierProvider<AdjustmentsNotifier, AdjustmentsState>(
      AdjustmentsNotifier.new,
    );

/// Model domain penyesuaian opname.
class AdjustmentModel {
  const AdjustmentModel({
    required this.id,
    required this.storeId,
    this.productId,
    this.name = '',
    this.stockBefore = 0,
    this.stockAfter = 0,
    this.diff = 0,
    this.reason = '',
    this.status = 'ok',
    this.voidReason,
    required this.createdAt,
  });

  final String id;
  final String storeId;
  final String? productId;
  final String name;
  final int stockBefore;
  final int stockAfter;
  final int diff;
  final String reason;
  final String status;
  final String? voidReason;
  final int createdAt;

  bool get isVoided => status == 'voided';
}

/// Status sinkronisasi manual ke cloud.
enum SyncStatus { idle, syncing, offline, error }

/// State opname: riwayat + status sinkron (tanpa draft — langsung simpan).
class AdjustmentsState {
  const AdjustmentsState({
    this.history = const [],
    this.syncStatus = SyncStatus.idle,
    this.lastError,
  });

  final List<AdjustmentModel> history;
  final SyncStatus syncStatus;
  final String? lastError;

  AdjustmentsState copyWith({
    List<AdjustmentModel>? history,
    SyncStatus? syncStatus,
    String? Function()? lastError,
  }) =>
      AdjustmentsState(
        history: history ?? this.history,
        syncStatus: syncStatus ?? this.syncStatus,
        lastError: lastError == null ? this.lastError : lastError(),
      );
}

/// Orkestrasi opname offline-first: simpan atomik via
/// `AppDb.saveAdjustmentFull`, backend salinan per `store_id` via sinkron
/// manual. Pola reuse `RestocksNotifier` (produk di-push dulu, cabang void).
class AdjustmentsNotifier extends Notifier<AdjustmentsState> {
  static const _uuid = Uuid();

  late final AdjustmentsApi _api;
  late final AppDb _db;

  String _storeId = '';

  @override
  AdjustmentsState build() {
    _api = ref.watch(adjustmentsApiProvider);
    _db = ref.watch(appDbProvider);
    return const AdjustmentsState();
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

  /// Sesuaikan stok produk ke hasil hitung fisik.
  /// Mengembalikan null bila sukses, pesan error bila gagal.
  Future<String?> adjustStock({
    required String productId,
    required int physicalStock,
    required String reason,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      const msg = 'Alasan penyesuaian wajib diisi';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    if (trimmed.length > 200) {
      const msg = 'Alasan maksimal 200 karakter';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    if (physicalStock < 0) {
      const msg = 'Stok fisik tidak valid';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    final product = await _db.getProduct(productId);
    final problem = _problemOf(product);
    if (problem != null) {
      state = state.copyWith(lastError: () => problem);
      return problem;
    }
    if (physicalStock == product!.stock) {
      const msg = 'Stok sama, tidak ada perubahan';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    final diff = physicalStock - product.stock;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    try {
      await _db.saveAdjustmentFull(
        adjustment: AdjustmentsCompanion.insert(
          id: _uuid.v4(),
          storeId: _storeId,
          productId: Value(productId),
          name: product.name,
          stockBefore: product.stock,
          stockAfter: physicalStock,
          diff: diff,
          reason: trimmed,
          createdAt: now,
        ),
        physicalStock: physicalStock,
      );
    } on ArgumentError catch (e) {
      final msg = e.message?.toString() ?? 'Penyesuaian gagal';
      state = state.copyWith(lastError: () => msg);
      return msg;
    } on StateError {
      const msg = 'Produk tidak tersedia. Periksa kembali.';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    await _refresh();
    state = state.copyWith(lastError: () => null);
    return null;
  }

  /// Batal beraudit: alasan wajib; stok dikembalikan atomik.
  Future<String?> voidAdjustment(String id, String reason) async {
    if (reason.trim().isEmpty) {
      const msg = 'Alasan batal wajib diisi';
      state = state.copyWith(lastError: () => msg);
      return msg;
    }
    try {
      await _db.voidAdjustment(
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

  /// Sinkron manual: push adjustment kotor lalu pull dari server.
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
      await pushAdjustments(accessToken, (e) => firstError ??= e);
      await pullAdjustments(accessToken);
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
        lastError: () => AdjustmentsApi.friendlyError(e),
      );
    } catch (_) {
      state = state.copyWith(
        syncStatus: SyncStatus.error,
        lastError: () => 'Sinkron gagal. Coba lagi.',
      );
    }
  }

  Future<void> pushAdjustments(
    String accessToken,
    void Function(String) onRowError,
  ) async {
    final dirty = await _db.dirtyAdjustments(_storeId);
    for (final row in dirty) {
      await pushSingleAdjustment(accessToken, row, onRowError);
    }
  }

  /// Push SATU adjustment (dipakai sinkron kronologis lintas tipe).
  /// Idempoten: 404 void = sukses, 409 = pesan per baris lalu lanjut.
  Future<void> pushSingleAdjustment(
    String accessToken,
    Adjustment row,
    void Function(String) onRowError,
  ) async {
    try {
      // Baris voided: kirim pembatalan ke server, bukan POST ulang dokumen.
      // 404 (belum pernah terkirim) = anggap sukses; 409 = pesan jelas.
      if (row.status == 'voided') {
        try {
          await _api.voidAdjustment(
            accessToken: accessToken,
            id: row.id,
            reason: row.voidReason ?? 'dibatalkan',
          );
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
        }
        await _db.markAdjustmentsClean([row.id]);
        return;
      }
      // Sinkron opname sekaligus sinkron produk: produk terkait di-push
      // DULU (stok cloud ikut terkini), baru adjustment di-POST sekali.
      final productError = await _pushMissingProducts(accessToken, row.id);
      if (productError != null) {
        onRowError(productError);
        return;
      }
      await _postAdjustment(accessToken, row);
      await _db.markAdjustmentsClean([row.id]);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        onRowError(AdjustmentsApi.friendlyError(e));
        return;
      }
      rethrow;
    }
  }

  /// POST satu adjustment kotor ke server.
  Future<void> _postAdjustment(
    String accessToken,
    Adjustment row,
  ) async {
    await _api.create(
      accessToken: accessToken,
      id: row.id,
      productId: row.productId!,
      physicalStock: row.stockAfter,
      reason: row.reason,
    );
  }

  /// Push produk dalam adjustment yang dirty, lalu tandai bersih.
  /// Mengembalikan pesan error Indonesia bila ada produk gagal push
  /// (null bila semua ok / tidak ada yang perlu di-push).
  /// Delegasi ke ProductsNotifier.pushOne (rekonsiliasi 409 konsisten).
  Future<String?> _pushMissingProducts(
    String accessToken,
    String adjustmentId,
  ) async {
    final row = await _db.getAdjustment(adjustmentId);
    final productId = row?.productId;
    if (productId == null) return null;
    final product = await _db.getProduct(productId);
    if (product == null || product.deletedAt != null) return null;
    try {
      await ref
          .read(productsProvider.notifier)
          .pushOne(accessToken, product.toModel());
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return ProductsApi.friendlyError(e);
      }
      rethrow;
    }
    return null;
  }

  Future<void> pullAdjustments(String accessToken) async {
    final server = await _api.list(accessToken);
    for (final s in server) {
      final local = await _db.getAdjustment(s.id);
      if (local == null) {
        await _db.upsertAdjustmentFromServer(
          AdjustmentsCompanion.insert(
            id: s.id,
            storeId: _storeId,
            productId: Value(s.productId),
            name: s.name,
            stockBefore: s.stockBefore,
            stockAfter: s.stockAfter,
            diff: s.diff,
            reason: s.reason,
            status: Value(s.status),
            voidReason: Value(s.voidReason),
            createdAt: s.createdAt,
          ),
        );
        continue;
      }
      // Void server menang atas ok lokal.
      if (s.status == 'voided' && local.status != 'voided') {
        await _db.upsertAdjustmentFromServer(
          AdjustmentsCompanion.insert(
            id: s.id,
            storeId: _storeId,
            productId: Value(s.productId),
            name: s.name,
            stockBefore: local.stockBefore,
            stockAfter: local.stockAfter,
            diff: local.diff,
            reason: local.reason,
            status: const Value('voided'),
            voidReason: Value(s.voidReason),
            createdAt: local.createdAt,
          ),
        );
        await _db.markAdjustmentsClean([s.id]);
      }
    }
  }

  /// Masalah katalog untuk opname: null/terhapus/arsip → pesan Indonesia.
  String? _problemOf(Product? product) {
    if (product == null || product.deletedAt != null) {
      return 'Produk tidak tersedia (dihapus).';
    }
    if (product.isArchived) {
      return '${product.name} diarsipkan.';
    }
    return null;
  }

  Future<void> _refresh() async {
    if (_storeId.isEmpty) return;
    final rows = await _db.adjustmentsHistory(_storeId);
    state = state.copyWith(
      history: rows
          .map(
            (r) => AdjustmentModel(
              id: r.id,
              storeId: r.storeId,
              productId: r.productId,
              name: r.name,
              stockBefore: r.stockBefore,
              stockAfter: r.stockAfter,
              diff: r.diff,
              reason: r.reason,
              status: r.status,
              voidReason: r.voidReason,
              createdAt: r.createdAt,
            ),
          )
          .toList(),
    );
  }
}
