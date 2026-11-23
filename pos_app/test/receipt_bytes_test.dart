import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/sales/receipt_bytes.dart';
import 'package:pos_app/features/sales/sale_model.dart';
import 'package:pos_app/features/sales/sales_screens.dart' show formatRupiah;

SaleModel sampleSale() => const SaleModel(
  id: 's1',
  storeId: 'toko-1',
  number: 'TE231120260001',
  total: 12000,
  paid: 15000,
  change: 3000,
  method: PayMethod.tunai,
  status: 'completed',
  createdAt: 1763900000000,
  items: [
    SaleItemModel(id: 'i1', productId: 'p1', name: 'Indomie Goreng', price: 3500, qty: 2),
    SaleItemModel(id: 'i2', productId: 'p2', name: 'Teh Botol', price: 5000, qty: 1),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('layout helper: center/pair/item pas 32 kolom', () {
    expect(receiptCenter('Warung').length, lessThanOrEqualTo(32));
    expect(receiptPair('TOTAL', 'Rp12.000').length, 32);
    expect(
      receiptItemName('Nama Produk Yang Sangat Panjang Sekali Melebihi 32 Kolom').length,
      32,
    );
    expect(receiptItemLine(2, 3500, 7000).length, 32);
  });

  test('struk memuat nama warung, nomor, total, bayar, kembali', () async {
    final sale = sampleSale();
    final bytes = await buildReceiptBytes(sale: sale, storeName: 'Warung Barokah');
    final text = latin1.decode(bytes, allowInvalid: true);
    expect(text, contains('Warung Barokah'));
    expect(text, contains(sale.number));
    expect(text, contains(formatRupiah(sale.total)));
    expect(text, contains(formatRupiah(sale.paid)));
    expect(text, contains(formatRupiah(sale.change)));
  });
}
