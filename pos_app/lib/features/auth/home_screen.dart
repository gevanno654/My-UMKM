import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pos_app/core/sync/sync_all_provider.dart';
import 'package:pos_app/features/reports/reports_provider.dart';
import 'package:pos_app/features/sales/sales_screens.dart'
    show formatRupiah, resolveStore;

import 'auth_provider.dart';
import 'auth_state.dart';

/// Home: ringkasan hari ini + aksi cepat + sinkron.
/// Data read-only dari provider laporan (periode hari ini).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final (storeId, _) = await resolveStore(ref);
    if (!mounted || storeId.isEmpty) return;
    await ref.read(reportsProvider.notifier).load(storeId);
    await ref.read(reportsProvider.notifier).goToday();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final name = switch (state) {
      AuthAuthenticated(profile: final p) => p.name,
      AuthPinSetupRequired(profile: final p) => p.name,
      _ => 'Pemilik',
    };
    final summary = ref.watch(reportsProvider).summary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Halo, $name!', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Ringkasan hari ini',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Omzet',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            formatRupiah(summary.revenue),
                            key: const Key('revenueValue'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaksi',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${summary.txCount}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('kasirButton'),
              onPressed: () => context.push('/sales'),
              child: const Text('Buka Kasir'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('reportsButton'),
              onPressed: () => context.push('/reports'),
              child: const Text('Lihat Laporan'),
            ),
            const SizedBox(height: 12),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      key: const Key('syncAllButton'),
                      onPressed: sync.status == SyncStatus.syncing
                          ? null
                          : () => ref.read(syncAllProvider.notifier).syncAll(),
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
}
