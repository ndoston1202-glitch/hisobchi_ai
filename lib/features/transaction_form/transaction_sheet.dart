import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/repository.dart';
import '../../domain/draft.dart';
import '../../domain/enums.dart';
import '../../domain/ledger.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../settings/type_editor.dart';

/// Kirim/Chiqim oynasini ochadi (yangi yoki tahrirlash uchun).
Future<void> showTransactionSheet(BuildContext context, TransactionDraft draft) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TransactionSheet(draft: draft),
  );
}

/// Mavjud tranzaksiyani tahrirlash uchun draft.
TransactionDraft draftFromTxn(Txn t, Ledger ledger) => TransactionDraft(
      direction: ledger.directionOf(t),
      id: t.id,
      typeId: t.typeId,
      walletId: t.walletId,
      amount: t.amount,
      personName: t.personId == null ? null : ledger.personById[t.personId]?.name,
      note: t.note,
      date: t.date,
      dueDate: t.dueDate,
    );

const _newTypeValue = -1;

class TransactionSheet extends ConsumerStatefulWidget {
  const TransactionSheet({super.key, required this.draft});

  final TransactionDraft draft;

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  late int? _typeId = widget.draft.typeId;
  late int? _walletId = widget.draft.walletId;
  late final _amount = TextEditingController(
    text: widget.draft.amount == null ? '' : formatAmount(widget.draft.amount!),
  );
  late final _person = TextEditingController(text: widget.draft.personName ?? '');
  late final _note = TextEditingController(text: widget.draft.note ?? '');
  late DateTime _date = widget.draft.date ?? DateTime.now();
  late DateTime? _dueDate = widget.draft.dueDate;
  bool _showErrors = false;
  bool _saving = false;

  /// "Yangi tur qo'shish" bekor qilinganda dropdown'ni asl qiymatiga qaytarish uchun.
  int _typeFieldVersion = 0;

  bool get _isEdit => widget.draft.id != null;
  bool get _income => widget.draft.direction == TxDirection.income;
  Color get _accent => _income ? incomeColor : expenseColor;

  @override
  void initState() {
    super.initState();
    final ledger = ref.read(ledgerProvider)!;
    final types = ledger.activeTypes(widget.draft.direction);
    _typeId ??= types.isEmpty ? null : types.first.id;
    _walletId ??= ledger.activeWallets.isEmpty ? null : ledger.activeWallets.first.id;
    _amount.addListener(() => setState(() {}));
    _person.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _person.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _onTypeChanged(int? value) async {
    if (value == _newTypeValue) {
      final id = await showTypeEditor(context, direction: widget.draft.direction);
      setState(() {
        if (id != null) _typeId = id;
        _typeFieldVersion++;
      });
      return;
    }
    setState(() => _typeId = value);
  }

  Future<void> _save(Ledger ledger) async {
    final type = ledger.typeById[_typeId];
    if (type == null || _walletId == null) return;
    if (type.kind.isDebt && _person.text.trim().isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    final amount = parseAmount(_amount.text);
    final budgetWarning = _budgetWarning(ledger, type, amount);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    try {
      await ref.read(repositoryProvider).saveTransaction(
            id: widget.draft.id,
            typeId: type.id,
            walletId: _walletId!,
            amount: amount,
            date: _date,
            note: _note.text,
            personName: _person.text,
            dueDate: _dueDate,
          );
      HapticFeedback.lightImpact();
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text(budgetWarning ?? (_isEdit ? 'O\'zgarishlar saqlandi' : 'Saqlandi: ${type.name} — ${formatMoney(amount)}')),
        backgroundColor: budgetWarning != null ? warningColor : null,
      ));
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Saqlab bo\'lmadi: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Saqlashdan keyin oylik byudjet oshib ketadimi.
  String? _budgetWarning(Ledger ledger, TxType type, int amount) {
    if (type.kind != TxKind.normal || type.direction != TxDirection.expense) return null;
    final status = ledger.budgetStatuses(_date).where((s) => s.type.id == type.id).firstOrNull;
    if (status == null) return null;
    final original = widget.draft.id == null ? null : ledger.txns.where((t) => t.id == widget.draft.id).firstOrNull;
    final alreadyCounted = original != null &&
        original.typeId == type.id &&
        original.date.year == _date.year &&
        original.date.month == _date.month;
    final spent = status.spent - (alreadyCounted ? original.amount : 0) + amount;
    if (spent <= status.limit) return null;
    return 'Diqqat: "${type.name}" byudjeti oshdi — ${formatAmount(spent)} / ${formatMoney(status.limit)}';
  }

  Future<void> _delete() async {
    final ok = await confirm(context, title: 'O\'chirish', message: 'Bu yozuv butunlay o\'chiriladi.');
    if (!ok || !mounted) return;
    await ref.read(repositoryProvider).deleteTransaction(widget.draft.id!);
    if (mounted) {
      Navigator.pop(context);
      showSnack(context, 'O\'chirildi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const SizedBox(height: 200);
    final theme = Theme.of(context);

    final types = ledger.activeTypes(widget.draft.direction);
    final current = ledger.typeById[_typeId];
    if (current != null && !types.contains(current)) types.insert(0, current);
    final kind = current?.kind ?? TxKind.normal;

    final balances = ledger.walletBalances();
    final wallets = ledger.activeWallets;
    final selectedWallet = ledger.walletById[_walletId];
    if (selectedWallet != null && !wallets.contains(selectedWallet)) wallets.insert(0, selectedWallet);

    final amount = parseAmount(_amount.text);
    final available = _availableBalance(ledger, balances);
    final insufficient = !_income && available != null && amount > available;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_income ? Icons.add_rounded : Icons.remove_rounded, color: _accent, size: 32, weight: 700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEdit ? (_income ? 'Kirimni tahrirlash' : 'Chiqimni tahrirlash') : (_income ? 'Kirim' : 'Chiqim'),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), tooltip: 'Yopish'),
              ],
            ),
            const Divider(height: 20),

            // ----------------------------------------------------- tur
            const FieldLabel('Tranzaksiya'),
            DropdownButtonFormField<int>(
              key: ValueKey('$_typeId/$_typeFieldVersion'),
              initialValue: _typeId,
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accent, width: 2),
                ),
              ),
              items: [
                for (final t in types)
                  DropdownMenuItem(
                    value: t.id,
                    child: Row(
                      children: [
                        TypeBadge(type: t, size: 30),
                        const SizedBox(width: 12),
                        Flexible(child: Text(t.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  ),
                DropdownMenuItem(
                  value: _newTypeValue,
                  child: Row(
                    children: [
                      IconBadge(icon: Icons.add_rounded, color: theme.colorScheme.primary, size: 30),
                      const SizedBox(width: 12),
                      Text('Yangi tur qo\'shish', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              onChanged: _onTypeChanged,
            ),

            // ------------------------------------------- qarz: kim, muddat
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: kind.isDebt ? _debtFields(ledger, kind) : const SizedBox(width: double.infinity),
            ),

            // -------------------------------------------------- hamyon
            const FieldLabel('Hamyon'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.75,
              children: [
                for (final w in wallets)
                  _WalletChoice(
                    wallet: w,
                    balance: balances[w.id] ?? 0,
                    selected: w.id == _walletId,
                    accent: _accent,
                    onTap: () => setState(() => _walletId = w.id),
                  ),
              ],
            ),

            // --------------------------------------------------- summa
            const FieldLabel("Summa (so'm)"),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [AmountInputFormatter()],
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: "so'm",
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final step in const [5000, 10000, 50000, 100000])
                  ActionChip(
                    label: Text('+${formatAmount(step)}'),
                    onPressed: () => _amount.text = formatAmount(parseAmount(_amount.text) + step),
                  ),
              ],
            ),
            if (insufficient)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: warningColor, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Hamyonda yetarli mablag\' yo\'q (balans: ${formatMoney(available)})',
                        style: const TextStyle(color: warningColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().shakeX(hz: 3, amount: 3),

            // ---------------------------------------------- sana, izoh
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
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Ixtiyoriy', counterText: ''),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (_isEdit) ...[
                  SizedBox(
                    width: 56,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: expenseColor,
                        minimumSize: const Size(56, 52),
                      ),
                      onPressed: _delete,
                      child: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                    onPressed: amount > 0 && current != null && _walletId != null && !_saving ? () => _save(ledger) : null,
                    child: const Text('Saqlash'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tahrirlashda asl summa shu hamyondan allaqachon ayrilgan — qaytarib qo'shamiz.
  int? _availableBalance(Ledger ledger, Map<int, int> balances) {
    if (_walletId == null) return null;
    var available = balances[_walletId] ?? 0;
    final original = widget.draft.id == null ? null : ledger.txns.where((t) => t.id == widget.draft.id).firstOrNull;
    if (original != null && original.walletId == _walletId && ledger.directionOf(original) == TxDirection.expense) {
      available += original.amount;
    }
    return available;
  }

  Widget _debtFields(Ledger ledger, TxKind kind) {
    final query = _person.text.trim().toLowerCase();
    final debts = ledger.personDebts();

    // Qaytarish turlarida — qoldig'i borlar summasi bilan; aks holda barcha odamlar.
    final List<(Person, int?)> suggestions;
    if (kind == TxKind.debtCollect || kind == TxKind.debtRepay) {
      suggestions = [
        for (final d in debts)
          if ((kind == TxKind.debtCollect ? d.owedToMe : d.iOwe) > 0)
            (d.person, kind == TxKind.debtCollect ? d.owedToMe : d.iOwe),
      ];
    } else {
      suggestions = [for (final p in ledger.people) (p, null)];
    }
    final filtered = suggestions
        .where((s) => query.isEmpty || s.$1.name.toLowerCase().contains(query))
        .where((s) => s.$1.name.toLowerCase() != query)
        .take(8)
        .toList();

    final question = switch (kind) {
      TxKind.debtGive => 'Kimga qarz berdingiz?',
      TxKind.debtTake => 'Kimdan qarz oldingiz?',
      TxKind.debtCollect => 'Kim qarzini qaytardi?',
      _ => 'Kimga qarzingizni qaytardingiz?',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(question),
        TextField(
          controller: _person,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: 'Ism',
            prefixIcon: const Icon(Icons.person_rounded),
            counterText: '',
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _accent, width: 2),
            ),
            errorText: _showErrors && _person.text.trim().isEmpty ? 'Kimligini kiriting' : null,
          ),
        ),
        if (filtered.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (person, owed) in filtered)
                ActionChip(
                  avatar: CircleAvatar(child: Text(person.name.characters.first.toUpperCase())),
                  label: Text(owed == null ? person.name : '${person.name} · ${formatAmount(owed)}'),
                  onPressed: () {
                    _person.text = person.name;
                    if (owed != null && parseAmount(_amount.text) == 0) _amount.text = formatAmount(owed);
                  },
                ),
            ],
          ),
        ],
        if (kind.hasDueDate) ...[
          const FieldLabel('Qaytarish sanasi (eslatma keladi)'),
          DateField(
            value: _dueDate,
            color: _accent,
            placeholder: 'Muddatsiz',
            onClear: () => setState(() => _dueDate = null),
            onTap: () async {
              final now = DateTime.now();
              final picked = await pickDate(
                context,
                initial: _dueDate ?? now.add(const Duration(days: 7)),
                first: DateTime(now.year - 1),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
        ],
      ],
    );
  }
}

class _WalletChoice extends StatelessWidget {
  const _WalletChoice({
    required this.wallet,
    required this.balance,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final Wallet wallet;
  final int balance;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.08) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? accent : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconFor(wallet.icon), color: selected ? accent : theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 4),
                Text(wallet.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  formatMoney(balance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: balance < 0 ? expenseColor : theme.colorScheme.onSurfaceVariant,
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
