import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../domain/enums.dart';
import '../../domain/ledger.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../shell/shell.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const Center(child: CircularProgressIndicator());
    final filter = ref.watch(historyFilterProvider);
    final notifier = ref.read(historyFilterProvider.notifier);
    final items = ledger.history(month: filter.month, typeId: filter.typeId, walletId: filter.walletId);

    var income = 0;
    var expense = 0;
    for (final item in items) {
      final t = item.txn;
      if (t == null || ledger.kindOf(t) != TxKind.normal) continue;
      if (ledger.directionOf(t) == TxDirection.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    // Kunlar bo'yicha guruhlash
    final groups = <DateTime, List<HistoryItem>>{};
    for (final item in items) {
      groups.putIfAbsent(DateTime(item.date.year, item.date.month, item.date.day), () => []).add(item);
    }

    final type = ledger.typeById[filter.typeId];
    final wallet = ledger.walletById[filter.walletId];

    return Scaffold(
      appBar: AppBar(title: const Text('Tarix')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Center(child: MonthSwitcher(month: filter.month, onShift: notifier.shiftMonth)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: type?.name ?? 'Barcha turlar',
                  icon: type == null ? Icons.category_rounded : iconFor(type.icon),
                  active: type != null,
                  onTap: () => _pickType(context, ref, ledger),
                  onClear: type == null ? null : () => notifier.setType(null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: wallet?.name ?? 'Barcha hamyonlar',
                  icon: wallet == null ? Icons.account_balance_wallet_rounded : iconFor(wallet.icon),
                  active: wallet != null,
                  onTap: () => _pickWallet(context, ref, ledger),
                  onClear: wallet == null ? null : () => notifier.setWallet(null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _TotalTile(label: 'Kirim', amount: income, color: incomeColor)),
              const SizedBox(width: 10),
              Expanded(child: _TotalTile(label: 'Chiqim', amount: expense, color: expenseColor)),
            ],
          ),
          if (items.isEmpty)
            const EmptyState(icon: Icons.inbox_rounded, text: 'Bu davrda yozuv yo\'q')
          else
            for (final (i, entry) in groups.entries.indexed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                    child: Text(
                      formatDayHeader(entry.key),
                      style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Column(
                      children: [
                        for (final item in entry.value)
                          Dismissible(
                            key: ValueKey('${item.txn != null ? 't' : 'o'}${item.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: expenseColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: expenseColor),
                            ),
                            confirmDismiss: (_) => confirm(
                              context,
                              title: 'O\'chirish',
                              message: 'Bu yozuv butunlay o\'chiriladi.',
                            ),
                            onDismissed: (_) {
                              final repo = ref.read(repositoryProvider);
                              item.txn != null ? repo.deleteTransaction(item.id) : repo.deleteTransfer(item.id);
                              showSnack(context, 'O\'chirildi');
                            },
                            child: HistoryTile(item: item, ledger: ledger, onTap: () => openHistoryItem(context, item, ledger)),
                          ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms, delay: (30 * i.clamp(0, 10)).ms),
        ],
      ),
    );
  }

  Future<void> _pickType(BuildContext context, WidgetRef ref, Ledger ledger) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            ListTile(leading: const Icon(Icons.category_rounded), title: const Text('Barcha turlar'), onTap: () => Navigator.pop(context, -1)),
            for (final direction in TxDirection.values) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(direction == TxDirection.income ? 'Kirim' : 'Chiqim', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              for (final t in ledger.types.where((t) => t.direction == direction))
                ListTile(
                  leading: TypeBadge(type: t, size: 36),
                  title: Text(t.archived ? '${t.name} (arxiv)' : t.name),
                  onTap: () => Navigator.pop(context, t.id),
                ),
            ],
          ],
        ),
      ),
    );
    if (id != null) ref.read(historyFilterProvider.notifier).setType(id == -1 ? null : id);
  }

  Future<void> _pickWallet(BuildContext context, WidgetRef ref, Ledger ledger) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_rounded),
            title: const Text('Barcha hamyonlar'),
            onTap: () => Navigator.pop(context, -1),
          ),
          for (final w in ledger.wallets)
            ListTile(
              leading: Icon(iconFor(w.icon)),
              title: Text(w.archived ? '${w.name} (arxiv)' : w.name),
              onTap: () => Navigator.pop(context, w.id),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (id != null) ref.read(historyFilterProvider.notifier).setWallet(id == -1 ? null : id);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.icon, required this.active, required this.onTap, this.onClear});

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: active,
      showCheckmark: false,
      onPressed: onTap,
      onDeleted: onClear,
      deleteIcon: const Icon(Icons.close_rounded, size: 18),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.label, required this.amount, required this.color});

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(formatMoney(amount), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
