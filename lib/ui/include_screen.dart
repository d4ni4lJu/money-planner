import 'package:flutter/material.dart';

import '../logic/budget.dart';
import '../logic/models.dart';
import '../state/app_scope.dart';
import 'theme.dart';
import 'widgets.dart';

/// Turn taxes, categories and custom expenses on or off.
class IncludeScreen extends StatelessWidget {
  const IncludeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final i = app.inputs;
    final tt = Theme.of(context).textTheme;
    final net = i.incomeType == IncomeType.net;
    final cats = applicableCategories(i);

    Widget toggle({required String key, required String title, IconData? icon, String? amount, bool enabled = true, Widget? extra}) {
      final on = !i.excluded.contains(key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: SwitchListTile(
            value: on,
            onChanged: enabled ? (v) => app.setIncluded(key, v) : null,
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            secondary: icon == null ? null : Icon(icon, size: 30),
            title: Text(title, style: tt.titleMedium?.copyWith(decoration: on ? null : TextDecoration.lineThrough)),
            subtitle: amount == null && extra == null
                ? null
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (amount != null) Text(amount, style: tt.bodyLarge),
                    ?extra,
                  ]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.t('include.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(s.t('include.body'), style: tt.bodyLarge),
                SectionTitle(s.t('include.taxes')),
                if (net) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(s.t('include.taxesNet'), style: tt.bodyLarge)),
                for (final t in app.budget.income.taxes)
                  toggle(
                    key: taxKey(t.id),
                    title: s.taxName(t.id),
                    amount: '${app.money(t.amount / 12)} / ${s.t('common.perMonth')}',
                    enabled: !net,
                  ),
                for (final g in Group.values) ...[
                  SectionTitle(s.groupName(g)),
                  for (final id in cats.where((c) => categoryGroups[c] == g)) toggle(key: id, title: s.categoryName(id), icon: categoryIcon(id)),
                  for (final c in i.custom.where((c) => c.group == g))
                    toggle(
                      key: 'custom:${c.id}',
                      title: c.name,
                      icon: categoryIcon('custom'),
                      amount: '${app.money(c.amount)} · ${s.t('include.mine')}',
                      extra: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, padding: EdgeInsets.zero),
                          icon: const Icon(Icons.delete, size: 26),
                          label: Text(s.t('edit.delete')),
                          onPressed: () async {
                            if (await confirm(context, s.t('include.deleteConfirm', {'name': c.name}))) app.deleteCustom(c.id);
                          },
                        ),
                      ),
                    ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
