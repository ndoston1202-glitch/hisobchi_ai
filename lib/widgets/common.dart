import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../domain/enums.dart';
import '../domain/ledger.dart';

/// Yumaloq burchakli, yumshoq soyali kartochka.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: softShadow(context),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(cardRadius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Rangli fon ustida ikonka (tur yoki hamyon).
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type, this.size = 44});

  final TxType type;
  final double size;

  @override
  Widget build(BuildContext context) => IconBadge(icon: iconFor(type.icon), color: Color(type.color), size: size);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 56, color: muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ],
      ),
    );
  }
}

/// Tranzaksiya yoki o'tkazma qatori.
class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.item, required this.ledger, this.onTap, this.showDate = false});

  final HistoryItem item;
  final Ledger ledger;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final String title;
    final String subtitle;
    final Widget leading;
    final String amount;
    final Color amountColor;

    final when = showDate ? '${formatShortDate(item.date)}, ${formatTime(item.date)}' : formatTime(item.date);
    if (item.txn case final t?) {
      final type = ledger.typeById[t.typeId]!;
      final person = t.personId == null ? null : ledger.personById[t.personId]?.name;
      final income = type.direction == TxDirection.income;
      title = person == null ? type.name : '${type.name} · $person';
      subtitle = [ledger.walletById[t.walletId]?.name ?? '', when, if (t.note.isNotEmpty) t.note].join(' · ');
      leading = TypeBadge(type: type);
      amount = '${income ? '+' : '−'}${formatAmount(t.amount)}';
      amountColor = income ? incomeColor : expenseColor;
    } else {
      final tr = item.transfer!;
      title = "O'tkazma";
      subtitle = [
        '${ledger.walletById[tr.fromWalletId]?.name} → ${ledger.walletById[tr.toWalletId]?.name}',
        when,
        if (tr.note.isNotEmpty) tr.note,
      ].join(' · ');
      leading = IconBadge(icon: Icons.swap_horiz_rounded, color: theme.colorScheme.primary);
      amount = formatAmount(tr.amount);
      amountColor = theme.colorScheme.onSurface;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(amount, style: TextStyle(color: amountColor, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Yozish paytida `117 200` ko'rinishida formatlaydi.
class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 13) digits = digits.substring(0, 13);
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final text = digits.isEmpty ? '' : formatAmount(int.parse(digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8, left: 2),
        child: Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        ),
      );
}

/// Sana tanlash maydoni.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onTap, this.placeholder = 'Tanlanmagan', this.onClear, this.color});

  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String placeholder;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.event_rounded, color: color),
          suffixIcon: value != null && onClear != null
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClear, tooltip: 'Tozalash')
              : null,
        ),
        child: Text(
          value == null ? placeholder : formatDate(value!),
          style: TextStyle(color: value == null ? theme.colorScheme.onSurfaceVariant : null, fontSize: 16),
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false, bool warning = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? expenseColor : (warning ? warningColor : null),
    ));
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String action = "O'chirish"}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bekor qilish')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: expenseColor, minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? DateTime(now.year - 10),
    lastDate: last ?? DateTime(now.year + 10),
  );
}

/// Oy tanlash: ◀ Oktabr 2026 ▶
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onShift});

  final DateTime month;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(onPressed: () => onShift(-1), icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Oldingi oy'),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            formatMonth(month),
            key: ValueKey(month),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: isCurrent ? null : () => onShift(1),
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Keyingi oy',
        ),
      ],
    );
  }
}
