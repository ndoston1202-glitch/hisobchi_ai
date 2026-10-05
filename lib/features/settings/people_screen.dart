import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../debts/person_screen.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final debts = {for (final d in ledger.personDebts()) d.person.id: d};

    return Scaffold(
      appBar: AppBar(title: const Text('Odamlar')),
      body: ledger.people.isEmpty
          ? const EmptyState(icon: Icons.people_alt_rounded, text: 'Hali odam yo\'q.\nQarz yozganingizda avtomatik qo\'shiladi.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final p in ledger.people)
                        ListTile(
                          leading: CircleAvatar(child: Text(p.name.characters.first.toUpperCase())),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(_summary(debts[p.id]!.owedToMe, debts[p.id]!.iOwe, p.phone)),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonScreen(personId: p.id))),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'edit') {
                                await showPersonEditor(context, person: p);
                                return;
                              }
                              if (!await confirm(context, title: 'O\'chirish', message: '"${p.name}" o\'chirilsinmi?')) return;
                              try {
                                await ref.read(repositoryProvider).deletePerson(p.id);
                              } on AppException catch (e) {
                                if (context.mounted) showSnack(context, e.message, error: true);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Tahrirlash')),
                              PopupMenuItem(value: 'delete', child: Text('O\'chirish', style: TextStyle(color: expenseColor))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPersonEditor(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Yangi odam'),
      ),
    );
  }

  String _summary(int owedToMe, int iOwe, String? phone) {
    final parts = [
      if (owedToMe > 0) 'Menga qarzdor: ${formatMoney(owedToMe)}',
      if (iOwe > 0) 'Men qarzdorman: ${formatMoney(iOwe)}',
      if (owedToMe <= 0 && iOwe <= 0) 'Qarz yo\'q',
      ?phone,
    ];
    return parts.join(' · ');
  }
}

Future<void> showPersonEditor(BuildContext context, {Person? person}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PersonEditor(person: person),
    );

class _PersonEditor extends ConsumerStatefulWidget {
  const _PersonEditor({this.person});

  final Person? person;

  @override
  ConsumerState<_PersonEditor> createState() => _PersonEditorState();
}

class _PersonEditorState extends ConsumerState<_PersonEditor> {
  late final _name = TextEditingController(text: widget.person?.name ?? '');
  late final _phone = TextEditingController(text: widget.person?.phone ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await ref.read(repositoryProvider).savePerson(id: widget.person?.id, name: _name.text, phone: _phone.text);
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
              widget.person == null ? 'Yangi odam' : 'Tahrirlash',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const FieldLabel('Ism'),
            TextField(
              controller: _name,
              autofocus: widget.person == null,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              decoration: const InputDecoration(counterText: ''),
            ),
            const FieldLabel('Telefon (ixtiyoriy)'),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '+998 90 123 45 67'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Saqlash')),
          ],
        ),
      ),
    );
  }
}
