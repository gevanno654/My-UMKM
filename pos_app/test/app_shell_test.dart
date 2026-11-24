import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_app/core/nav/app_shell.dart';

/// Layar dummy: meniru layar fitur (AppBar sendiri + tombol drawer).
class _DummyScreen extends StatelessWidget {
  const _DummyScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Isi'),
        leading: const DrawerMenuButton(),
      ),
      body: const Text('isi'),
    );
  }
}

Future<void> pumpShell(WidgetTester tester, double width, String location) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/isi',
            builder: (_, state) => const _DummyScreen(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('layar sempit: tombol drawer di AppBar layar, rail tidak', (
    tester,
  ) async {
    await pumpShell(tester, 400, '/isi');
    expect(find.byKey(const Key('navDrawerButton')), findsOneWidget);
    expect(find.byKey(const Key('navRail')), findsNothing);
  });

  testWidgets('tablet: rail permanen tampil', (tester) async {
    await pumpShell(tester, 1000, '/isi');
    expect(find.byKey(const Key('navRail')), findsOneWidget);
    expect(find.byKey(const Key('nav-kasir')), findsOneWidget);
    expect(find.byKey(const Key('navDrawerButton')), findsNothing);
  });

  testWidgets('drawer memuat semua menu + toggle tema', (tester) async {
    await pumpShell(tester, 400, '/isi');
    await tester.tap(find.byKey(const Key('navDrawerButton')));
    await tester.pumpAndSettle();
    for (final key in [
      'nav-kasir',
      'nav-products',
      'nav-restocks',
      'nav-adjustments',
      'nav-reports',
      'themeToggleButton',
      'logoutButton',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });
}
