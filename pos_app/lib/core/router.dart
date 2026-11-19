import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/home_placeholder.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';

/// Semua route fondasi. Screen PIN (Task 5) masih placeholder.
const appRoutePaths = <String>[
  '/splash',
  '/login',
  '/register',
  '/pin-setup',
  '/pin-unlock',
  '/home',
];

GoRouter buildRouter({String initialLocation = '/splash'}) {
  return GoRouter(
    initialLocation: initialLocation,
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
        builder: (context, state) =>
            const PlaceholderScreen(path: '/pin-setup'),
      ),
      GoRoute(
        path: '/pin-unlock',
        builder: (context, state) =>
            const PlaceholderScreen(path: '/pin-unlock'),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePlaceholder(),
      ),
    ],
  );
}

/// Placeholder sementara; menampilkan path-nya agar mudah diverifikasi.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(path),
      ),
    );
  }
}
