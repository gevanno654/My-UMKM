import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_db.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';
import 'printer_service.dart';
import 'receipt_bytes.dart';
import 'sale_model.dart';
import 'sales_provider.dart';

String formatRupiah(int value) {
  final digits = value.toString();
  final buf = StringBuffer();
  var count = 0;
  for (var i = digits.length - 1; i >= 0; i--) {
    buf.write(digits[i]);
    count++;
    if (count % 3 == 0 && i > 0) buf.write('.');
  }
  return 'Rp${buf.toString().split('').reversed.join()}';
}

/// Boot kasir: storeId dari auth, storeName dari profil tersimpan.
Future<(String, String)> resolveStore(WidgetRef ref) async {
  final authState = ref.read(authProvider);
  var storeId = switch (authState) {
    AuthAuthenticated(profile: final p) => p.storeId,
    AuthPinSetupRequired(profile: final p) => p.storeId,
    AuthPinLocked(profile: final p) => p.storeId,
    _ => '',
  };
  var storeName = switch (authState) {
    AuthAuthenticated(profile: final p) => p.storeName,
    AuthPinSetupRequired(profile: final p) => p.storeName,
    AuthPinLocked(profile: final p) => p.storeName,
    _ => '',
  };
  if (storeId.isEmpty) {
    try {
      final tokens = await ref.read(secureSessionProvider).readTokens();
      final raw = tokens.profileJson;
      if (raw != null && raw.isNotEmpty) {
        final p = AuthProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        storeId = p.storeId;
        storeName = p.storeName;
      }
    } catch (_) {
      // Biarkan kosong; load menampilkan error.
    }
  }
  return (storeId, storeName);
}

/// Layar kasir: search produk + hasil + keranjang + total + Bayar.
class KasirScreen extends ConsumerStatefulWidget {
  const KasirScreen({super.key});

  @override
  ConsumerState<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends ConsumerState<KasirScreen> {
  final _search = TextEditingController();
  bool _booted = false;
  List<Product> _results = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (_booted || !mounted) return;
    _booted = true;
    final (storeId, storeName) = await resolveStore(ref);
    if (!mounted) return;
    await ref.read(salesProvider.notifier).load(storeId, storeName: storeName);
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _onSearchChanged(String q) async {
    _debounce?.cancel();
    final query = q.trim();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final db = ref.read(appDbProvider);
      final storeId = _storeIdOf();
      if (query.isEmpty || storeId.isEmpty) {
        setState(() => _results = []);
        return;
      }
      final rows = await db.searchProducts(storeId, query);
      if (!mounted) return;
      setState(() {
        _results = rows.where((p) => !p.isArchived && p.deletedAt == null).toList();
      });
    });
  }

  String _storeIdOf() {
    final authState = ref.read(authProvider);
    return switch (authState) {
      AuthAuthenticated(profile: final p) => p.storeId,
      AuthPinSetupRequired(profile: final p) => p.storeId,
      AuthPinLocked(profile: final p) => p.storeId,
      _ => '',
    };
  }

  Future<void> _openScan() async {
    final result = await context.push<String>('/products/scan');
    if (!mounted || result == null || result.isEmpty) return;
    _search.text = result;
    await _onSearchChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: [
          IconButton(
            key: const Key('historyButton'),
            tooltip: 'Riwayat',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/sales/history'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              key: const Key('kasirSearchField'),
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Cari nama / barcode…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Scan barcode',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _openScan,
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_results.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final p = _results[i];
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      '${formatRupiah(p.sellPrice)} • stok ${p.stock}',
                    ),
                    trailing: TextButton(
                      child: const Text('Tambah'),
                      onPressed: () async {
                        final err = await ref
                            .read(salesProvider.notifier)
                            .addItem(p.id, 1);
                        if (!context.mounted) return;
                        if (err != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                    ),
                    onTap: () async {
                      final err = await ref
                          .read(salesProvider.notifier)
                          .addItem(p.id, 1);
                      if (!context.mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                  );
                },
              ),
            ),
          const Divider(),
          Expanded(
            child: state.cartLines.isEmpty
                ? const Center(child: Text('Keranjang kosong'))
                : ListView.builder(
                    itemCount: state.cartLines.length,
                    itemBuilder: (context, i) {
                      final line = state.cartLines[i];
                      final product = state.catalog[line.productId];
                      final name = product?.name ?? 'Produk dihapus';
                      final price = product?.sellPrice ?? 0;
                      return ListTile(
                        title: Text(name),
                        subtitle: Text(formatRupiah(price)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () => ref
                                  .read(salesProvider.notifier)
                                  .setQty(line.productId, line.qty - 1),
                            ),
                            Text('${line.qty}'),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => ref
                                  .read(salesProvider.notifier)
                                  .setQty(line.productId, line.qty + 1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref
                                  .read(salesProvider.notifier)
                                  .setQty(line.productId, 0),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                state.lastError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total: ${formatRupiah(state.total)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton(
                  key: const Key('payButton'),
                  onPressed: state.cartLines.isEmpty
                      ? null
                      : () => context.push('/sales/pay'),
                  child: const Text('Bayar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layar bayar: metode + nominal tunai (cepat: Uang pas/50rb/100rb).
class PayScreen extends ConsumerStatefulWidget {
  const PayScreen({super.key});

  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen> {
  final _paid = TextEditingController();
  PayMethod _method = PayMethod.tunai;

  @override
  void dispose() {
    _paid.dispose();
    super.dispose();
  }

  int get _paidValue => int.tryParse(_paid.text.replaceAll('.', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesProvider);
    final change = _paidValue - state.total;
    final canPay = _method != PayMethod.tunai || _paidValue >= state.total;
    return Scaffold(
      appBar: AppBar(title: const Text('Bayar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Total: ${formatRupiah(state.total)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            SegmentedButton<PayMethod>(
              segments: const [
                ButtonSegment(value: PayMethod.tunai, label: Text('Tunai')),
                ButtonSegment(value: PayMethod.qris, label: Text('QRIS')),
                ButtonSegment(
                  value: PayMethod.transfer,
                  label: Text('Transfer'),
                ),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 12),
            if (_method == PayMethod.tunai) ...[
              TextField(
                key: const Key('paidField'),
                controller: _paid,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal bayar (Rp)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(
                      () => _paid.text = state.total.toString(),
                    ),
                    child: const Text('Uang pas'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _paid.text = '50000'),
                    child: const Text('50rb'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _paid.text = '100000'),
                    child: const Text('100rb'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Kembalian: ${formatRupiah(change < 0 ? 0 : change)}'),
            ] else
              const Text('Nominal = total (dicatat, tanpa verifikasi).'),
            const Spacer(),
            if (state.lastError != null)
              Text(
                state.lastError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            FilledButton(
              key: const Key('confirmPayButton'),
              onPressed: canPay
                  ? () async {
                      final err = await ref
                          .read(salesProvider.notifier)
                          .checkout(paid: _paidValue, method: _method);
                      if (!context.mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(err)));
                        return;
                      }
                      context.go('/sales/receipt');
                    }
                  : null,
              child: const Text('Konfirmasi Bayar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Struk layar: nomor, tanggal, item×qty, total, bayar, kembali, metode.
/// [ReceiptView] terstruktur terpisah agar printer Bluetooth tinggal plug-in.
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, this.printerService});

  /// Diinjeksi di test agar tidak menyentuh Bluetooth asli.
  final PrinterService? printerService;

  /// Cetak opt-in: bangun byte dari transaksi tampil → pilih printer → cetak.
  /// Gagal = snackbar saja; kasir tidak diblokir.
  Future<void> _print(BuildContext context, WidgetRef ref, SaleModel sale) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final (_, storeName) = await resolveStore(ref);
      final bytes = await buildReceiptBytes(sale: sale, storeName: storeName);
      final svc = printerService ?? PrinterService();
      final saved = await svc.savedMac();
      String? mac = saved;
      if (!context.mounted) return;
      if (mac == null) {
        mac = await showDialog<String>(
          context: context,
          builder: (context) => _PrinterDialog(service: svc),
        );
        if (mac == null) return;
        await svc.saveMac(mac);
      }
      await svc.printBytes(bytes, mac: mac);
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Struk tercetak.')));
    } on PrinterException catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mencetak. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(salesProvider);
    final sale = state.history.isEmpty ? null : state.history.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Struk')),
      body: sale == null
          ? const Center(child: Text('Belum ada transaksi'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ReceiptView(sale: sale)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _print(context, ref, sale),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Cetak Struk'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => context.go('/sales'),
                    child: const Text('Transaksi Baru'),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Dialog pilih printer: MAC tersimpan + daftar paired + simpan pilihan.
class _PrinterDialog extends StatefulWidget {
  const _PrinterDialog({required this.service});

  final PrinterService service;

  @override
  State<_PrinterDialog> createState() => _PrinterDialogState();
}

class _PrinterDialogState extends State<_PrinterDialog> {
  List<PrinterDevice> _devices = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final paired = await widget.service.pairedPrinters();
      if (!mounted) return;
      setState(() {
        _devices = paired.map((b) => PrinterDevice(b.name, b.macAdress)).toList();
        _loading = false;
      });
    } on PrinterException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memindai printer. Coba lagi.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Printer'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Text(_error!)
            : _devices.isEmpty
            ? const Text(
                'Tidak ada printer ter-pairing.\nPairing dulu di Pengaturan Bluetooth HP.',
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _devices.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(
                    _devices[i].name.isEmpty ? '(tanpa nama)' : _devices[i].name,
                  ),
                  subtitle: Text(_devices[i].mac),
                  onTap: () => Navigator.pop(context, _devices[i].mac),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
      ],
    );
  }
}

/// Nama + MAC printer untuk dialog (terlepas dari tipe paket).
class PrinterDevice {
  const PrinterDevice(this.name, this.mac);

  final String name;
  final String mac;
}

class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.sale});

  final SaleModel sale;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              sale.number,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              DateTime.fromMillisecondsSinceEpoch(
                sale.createdAt,
              ).toLocal().toString(),
            ),
            const Divider(),
            for (final i in sale.items)
              Text(
                '${i.name} ×${i.qty} — ${formatRupiah(i.subtotal)}',
              ),
            const Divider(),
            Text('Total: ${formatRupiah(sale.total)}'),
            Text('Bayar (${sale.method.name}): ${formatRupiah(sale.paid)}'),
            Text('Kembali: ${formatRupiah(sale.change)}'),
          ],
        ),
      ),
    );
  }
}

/// Riwayat transaksi + sinkron + void per item (alasan wajib).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (_booted || !mounted) return;
    _booted = true;
    final (storeId, storeName) = await resolveStore(ref);
    if (!mounted) return;
    await ref.read(salesProvider.notifier).load(storeId, storeName: storeName);
  }

  Future<void> _confirmVoid(String id, String number) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void transaksi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('"$number" dibatalkan, stok dikembalikan.'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('voidReasonField'),
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Alasan void (wajib)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('confirmVoidButton'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final err = await ref
          .read(salesProvider.notifier)
          .voidSale(id, reason.text);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
      ),
      body: state.history.isEmpty
          ? const Center(child: Text('Belum ada transaksi'))
          : ListView.builder(
              itemCount: state.history.length,
              itemBuilder: (context, i) {
                final s = state.history[i];
                return ListTile(
                  title: Text(s.number),
                  subtitle: Text(
                    '${formatRupiah(s.total)} • ${s.method.name}'
                    '${s.isVoided ? ' • VOID' : ''}',
                  ),
                  trailing: s.isVoided
                      ? const Text('VOID')
                      : IconButton(
                          key: const Key('voidButton'),
                          tooltip: 'Void',
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: () => _confirmVoid(s.id, s.number),
                        ),
                );
              },
            ),
    );
  }
}
