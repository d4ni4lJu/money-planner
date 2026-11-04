import 'package:flutter/material.dart';

import '../logic/models.dart';
import '../state/app_scope.dart';
import 'widgets.dart';

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), child: child),
      ),
    );

/// Change one category's monthly amount, or stop counting it.
Future<void> showEditSheet(BuildContext context, CategoryLine line) => _sheet(context, _EditSheet(line: line));

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.line});
  final CategoryLine line;
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late double? _amount = widget.line.amount;
  late final _name = TextEditingController(text: widget.line.customName ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _customId => widget.line.id.substring('custom:'.length);

  void _save() {
    final app = AppScope.read(context);
    final l = widget.line;
    if (l.isCustom) {
      app.updateCustom(_customId, name: _name.text.trim().isEmpty ? null : _name.text.trim(), amount: _amount ?? 0);
    } else if ((_amount ?? 0) != l.amount) {
      app.editCategory(l.id, _amount ?? 0);
    }
    Navigator.pop(context);
  }

  Future<void> _remove() async {
    final app = AppScope.read(context);
    final s = app.s;
    final l = widget.line;
    final name = s.category(l);
    if (l.isCustom) {
      if (!await confirm(context, s.t('include.deleteConfirm', {'name': name}))) return;
      app.deleteCustom(_customId);
    } else {
      if (!await confirm(context, s.t('edit.removeConfirm', {'name': name}))) return;
      app.setIncluded(l.id, false);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final l = widget.line;
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.t('edit.title', {'name': s.category(l)}), style: tt.headlineSmall),
      if (l.estimate > 0 && !l.isCustom && !l.fixed) ...[
        const SizedBox(height: 8),
        Text(s.t('edit.usual', {'amount': app.money(l.estimate)}), style: tt.bodyLarge),
      ],
      const SizedBox(height: 24),
      if (l.isCustom) ...[
        Text(s.t('edit.name'), style: tt.titleMedium),
        const SizedBox(height: 8),
        TextField(controller: _name, style: tt.bodyLarge),
        const SizedBox(height: 24),
      ],
      MoneyField(label: s.t('edit.amount'), value: _amount, onChanged: (v) => setState(() => _amount = v)),
      const SizedBox(height: 28),
      BigButton(icon: Icons.check, label: s.t('common.save'), onPressed: _save),
      const SizedBox(height: 12),
      BigButton(label: s.t('common.cancel'), outlined: true, onPressed: () => Navigator.pop(context)),
      const SizedBox(height: 20),
      TextButton.icon(
        onPressed: _remove,
        icon: Icon(l.isCustom ? Icons.delete : Icons.remove_circle_outline, size: 28),
        label: Text(l.isCustom ? s.t('edit.delete') : s.t('edit.remove')),
        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      ),
    ]);
  }
}

/// Add a custom expense.
Future<void> showAddSheet(BuildContext context) => _sheet(context, const _AddSheet());

class _AddSheet extends StatefulWidget {
  const _AddSheet();
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _name = TextEditingController();
  double? _amount;
  Group _group = Group.needs;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && (_amount ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final tt = Theme.of(context).textTheme;
    const ideas = ['medicine', 'pet', 'gifts', 'class', 'travel', 'family'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.t('add.title'), style: tt.headlineSmall),
      const SizedBox(height: 24),
      Text(s.t('add.name'), style: tt.titleMedium),
      const SizedBox(height: 8),
      TextField(controller: _name, style: tt.bodyLarge, onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      Text(s.t('add.ideas'), style: tt.bodyMedium),
      const SizedBox(height: 6),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final i in ideas)
          ActionChip(
            label: Text(s.t('add.idea.$i'), style: tt.bodyLarge),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            onPressed: () => setState(() => _name.text = s.t('add.idea.$i')),
          ),
      ]),
      const SizedBox(height: 24),
      MoneyField(label: s.t('edit.amount'), value: _amount, onChanged: (v) => setState(() => _amount = v)),
      const SizedBox(height: 24),
      ChoiceTile(title: s.t('add.need'), selected: _group == Group.needs, onTap: () => setState(() => _group = Group.needs)),
      const SizedBox(height: 10),
      ChoiceTile(title: s.t('add.want'), selected: _group == Group.wants, onTap: () => setState(() => _group = Group.wants)),
      const SizedBox(height: 28),
      BigButton(
        icon: Icons.add,
        label: s.t('add.save'),
        onPressed: _valid
            ? () {
                app.addCustom(_name.text.trim(), _amount!, _group);
                Navigator.pop(context);
              }
            : null,
      ),
      const SizedBox(height: 12),
      BigButton(label: s.t('common.cancel'), outlined: true, onPressed: () => Navigator.pop(context)),
    ]);
  }
}
