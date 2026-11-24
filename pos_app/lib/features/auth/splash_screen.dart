import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';
import 'auth_state.dart';

/// Splash: bootstrap sesi lalu arahkan ke route yang tepat.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    await ref.read(authProvider.notifier).bootstrap();
    if (!mounted) return;
    final state = ref.read(authProvider);
    if (state is AuthAuthenticated) {
      context.go('/home');
    } else if (state is AuthPinLocked) {
      // Sesi tersimpan + PIN sudah ada: wajib buka via PIN (offline OK).
      context.go('/pin-unlock');
    } else if (state is AuthPinSetupRequired) {
      context.go('/pin-setup');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 16),
            Text(
              'POS Warung',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}
