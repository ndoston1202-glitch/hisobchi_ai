import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../data/database.dart';
import '../../data/repository.dart';
import '../../domain/enums.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Tranzaksiya turini qo'shish/tahrirlash. Saqlangan tur id sini qaytaradi.
Future<int?> showTypeEditor(BuildContext context, {TxType? type, required TxDirection direction}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TypeEditor(type: type, direction: direction),
  );
}

class _TypeEditor extends ConsumerStatefulWidget {
  const _TypeEditor({required this.type, required this.direction});

  final TxType? type;
  final TxDirection direction;

  @override
  ConsumerState<_TypeEditor> createState() => _TypeEditorState();
}

class _TypeEditorState extends ConsumerState<_TypeEditor> {
  late final _name = TextEditingController(text: widget.type?.name ?? '');
  late String _icon = widget.type?.icon ?? (widget.direction == TxDirection.income ? 'plus' : 'shopping');
  late int _color = widget.type?.color ?? typeColors.first;
  bool _saving = false;

  bool get _isSystem => widget.type?.isSystem ?? false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = await ref.read(repositoryProvider).saveType(
            id: widget.type?.id,
            name: _name.text,
            icon: _icon,
            color: _color,
            direction: widget.direction,
          );
      if (mounted) Navigator.pop(context, id);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_color);
    final title = widget.type == null
        ? (widget.direction == TxDirection.income ? 'Yangi kirim turi' : 'Yangi chiqim turi')
        : 'Turni tahrirlash';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(icon: iconFor(_icon), color: color, size: 48),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
            const FieldLabel('Nomi'),
            TextField(
              controller: _name,
              enabled: !_isSystem,
              autofocus: widget.type == null,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Masalan: Sport zal',
                helperText: _isSystem ? 'Qarz turlarining nomi o\'zgarmaydi' : null,
                counterText: '',
              ),
            ),
            const FieldLabel('Ikonka'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in appIcons.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _icon = entry.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: entry.key == _icon ? color.withValues(alpha: 0.18) : null,
                        border: Border.all(color: entry.key == _icon ? color : Colors.transparent, width: 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(entry.value, color: entry.key == _icon ? color : null),
                    ),
                  ),
              ],
            ),
            const FieldLabel('Rang'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in typeColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: c == _color ? 3 : 0),
                      ),
                      child: c == _color ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _saving ? null : _save, child: const Text('Saqlash')),
          ],
        ),
      ),
    );
  }
}
