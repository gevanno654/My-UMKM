import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('POS Warung')),
      body: Center(child: Text('Halo, $name! Kasir segera hadir.')),
    );
  }
}
