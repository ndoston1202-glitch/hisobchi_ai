import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../domain/draft.dart';
import '../../domain/enums.dart';
import '../../domain/ledger.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/logo.dart';
import '../debts/person_screen.dart';
import '../shell/shell.dart';
import '../transaction_form/transaction_sheet.dart';
import '../transfer/transfer_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const Center(child: CircularProgressIndicator());

    final now = DateTime.now();
    final balances = ledger.walletBalances();
    final month = ledger.monthTotals(now);
    final urgent = ledger.openDebts().where((d) => d.isDueWithin(now, 3)).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final recent = ledger.history().take(10).toList();

    final sections = <Widget>[
      _Header(now: now),
      _BalanceCard(total: ledger.totalBalance(), month: month),
      const SizedBox(height: 16),
      SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ledger.activeWallets.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final w = ledger.activeWallets[i];
            final balance = balances[w.id] ?? 0;
            return SizedBox(
              width: 140,
              child: AppCard(
                padding: const EdgeInsets.all(14),
                onTap: () {
                  ref.read(historyFilterProvider.notifier).showWallet(w.id);
                  ref.read(shellIndexProvider.notifier).go(1);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(iconFor(w.icon), color: brandColor),
                    const Spacer(),
                    Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      formatMoney(balance),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, color: balance < 0 ? expenseColor : null),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Kirim',
              icon: Icons.add_rounded,
              color: incomeColor,
              onTap: () => showTransactionSheet(context, const TransactionDraft(direction: TxDirection.income)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              label: 'Chiqim',
              icon: Icons.remove_rounded,
              color: expenseColor,
              onTap: () => showTransactionSheet(context, const TransactionDraft(direction: TxDirection.expense)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => showTransferSheet(context),
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text("Hamyonlar o'rtasida o'tkazma"),
      ),
      if (urgent.isNotEmpty) ...[
        const SectionTitle('Qarz muddatlari'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(children: [for (final d in urgent) _UrgentDebtTile(debt: d, now: now)]),
        ),
      ],
      SectionTitle(
        'Oxirgi yozuvlar',
        action: recent.isEmpty ? null : 'Barchasi',
        onAction: () => ref.read(shellIndexProvider.notifier).go(1),
      ),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: recent.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_rounded,
                text: 'Hali yozuv yo\'q.\n"Kirim" yoki "Chiqim" tugmasini bosing.',
              )
            : Column(
                children: [
                  for (final item in recent)
                    HistoryTile(
                      item: item,
                      ledger: ledger,
                      showDate: true,
                      onTap: () => openHistoryItem(context, item, ledger),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 24),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          for (final (i, s) in sections.indexed)
            s.animate().fadeIn(duration: 350.ms, delay: (40 * i).ms).slideY(begin: 0.06, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final greeting = now.hour < 5
        ? 'Xayrli tun'
        : now.hour < 12
            ? 'Xayrli tong'
            : now.hour < 18
                ? 'Xayrli kun'
                : 'Xayrli kech';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(
        children: [
          const HisobchiLogo(size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  formatDate(now),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.total, required this.month});

  final int total;
  final MonthTotals month;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34D399), brandColor, brandDark],
        ),
        boxShadow: [BoxShadow(color: brandColor.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Umumiy balans', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: total.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(value.round()),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Shu oy', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _MonthPill(icon: Icons.south_west_rounded, label: 'Kirim', amount: month.income)),
              const SizedBox(width: 10),
              Expanded(child: _MonthPill(icon: Icons.north_east_rounded, label: 'Chiqim', amount: month.expense)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthPill extends StatelessWidget {
  const _MonthPill({required this.icon, required this.label, required this.amount});

  final IconData icon;
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatAmount(amount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgentDebtTile extends StatelessWidget {
  const _UrgentDebtTile({required this.debt, required this.now});

  final OpenDebt debt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final overdue = debt.isOverdue(now);
    final color = overdue ? expenseColor : warningColor;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: IconBadge(icon: overdue ? Icons.error_rounded : Icons.schedule_rounded, color: color, size: 40),
      title: Text(
        debt.owedToMe ? '${debt.person.name} qarzini undiring' : '${debt.person.name}ga qarzingizni qaytaring',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${formatMoney(debt.remaining)} · ${formatDueRelative(debt.dueDate!, now: now)}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonScreen(personId: debt.person.id))),
    );
  }
}
