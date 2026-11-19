import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'features/auth/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: PosApp()));
}

/// Root aplikasi POS Warung.
///
/// Gate PIN ([authSnapshot]) dibaca live dari [authProvider] setiap kali
/// GoRouter mengevaluasi redirect; `ref.read` (bukan `watch`) agar router
/// tidak dibuat ulang setiap state berubah.
class PosApp extends ConsumerWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'POS Warung',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      routerConfig: buildRouter(
        authSnapshot: () => ref.read(authProvider),
      ),
    );
  }
}
