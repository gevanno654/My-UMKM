import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme_mode_provider.dart';
import '../../features/auth/auth_provider.dart';

/// Cangkang navigasi adaptif: drawer di HP (<840dp), rail permanen di tablet.
/// Menu: Kasir, Kelola Produk, Restock, Opname, Laporan + toggle tema + Keluar.
///
/// Di HP shell TIDAK membuat AppBar sendiri (agar tidak bertumpuk dengan
/// AppBar layar fitur). Layar utama membuka drawer lewat [DrawerMenuButton]
/// yang dipasang sebagai `leading` AppBar mereka; sub-layar (push) mengandalkan
/// tombol kembali + swipe tepi drawer.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, this.selectedPath = ''});

  static const breakpoint = 840.0;

  final Widget child;

  /// Path route aktif untuk highlight menu; kosong = tanpa seleksi.
  final String selectedPath;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Akses pembuka drawer shell dari AppBar layar fitur (child Scaffold).
class DrawerHandle extends InheritedWidget {
  const DrawerHandle({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static DrawerHandle? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DrawerHandle>();

  @override
  bool updateShouldNotify(DrawerHandle old) => openDrawer != old.openDrawer;
}

/// Tombol hamburger untuk `leading` AppBar layar utama (mode HP).
class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final handle = DrawerHandle.maybeOf(context);
    // Di tablet (rail) atau di luar shell: tidak tampil apa-apa.
    if (handle == null ||
        MediaQuery.sizeOf(context).width >= AppShell.breakpoint) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('navDrawerButton'),
      icon: const Icon(Icons.menu_outlined),
      onPressed: handle.openDrawer,
    );
  }
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _items = [
    (key: 'nav-kasir', label: 'Kasir', icon: Icons.point_of_sale_outlined, path: '/sales'),
    (key: 'nav-products', label: 'Produk', icon: Icons.inventory_2_outlined, path: '/products'),
    (key: 'nav-restocks', label: 'Restock', icon: Icons.add_box_outlined, path: '/restocks'),
    (key: 'nav-adjustments', label: 'Opname', icon: Icons.fact_check_outlined, path: '/adjustments'),
    (key: 'nav-reports', label: 'Laporan', icon: Icons.bar_chart_outlined, path: '/reports'),
  ];

  int _selectedIndex(String location) {
    for (var i = 0; i < _items.length; i++) {
      if (location == _items[i].path ||
          location.startsWith('${_items[i].path}/')) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppShell.breakpoint;
    final selected = _selectedIndex(widget.selectedPath);
    final themeMode = switch (ref.watch(themeModeProvider)) {
      AsyncData(:final value) => value,
      _ => ThemeMode.system,
    };

    void go(int index) {
      if (index >= 0 && index < _items.length) context.go(_items[index].path);
    }

    Future<void> logout() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keluar dari akun?'),
          content: const Text(
            'Sesi di HP ini dihapus. Untuk masuk lagi perlu login ulang + PIN.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('confirmLogoutButton'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Keluar'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(authProvider.notifier).logout();
      }
    }

    final drawer = NavigationDrawer(
      selectedIndex: selected >= 0 ? selected : null,
      onDestinationSelected: (i) {
        Navigator.pop(context);
        go(i);
      },
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Image.asset('assets/logo.png', width: 40, height: 40),
              const SizedBox(width: 12),
              Text(
                'POS Warung',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        for (var i = 0; i < _items.length; i++)
          NavigationDrawerDestination(
            key: Key(_items[i].key),
            icon: Icon(_items[i].icon),
            label: Text(_items[i].label),
          ),
        const Divider(),
        ListTile(
          key: const Key('themeToggleButton'),
          leading: Icon(
            themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          title: Text(
            themeMode == ThemeMode.dark ? 'Mode terang' : 'Mode gelap',
          ),
          onTap: () {
            ref.read(themeModeProvider.notifier).setMode(
                  themeMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                );
          },
        ),
        ListTile(
          key: const Key('logoutButton'),
          leading: const Icon(Icons.logout_outlined),
          title: const Text('Keluar'),
          onTap: logout,
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        key: const Key('navRail'),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected >= 0 ? selected : null,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Image.asset(
                  'assets/logo.png',
                  width: 40,
                  height: 40,
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('themeToggleButton'),
                          tooltip: 'Ganti tema',
                          icon: Icon(
                            themeMode == ThemeMode.dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                          onPressed: () {
                            ref
                                .read(themeModeProvider.notifier)
                                .setMode(
                                  themeMode == ThemeMode.dark
                                      ? ThemeMode.light
                                      : ThemeMode.dark,
                                );
                          },
                        ),
                        IconButton(
                          key: const Key('logoutButton'),
                          tooltip: 'Keluar',
                          icon: const Icon(Icons.logout_outlined),
                          onPressed: logout,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: [
                for (var i = 0; i < _items.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_items[i].icon, key: Key(_items[i].key)),
                    label: Text(_items[i].label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      // Tanpa AppBar sendiri: judul + aksi milik layar fitur (child),
      // agar tidak ada dua AppBar bertumpuk di HP.
      key: _scaffoldKey,
      drawer: drawer,
      body: DrawerHandle(
        openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        child: widget.child,
      ),
    );
  }
}
