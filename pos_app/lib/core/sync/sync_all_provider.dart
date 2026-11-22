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

/// Orkestrator sinkron global: push SEMUA dokumen dulu (produk → kasir →
/// kulakan → opname), baru pull SEMUA. Pull hanya jalan setelah server
/// menerima seluruh dokumen, sehingga stok lokal tidak pernah tertimpa
/// angka server yang basi (akar bug restock +5 jadi +10).
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

      // Fase push: produk dulu, lalu dokumen yang merujuknya.
      await products.pushCatalog(accessToken, (e) => firstError ??= e);
      await sales.pushSales(accessToken, (e) => firstError ??= e);
      await restocks.pushRestocks(accessToken, (e) => firstError ??= e);
      await adjustments.pushAdjustments(
        accessToken,
        (e) => firstError ??= e,
      );

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
