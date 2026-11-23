import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_state.dart';
import '../features/auth/home_placeholder.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/pin_setup_screen.dart';
import '../features/auth/pin_unlock_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/products/product_model.dart';
import '../features/products/products_screens.dart';
import '../features/products/scan_screen.dart';
import '../features/restocks/restocks_screens.dart';
import '../features/adjustments/adjustments_screens.dart';
import '../features/reports/reports_screens.dart';
import '../features/sales/printer_setup_screen.dart';
import '../features/sales/sales_screens.dart';

/// Semua route fondasi + produk + kasir + restock + laporan.
const appRoutePaths = <String>[
  '/splash',
  '/login',
  '/register',
  '/pin-setup',
  '/pin-unlock',
  '/home',
  '/products',
  '/products/new',
  '/products/scan',
  '/products/:id',
  '/products/:id/edit',
  '/sales',
  '/sales/pay',
  '/sales/receipt',
  '/sales/history',
  '/settings/printer',
  '/restocks',
  '/restocks/new',
  '/restocks/:id',
  '/adjustments',
  '/reports',
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
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
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
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductsListScreen(),
      ),
      GoRoute(
        path: '/products/new',
        builder: (context, state) => const ProductFormScreen(),
      ),
      GoRoute(
        path: '/products/scan',
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/products/:id/edit',
        builder: (context, state) => ProductFormScreen(
          product: state.extra as ProductModel?,
        ),
      ),
      GoRoute(
        path: '/sales',
        builder: (context, state) => const KasirScreen(),
      ),
      GoRoute(
        path: '/sales/pay',
        builder: (context, state) => const PayScreen(),
      ),
      GoRoute(
        path: '/sales/receipt',
        builder: (context, state) => const ReceiptScreen(),
      ),
      GoRoute(
        path: '/sales/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/settings/printer',
        builder: (context, state) => const PrinterSetupScreen(),
      ),
      GoRoute(
        path: '/restocks',
        builder: (context, state) => const RestocksListScreen(),
      ),
      GoRoute(
        path: '/restocks/new',
        builder: (context, state) => const RestockDraftScreen(),
      ),
      GoRoute(
        path: '/restocks/:id',
        builder: (context, state) => RestockDetailScreen(
          restockId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/adjustments',
        builder: (context, state) => const AdjustmentsListScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
    ],
  );
}
