import 'package:go_router/go_router.dart';

import '../features/auth/auth_state.dart';
import '../features/auth/home_placeholder.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/pin_setup_screen.dart';
import '../features/auth/pin_unlock_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';

/// Semua route fondasi. Screen PIN sudah asli (Task 5).
const appRoutePaths = <String>[
  '/splash',
  '/login',
  '/register',
  '/pin-setup',
  '/pin-unlock',
  '/home',
];

/// Aturan gate auth murni (tanpa I/O) agar mudah diuji:
/// mengembalikan path redirect, atau null bila lokasi sudah benar.
///
/// - Sesi terkunci ([AuthPinLocked]) selalu diarahkan ke `/pin-unlock`.
/// - [AuthPinSetupRequired] diarahkan ke `/pin-setup`.
/// - [AuthAuthenticated] yang nyasar ke route tamu/gate diarahkan `/home`.
/// - [AuthUnauthenticated] hanya boleh di splash/login/register.
String? authRedirect(AuthState state, String location) {
  if (state is AuthPinLocked) {
    return location == '/pin-unlock' ? null : '/pin-unlock';
  }
  if (state is AuthPinSetupRequired) {
    return location == '/pin-setup' ? null : '/pin-setup';
  }
  if (state is AuthAuthenticated) {
    if (location == '/login' ||
        location == '/register' ||
        location == '/splash' ||
        location == '/pin-setup' ||
        location == '/pin-unlock') {
      return '/home';
    }
    return null;
  }
  if (state is AuthUnauthenticated) {
    if (location == '/login' ||
        location == '/register' ||
        location == '/splash') {
      return null;
    }
    return '/login';
  }
  // AuthInitial/AuthLoading/AuthFailure: biarkan alur berjalan (splash boot).
  return null;
}

GoRouter buildRouter({
  String initialLocation = '/splash',
  AuthState Function()? authSnapshot,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: authSnapshot == null
        ? null
        : (context, goState) =>
            authRedirect(authSnapshot(), goState.uri.path),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/pin-setup',
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/pin-unlock',
        builder: (context, state) => const PinUnlockScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePlaceholder(),
      ),
    ],
  );
}
