import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';
import 'auth_state.dart';
import 'pin_guard.dart';
import 'pin_pad.dart';

/// Layar buka-kunci PIN (murni offline — tanpa panggilan jaringan).
class PinUnlockScreen extends ConsumerStatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  String? _error;

  Future<void> _submit(String pin) async {
    final notifier = ref.read(authProvider.notifier);
    final userId = switch (ref.read(authProvider)) {
      AuthPinLocked(profile: final p) => p.id,
      _ => null,
    };
    if (userId == null) {
      setState(() => _error = 'Sesi tidak valid. Login ulang.');
      return;
    }
    final session = ref.read(secureSessionProvider);
    final guard = PinGuard(session: session, userId: userId);
    if (await guard.isLocked()) {
      final until = await guard.lockedUntil();
      final seconds = until == null
          ? 60
          : until.difference(DateTime.now()).inSeconds.clamp(1, 60);
      setState(
        () => _error = 'Terlalu banyak salah. Coba lagi dalam $seconds detik.',
      );
      return;
    }
    final ok = await notifier.unlockSession(pin);
    if (!mounted) return;
    if (ok) {
      // Defer seperti PinSetupScreen: hindari rebuild loop saat pumpAndSettle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
      setState(() {});
      return;
    }
    final remaining = await guard.remainingAttempts();
    setState(
      () => _error = remaining > 0
          ? 'PIN salah. Sisa percobaan: $remaining.'
          : 'Terlalu banyak salah. Coba lagi dalam 60 detik.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Buka dengan PIN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  key: const Key('errorText'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const Text(
              'PIN 6 digit',
              key: Key('pinField'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            PinPad(
              key: ValueKey('pinPad-$_error'),
              onChanged: (v) {
                if (v.length != 6 || state.isLoading) return;
                _submit(v);
              },
            ),
            const SizedBox(height: 12),
            if (state.isLoading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
