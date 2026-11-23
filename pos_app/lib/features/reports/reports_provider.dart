import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/db/app_db.dart';
import 'package:pos_app/features/auth/auth_provider.dart';
import 'package:pos_app/features/sales/sale_model.dart';

/// Periode agregasi laporan.
enum ReportPeriod { day, week, month }

/// Batas rentang [start, end) dalam epoch millis.
class ReportRange {
  const ReportRange(this.startMillis, this.endMillis);
  final int startMillis;
  final int endMillis;

  bool contains(int createdAtMillis) =>
      createdAtMillis >= startMillis && createdAtMillis < endMillis;
}

/// Ringkasan angka laporan satu periode (void dikecualikan).
class ReportsSummary {
  const ReportsSummary({this.revenue = 0, this.profit = 0, this.txCount = 0});

  final int revenue;
  final int profit;
  final int txCount;

  int get avgTicket => txCount == 0 ? 0 : revenue ~/ txCount;
}

/// Satu bucket harian untuk chart.
class DailyBucket {
  const DailyBucket({required this.label, this.revenue = 0, this.profit = 0});
  final String label;
  final int revenue;
  final int profit;
}

/// Produk laris: agregat qty per nama (void dikecualikan).
class TopProduct {
  const TopProduct({required this.name, this.qty = 0, this.revenue = 0});
  final String name;
  final int qty;
  final int revenue;
}

class ReportsState {
  const ReportsState({
    this.period = ReportPeriod.day,
    this.anchorMillis,
    this.summary = const ReportsSummary(),
    this.daily = const [],
    this.topProducts = const [],
    this.sales = const [],
  });

  final ReportPeriod period;
  final int? anchorMillis;
  final ReportsSummary summary;
  final List<DailyBucket> daily;
  final List<TopProduct> topProducts;
  final List<SaleModel> sales;

  ReportsState copyWith({
    ReportPeriod? period,
    int? Function()? anchorMillis,
    ReportsSummary? summary,
    List<DailyBucket>? daily,
    List<TopProduct>? topProducts,
    List<SaleModel>? sales,
  }) => ReportsState(
    period: period ?? this.period,
    anchorMillis: anchorMillis == null ? this.anchorMillis : anchorMillis(),
    summary: summary ?? this.summary,
    daily: daily ?? this.daily,
    topProducts: topProducts ?? this.topProducts,
    sales: sales ?? this.sales,
  );
}

/// Batas rentang periode berisi [anchor] (waktu lokal).
/// week: Senin–Minggu; month: tanggal 1 s.d. akhir bulan.
ReportRange rangeOf(ReportPeriod period, DateTime anchor) {
  final day = DateTime(anchor.year, anchor.month, anchor.day);
  switch (period) {
    case ReportPeriod.day:
      return ReportRange(
        day.millisecondsSinceEpoch,
        day.add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
    case ReportPeriod.week:
      final monday = day.subtract(Duration(days: day.weekday - 1));
      return ReportRange(
        monday.millisecondsSinceEpoch,
        monday.add(const Duration(days: 7)).millisecondsSinceEpoch,
      );
    case ReportPeriod.month:
      final first = DateTime(day.year, day.month, 1);
      final next = DateTime(day.year, day.month + 1, 1);
      return ReportRange(
        first.millisecondsSinceEpoch,
        next.millisecondsSinceEpoch,
      );
  }
}

class ReportsNotifier extends Notifier<ReportsState> {
  AppDb get _db => ref.read(appDbProvider);
  String _storeId = '';

  @override
  ReportsState build() => const ReportsState();

  /// Muat ulang agregasi periode aktif dari DB lokal (read-only).
  Future<void> load(String storeId) async {
    _storeId = storeId;
    await _reload();
  }

  Future<void> setPeriod(ReportPeriod period) async {
    state = state.copyWith(period: period);
    await _reload();
  }

  /// Geser periode maju (+1) / mundur (-1), hitung dari anchor/jangkar.
  Future<void> movePeriod(int delta) async {
    final anchor = state.anchorMillis == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(state.anchorMillis!);
    DateTime next;
    switch (state.period) {
      case ReportPeriod.day:
        next = anchor.add(Duration(days: delta));
        break;
      case ReportPeriod.week:
        next = anchor.add(Duration(days: 7 * delta));
        break;
      case ReportPeriod.month:
        next = DateTime(anchor.year, anchor.month + delta, 1);
        break;
    }
    state = state.copyWith(
      anchorMillis: () => next.millisecondsSinceEpoch,
    );
    await _reload();
  }

  Future<void> goToday() async {
    state = state.copyWith(anchorMillis: () => null);
    await _reload();
  }

  Future<void> _reload() async {
    if (_storeId.isEmpty) return;
    final now = state.anchorMillis == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(state.anchorMillis!);
    final range = rangeOf(state.period, now);
    final rows = await _db.salesHistory(_storeId);
    final sales = <SaleModel>[];
    for (final row in rows) {
      if (row.status == 'voided') continue;
      if (row.createdAt < range.startMillis ||
          row.createdAt >= range.endMillis) {
        continue;
      }
      final items = await _db.saleItemsOf(row.id);
      sales.add(
        SaleModel(
          id: row.id,
          storeId: row.storeId,
          number: row.number,
          total: row.total,
          paid: row.paid,
          change: row.change,
          method: PayMethod.values.byName(row.method),
          status: row.status,
          voidReason: row.voidReason,
          createdAt: row.createdAt,
          items: items
              .map(
                (r) => SaleItemModel(
                  id: r.id,
                  productId: r.productId,
                  name: r.name,
                  price: r.price,
                  costPrice: r.costPrice,
                  qty: r.qty,
                ),
              )
              .toList(),
        ),
      );
    }

    var revenue = 0;
    var profit = 0;
    final qtyByName = <String, int>{};
    final revenueByName = <String, int>{};
    for (final s in sales) {
      revenue += s.total;
      for (final i in s.items) {
        profit += i.profit;
        qtyByName.update(i.name, (v) => v + i.qty, ifAbsent: () => i.qty);
        revenueByName.update(
          i.name,
          (v) => v + i.subtotal,
          ifAbsent: () => i.subtotal,
        );
      }
    }

    final dayCount = state.period == ReportPeriod.month
        ? DateTime(now.year, now.month + 1, 0).day
        : state.period == ReportPeriod.week
        ? 7
        : 1;
    final buckets = <DailyBucket>[];
    final origin = DateTime.fromMillisecondsSinceEpoch(range.startMillis);
    for (var d = 0; d < dayCount; d++) {
      final dayStart = DateTime(origin.year, origin.month, origin.day + d);
      final dayEnd = dayStart.add(const Duration(days: 1));
      var r = 0;
      var p = 0;
      for (final s in sales) {
        final created = DateTime.fromMillisecondsSinceEpoch(s.createdAt);
        if (created.isBefore(dayStart) || !created.isBefore(dayEnd)) continue;
        r += s.total;
        for (final i in s.items) {
          p += i.profit;
        }
      }
      buckets.add(
        DailyBucket(
          label: '${dayStart.day}/${dayStart.month}',
          revenue: r,
          profit: p,
        ),
      );
    }

    final top = qtyByName.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    state = state.copyWith(
      summary: ReportsSummary(
        revenue: revenue,
        profit: profit,
        txCount: sales.length,
      ),
      daily: buckets,
      topProducts: top
          .take(10)
          .map(
            (e) => TopProduct(
              name: e.key,
              qty: e.value,
              revenue: revenueByName[e.key] ?? 0,
            ),
          )
          .toList(),
      sales: sales,
    );
  }
}

final reportsProvider = NotifierProvider<ReportsNotifier, ReportsState>(
  ReportsNotifier.new,
);
