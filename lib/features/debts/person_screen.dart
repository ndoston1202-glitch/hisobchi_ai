import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/enums.dart';
import '../../domain/ledger.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../settings/people_screen.dart';
import '../shell/shell.dart';
import 'debts_screen.dart';

/// Bitta odam bilan qarz tarixi va tezkor "Qaytarildi" tugmalari.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final person = ledger?.personById[personId];
    if (ledger == null || person == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Topilmadi')));
    }
    final debt = ledger.debtOf(person);
    final now = DateTime.now();
    final history = [
      for (final t in ledger.txns)
        if (t.personId == personId) HistoryItem.txn(t),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          IconButton(
            tooltip: 'Tahrirlash',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => showPersonEditor(context, person: person),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (person.phone != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Row(
                children: [
                  const Icon(Icons.phone_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(person.phone!),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(child: _Balance(label: 'Menga qarzdor', amount: debt.owedToMe, color: incomeColor)),
              const SizedBox(width: 10),
              Expanded(child: _Balance(label: 'Men qarzdorman', amount: debt.iOwe, color: expenseColor)),
            ],
          ),
          const SizedBox(height: 14),
          if (debt.owedToMe > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: incomeColor),
                onPressed: () => openDebtForm(context, ledger, TxKind.debtCollect, person: person.name, amount: debt.owedToMe),
                icon: const Icon(Icons.check_circle_rounded),
                label: Text('Qaytarib oldim · ${formatMoney(debt.owedToMe)}'),
              ),
            ),
          if (debt.iOwe > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: expenseColor),
                onPressed: () => openDebtForm(context, ledger, TxKind.debtRepay, person: person.name, amount: debt.iOwe),
                icon: const Icon(Icons.check_circle_rounded),
                label: Text('Qaytardim · ${formatMoney(debt.iOwe)}'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => openDebtForm(context, ledger, TxKind.debtGive, person: person.name),
                  child: const Text('Qarz berish'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => openDebtForm(context, ledger, TxKind.debtTake, person: person.name),
                  child: const Text('Qarz olish'),
                ),
              ),
            ],
          ),
          if (debt.open.any((d) => d.dueDate != null)) ...[
            const SectionTitle('Ochiq qarzlar muddati'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final d in debt.open.where((d) => d.dueDate != null))
                    ListTile(
                      leading: Icon(
                        d.isOverdue(now) ? Icons.error_rounded : Icons.event_rounded,
                        color: d.isOverdue(now) ? expenseColor : warningColor,
                      ),
                      title: Text(d.owedToMe ? 'Undirish: ${formatMoney(d.remaining)}' : 'Qaytarish: ${formatMoney(d.remaining)}'),
                      subtitle: Text('${formatDate(d.dueDate!)} · ${formatDueRelative(d.dueDate!, now: now)}'),
                    ),
                ],
              ),
            ),
          ],
          const SectionTitle('Tarix'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: history.isEmpty
                ? const EmptyState(icon: Icons.history_rounded, text: 'Yozuvlar yo\'q')
                : Column(
                    children: [
                      for (final item in history)
                        HistoryTile(
                          item: item,
                          ledger: ledger,
                          showDate: true,
                          onTap: () => openHistoryItem(context, item, ledger),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.label, required this.amount, required this.color});

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(formatMoney(amount), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
