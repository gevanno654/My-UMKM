import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/app_shell.dart';
import '../sales/sales_screens.dart' show resolveStore;
import 'adjustments_provider.dart';

/// Riwayat penyesuaian opname + sinkron + void per baris.
class AdjustmentsListScreen extends ConsumerStatefulWidget {
  const AdjustmentsListScreen({super.key});

  @override
  ConsumerState<AdjustmentsListScreen> createState() =>
      _AdjustmentsListScreenState();
}

class _AdjustmentsListScreenState extends ConsumerState<AdjustmentsListScreen> {
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (_booted || !mounted) return;
    _booted = true;
    final (storeId, _) = await resolveStore(ref);
    if (!mounted) return;
    await ref.read(adjustmentsProvider.notifier).load(storeId);
  }

  Future<void> _confirmVoid(String id, String name) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan penyesuaian?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('"$name" dibatalkan, stok dikembalikan.'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('voidReasonField'),
              controller: reason,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Alasan batal (wajib)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('voidButton'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final err = await ref
          .read(adjustmentsProvider.notifier)
          .voidAdjustment(id, reason.text);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adjustmentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opname'),
        leading: const DrawerMenuButton(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                state.lastError!,
                key: const Key('adjustErrorText'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: state.history.isEmpty
                ? const Center(child: Text('Belum ada penyesuaian'))
                : ListView.builder(
                    itemCount: state.history.length,
                    itemBuilder: (context, i) {
                      final a = state.history[i];
                      final date =
                          DateTime.fromMillisecondsSinceEpoch(a.createdAt)
                              .toLocal();
                      final dateStr =
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                      final diffStr =
                          '${a.diff > 0 ? '+' : ''}${a.diff} (${a.stockBefore} → ${a.stockAfter})';
                      return ListTile(
                        title: Text(a.name.isEmpty ? a.reason : a.name),
                        subtitle: Text(
                          '$diffStr • $dateStr • ${a.reason}'
                          '${a.isVoided ? ' • BATAL' : ''}',
                        ),
                        trailing: a.isVoided
                            ? const Text('BATAL')
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    diffStr.split(' ').first,
                                    style: TextStyle(
                                      // Hijau/merah = status selisih (±), bukan
                                      // identitas fitur. Skema M3 tidak punya
                                      // warna sukses, jadi pakai error/primary.
                                      color: a.diff > 0
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    key: Key('void-${a.id}'),
                                    tooltip: 'Batalkan',
                                    icon: const Icon(Icons.cancel_outlined),
                                    onPressed: () => _confirmVoid(
                                      a.id,
                                      a.name.isEmpty ? a.reason : a.name,
                                    ),
                                  ),
                                ],
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
