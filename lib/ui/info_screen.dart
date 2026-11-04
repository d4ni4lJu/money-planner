import 'package:flutter/material.dart';

import '../logic/models.dart';
import '../state/app_scope.dart';
import 'steps.dart';
import 'widgets.dart';

/// A summary of every answer, each with a big "Change" button.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  void _open(BuildContext context, String title, Widget step) => Navigator.of(context).push(MaterialPageRoute(
        builder: (c) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: step)),
          ]),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: BigButton(icon: Icons.check, label: AppScope.of(c).s.t('common.done'), onPressed: () => Navigator.pop(c)),
            ),
          ),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final i = app.inputs;
    final known = [
      for (final k in KnownCosts.fields)
        if (i.known[k] != null) '${s.categoryName(_knownCategory[k]!)}: ${app.money(i.known[k]!)}',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.t('info.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(children: [
                _InfoCard(
                  icon: Icons.place,
                  title: s.t('info.location'),
                  lines: [s.placeName(i.location)],
                  onChange: () => _open(context, s.t('info.location'), const LocationStep()),
                ),
                _InfoCard(
                  icon: Icons.payments,
                  title: s.t('info.income'),
                  lines: [
                    '${app.money(i.incomeAmount)} · ${s.t('freq.${i.frequency.name}')}',
                    s.t(i.incomeType == IncomeType.net ? 'income.afterTax' : 'income.beforeTax'),
                  ],
                  onChange: () => _open(context, s.t('info.income'), const IncomeStep()),
                ),
                _InfoCard(
                  icon: Icons.people,
                  title: s.t('info.household'),
                  lines: [
                    [s.t('info.adults', {'n': i.adults}), if (i.children > 0) s.t('info.children', {'n': i.children})].join(s.ja ? '、' : ', '),
                    s.t(i.hasCar ? 'info.car' : 'info.noCar'),
                  ],
                  onChange: () => _open(context, s.t('info.household'), const HouseholdStep()),
                ),
                _InfoCard(
                  icon: Icons.receipt_long,
                  title: s.t('info.bills'),
                  lines: known.isEmpty ? [s.t('info.billsNone')] : known,
                  onChange: () => _open(context, s.t('info.bills'), const BillsStep()),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

const _knownCategory = {
  'rent': 'housing',
  'carPayment': 'carPayment',
  'debtPayments': 'debt',
  'healthInsurance': 'healthcare',
  'subscriptions': 'subscriptions',
};

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.lines, required this.onChange});
  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: tt.titleLarge)),
            ]),
            const SizedBox(height: 10),
            for (final l in lines) Text(l, style: tt.bodyLarge),
            const SizedBox(height: 14),
            BigButton(icon: Icons.edit, label: AppScope.of(context).s.t('common.change'), outlined: true, onPressed: onChange),
          ]),
        ),
      ),
    );
  }
}
