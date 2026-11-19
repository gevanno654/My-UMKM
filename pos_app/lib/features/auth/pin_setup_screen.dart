import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';

/// Layar pembuatan PIN 6-digit (2x input: PIN + konfirmasi).
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authProvider.notifier);
    final error = await notifier.completePinSetup(
      pin: _pin.text,
      confirmPin: _confirm.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Buat PIN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Buat PIN 6 digit untuk membuka aplikasi tanpa internet.',
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
              TextFormField(
                key: const Key('pinField'),
                controller: _pin,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'PIN 6 digit'),
                validator: (v) => v != null && v.length == 6
                    ? null
                    : 'PIN harus 6 digit',
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('confirmPinField'),
                controller: _confirm,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration:
                    const InputDecoration(labelText: 'Ulangi PIN'),
                validator: (v) => v != null && v.length == 6
                    ? null
                    : 'PIN harus 6 digit',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                key: const Key('pinSetupButton'),
                onPressed: state.isLoading ? null : _submit,
                child: const Text('Simpan PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
