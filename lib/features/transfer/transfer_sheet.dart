import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../data/database.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

Future<void> showTransferSheet(BuildContext context, {Transfer? transfer}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TransferSheet(transfer: transfer),
  );
}

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet({this.transfer});

  final Transfer? transfer;

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  int? _from;
  int? _to;
  late final _amount = TextEditingController(
    text: widget.transfer == null ? '' : formatAmount(widget.transfer!.amount),
  );
  late final _note = TextEditingController(text: widget.transfer?.note ?? '');
  late DateTime _date = widget.transfer?.date ?? DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final wallets = ref.read(ledgerProvider)!.activeWallets;
    _from = widget.transfer?.fromWalletId ?? (wallets.length > 1 ? wallets[1].id : null);
    _to = widget.transfer?.toWalletId ?? (wallets.isNotEmpty ? wallets.first.id : null);
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(repositoryProvider).saveTransfer(
            id: widget.transfer?.id,
            fromWalletId: _from!,
            toWalletId: _to!,
            amount: parseAmount(_amount.text),
            date: _date,
            note: _note.text,
          );
      HapticFeedback.lightImpact();
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'O\'tkazma saqlandi');
      }
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, title: 'O\'chirish', message: 'O\'tkazma o\'chiriladi.') || !mounted) return;
    await ref.read(repositoryProvider).deleteTransfer(widget.transfer!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const SizedBox(height: 200);
    final theme = Theme.of(context);
    final balances = ledger.walletBalances();
    final wallets = [
      ...ledger.activeWallets,
      for (final id in [_from, _to])
        if (ledger.walletById[id] case final w? when w.archived) w,
    ];

    DropdownButtonFormField<int> walletDropdown(int? value, ValueChanged<int?> onChanged) => DropdownButtonFormField<int>(
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          items: [
            for (final w in wallets)
              DropdownMenuItem(
                value: w.id,
                child: Row(
                  children: [
                    Icon(iconFor(w.icon), color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(w.name, overflow: TextOverflow.ellipsis)),
                    Text(formatMoney(balances[w.id] ?? 0), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
          ],
          onChanged: onChanged,
        );

    final amount = parseAmount(_amount.text);
    final valid = amount > 0 && _from != null && _to != null && _from != _to;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: theme.colorScheme.primary, size: 32),
                const SizedBox(width: 8),
                Expanded(child: Text("O'tkazma", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), tooltip: 'Yopish'),
              ],
            ),
            const Divider(height: 20),
            const FieldLabel('Qayerdan'),
            walletDropdown(_from, (v) => setState(() => _from = v)),
            Center(
              child: IconButton.filledTonal(
                tooltip: 'Almashtirish',
                onPressed: () => setState(() {
                  final from = _from;
                  _from = _to;
                  _to = from;
                }),
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ),
            const Text('Qayerga'),
            const SizedBox(height: 8),
            walletDropdown(_to, (v) => setState(() => _to = v)),
            if (_from != null && _from == _to)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Hamyonlar har xil bo\'lishi kerak', style: TextStyle(color: Colors.redAccent)),
              ),
            const FieldLabel("Summa (so'm)"),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [AmountInputFormatter()],
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              decoration: const InputDecoration(hintText: '0', suffixText: "so'm"),
            ),
            const FieldLabel('Sana'),
            DateField(
              value: _date,
              onTap: () async {
                final picked = await pickDate(context, initial: _date);
                if (picked != null) {
                  setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
                }
              },
            ),
            const FieldLabel('Izoh'),
            TextField(
              controller: _note,
              maxLength: 120,
              decoration: const InputDecoration(hintText: 'Ixtiyoriy', counterText: ''),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.transfer != null) ...[
                  SizedBox(
                    width: 56,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Colors.redAccent, minimumSize: const Size(56, 52)),
                      onPressed: _delete,
                      child: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: FilledButton(onPressed: valid && !_saving ? _save : null, child: const Text('Saqlash'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
