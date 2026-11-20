import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/db/app_db.dart';
import 'core/router.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDb.openFile();
  runApp(
    ProviderScope(
      overrides: [appDbProvider.overrideWithValue(db)],
      child: const PosApp(),
    ),
  );
}

/// Router aplikasi: dibuat sekali per [ProviderScope] dan di-refresh
/// otomatis setiap [authProvider] berubah (login/logout/PIN), sehingga
/// `redirect` GoRouter dievaluasi ulang tanpa navigasi manual.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);
  return buildRouter(
    authSnapshot: () => ref.read(authProvider),
    refreshListenable: refresh,
  );
});

/// Meneruskan perubahan [authProvider] ke GoRouter via [ChangeNotifier].
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _sub = _ref.listen(authProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Root aplikasi POS Warung.
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
      routerConfig: ref.watch(routerProvider),
    );
  }
}
