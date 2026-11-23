import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'sale_model.dart';
import 'sales_screens.dart' show formatRupiah;

/// Lebar kolom kertas 58mm (font A).
const receiptColumns = 32;

/// Rata tengah dalam 32 kolom (murni, unit-testable).
String receiptCenter(String s) {
  final t = s.length > receiptColumns ? s.substring(0, receiptColumns) : s;
  final pad = ((receiptColumns - t.length) / 2).floor();
  return '${' ' * pad}$t';
}

/// Pasangan kiri-kanan dalam 32 kolom (murni, unit-testable).
String receiptPair(String left, String right) {
  final r = right.length > receiptColumns ? right.substring(right.length - receiptColumns) : right;
  final maxLeft = receiptColumns - r.length;
  if (maxLeft <= 1) return r.substring(0, receiptColumns);
  var l = left.length >= maxLeft ? '${left.substring(0, maxLeft - 2)}.' : left;
  return '$l${' ' * (receiptColumns - l.length - r.length)}$r';
}

/// Nama item: potong 32 kolom (murni, unit-testable).
String receiptItemName(String name) =>
    name.length > receiptColumns ? '${name.substring(0, receiptColumns - 1)}.' : name;

/// Baris harga item: `qty x harga ... subtotal` (murni).
String receiptItemLine(int qty, int price, int subtotal) =>
    receiptPair('$qty x ${formatRupiah(price)}', formatRupiah(subtotal));

/// Kata kunci nama perangkat yang kemungkinan printer struk.
final _printerNamePattern = RegExp(
  'printer|thermal|xprinter|iware|rpp|pos|58mm|80mm|btprinter',
  caseSensitive: false,
);

/// True bila [name] tampak seperti printer struk (mis. "RPP02N").
bool isLikelyPrinter(String name) => _printerNamePattern.hasMatch(name);

/// Rekord partisi daftar perangkat: printer kemungkinan + sisanya.
typedef PartitionedDevices = ({
  List<BluetoothInfo> printers,
  List<BluetoothInfo> others,
});

/// Pisah daftar paired: yang mirip printer di atas, sisanya di bawah.
/// Tidak ada yang hilang — semua perangkat tetap bisa dipilih.
PartitionedDevices partitionPrinters(List<BluetoothInfo> devices) {
  final printers = <BluetoothInfo>[];
  final others = <BluetoothInfo>[];
  for (final d in devices) {
    if (isLikelyPrinter(d.name)) {
      printers.add(d);
    } else {
      others.add(d);
    }
  }
  return (printers: printers, others: others);
}
///
/// Murni: tidak menyentuh printer/Bluetooth, aman untuk unit test.
/// [storeName] dilewat sebagai parameter (di-resolve via `resolveStore`).
Future<List<int>> buildReceiptBytes({
  required SaleModel sale,
  required String storeName,
}) async {
  final profile = await CapabilityProfile.load();
  final g = Generator(PaperSize.mm58, profile);
  final bytes = <int>[];

  bytes.addAll(
    g.text(receiptCenter(storeName), styles: const PosStyles(align: PosAlign.center, bold: true)),
  );
  bytes.addAll(
    g.text(receiptCenter('No: ${sale.number}'), styles: const PosStyles(align: PosAlign.center)),
  );
  final date = DateTime.fromMillisecondsSinceEpoch(sale.createdAt).toLocal();
  final dateStr =
      '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  bytes.addAll(g.text(receiptCenter(dateStr), styles: const PosStyles(align: PosAlign.center)));
  bytes.addAll(g.text('-' * receiptColumns));

  for (final i in sale.items) {
    bytes.addAll(g.text(receiptItemName(i.name)));
    bytes.addAll(g.text(receiptItemLine(i.qty, i.price, i.subtotal)));
  }

  bytes.addAll(g.text('-' * receiptColumns));
  bytes.addAll(
    g.text(
      receiptPair('TOTAL', formatRupiah(sale.total)),
      styles: const PosStyles(bold: true),
    ),
  );
  bytes.addAll(g.text(receiptPair(_methodLabel(sale.method), formatRupiah(sale.paid))));
  bytes.addAll(g.text(receiptPair('KEMBALI', formatRupiah(sale.change))));
  bytes.addAll(g.text('-' * receiptColumns));
  bytes.addAll(
    g.text(receiptCenter('Terima kasih'), styles: const PosStyles(align: PosAlign.center)),
  );
  bytes.addAll(
    g.text(receiptCenter('sampai jumpa kembali'), styles: const PosStyles(align: PosAlign.center)),
  );
  bytes.addAll(g.feed(2));

  return bytes;
}

String _methodLabel(PayMethod m) => switch (m) {
  PayMethod.tunai => 'TUNAI',
  PayMethod.qris => 'QRIS',
  PayMethod.transfer => 'TRANSFER',
};

String _month(int m) => const [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
][m];
