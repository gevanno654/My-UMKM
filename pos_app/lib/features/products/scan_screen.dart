import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Ambil barcode valid pertama dari daftar mentah: trim, abaikan null/kosong.
/// Mengembalikan null bila tidak ada yang valid.
String? firstBarcode(List<String?> values) {
  for (final v in values) {
    final trimmed = v?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

/// Layar scan barcode kamera penuh.
///
/// Hasil pertama yang valid langsung `pop` sebagai String ke pemanggil
/// (`/products` untuk cari, form untuk isi field). Permission kamera
/// ditolak → pesan ramah (tanpa dep tambahan).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final MobileScannerController _controller;
  bool _done = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done || !mounted) return;
    final code = firstBarcode(
      capture.barcodes.map((b) => b.rawValue).toList(),
    );
    if (code == null) return;
    _done = true;
    context.pop(code);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyalakan lampu. Coba lagi.')),
      );
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengganti kamera. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Barcode')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(_cameraError!, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text(
                  'Buka Pengaturan > Aplikasi > POS Warung > Izin, '
                  'lalu aktifkan Kamera dan coba lagi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            key: const Key('torchButton'),
            tooltip: 'Lampu',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: _toggleTorch,
          ),
          IconButton(
            key: const Key('flipCameraButton'),
            tooltip: 'Ganti kamera',
            icon: const Icon(Icons.flip_camera_ios_outlined),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error) {
          if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _cameraError == null) {
                setState(() {
                  _cameraError = 'Izin kamera ditolak.';
                });
              }
            });
          }
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
