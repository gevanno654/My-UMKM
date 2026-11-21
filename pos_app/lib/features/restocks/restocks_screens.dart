import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_db.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';
import '../sales/sales_screens.dart' show formatRupiah, resolveStore;
import 'restocks_provider.dart';

/// Riwayat penerimaan + sinkron + FAB kulakan.
class RestocksListScreen extends ConsumerStatefulWidget {
  const RestocksListScreen({super.key});

  @override
  ConsumerState<RestocksListScreen> createState() =>
      _RestocksListScreenState();
}

class _RestocksListScreenState extends ConsumerState<RestocksListScreen> {
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (_booted || !mounted) return;
    _booted = true;
    final (storeId, _) = await resolveStore(ref);
    if (!mounted) return;
    await ref.read(restocksProvider.notifier).load(storeId);
  }

  Future<void> _sync() async {
    final session = ref.read(secureSessionProvider);
    final tokens = await session.readTokens();
    if (!mounted) return;
    await ref
        .read(restocksProvider.notifier)
        .syncNow(accessToken: tokens.accessToken ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restocksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restock'),
        actions: [
          IconButton(
            tooltip: 'Sinkron',
            icon: const Icon(Icons.sync_outlined),
            onPressed: _sync,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('kulakanButton'),
        tooltip: 'Kulakan',
        onPressed: () => context.push('/restocks/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                state.lastError!,
                key: const Key('restockErrorText'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: state.history.isEmpty
                ? const Center(child: Text('Belum ada penerimaan'))
                : ListView.builder(
                    itemCount: state.history.length,
                    itemBuilder: (context, i) {
                      final r = state.history[i];
                      final date =
                          DateTime.fromMillisecondsSinceEpoch(r.createdAt)
                              .toLocal();
                      final dateStr =
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                      return ListTile(
                        title: Text(
                          '${formatRupiah(r.total)} • ${r.items.length} item',
                        ),
                        subtitle: Text(
                          '$dateStr${r.isVoided ? ' • BATAL' : ''}',
                        ),
                        trailing: r.isVoided
                            ? const Text('BATAL')
                            : const Icon(Icons.chevron_right),
                        onTap: () => context.push('/restocks/${r.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Draft kulakan: search produk + scan + baris draft + ringkasan + simpan.
class RestockDraftScreen extends ConsumerStatefulWidget {
  const RestockDraftScreen({super.key});

  @override
  ConsumerState<RestockDraftScreen> createState() => _RestockDraftScreenState();
}

class _RestockDraftScreenState extends ConsumerState<RestockDraftScreen> {
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
    final (storeId, _) = await resolveStore(ref);
    if (!mounted) return;
    await ref.read(restocksProvider.notifier).load(storeId);
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
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
        _results =
            rows.where((p) => !p.isArchived && p.deletedAt == null).toList();
      });
    });
  }

  Future<void> _openScan() async {
    final result = await context.push<String>('/products/scan');
    if (!mounted || result == null || result.isEmpty) return;
    _search.text = result;
    await _onSearchChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restocksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kulakan Baru')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              key: const Key('restockSearchField'),
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
              height: 180,
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final p = _results[i];
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      '${formatRupiah(p.costPrice)} • stok ${p.stock}',
                    ),
                    trailing: TextButton(
                      child: const Text('Tambah'),
                      onPressed: () => _addProduct(p.id),
                    ),
                    onTap: () => _addProduct(p.id),
                  );
                },
              ),
            ),
          const Divider(),
          Expanded(
            child: state.draftLines.isEmpty
                ? const Center(child: Text('Draft kosong'))
                : ListView.builder(
                    itemCount: state.draftLines.length,
                    itemBuilder: (context, i) {
                      final line = state.draftLines[i];
                      return _DraftRow(line: line);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      state.lastError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Text(
                  'Total modal: ${formatRupiah(state.draftTotalModal)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('saveRestockButton'),
                  onPressed: state.draftLines.isEmpty ? null : _save,
                  child: const Text('Simpan Kulakan'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addProduct(String productId) async {
    final err =
        await ref.read(restocksProvider.notifier).addToDraft(productId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _save() async {
    final err = await ref.read(restocksProvider.notifier).saveRestock();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (mounted) context.pop();
  }
}

/// Satu baris draft: nama + stepper qty + harga beli + hapus.
class _DraftRow extends ConsumerStatefulWidget {
  const _DraftRow({required this.line});

  final RestockDraftLine line;

  @override
  ConsumerState<_DraftRow> createState() => _DraftRowState();
}

class _DraftRowState extends ConsumerState<_DraftRow> {
  late final TextEditingController _cost;

  @override
  void initState() {
    super.initState();
    _cost = TextEditingController(text: '${widget.line.costPrice}');
  }

  @override
  void didUpdateWidget(covariant _DraftRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.costPrice != widget.line.costPrice &&
        _cost.text != '${widget.line.costPrice}') {
      _cost.text = '${widget.line.costPrice}';
    }
  }

  @override
  void dispose() {
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final db = ref.watch(appDbProvider);
    return FutureBuilder<Product?>(
      future: db.getProduct(line.productId),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? '…';
        return Card(
          key: Key('draftLine-${line.productId}'),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name)),
                    IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(restocksProvider.notifier)
                          .removeFromDraft(line.productId),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Kurangi',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => ref
                          .read(restocksProvider.notifier)
                          .setDraftQty(line.productId, line.qty - 1),
                    ),
                    Text('${line.qty}'),
                    IconButton(
                      tooltip: 'Tambah',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => ref
                          .read(restocksProvider.notifier)
                          .setDraftQty(line.productId, line.qty + 1),
                    ),
                    const Spacer(),
                    Text(formatRupiah(line.subtotal)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('costPriceField-${line.productId}'),
                        controller: _cost,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga beli',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => ref
                            .read(restocksProvider.notifier)
                            .setDraftPrices(
                              line.productId,
                              costPrice: v.trim().isEmpty
                                  ? 0
                                  : int.tryParse(v.trim()) ?? -1,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Detail penerimaan + tombol batalkan (alasan wajib).
class RestockDetailScreen extends ConsumerStatefulWidget {
  const RestockDetailScreen({super.key, required this.restockId});

  final String restockId;

  @override
  ConsumerState<RestockDetailScreen> createState() =>
      _RestockDetailScreenState();
}

class _RestockDetailScreenState extends ConsumerState<RestockDetailScreen> {
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (_booted || !mounted) return;
    _booted = true;
    final profileJson =
        await ref.read(secureSessionProvider).readTokens().then(
              (t) => t.profileJson,
            ).catchError((_) => null);
    var storeId = '';
    if (profileJson != null && profileJson.isNotEmpty) {
      try {
        storeId = AuthProfile.fromJson(
          jsonDecode(profileJson) as Map<String, dynamic>,
        ).storeId;
      } catch (_) {
        // Biarkan kosong; riwayat tetap dari state bila sudah load.
      }
    }
    if (!mounted) return;
    if (storeId.isNotEmpty) {
      await ref.read(restocksProvider.notifier).load(storeId);
    }
  }

  Future<void> _confirmVoid(String id) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan penerimaan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Stok akan dikembalikan.'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('voidReasonField'),
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Alasan batal (wajib)',
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
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final err = await ref
          .read(restocksProvider.notifier)
          .voidRestock(id, reason.text);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      } else if (mounted) {
        context.pop();
      }
    }
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restocksProvider);
    final restock = state.history
        .where((e) => e.id == widget.restockId)
        .firstOrNull;
    if (restock == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Restock')),
        body: const Center(child: Text('Penerimaan tidak ditemukan.')),
      );
    }
    final date =
        DateTime.fromMillisecondsSinceEpoch(restock.createdAt).toLocal();
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Restock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Tanggal'),
            trailing: Text(date.toString()),
          ),
          ListTile(
            title: const Text('Total modal'),
            trailing: Text(formatRupiah(restock.total)),
          ),
          if (restock.isVoided)
            ListTile(
              title: const Text('Status'),
              trailing: Text('BATAL (${restock.voidReason ?? ''})'),
            ),
          const Divider(),
          for (final i in restock.items)
            ListTile(
              title: Text(i.name),
              subtitle: Text(
                '×${i.qty} • beli ${formatRupiah(i.costPrice)}'
                '${i.sellPrice != null ? ' • jual baru ${formatRupiah(i.sellPrice!)}' : ''}',
              ),
              trailing: Text(formatRupiah(i.subtotal)),
            ),
          const SizedBox(height: 16),
          if (!restock.isVoided)
            OutlinedButton.icon(
              key: const Key('voidRestockButton'),
              onPressed: () => _confirmVoid(restock.id),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Batalkan'),
            ),
        ],
      ),
    );
  }
}
