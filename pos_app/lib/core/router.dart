import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Semua route fondasi. Screen asli (Task 4-5) akan menggantikan
/// [PlaceholderScreen] satu per satu tanpa mengubah path.
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
      for (final path in appRoutePaths)
        GoRoute(
          path: path,
          builder: (context, state) => PlaceholderScreen(path: path),
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
