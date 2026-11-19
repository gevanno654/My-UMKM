import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Executor SQLite untuk AppDb.
///
/// - Test: teruskan `NativeDatabase.memory()`.
/// - Produksi: pakai [openFileDb] (async) — file `pos.db` di direktori
///   dokumen aplikasi sehingga cache selamat dari restart (offline-first).
///
/// Tidak ada executor malas kustom: [NativeDatabase.createInBackground]
/// sudah membuka koneksi di isolate latar.
QueryExecutor openMemoryDb() => NativeDatabase.memory();

Future<QueryExecutor> openFileDb({String fileName = 'pos.db'}) async {
  final dir = await getApplicationDocumentsDirectory();
  return NativeDatabase.createInBackground(File(p.join(dir.path, fileName)));
}
