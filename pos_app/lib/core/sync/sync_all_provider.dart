import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/auth/auth_state.dart';
import 'package:pos_app/features/products/products_api.dart';
import 'package:pos_app/features/products/products_provider.dart';
import 'package:pos_app/features/sales/sales_provider.dart';
import 'package:pos_app/features/restocks/restocks_provider.dart';
import 'package:pos_app/features/adjustments/adjustments_provider.dart';

final syncAllProvider =
    NotifierProvider<SyncAllNotifier, SyncAllState>(SyncAllNotifier.new);

/// Status sinkronisasi global.
enum SyncStatus { idle, syncing, offline, error }

/// State sinkron global: satu status + satu pesan error untuk Home.
class SyncAllState {
  const SyncAllState({this.status = SyncStatus.idle, this.lastError});

  final SyncStatus status;
  final String? lastError;

  SyncAllState copyWith({SyncStatus? status, String? Function()? lastError}) =>
      SyncAllState(
        status: status ?? this.status,
        lastError: lastError == null ? this.lastError : lastError(),
      );
}

/// Orkestrator sinkron global = BACKUP satu arah (HP → cloud).
/// Stok lokal otoritatif: sinkron tidak boleh mengubah stok aplikasi.
/// - Push: katalog dulu, lalu SEMUA dokumen dirty dalam urutan kronologis
///   dibuatnya (kulakan sebelum kasir bila dibuat duluan), sehingga stok
///   cloud yang hanya bergerak via dokumen tidak pernah mendapat urutan
///   terbalik (akar error "Stok tidak cukup di server").
/// - Pull: hanya metadata katalog (nama/harga/foto/hapus/arsip) + riwayat
///   dokumen. Stok lokal TIDAK PERNAH ditimpa angka server.
class SyncAllNotifier extends Notifier<SyncAllState> {
  @override
  SyncAllState build() => const SyncAllState();

  /// Sinkron semua data toko. Mengembalikan null bila sukses,
  /// pesan error Indonesia bila gagal.
  Future<String?> syncAll() async {
    final authState = ref.read(authProvider);
    final (storeId, storeName) = switch (authState) {
      AuthAuthenticated(profile: final p) => (p.storeId, p.storeName),
      AuthPinSetupRequired(profile: final p) => (p.storeId, p.storeName),
      AuthPinLocked(profile: final p) => (p.storeId, p.storeName),
      _ => ('', ''),
    };
    if (storeId.isEmpty) {
      const msg = 'Sesi toko tidak ditemukan. Login ulang.';
      state = state.copyWith(
        status: SyncStatus.error,
        lastError: () => msg,
      );
      return msg;
    }
    final session = ref.read(secureSessionProvider);
    final tokens = await session.readTokens();
    final accessToken = tokens.accessToken ?? '';

    state = state.copyWith(
      status: SyncStatus.syncing,
      lastError: () => null,
    );
    String? firstError;
    try {
      final products = ref.read(productsProvider.notifier);
      final sales = ref.read(salesProvider.notifier);
      final restocks = ref.read(restocksProvider.notifier);
      final adjustments = ref.read(adjustmentsProvider.notifier);

      await products.load(storeId);
      await sales.load(storeId, storeName: storeName);
      await restocks.load(storeId);
      await adjustments.load(storeId);

      // Fase push 1: katalog (nama/harga/foto/hapus). Stok TIDAK
      // dikirim: body produk selalu stok 0, stok cloud hanya bergerak
      // via dokumen di bawah.
      await products.pushCatalog(accessToken, (e) => firstError ??= e);

      // Fase push 2: dokumen dirty lintas tipe dalam urutan kronologis
      // dibuatnya (createdAt), bukan per tipe. Restock yang dibuat sebelum
      // sale di-push duluan, sehingga stok cloud cukup saat sale di-POST.
      final db = ref.read(appDbProvider);
      final docs = [
        for (final r in await db.dirtyRestocks(storeId))
          (createdAt: r.createdAt, push: () => restocks.pushSingleRestock(
                accessToken,
                r,
                (e) => firstError ??= e,
              )),
        for (final s in await db.dirtySales(storeId))
          (createdAt: s.createdAt, push: () => sales.pushSingleSale(
                accessToken,
                s,
                (e) => firstError ??= e,
              )),
        for (final a in await db.dirtyAdjustments(storeId))
          (createdAt: a.createdAt, push: () => adjustments.pushSingleAdjustment(
                accessToken,
                a,
                (e) => firstError ??= e,
              )),
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final doc in docs) {
        await doc.push();
      }

      // Fase pull: server sudah punya semua dokumen.
      await products.pullCatalog(accessToken);
      await sales.pullSales(accessToken);
      await restocks.pullRestocks(accessToken);
      await adjustments.pullAdjustments(accessToken);

      await products.load(storeId);
      await sales.load(storeId, storeName: storeName);
      await restocks.load(storeId);
      await adjustments.load(storeId);

      state = state.copyWith(
        status: firstError == null ? SyncStatus.idle : SyncStatus.error,
        lastError: () => firstError,
      );
      return firstError;
    } on DioException catch (e) {
      final offline =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError;
      final msg = offline
          ? 'Tidak ada koneksi. Data tersimpan lokal, sinkron lagi nanti.'
          : ProductsApi.friendlyError(e);
      state = state.copyWith(
        status: offline ? SyncStatus.offline : SyncStatus.error,
        lastError: () => msg,
      );
      return msg;
    } catch (_) {
      const msg = 'Sinkron gagal. Coba lagi.';
      state = state.copyWith(
        status: SyncStatus.error,
        lastError: () => msg,
      );
      return msg;
    }
  }
}
