import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';
import 'auth_state.dart';
import 'auth_validators.dart';

/// Layar pendaftaran toko + pemilik baru.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _store = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _store.dispose();
    _owner.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authProvider.notifier);
    await notifier.register(
      storeName: _store.text.trim(),
      ownerName: _owner.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    final state = ref.read(authProvider);
    if (state is AuthPinSetupRequired) {
      context.go('/pin-setup');
    } else if (state is AuthAuthenticated) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Toko')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    key: const Key('errorText'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              TextFormField(
                key: const Key('storeField'),
                controller: _store,
                decoration: const InputDecoration(labelText: 'Nama toko'),
                validator: (v) => AuthValidators.required(v, 'Nama toko'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('ownerField'),
                controller: _owner,
                decoration: const InputDecoration(labelText: 'Nama pemilik'),
                validator: (v) => AuthValidators.required(v, 'Nama pemilik'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('emailField'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('passwordField'),
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: AuthValidators.password,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('confirmField'),
                controller: _confirm,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Konfirmasi password'),
                validator: (v) =>
                    AuthValidators.confirmPassword(v, _password.text),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                key: const Key('registerButton'),
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Daftar'),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sudah punya akun? Masuk'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
