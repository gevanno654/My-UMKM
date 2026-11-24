import 'package:flutter/material.dart';

import 'reports_provider.dart';

/// Chart batang berdampingan omzet vs laba per hari (CustomPainter).
/// Scroll horizontal bila bucket > 8 agar muat di HP kecil.
class ProfitBarChart extends StatelessWidget {
  const ProfitBarChart({super.key, required this.daily});

  final List<DailyBucket> daily;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (daily.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Belum ada data periode ini')),
      );
    }
    final maxValue = daily.fold<int>(
      1,
      (m, d) => d.revenue > m ? d.revenue : (d.profit > m ? d.profit : m),
    );
    final wide = daily.length > 8;
    final chart = SizedBox(
      width: wide ? daily.length * 56.0 : double.infinity,
      height: 180,
      child: CustomPaint(
        painter: _BarsPainter(
          daily: daily,
          maxValue: maxValue,
          revenue: scheme.primary,
          profit: scheme.outline,
          grid: scheme.outlineVariant,
        ),
      ),
    );
    final labels = SizedBox(
      width: wide ? daily.length * 56.0 : double.infinity,
      child: Row(
        children: [
          for (final d in daily)
            Expanded(
              child: Text(
                d.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
    final legend = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _swatch(scheme.primary, 'Omzet'),
        const SizedBox(width: 12),
        _swatch(scheme.outline, 'Laba'),
      ],
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        legend,
        const SizedBox(height: 8),
        chart,
        labels,
      ],
    );
    if (!wide) return body;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: daily.length * 56.0, child: body),
    );
  }

  /// Chart batang berdampingan omzet vs laba per hari (CustomPainter).
  /// Scroll horizontal bila bucket > 8 agar muat di HP kecil.
  /// Warna mengikuti skema tema (primary + outline), tanpa warna per fitur.
  Widget _swatch(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 4),
      Text(label),
    ],
  );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.daily,
    required this.maxValue,
    required this.revenue,
    required this.profit,
    required this.grid,
  });

  final List<DailyBucket> daily;
  final int maxValue;
  final Color revenue;
  final Color profit;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    // Grid + sumbu nol agar tinggi batang proporsional.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var g = 0; g <= 4; g++) {
      final y = size.height - (size.height * g / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final slot = size.width / daily.length;
    final barW = (slot / 3).clamp(8.0, 28.0);
    final rev = Paint()..color = revenue;
    final prof = Paint()..color = profit;
    for (var i = 0; i < daily.length; i++) {
      final d = daily[i];
      final cx = slot * i + slot / 2;
      final revH = size.height * (d.revenue / maxValue);
      final profH = size.height * (d.profit / maxValue);
      canvas.drawRect(
        Rect.fromLTWH(cx - barW - 1, size.height - revH, barW, revH),
        rev,
      );
      canvas.drawRect(
        Rect.fromLTWH(cx + 1, size.height - profH, barW, profH),
        prof,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.daily != daily ||
      old.maxValue != maxValue ||
      old.revenue != revenue ||
      old.profit != profit ||
      old.grid != grid;
}
