import '../../core/db/app_db.dart';

/// Metode pembayaran kasir v1.
enum PayMethod { tunai, qris, transfer }

/// Item transaksi: snapshot nama + harga saat jual.
class SaleItemModel {
  const SaleItemModel({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
  });

  final String id;
  final String? productId;
  final String name;
  final int price;
  final int qty;

  int get subtotal => price * qty;
}

/// Transaksi penjualan (domain, bebas Drift kecuali konversi).
class SaleModel {
  const SaleModel({
    required this.id,
    required this.storeId,
    required this.number,
    required this.total,
    required this.paid,
    required this.change,
    required this.method,
    required this.status,
    this.voidReason,
    required this.createdAt,
    this.items = const [],
  });

  final String id;
  final String storeId;
  final String number;
  final int total;
  final int paid;
  final int change;
  final PayMethod method;
  final String status;
  final String? voidReason;
  final int createdAt;
  final List<SaleItemModel> items;

  bool get isVoided => status == 'voided';
}

/// Inisial toko untuk nomor struk: huruf pertama tiap kata (A-Z),
/// maks 3 kata pertama; nama satu kata → 3 huruf pertama.
/// Contoh: "Toko Evan" → TE, "Warung Barokah Jaya" → WBJ, "Sembako" → SEM.
String receiptInitials(String storeName) {
  final words = storeName
      .toUpperCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(3)
      .toList();
  if (words.isEmpty) return 'XX';
  if (words.length == 1) {
    final letters = words.first.replaceAll(RegExp(r'[^A-Z]'), '');
    if (letters.isEmpty) return 'XX';
    return letters.substring(0, letters.length >= 3 ? 3 : letters.length);
  }
  return words.map((w) => w[0]).join();
}

/// Format nomor struk: `<INISIAL><DDMMYYYY><NNNN>` (seq zero-pad min 4).
String formatReceipt(String initials, DateTime date, int seq) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString().padLeft(4, '0');
  return '$initials$dd$mm$yyyy${seq.toString().padLeft(4, '0')}';
}

/// Konversi baris Drift → domain.
extension SaleRowX on Sale {
  SaleModel toModel(List<SaleItem> rows) => SaleModel(
    id: id,
    storeId: storeId,
    number: number,
    total: total,
    paid: paid,
    change: change,
    method: PayMethod.values.byName(method),
    status: status,
    voidReason: voidReason,
    createdAt: createdAt,
    items: rows
        .map(
          (r) => SaleItemModel(
            id: r.id,
            productId: r.productId,
            name: r.name,
            price: r.price,
            qty: r.qty,
          ),
        )
        .toList(),
  );
}
