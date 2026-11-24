import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';
import 'pin_pad.dart';

/// Layar pembuatan PIN 6-digit (2 tahap: PIN lalu konfirmasi).
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  bool _confirming = false;
  String? _error;

  Future<void> _submit(String pin, String confirmPin) async {
    final notifier = ref.read(authProvider.notifier);
    final error = await notifier.completePinSetup(
      pin: pin,
      confirmPin: confirmPin,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = error;
        _confirming = false;
        _pin = '';
      });
      return;
    }
    // Defer navigasi ke post-frame: state berubah (watch) + go() sinkron
    // dalam satu frame bisa memicu rebuild loop yang menggantung pumpAndSettle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/home');
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final stepLabel = _confirming ? 'Ulangi PIN' : 'Buat PIN 6 digit';
    return Scaffold(
      appBar: AppBar(title: const Text('Buat PIN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _confirming
                  ? 'Ulangi PIN 6 digit untuk konfirmasi.'
                  : 'Buat PIN 6 digit untuk membuka aplikasi tanpa internet.',
            ),
            const SizedBox(height: 16),
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
            Text(
              stepLabel,
              key: Key(_confirming ? 'confirmPinField' : 'pinField'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            PinPad(
              key: ValueKey('pinPad-$_confirming-$_error'),
              onChanged: (v) {
                if (v.length != 6) return;
                if (!_confirming) {
                  setState(() {
                    _pin = v;
                    _confirming = true;
                  });
                } else {
                  _submit(_pin, v);
                }
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
