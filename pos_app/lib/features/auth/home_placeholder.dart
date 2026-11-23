import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pos_app/core/sync/sync_all_provider.dart';

import 'auth_provider.dart';
import 'auth_state.dart';

/// Placeholder home; diganti kasir asli di plan berikutnya.
class HomePlaceholder extends ConsumerWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider);
    final name = switch (state) {
      AuthAuthenticated(profile: final p) => p.name,
      AuthPinSetupRequired(profile: final p) => p.name,
      _ => 'Pemilik',
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Warung'),
        actions: [
          IconButton(
            key: const Key('logoutButton'),
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Halo, $name!'),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const Key('kasirButton'),
              onPressed: () => context.push('/sales'),
              child: const Text('Kasir'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('restockButton'),
              onPressed: () => context.push('/restocks'),
              child: const Text('Restock'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('opnameButton'),
              onPressed: () => context.push('/adjustments'),
              child: const Text('Opname'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('productsButton'),
              onPressed: () => context.push('/products'),
              child: const Text('Kelola Produk'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('reportsButton'),
              onPressed: () => context.push('/reports'),
              child: const Text('Laporan'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('printerSetupButton'),
              onPressed: () => context.push('/settings/printer'),
              child: const Text('Printer Struk'),
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final sync = ref.watch(syncAllProvider);
                final label = switch (sync.status) {
                  SyncStatus.syncing => 'Menyinkron...',
                  SyncStatus.offline => 'Offline — coba lagi',
                  SyncStatus.error => 'Gagal sinkron',
                  SyncStatus.idle => 'Sinkron Semua',
                };
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      key: const Key('syncAllButton'),
                      onPressed: sync.status == SyncStatus.syncing
                          ? null
                          : () =>
                                ref.read(syncAllProvider.notifier).syncAll(),
                      child: Text(label),
                    ),
                    if (sync.lastError != null)
                      Padding(
                        key: const Key('syncAllStatus'),
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          sync.lastError!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Sesi di HP ini dihapus. Untuk masuk lagi perlu login ulang + PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('confirmLogoutButton'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}
