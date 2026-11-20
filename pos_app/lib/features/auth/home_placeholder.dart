import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            Text('Halo, $name! Kasir segera hadir.'),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const Key('productsButton'),
              onPressed: () => context.push('/products'),
              child: const Text('Kelola Produk'),
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
