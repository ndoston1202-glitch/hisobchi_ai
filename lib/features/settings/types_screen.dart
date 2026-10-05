import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository.dart';
import '../../domain/enums.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'type_editor.dart';

class TypesScreen extends ConsumerWidget {
  const TypesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Tranzaksiya turlari'),
            bottom: const TabBar(tabs: [Tab(text: 'Chiqim'), Tab(text: 'Kirim')]),
          ),
          body: TabBarView(
            children: [
              _TypeList(types: ledger.types.where((t) => t.direction == TxDirection.expense).toList()),
              _TypeList(types: ledger.types.where((t) => t.direction == TxDirection.income).toList()),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showTypeEditor(
              context,
              direction: DefaultTabController.of(context).index == 0 ? TxDirection.expense : TxDirection.income,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yangi tur'),
          ),
        ),
      ),
    );
  }
}

class _TypeList extends ConsumerWidget {
  const _TypeList({required this.types});

  final List<TxType> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = types.where((t) => !t.archived).toList();
    final archived = types.where((t) => t.archived).toList();
    final repo = ref.read(repositoryProvider);

    Widget tile(TxType t) => ListTile(
          leading: Opacity(opacity: t.archived ? 0.4 : 1, child: TypeBadge(type: t, size: 40)),
          title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: t.isSystem ? const Text('Qarz turi · kimligini so\'raydi') : null,
          onTap: t.archived ? null : () => showTypeEditor(context, type: t, direction: t.direction),
          trailing: t.isSystem
              ? const Icon(Icons.lock_outline_rounded, size: 20)
              : t.archived
                  ? TextButton(onPressed: () => repo.restoreType(t.id), child: const Text('Tiklash'))
                  : IconButton(
                      tooltip: 'O\'chirish',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        if (!await confirm(context, title: 'O\'chirish', message: '"${t.name}" turi olib tashlansinmi?')) return;
                        try {
                          final result = await repo.removeType(t.id);
                          if (context.mounted) {
                            showSnack(context, result == Removal.archived ? 'Tur ishlatilgan — arxivlandi' : 'O\'chirildi');
                          }
                        } on AppException catch (e) {
                          if (context.mounted) showSnack(context, e.message, error: true);
                        }
                      },
                    ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [for (final t in active) tile(t)])),
        if (archived.isNotEmpty) ...[
          const SectionTitle('Arxiv'),
          AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [for (final t in archived) tile(t)])),
        ],
      ],
    );
  }
}
