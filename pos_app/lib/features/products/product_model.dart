import 'package:drift/drift.dart';

import '../../core/db/app_db.dart';

/// Model domain produk (lapisan logika, bebas Drift kecuali konversi).
///
/// Uang = INTEGER rupiah (tanpa desimal). Waktu = millis UTC epoch.
class ProductModel {
  const ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.barcode,
    required this.costPrice,
    required this.sellPrice,
    this.stock = 0,
    this.category = '',
    this.photoPath = '',
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String storeId;
  final String name;
  final String? barcode;
  final int costPrice;
  final int sellPrice;
  final int stock;
  final String category;
  final String photoPath;
  final bool isArchived;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  /// Normalisasi barcode: trim; string kosong/blank → null (agar unik
  /// `(storeId, barcode)` tidak bentrok untuk produk tanpa barcode).
  static String? normalizeBarcode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Validasi form produk. Mengembalikan pesan error Indonesia, atau null
  /// bila valid. Batas: nama 1..100, kategori ≤50, angka 0..999999999.
  static String? validate({
    required String name,
    required int costPrice,
    required int sellPrice,
    required int stock,
    String category = '',
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return 'Nama produk wajib diisi';
    if (trimmedName.length > 100) {
      return 'Nama produk maksimal 100 karakter';
    }
    if (category.length > 50) return 'Kategori maksimal 50 karakter';
    if (costPrice < 0 || costPrice > 999999999) {
      return 'Harga beli harus antara 0 dan 999999999';
    }
    if (sellPrice < 0 || sellPrice > 999999999) {
      return 'Harga jual harus antara 0 dan 999999999';
    }
    if (stock < 0 || stock > 999999999) {
      return 'Stok harus antara 0 dan 999999999';
    }
    return null;
  }

  /// Bangun dari baris Drift.
  factory ProductModel.fromDb(Product row) => ProductModel(
    id: row.id,
    storeId: row.storeId,
    name: row.name,
    barcode: row.barcode,
    costPrice: row.costPrice,
    sellPrice: row.sellPrice,
    stock: row.stock,
    category: row.category,
    photoPath: row.photoPath,
    isArchived: row.isArchived,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );

  /// Companion untuk insert baris baru (id sudah UUID lokal).
  /// Barcode dinormalisasi; `dirty=1` agar ikut push sinkron.
  ProductsCompanion toInsertCompanion() => ProductsCompanion.insert(
    id: id,
    storeId: storeId,
    name: name,
    barcode: Value(normalizeBarcode(barcode)),
    costPrice: costPrice,
    sellPrice: sellPrice,
    stock: Value(stock),
    category: Value(category),
    photoPath: Value(photoPath),
    isArchived: Value(isArchived),
    createdAt: createdAt,
    updatedAt: updatedAt,
    dirty: const Value(1),
  );
}
