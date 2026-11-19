/// Hasil autentikasi online (register/login/refresh/me).
/// Cerminkan kontrak `docs/API_AUTH.md`.
class AuthProfile {
  const AuthProfile({
    required this.id,
    required this.storeId,
    required this.name,
    required this.email,
    required this.storeName,
  });

  final String id;
  final String storeId;
  final String name;
  final String email;
  final String storeName;

  factory AuthProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final store = json['store'] as Map<String, dynamic>;
    return AuthProfile(
      id: user['id'] as String,
      storeId: user['storeId'] as String,
      name: user['name'] as String,
      email: user['email'] as String,
      storeName: store['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'user': {
          'id': id,
          'storeId': storeId,
          'name': name,
          'email': email,
        },
        'store': {
          'id': storeId,
          'name': storeName,
        },
      };
}

class AuthResult {
  const AuthResult({
    required this.profile,
    required this.accessToken,
    required this.refreshToken,
  });

  final AuthProfile profile;
  final String accessToken;
  final String refreshToken;
}

/// Status auth di client. Alur:
///
/// `initial` → (bootstrap) → `unauthenticated` atau `authenticated`/`pinSetupRequired`
/// register/login sukses → `pinSetupRequired` (PIN belum ada) atau `authenticated`.
sealed class AuthState {
  const AuthState();

  bool get isLoading => this is AuthLoading;

  /// Pesan error terakhir; null bila tidak ada. Dioverride subclass yang relevan.
  String? get error => null;
}

/// Status awal sebelum bootstrap membaca secure storage.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Menunggu respons jaringan (dipakai saat login/register/refresh berjalan).
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Belum ada sesi valid; [error] berisi pesan terakhir (mis. login gagal).
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.error});

  @override
  final String? error;
}

/// Gagal total yang tidak bisa dipulihkan ke state sebelumnya.
class AuthFailure extends AuthState {
  const AuthFailure(this.error);

  @override
  final String error;
}

/// Sesi online valid, tapi PIN lokal belum diset (Task 5 mengisi ini).
class AuthPinSetupRequired extends AuthState {
  const AuthPinSetupRequired(this.profile);

  final AuthProfile profile;
}

/// Sesi penuh: token ada + PIN lokal sudah diset.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.profile);

  final AuthProfile profile;
}
