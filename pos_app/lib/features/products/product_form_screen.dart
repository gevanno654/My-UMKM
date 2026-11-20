import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_store.dart';
import 'product_model.dart';
import 'products_provider.dart';

/// Form tambah/ubah produk: field nama/barcode/harga/stok/kategori + foto
/// (dialog Kamera/Galeri → preview → hapus foto). Scan barcode via kamera
/// diarahkan ke `/products/scan` (route dipasang Task 5).
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final ProductModel? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _sell;
  late final TextEditingController _stock;
  late final TextEditingController _category;

  String _photoPath = '';
  bool _saving = false;
  String? _submitError;

  static final _picker = ImagePicker();

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _cost = TextEditingController(text: p == null ? '' : '${p.costPrice}');
    _sell = TextEditingController(text: p == null ? '' : '${p.sellPrice}');
    _stock = TextEditingController(text: p == null ? '' : '${p.stock}');
    _category = TextEditingController(text: p?.category ?? '');
    _photoPath = p?.photoPath ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _cost.dispose();
    _sell.dispose();
    _stock.dispose();
    _category.dispose();
    super.dispose();
  }

  int _parseInt(String raw) => int.tryParse(raw.trim()) ?? -1;

  String? _numberValidator(String? v, String label, {bool allowEmpty = false}) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return allowEmpty ? null : '$label wajib diisi';
    final n = int.tryParse(raw);
    if (n == null || n < 0 || n > 999999999) {
      return '$label harus angka 0..999999999';
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sumber foto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('photoCameraOption'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              key: const Key('photoGalleryOption'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      final relative = await PhotoStore().savePicked(picked);
      if (!mounted) return;
      setState(() => _photoPath = relative);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitError = 'Gagal mengambil foto. Coba lagi.');
    }
  }

  Future<void> _scanBarcode() async {
    if (!mounted) return;
    final result = await context.push<String>('/products/scan');
    if (!mounted || result == null) return;
    setState(() => _barcode.text = result);
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _submitError = null);
    if (!_formKey.currentState!.validate()) return;
    final error = ProductModel.validate(
      name: _name.text,
      costPrice: _parseInt(_cost.text),
      sellPrice: _parseInt(_sell.text),
      stock: _parseInt(_stock.text),
      category: _category.text,
    );
    if (error != null) {
      setState(() => _submitError = error);
      return;
    }
    setState(() => _saving = true);
    try {
      final notifier = ref.read(productsProvider.notifier);
      final existing = widget.product;
      final model = existing != null
          ? ProductModel(
              id: existing.id,
              storeId: existing.storeId,
              name: _name.text.trim(),
              barcode: ProductModel.normalizeBarcode(_barcode.text),
              costPrice: _parseInt(_cost.text),
              sellPrice: _parseInt(_sell.text),
              stock: _parseInt(_stock.text),
              category: _category.text.trim(),
              photoPath: _photoPath,
              isArchived: existing.isArchived,
              createdAt: existing.createdAt,
              updatedAt: existing.updatedAt,
              deletedAt: existing.deletedAt,
            )
          : notifier.newProduct(
              name: _name.text.trim(),
              barcode: ProductModel.normalizeBarcode(_barcode.text),
              costPrice: _parseInt(_cost.text),
              sellPrice: _parseInt(_sell.text),
              stock: _parseInt(_stock.text),
              category: _category.text.trim(),
              photoPath: _photoPath,
            );
      final saveError = await notifier.saveProduct(model);
      if (!mounted) return;
      if (saveError != null) {
        setState(() => _submitError = saveError);
        return;
      }
      if (mounted) context.pop(true);
    } catch (_) {
      // Generic catch: form tidak boleh macet di loading.
      if (!mounted) return;
      setState(() => _submitError = 'Gagal menyimpan produk. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoStore = PhotoStore();
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Ubah Produk' : 'Tambah Produk'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _submitError!,
                    key: const Key('formErrorText'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              GestureDetector(
                key: const Key('photoPreview'),
                onTap: _pickPhoto,
                child: Center(
                  child: _photoPath.isEmpty
                      ? Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_outlined,
                            size: 40,
                            color: Colors.grey,
                          ),
                        )
                      : FutureBuilder(
                          future: photoStore.resolve(_photoPath),
                          builder: (context, snapshot) {
                            final file = snapshot.data;
                            if (file == null) {
                              return const SizedBox.square(
                                dimension: 120,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                file,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    key: const Key('photoButton'),
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      _photoPath.isEmpty ? 'Tambah foto' : 'Ganti foto',
                    ),
                  ),
                  if (_photoPath.isNotEmpty)
                    TextButton.icon(
                      key: const Key('photoRemoveButton'),
                      onPressed: () => setState(() => _photoPath = ''),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus foto'),
                    ),
                ],
              ),
              TextFormField(
                key: const Key('nameField'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nama produk'),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Nama produk wajib diisi'
                    : ((v ?? '').trim().length > 100
                        ? 'Nama produk maksimal 100 karakter'
                        : null),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('barcodeField'),
                controller: _barcode,
                decoration: InputDecoration(
                  labelText: 'Barcode (opsional)',
                  suffixIcon: IconButton(
                    key: const Key('scanButton'),
                    tooltip: 'Scan barcode',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('costField'),
                      controller: _cost,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga beli',
                      ),
                      validator: (v) =>
                          _numberValidator(v, 'Harga beli'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('sellField'),
                      controller: _sell,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga jual',
                      ),
                      validator: (v) =>
                          _numberValidator(v, 'Harga jual'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('stockField'),
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stok'),
                      validator: (v) => _numberValidator(v, 'Stok'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('categoryField'),
                      controller: _category,
                      decoration: const InputDecoration(
                        labelText: 'Kategori (opsional)',
                      ),
                      validator: (v) => (v ?? '').length > 50
                          ? 'Kategori maksimal 50 karakter'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                key: const Key('saveButton'),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_editing ? 'Simpan perubahan' : 'Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
