import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';
import '../adjustments/adjustments_provider.dart' as adj;
import 'photo_store.dart';
import 'product_model.dart';
import 'products_provider.dart';

/// Daftar produk: search (nama/barcode), filter chip Aktif/Arsip,
/// thumbnail foto + nama + harga jual + stok + badge arsip,
/// FAB tambah, ikon scan di search, tombol Sinkron + status + error,
/// hapus via swipe/konfirmasi 2 langkah, arsip via menu.
class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() =>
      _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  final _search = TextEditingController();
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  /// Muat daftar toko dari sesi auth SEKALI saat layar dibuka.
  ///
  /// Tanpa ini `_storeId` notifier kosong → simpan gagal + sinkron
  /// menolak ("Toko belum dimuat"). Sumber storeId: state auth bila sudah
  /// terautentikasi, fallback ke profil tersimpan di secure storage
  /// (kasus state belum bootstrap).
  Future<void> _boot() async {
    if (_booted || !mounted) return;
    _booted = true;
    try {
      final authState = ref.read(authProvider);
      var storeId = switch (authState) {
        AuthAuthenticated(profile: final p) => p.storeId,
        AuthPinSetupRequired(profile: final p) => p.storeId,
        AuthPinLocked(profile: final p) => p.storeId,
        _ => '',
      };
      if (storeId.isEmpty && mounted) {
        try {
          final tokens = await ref.read(secureSessionProvider).readTokens();
          final raw = tokens.profileJson;
          if (raw != null && raw.isNotEmpty) {
            storeId = AuthProfile.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            ).storeId;
          }
        } catch (_) {
          // Fallback gagal → biarkan storeId kosong, load tetap dipanggil
          // agar error tampil di UI, bukan macet.
        }
      }
      if (!mounted) return;
      await ref.read(productsProvider.notifier).load(storeId);
    } catch (_) {
      // Boot tidak boleh melempar: error tampil via state.lastError.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openScan() async {
    if (!mounted) return;
    final result = await context.push<String>('/products/scan');
    if (!mounted || result == null || result.isEmpty) return;
    _search.text = result;
    await ref.read(productsProvider.notifier).setQuery(result);
  }

  Future<void> _confirmDelete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text('"$name" akan dihapus. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('confirmDeleteButton'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(productsProvider.notifier).deleteProduct(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);
    final photoStore = PhotoStore();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addButton'),
        tooltip: 'Tambah produk',
        onPressed: () async {
          await context.push('/products/new');
        },
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const Key('searchField'),
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Cari nama / barcode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  key: const Key('scanButton'),
                  tooltip: 'Scan barcode',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _openScan,
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  ref.read(productsProvider.notifier).setQuery(v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  key: const Key('filterAktifChip'),
                  label: const Text('Aktif'),
                  selected: !state.showArchived,
                  onSelected: (_) => ref
                      .read(productsProvider.notifier)
                      .toggleArchived(false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('filterArsipChip'),
                  label: const Text('Arsip'),
                  selected: state.showArchived,
                  onSelected: (_) => ref
                      .read(productsProvider.notifier)
                      .toggleArchived(true),
                ),
              ],
            ),
          ),
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                state.lastError!,
                key: const Key('listErrorText'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.products.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada produk. Ketuk + untuk menambah.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.products.length,
                        itemBuilder: (context, index) {
                          final p = state.products[index];
                          return Dismissible(
                            key: Key('product-${p.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (_) async {
                              await _confirmDelete(p.id, p.name);
                              return false;
                            },
                            child: ListTile(
                              leading: ProductPhotoThumb(
                                photoPath: p.photoPath,
                                photoStore: photoStore,
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(p.name)),
                                  if (p.isArchived)
                                    Container(
                                      key: Key('arsipBadge-${p.id}'),
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Arsip',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                'Rp${p.sellPrice} • Stok ${p.stock}',
                              ),
                              trailing: PopupMenuButton<String>(
                                key: Key('menu-${p.id}'),
                                onSelected: (value) async {
                                  final notifier = ref.read(
                                    productsProvider.notifier,
                                  );
                                  if (value == 'arsip') {
                                    await notifier.archiveProduct(
                                      p.id,
                                      !p.isArchived,
                                    );
                                  } else if (value == 'hapus' &&
                                      context.mounted) {
                                    await _confirmDelete(p.id, p.name);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'arsip',
                                    child: Text(
                                      p.isArchived
                                          ? 'Kembalikan dari arsip'
                                          : 'Arsipkan',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'hapus',
                                    child: Text('Hapus'),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                await context.push('/products/${p.id}');
                              },
                            ),
                          );
                        },
                      ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail produk: info lengkap + tombol ubah/arsip/hapus.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productsProvider);
    final product = state.products
        .where((e) => e.id == productId)
        .firstOrNull;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Produk')),
        body: const Center(child: Text('Produk tidak ditemukan.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            key: const Key('editButton'),
            tooltip: 'Ubah',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await context.push(
                '/products/${product.id}/edit',
                extra: product,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
          Center(
            child: ProductPhotoThumb(
              photoPath: product.photoPath,
              photoStore: PhotoStore(),
              size: 120,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Harga beli'),
            trailing: Text('Rp${product.costPrice}'),
          ),
          ListTile(
            title: const Text('Harga jual'),
            trailing: Text('Rp${product.sellPrice}'),
          ),
          ListTile(
            title: const Text('Stok'),
            trailing: Text('Stok: ${product.stock}'),
          ),
          if (product.barcode != null)
            ListTile(
              title: const Text('Barcode'),
              trailing: Text(product.barcode!),
            ),
          if (product.category.isNotEmpty)
            ListTile(
              title: const Text('Kategori'),
              trailing: Text(product.category),
            ),
          const SizedBox(height: 16),
          if (!product.isArchived)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('adjustButton'),
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Sesuaikan stok (opname)'),
                onPressed: () async {
                  await _openAdjustDialog(context, ref, product);
                },
              ),
            ),
          if (!product.isArchived) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('archiveButton'),
                  onPressed: () async {
                    await ref
                        .read(productsProvider.notifier)
                        .archiveProduct(
                          product.id,
                          !product.isArchived,
                        );
                  },
                  icon: const Icon(Icons.archive_outlined),
                  label: Text(
                    product.isArchived ? 'Kembalikan' : 'Arsipkan',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('deleteButton'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Hapus produk?'),
                        content: Text(
                          '"${product.name}" akan dihapus. Lanjutkan?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            key: const Key('confirmDeleteButton'),
                            onPressed: () =>
                                Navigator.pop(context, true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(productsProvider.notifier)
                          .deleteProduct(product.id);
                      if (context.mounted) context.pop();
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus'),
                ),
              ),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog sesuaikan stok: hasil hitung fisik + alasan wajib.
/// Sukses → tutup + snackbar; gagal → pesan tampil di dialog.
Future<void> _openAdjustDialog(
  BuildContext context,
  WidgetRef ref,
  ProductModel product,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _AdjustDialog(
      productId: product.id,
      productName: product.name,
      systemStock: product.stock,
      onSave: (physicalStock, reason) => ref
          .read(adj.adjustmentsProvider.notifier)
          .adjustStock(
            productId: product.id,
            physicalStock: physicalStock,
            reason: reason,
          ),
    ),
  );
  if (context.mounted) {
    // Baca ulang produk agar stok di layar ikut angka baru.
    await ref.read(productsProvider.notifier).refreshProduct(product.id);
  }
  if (context.mounted) {
    // Snackbar hanya bila benar-benar tersimpan (stok berubah).
    final updated = ref.read(productsProvider).products
        .where((e) => e.id == product.id)
        .firstOrNull;
    if (updated != null && updated.stock != product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok disesuaikan.')),
      );
    }
  }
}

class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({
    required this.productId,
    required this.productName,
    required this.systemStock,
    required this.onSave,
  });

  final String productId;
  final String productName;
  final int systemStock;
  final Future<String?> Function(int physicalStock, String reason) onSave;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  late final TextEditingController _physical;
  late final TextEditingController _reason;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _physical = TextEditingController(text: '${widget.systemStock}');
    _reason = TextEditingController();
  }

  @override
  void dispose() {
    _physical.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sesuaikan stok'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stok sistem: ${widget.systemStock}'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('physicalField'),
            controller: _physical,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Hasil hitung fisik',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('reasonField'),
            controller: _reason,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Alasan (wajib)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                key: const Key('adjustErrorText'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('saveAdjustButton'),
          onPressed: _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  final parsed = int.tryParse(_physical.text.trim());
                  final err = await widget.onSave(
                    parsed ?? -1,
                    _reason.text,
                  );
                  if (!context.mounted) return;
                  if (err != null) {
                    setState(() {
                      _error = err;
                      _saving = false;
                    });
                    return;
                  }
                  Navigator.pop(context);
                },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
