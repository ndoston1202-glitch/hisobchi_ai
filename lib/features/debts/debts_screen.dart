import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/draft.dart';
import '../../domain/enums.dart';
import '../../domain/ledger.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../transaction_form/transaction_sheet.dart';
import 'person_screen.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const Center(child: CircularProgressIndicator());
    final debts = ledger.personDebts();
    final owedToMe = debts.where((d) => d.owedToMe > 0).toList();
    final iOwe = debts.where((d) => d.iOwe > 0).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Qarzlar'),
          bottom: TabBar(
            tabs: [
              _SumTab(label: 'Menga qarzdor', amount: owedToMe.fold(0, (s, d) => s + d.owedToMe), color: incomeColor),
              _SumTab(label: 'Men qarzdorman', amount: iOwe.fold(0, (s, d) => s + d.iOwe), color: expenseColor),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DebtList(debts: owedToMe, owedToMe: true, ledger: ledger),
            _DebtList(debts: iOwe, owedToMe: false, ledger: ledger),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: expenseColor),
                    onPressed: () => openDebtForm(context, ledger, TxKind.debtGive),
                    icon: const Icon(Icons.north_east_rounded),
                    label: const Text('Qarz berish'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: incomeColor),
                    onPressed: () => openDebtForm(context, ledger, TxKind.debtTake),
                    icon: const Icon(Icons.south_west_rounded),
                    label: const Text('Qarz olish'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Qarz turini tanlagan holda formani ochadi.
void openDebtForm(BuildContext context, Ledger ledger, TxKind kind, {String? person, int? amount}) {
  final type = ledger.types.firstWhere((t) => t.kind == kind);
  showTransactionSheet(
    context,
    TransactionDraft(direction: kind.direction, typeId: type.id, personName: person, amount: amount),
  );
}

class _SumTab extends StatelessWidget {
  const _SumTab({required this.label, required this.amount, required this.color});

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Tab(
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(height: 2),
            Text(formatMoney(amount), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _DebtList extends StatelessWidget {
  const _DebtList({required this.debts, required this.owedToMe, required this.ledger});

  final List<PersonDebt> debts;
  final bool owedToMe;
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return EmptyState(
        icon: Icons.handshake_rounded,
        text: owedToMe ? 'Sizga hech kim qarzdor emas' : 'Sizda qarz yo\'q 🎉',
      );
    }
    final now = DateTime.now();
    final sorted = [...debts]..sort((a, b) {
        final da = a.nearestDue(owedToMe: owedToMe);
        final db = b.nearestDue(owedToMe: owedToMe);
        if (da == null && db == null) return a.person.name.compareTo(b.person.name);
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final d = sorted[i];
        final amount = owedToMe ? d.owedToMe : d.iOwe;
        final due = d.nearestDue(owedToMe: owedToMe);
        final overdue = due != null && due.isBefore(DateTime(now.year, now.month, now.day));
        final color = owedToMe ? incomeColor : expenseColor;
        return AppCard(
          color: overdue ? expenseColor.withValues(alpha: 0.08) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonScreen(personId: d.person.id))),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(
                  d.person.name.characters.first.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.person.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    if (due != null)
                      Row(
                        children: [
                          Icon(Icons.event_rounded, size: 14, color: overdue ? expenseColor : Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '${formatShortDate(due)} · ${formatDueRelative(due, now: now)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: overdue ? expenseColor : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: overdue ? FontWeight.w700 : null,
                            ),
                          ),
                        ],
                      )
                    else
                      Text('Muddatsiz', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(formatMoney(amount), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms, delay: (40 * i.clamp(0, 10)).ms).slideX(begin: 0.05);
      },
    );
  }
}
