import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sales/sales_screens.dart' show formatRupiah, resolveStore;
import 'profit_bar_chart.dart';
import 'reports_provider.dart';

String _periodName(ReportPeriod p) => switch (p) {
  ReportPeriod.day => 'Harian',
  ReportPeriod.week => 'Mingguan',
  ReportPeriod.month => 'Bulanan',
};

String _rangeText(ReportPeriod period, int? anchorMillis) {
  final anchor = anchorMillis == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(anchorMillis);
  final range = rangeOf(period, anchor);
  final s = DateTime.fromMillisecondsSinceEpoch(range.startMillis);
  final e = DateTime.fromMillisecondsSinceEpoch(
    range.endMillis - 1,
  );
  String d(DateTime t) => '${t.day}/${t.month}/${t.year}';
  return '${d(s)} – ${d(e)}';
}

/// Layar laporan pendapatan offline: ringkasan + chart + laris + rincian.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
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
    await ref.read(reportsProvider.notifier).load(storeId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final notifier = ref.read(reportsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const Key('periodDayButton'),
                label: const Text('Harian'),
                selected: state.period == ReportPeriod.day,
                onSelected: (_) => notifier.setPeriod(ReportPeriod.day),
              ),
              ChoiceChip(
                key: const Key('periodWeekButton'),
                label: const Text('Mingguan'),
                selected: state.period == ReportPeriod.week,
                onSelected: (_) => notifier.setPeriod(ReportPeriod.week),
              ),
              ChoiceChip(
                key: const Key('periodMonthButton'),
                label: const Text('Bulanan'),
                selected: state.period == ReportPeriod.month,
                onSelected: (_) => notifier.setPeriod(ReportPeriod.month),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                key: const Key('prevPeriodButton'),
                tooltip: 'Periode sebelumnya',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => notifier.movePeriod(-1),
              ),
              Expanded(
                child: Text(
                  key: const Key('rangeLabel'),
                  '${_periodName(state.period)} • ${_rangeText(state.period, state.anchorMillis)}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                key: const Key('nextPeriodButton'),
                tooltip: 'Periode berikutnya',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => notifier.movePeriod(1),
              ),
              TextButton(
                key: const Key('todayButton'),
                onPressed: () => notifier.goToday(),
                child: const Text('Hari ini'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _card(
                'Omzet',
                formatRupiah(state.summary.revenue),
                const Key('revenueValue'),
              ),
              _card(
                'Laba kotor',
                formatRupiah(state.summary.profit),
                const Key('profitValue'),
              ),
              _card(
                'Transaksi',
                '${state.summary.txCount}',
                const Key('txValue'),
              ),
              _card(
                'Rata-rata struk',
                formatRupiah(state.summary.avgTicket),
                const Key('avgValue'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Omzet vs laba per hari',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ProfitBarChart(
            key: const Key('profitChart'),
            daily: state.daily,
          ),
          const SizedBox(height: 16),
          Text(
            'Produk laris',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (state.topProducts.isEmpty)
            const Text('Belum ada penjualan periode ini')
          else
            for (final t in state.topProducts)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t.name),
                trailing: Text('${t.qty}× • ${formatRupiah(t.revenue)}'),
              ),
          const SizedBox(height: 8),
          Text(
            'Rincian transaksi',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (state.sales.isEmpty)
            const Text('Belum ada transaksi (void dikecualikan)')
          else
            for (final s in state.sales)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.number),
                subtitle: Text(
                  '${formatRupiah(s.total)} • ${s.method.name} • ${s.items.length} item',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String label, String value, Key key) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            key: key,
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    ),
  );
}
