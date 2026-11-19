import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_db.dart';
import '../../core/session/secure_session.dart';
import 'auth_api.dart';
import 'auth_state.dart';

final secureSessionProvider = Provider<SecureSession>((ref) {
  return SecureSession();
});

final appDbProvider = Provider<AppDb>((ref) {
  final db = AppDb(NativeDatabase.memory());
  ref.onDispose(db.close);
  return db;
});

final authApiProvider = Provider<AuthApi>((ref) => AuthApi());

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Orkestrasi auth online: API → secure storage → cache Drift → state.
///
/// Register/login sukses → token tersimpan + profil ter-cache ke Drift +
/// state [AuthPinSetupRequired] (PIN belum ada) atau [AuthAuthenticated].
class AuthNotifier extends Notifier<AuthState> {
  late final AuthApi _api;
  late final SecureSession _session;
  late final AppDb _db;

  @override
  AuthState build() {
    _api = ref.watch(authApiProvider);
    _session = ref.watch(secureSessionProvider);
    _db = ref.watch(appDbProvider);
    return const AuthInitial();
  }

  Future<void> bootstrap() async {
    final tokens = await _session.readTokens();
    if (tokens.accessToken == null ||
        tokens.refreshToken == null ||
        tokens.profileJson == null) {
      state = const AuthUnauthenticated();
      return;
    }
    final profile = AuthProfile.fromJson(
      jsonDecode(tokens.profileJson!) as Map<String, dynamic>,
    );
    state = tokens.pinHash == null
        ? AuthPinSetupRequired(profile)
        : AuthAuthenticated(profile);
  }

  Future<void> register({
    required String storeName,
    required String ownerName,
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      final result = await _api.register(
        storeName: storeName,
        ownerName: ownerName,
        email: email,
        password: password,
      );
      await _persistSuccess(result);
    } on DioException catch (e) {
      state = AuthUnauthenticated(error: AuthApi.friendlyError(e));
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      final result = await _api.login(email: email, password: password);
      await _persistSuccess(result);
    } on DioException catch (e) {
      state = AuthUnauthenticated(error: AuthApi.friendlyError(e));
    }
  }

  Future<void> refresh() async {
    final tokens = await _session.readTokens();
    if (tokens.refreshToken == null) {
      state = const AuthUnauthenticated(
        error: 'Sesi kedaluwarsa. Silakan login ulang.',
      );
      return;
    }
    state = const AuthLoading();
    try {
      final rotated = await _api.refresh(tokens.refreshToken!);
      await _session.saveTokens(
        accessToken: rotated.accessToken,
        refreshToken: rotated.refreshToken,
      );
      await bootstrap();
    } on DioException catch (e) {
      state = AuthUnauthenticated(error: AuthApi.friendlyError(e));
    }
  }

  Future<void> logout() async {
    await _session.clear();
    state = const AuthUnauthenticated();
  }

  Future<void> _persistSuccess(AuthResult result) async {
    await _session.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      profileJson: jsonEncode(result.profile.toJson()),
    );
    await _db.upsertStore(
      LocalStoresCompanion.insert(
        serverId: result.profile.storeId,
        name: result.profile.storeName,
      ),
    );
    await _db.upsertUser(
      LocalUsersCompanion.insert(
        serverId: result.profile.id,
        storeId: result.profile.storeId,
        name: result.profile.name,
        email: result.profile.email,
      ),
    );
    final tokens = await _session.readTokens();
    state = tokens.pinHash == null
        ? AuthPinSetupRequired(result.profile)
        : AuthAuthenticated(result.profile);
  }
}
