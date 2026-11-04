import 'package:flutter/material.dart';

import '../logic/budget.dart';
import '../logic/models.dart';
import '../state/app_scope.dart';
import 'include_screen.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final b = app.budget;
    final tt = Theme.of(context).textTheme;
    final allWarnings = app.budgetWarnings.where((w) => w.code != 'healthy' && w.code != 'shortfall').toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.t('home.greeting'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Icons.place, color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 6),
                  Expanded(child: Text(s.placeName(app.inputs.location), style: tt.titleMedium)),
                ]),
                const SizedBox(height: 14),
                const _IncomeCard(),
                const SizedBox(height: 14),
                const _ResultBanner(),
                for (final w in allWarnings) ...[const SizedBox(height: 12), _WarningCard(w)],
                SectionTitle(s.t('home.where')),
                _MoneyBar(budget: b),
                const SizedBox(height: 18),
                Text(s.t('home.tapHint'), style: tt.bodyLarge),
                for (final g in Group.values)
                  if (b.lines.any((l) => l.group == g)) ...[
                    SectionTitle(s.groupName(g), trailing: app.money(b.groupTotal(g))),
                    for (final l in b.lines.where((l) => l.group == g)) ...[
                      _CategoryTile(line: l),
                      const SizedBox(height: 10),
                    ],
                  ],
                const SizedBox(height: 20),
                BigButton(icon: Icons.add_circle, label: s.t('home.addOwn'), tonal: true, onPressed: () => showAddSheet(context)),
                const SizedBox(height: 12),
                BigButton(
                  icon: Icons.tune,
                  label: s.t('home.whatCounts'),
                  outlined: true,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IncludeScreen())),
                ),
                if (app.edits.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  BigButton(
                    icon: Icons.undo,
                    label: s.t('home.resetEdits'),
                    outlined: true,
                    onPressed: () async {
                      if (await confirm(context, s.t('home.resetEditsConfirm'))) app.resetEdits();
                    },
                  ),
                ],
                const SizedBox(height: 28),
                Text(s.t('home.disclaimer', {'year': app.country.data.dataYear}), style: tt.bodySmall),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final b = app.budget;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('home.income'), style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(app.money(b.takeHome), style: tt.displaySmall?.copyWith(color: cs.onPrimaryContainer)),
          ),
          Text('${s.t('home.afterTax')} · ${s.t('common.perMonth')}', style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer)),
          if (app.inputs.incomeType == IncomeType.gross) ...[
            const SizedBox(height: 8),
            Text(
              s.t('home.taxLine', {'gross': app.money(b.income.grossMonthly), 'tax': app.money(b.income.taxTotal / 12)}),
              style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final b = app.budget;
    final tt = Theme.of(context).textTheme;
    final br = Theme.of(context).brightness;
    final short = b.unassigned < -1;
    final savings = b.groupTotal(Group.savings);
    final st = statusStyle(short ? Status.short : Status.good, br);
    final title = short
        ? s.t('home.short', {'amount': app.money(-b.unassigned)})
        : b.unassigned > 1
            ? s.t('home.leftover', {'amount': app.money(b.unassigned)})
            : s.t('home.canSave', {'amount': app.money(savings)});
    final sub = short ? s.t('home.shortSub') : b.unassigned > 1 ? null : s.t('home.canSaveSub', {'year': app.money(savings * 12)});
    return Semantics(
      liveRegion: true,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: st.color, width: 3)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(short ? Icons.warning_rounded : Icons.savings_rounded, color: st.color, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tt.titleLarge),
                if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, style: tt.bodyLarge)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard(this.w);
  final BudgetWarning w;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final br = Theme.of(context).brightness;
    final (color, icon) = switch (w.level) {
      WarningLevel.critical => (statusStyle(Status.short, br).color, Icons.error_rounded),
      WarningLevel.warning => (statusStyle(Status.tight, br).color, Icons.warning_amber_rounded),
      WarningLevel.info => (Theme.of(context).colorScheme.primary, Icons.info_rounded),
    };
    return Card(
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 8))),
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text(app.s.warning(w, app.cc), style: Theme.of(context).textTheme.bodyLarge)),
        ]),
      ),
    );
  }
}

/// One thick bar split into Needs / Nice to have / Savings, with a written legend.
class _MoneyBar extends StatelessWidget {
  const _MoneyBar({required this.budget});
  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final br = Theme.of(context).brightness;
    final tt = Theme.of(context).textTheme;
    final groups = [for (final g in Group.values) if (budget.groupTotal(g) > 0) g];
    final total = groups.fold(0.0, (t, g) => t + budget.groupTotal(g));
    if (total <= 0) return const SizedBox.shrink();
    return Semantics(
      label: groups.map((g) => '${s.groupName(g)} ${s.pct(budget.groupTotal(g) / total)}').join(', '),
      child: Column(children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 40,
              child: Row(children: [
                for (final (i, g) in groups.indexed)
                  Expanded(
                    flex: (budget.groupTotal(g) / total * 1000).round().clamp(1, 1000),
                    child: Container(
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                      color: groupColor(g, br),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ExcludeSemantics(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(width: 26, height: 26, decoration: BoxDecoration(color: groupColor(g, br), borderRadius: BorderRadius.circular(6))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
                    Text(s.groupName(g), style: tt.titleMedium),
                    Text('${app.money(budget.groupTotal(g))}  (${s.pct(budget.groupTotal(g) / total)})', style: tt.bodyLarge),
                  ]),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.line});
  final CategoryLine line;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final status = lineStatus(line, app.budget);
    final sub = line.isCustom || line.fixed
        ? s.t('home.yourCost')
        : line.estimate > 0
            ? s.t('home.usual', {'amount': app.money(line.estimate)})
            : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showEditSheet(context, line),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(children: [
            CircleAvatar(radius: 26, backgroundColor: cs.secondaryContainer, child: Icon(categoryIcon(line.id), size: 30, color: cs.onSecondaryContainer)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.category(line), style: tt.titleMedium),
                const SizedBox(height: 2),
                Text(app.money(line.amount), style: tt.headlineSmall),
                if (sub != null) Text(sub, style: tt.bodyMedium),
                if (status != Status.none) Padding(padding: const EdgeInsets.only(top: 4), child: StatusChip(status: status)),
              ]),
            ),
            Icon(Icons.chevron_right, size: 32, color: cs.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
