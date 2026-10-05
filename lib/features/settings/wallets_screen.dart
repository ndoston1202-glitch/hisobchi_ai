import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final balances = ledger.walletBalances();
    final repo = ref.read(repositoryProvider);

    Widget tile(Wallet w) => ListTile(
          leading: Opacity(opacity: w.archived ? 0.4 : 1, child: IconBadge(icon: iconFor(w.icon), color: brandColor, size: 40)),
          title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Balans: ${formatMoney(balances[w.id] ?? 0)}'),
          onTap: w.archived ? null : () => _showWalletEditor(context, wallet: w),
          trailing: w.archived
              ? TextButton(onPressed: () => repo.restoreWallet(w.id), child: const Text('Tiklash'))
              : IconButton(
                  tooltip: 'O\'chirish',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    if (!await confirm(context, title: 'O\'chirish', message: '"${w.name}" hamyoni olib tashlansinmi?')) return;
                    try {
                      final result = await repo.removeWallet(w.id);
                      if (context.mounted) {
                        showSnack(context, result == Removal.archived ? 'Hamyonda yozuvlar bor — arxivlandi' : 'O\'chirildi');
                      }
                    } on AppException catch (e) {
                      if (context.mounted) showSnack(context, e.message, error: true);
                    }
                  },
                ),
        );

    final archived = ledger.wallets.where((w) => w.archived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Hamyonlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [for (final w in ledger.activeWallets) tile(w)])),
          if (archived.isNotEmpty) ...[
            const SectionTitle('Arxiv'),
            AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [for (final w in archived) tile(w)])),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWalletEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yangi hamyon'),
      ),
    );
  }
}

Future<void> _showWalletEditor(BuildContext context, {Wallet? wallet}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WalletEditor(wallet: wallet),
    );

class _WalletEditor extends ConsumerStatefulWidget {
  const _WalletEditor({this.wallet});

  final Wallet? wallet;

  @override
  ConsumerState<_WalletEditor> createState() => _WalletEditorState();
}

class _WalletEditorState extends ConsumerState<_WalletEditor> {
  late final _name = TextEditingController(text: widget.wallet?.name ?? '');
  late final _initial = TextEditingController(
    text: widget.wallet == null || widget.wallet!.initialBalance == 0 ? '' : formatAmount(widget.wallet!.initialBalance),
  );
  late String _icon = widget.wallet?.icon ?? 'wallet';

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await ref.read(repositoryProvider).saveWallet(
            id: widget.wallet?.id,
            name: _name.text,
            icon: _icon,
            initialBalance: parseAmount(_initial.text),
          );
      if (mounted) Navigator.pop(context);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.wallet == null ? 'Yangi hamyon' : 'Hamyonni tahrirlash',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const FieldLabel('Nomi'),
            TextField(
              controller: _name,
              autofocus: widget.wallet == null,
              maxLength: 40,
              decoration: const InputDecoration(hintText: 'Masalan: Uzcard', counterText: ''),
            ),
            const FieldLabel('Ikonka'),
            Wrap(
              spacing: 10,
              children: [
                for (final key in walletIconKeys)
                  ChoiceChip(
                    label: Icon(iconFor(key)),
                    selected: key == _icon,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _icon = key),
                  ),
              ],
            ),
            const FieldLabel("Boshlang'ich balans (so'm)"),
            TextField(
              controller: _initial,
              keyboardType: TextInputType.number,
              inputFormatters: [AmountInputFormatter()],
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: "so'm",
                helperText: 'Ilovadan oldin hamyonda bo\'lgan pul',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Saqlash')),
          ],
        ),
      ),
    );
  }
}
