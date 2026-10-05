import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/database.dart';
import '../../domain/enums.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../stats/stats_screen.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final statuses = {for (final s in ledger.budgetStatuses(DateTime.now())) s.type.id: s};
    final types = ledger.activeTypes(TxDirection.expense).where((t) => t.kind == TxKind.normal).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Byudjetlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Chiqim turiga oylik limit qo\'ying. 80% ga yetganda sariq, oshganda qizil bo\'ladi.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Column(
              children: [
                for (final t in types)
                  statuses[t.id] != null
                      ? InkWell(onTap: () => _editLimit(context, ref, t, statuses[t.id]!.limit), child: BudgetProgress(status: statuses[t.id]!))
                      : ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: TypeBadge(type: t, size: 30),
                          title: Text(t.name),
                          trailing: const Text('Limit yo\'q'),
                          onTap: () => _editLimit(context, ref, t, null),
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editLimit(BuildContext context, WidgetRef ref, TxType type, int? current) async {
    final controller = TextEditingController(text: current == null ? '' : formatAmount(current));
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${type.name} — oylik limit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [AmountInputFormatter()],
          decoration: const InputDecoration(suffixText: "so'm", hintText: '0 — olib tashlash'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, parseAmount(controller.text)),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await ref.read(repositoryProvider).setBudget(type.id, result);
  }
}
