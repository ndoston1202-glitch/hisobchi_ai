import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/ledger.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../settings/budgets_screen.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const Center(child: CircularProgressIndicator());
    final byType = ledger.expenseByType(_month);
    final totals = ledger.monthTotals(_month);
    final months = ledger.lastMonths(_month);
    final budgets = ledger.budgetStatuses(_month);

    final sections = <Widget>[
      Center(
        child: MonthSwitcher(
          month: _month,
          onShift: (d) => setState(() {
            _month = DateTime(_month.year, _month.month + d);
            _touched = null;
          }),
        ),
      ),
      Row(
        children: [
          Expanded(child: _Stat(label: 'Kirim', amount: totals.income, color: incomeColor)),
          const SizedBox(width: 10),
          Expanded(child: _Stat(label: 'Chiqim', amount: totals.expense, color: expenseColor)),
          const SizedBox(width: 10),
          Expanded(
            child: _Stat(
              label: 'Farq',
              amount: totals.income - totals.expense,
              color: totals.income >= totals.expense ? incomeColor : expenseColor,
            ),
          ),
        ],
      ),
      const SectionTitle('Chiqimlar tarkibi'),
      AppCard(
        child: byType.isEmpty
            ? const EmptyState(icon: Icons.donut_large_rounded, text: 'Bu oyda chiqim yo\'q')
            : Column(
                children: [
                  SizedBox(
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 64,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                if (!event.isInterestedForInteractions) return;
                                setState(() => _touched = response?.touchedSection?.touchedSectionIndex);
                              },
                            ),
                            sections: [
                              for (final (i, (type, sum)) in byType.indexed)
                                PieChartSectionData(
                                  value: sum.toDouble(),
                                  color: Color(type.color),
                                  radius: i == _touched ? 46 : 38,
                                  showTitle: false,
                                ),
                            ],
                          ),
                          duration: const Duration(milliseconds: 400),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _touched != null && _touched! < byType.length ? byType[_touched!].$1.name : 'Jami',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
                            ),
                            Text(
                              formatAmount(_touched != null && _touched! < byType.length ? byType[_touched!].$2 : totals.expense),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final (type, sum) in byType)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          TypeBadge(type: type, size: 34),
                          const SizedBox(width: 10),
                          Expanded(child: Text(type.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text(
                            '${(sum * 100 / math.max(1, totals.expense)).round()}%',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 12),
                          Text(formatAmount(sum), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      const SectionTitle('Oxirgi 6 oy'),
      AppCard(child: SizedBox(height: 220, child: _MonthsChart(months: months))),
      SectionTitle(
        'Byudjetlar',
        action: 'Sozlash',
        onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen())),
      ),
      AppCard(
        child: budgets.isEmpty
            ? const EmptyState(icon: Icons.savings_rounded, text: 'Byudjet belgilanmagan.\nChiqim turlariga oylik limit qo\'ying.')
            : Column(children: [for (final b in budgets) BudgetProgress(status: b)]),
      ),
      const SizedBox(height: 24),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Statistika')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final (i, s) in sections.indexed) s.animate().fadeIn(duration: 300.ms, delay: (40 * i).ms),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.amount, required this.color});

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(formatAmount(amount), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _MonthsChart extends StatelessWidget {
  const _MonthsChart({required this.months});

  final List<MonthTotals> months;

  @override
  Widget build(BuildContext context) {
    final maxValue = months.fold<int>(0, (m, t) => math.max(m, math.max(t.income, t.expense)));
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _Legend(color: incomeColor, text: 'Kirim'),
            const SizedBox(width: 12),
            _Legend(color: expenseColor, text: 'Chiqim'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxValue == 0 ? 1 : maxValue * 1.15,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(formatAmount(rod.toY.round()), const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= months.length) return const SizedBox();
                      final name = capitalize(monthName(months[i].month.month));
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(name.substring(0, 3), style: TextStyle(color: muted, fontSize: 12)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (final (i, m) in months.indexed)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(toY: m.income.toDouble(), color: incomeColor, width: 10, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: m.expense.toDouble(), color: expenseColor, width: 10, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 400),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      );
}

/// Byudjet progress chizig'i: ≥80% sariq, ≥100% qizil.
class BudgetProgress extends StatelessWidget {
  const BudgetProgress({super.key, required this.status});

  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.level) {
      BudgetLevel.ok => incomeColor,
      BudgetLevel.warning => warningColor,
      BudgetLevel.over => expenseColor,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TypeBadge(type: status.type, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(status.type.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(
                '${formatAmount(status.spent)} / ${formatAmount(status.limit)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: status.ratio.clamp(0, 1).toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
