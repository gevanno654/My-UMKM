import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'printer_service.dart';
import 'receipt_bytes.dart';

/// Layar siapkan printer sekali: status + minta izin resmi + daftar tersaring.
///
/// Dipakai sekali di awal (dan saat ganti printer). Layar Struk tinggal
/// tombol Cetak tanpa dialog pilih.
class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key, this.service});

  /// Diinjeksi di test agar tidak menyentuh Bluetooth asli.
  final PrinterService? service;

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  PrinterService get _svc => widget.service ?? PrinterService();

  (String, String)? _saved;
  bool _loadingSaved = true;
  bool _scanning = false;
  PrinterPermission? _permission;
  List<BluetoothInfo> _printers = const [];
  List<BluetoothInfo> _others = const [];
  String? _error;
  bool _showOthers = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _svc.savedPrinter();
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _loadingSaved = false;
    });
  }

  Future<void> _setup() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final perm = await _svc.requestPermission();
      if (!mounted) return;
      setState(() => _permission = perm);
      if (perm != PrinterPermission.granted) return;
      final paired = await _svc.pairedPrinters();
      if (!mounted) return;
      final parts = partitionPrinters(paired);
      setState(() {
        _printers = parts.printers;
        _others = parts.others;
      });
    } on PrinterException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Gagal menyiapkan printer. Coba lagi.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _choose(BluetoothInfo device) async {
    final label = device.name.isEmpty ? device.macAdress : device.name;
    try {
      await _svc.savePrinter(name: label, mac: device.macAdress);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal menyimpan printer.')));
      return;
    }
    if (!mounted) return;
    setState(() {
      _saved = (label, device.macAdress);
      _printers = const [];
      _others = const [];
      _permission = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Printer tersimpan.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Struk')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.print_outlined),
              title: Text(
                _loadingSaved
                    ? 'Memuat…'
                    : _saved != null
                    ? 'Tersimpan: ${_saved!.$1}'
                    : 'Belum disiapkan',
              ),
              subtitle: _saved != null ? Text(_saved!.$2) : null,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _scanning ? null : _setup,
            icon: const Icon(Icons.bluetooth_outlined),
            label: Text(
              _saved != null ? 'Ganti Printer' : 'Siapkan Printer',
            ),
          ),
          if (_permission == PrinterPermission.permanentlyDenied) ...[
            const SizedBox(height: 8),
            const Text(
              'Izin ditolak permanen. Aktifkan "Perangkat di sekitar" di Pengaturan HP.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _svc.openSettings(),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Buka Pengaturan'),
            ),
          ],
          if (_permission == PrinterPermission.denied) ...[
            const SizedBox(height: 8),
            const Text(
              'Izin belum diberikan. Ketuk Siapkan lagi untuk memunculkan popup.',
            ),
          ],
          if (_scanning) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!),
          ],
          if (_printers.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Printer ditemukan:'),
            for (final d in _printers)
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(d.name.isEmpty ? '(tanpa nama)' : d.name),
                subtitle: Text(d.macAdress),
                onTap: () => _choose(d),
              ),
          ],
          if (_others.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              key: const Key('otherDevicesTile'),
              title: Text('Perangkat lain (${_others.length})'),
              initiallyExpanded: _showOthers,
              onExpansionChanged: (v) => setState(() => _showOthers = v),
              children: [
                for (final d in _others)
                  ListTile(
                    leading: const Icon(Icons.bluetooth_outlined),
                    title: Text(d.name.isEmpty ? '(tanpa nama)' : d.name),
                    subtitle: Text(d.macAdress),
                    onTap: () => _choose(d),
                  ),
              ],
            ),
          ],
          if (!_scanning &&
              _permission == PrinterPermission.granted &&
              _printers.isEmpty &&
              _others.isEmpty &&
              _error == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Tidak ada perangkat ter-pairing.\nPairing printer dulu di Pengaturan Bluetooth HP.',
            ),
          ],
        ],
      ),
    );
  }
}
