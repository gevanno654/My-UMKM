import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Penyimpanan foto produk di direktori dokumen aplikasi.
///
/// - File fisik: `<docs>/product_photos/<uuid>.jpg`
/// - Di database hanya path relatif (`product_photos/<uuid>.jpg`) agar
///   tahan terhadap perubahan lokasi direktori antar perangkat/install.
class PhotoStore {
  PhotoStore({Directory? docsDirOverride}) : _docsDirOverride = docsDirOverride;

  static const _dirName = 'product_photos';
  static const _uuid = Uuid();

  final Directory? _docsDirOverride;

  Future<Directory> _docsDir() async =>
      _docsDirOverride ?? await getApplicationDocumentsDirectory();

  /// Salin hasil [picked] (kamera/galeri, dibatasi maxWidth 1024 + quality 80
  /// saat pick) ke `<docs>/product_photos/<uuid>.jpg`.
  /// Mengembalikan path relatif untuk kolom `photoPath` di DB.
  Future<String> savePicked(XFile picked, {String? filename}) async {
    final docs = await _docsDir();
    final dir = Directory(p.join(docs.path, _dirName));
    await dir.create(recursive: true);
    final name = filename ?? '${_uuid.v4()}.jpg';
    final dest = File(p.join(dir.path, p.basename(name)));
    await picked.saveTo(dest.path);
    // Path relatif selalu pakai '/' (posix) agar konsisten di DB
    // lintas platform — jangan pakai p.join (backslash di Windows).
    return '$_dirName/${p.basename(dest.path)}';
  }

  /// Path relatif (dari DB) → file absolut. Tidak menyentuh disk selain
  /// membangun path; pemanggil cek `exists()` bila perlu.
  Future<File> resolve(String relative) async {
    final docs = await _docsDir();
    final safe = p.normalize(relative).replaceAll('\\', '/');
    final parts = safe
        .split('/')
        .where((s) => s.isNotEmpty && s != '.' && s != '..')
        .toList();
    return File(p.joinAll([docs.path, ...parts]));
  }

  /// SHA-256 hex (64 char) isi file. Dipakai sebagai identitas foto
  /// lintas HP: sama persis → tidak perlu transfer ulang.
  Future<String> sha256Of(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Hapus file fisik dari path relatif. Dipakai saat purge (bukan saat
  /// soft delete — foto dipertahankan sampai purge fisik).
  Future<void> deleteFile(String relative) async {
    if (relative.isEmpty) return;
    try {
      final file = await resolve(relative);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Purge tidak boleh gagal karena satu file hilang/rusak.
    }
  }
}

/// Thumbnail foto produk: `Image.file` dengan fallback placeholder bila
/// file hilang/rusak — tidak boleh crash.
class ProductPhotoThumb extends StatelessWidget {
  const ProductPhotoThumb({
    super.key,
    required this.photoPath,
    required this.photoStore,
    this.size = 48,
  });

  final String photoPath;
  final PhotoStore photoStore;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (photoPath.isEmpty) return _placeholder;
    return FutureBuilder<File>(
      future: photoStore.resolve(photoPath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return _placeholder;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder,
          ),
        );
      },
    );
  }

  Widget get _placeholder => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.image_not_supported_outlined,
          size: size * 0.5,
          color: Colors.grey,
        ),
      );
}
