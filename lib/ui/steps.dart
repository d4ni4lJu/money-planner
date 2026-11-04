import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../logic/budget.dart';
import '../logic/countries.dart';
import '../logic/models.dart';
import '../services/locator.dart';
import '../state/app_scope.dart';
import 'widgets.dart';

/// Replaceable in tests.
Locator locator = const Locator();

class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.title, this.body});
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text(title, style: tt.headlineMedium)),
      if (body != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(body!, style: tt.bodyLarge)),
      const SizedBox(height: 24),
    ]);
  }
}

// ---------------- location ----------------

class LocationStep extends StatefulWidget {
  const LocationStep({super.key, this.autoDetect = false});

  /// Start finding the location as soon as the step opens.
  final bool autoDetect;

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  bool _busy = false;
  String? _message;
  bool _error = false;
  static bool _autoDone = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoDetect && !_autoDone) {
      _autoDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _detect());
    }
  }

  Future<void> _detect() async {
    final app = AppScope.read(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await locator.detect();
    if (!mounted) return;
    final s = app.s;
    String msg;
    var err = true;
    switch (r.status) {
      case DetectStatus.found:
        final f = r.found!;
        app.setLocation(f.key);
        final place = s.placeName(f.key);
        msg = !f.isCity
            ? s.t('loc.foundRegion', {'place': place})
            : f.distanceKm > 3
                ? s.t('loc.foundNear', {'place': place, 'km': f.distanceKm})
                : s.t('loc.found', {'place': place});
        err = false;
      case DetectStatus.denied:
        msg = s.t('loc.denied');
      case DetectStatus.off:
        msg = s.t('loc.off');
      case DetectStatus.notCovered:
        msg = s.t('loc.notCovered');
      case DetectStatus.error:
        msg = s.t('loc.error');
    }
    setState(() {
      _busy = false;
      _message = msg;
      _error = err;
    });
  }

  Future<void> _choose() async {
    final key = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const LocationPicker()));
    if (key != null && mounted) {
      AppScope.read(context).setLocation(key);
      setState(() => _message = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StepHeader(title: s.t('loc.title'), body: s.t('loc.body')),
      BigButton(icon: Icons.my_location, label: _busy ? s.t('loc.finding') : s.t('loc.find'), onPressed: _busy ? null : _detect),
      if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Semantics(
            liveRegion: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_error ? Icons.info : Icons.check_circle, color: _error ? cs.error : const Color(0xFF1B7A1B), size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(_message!, style: tt.bodyLarge)),
            ]),
          ),
        ),
      const SizedBox(height: 16),
      BigButton(icon: Icons.list, label: s.t('loc.choose'), onPressed: _choose, outlined: true),
      const SizedBox(height: 28),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Icon(Icons.place, size: 36, color: cs.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.t('loc.selected'), style: tt.bodyMedium),
                Text(s.placeName(app.inputs.location), style: tt.titleLarge),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key});
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final q = _q.trim().toLowerCase();
    final order = app.cc == CountryCode.us ? [CountryCode.us, CountryCode.jp] : [CountryCode.jp, CountryCode.us];
    final items = <Widget>[];

    for (final cc in order) {
      final data = countries[cc]!.data;
      bool match(List<String> names) => q.isEmpty || names.any((n) => n.toLowerCase().contains(q));
      final cities = data.cities
          .where((c) => match([...S.searchNames(cc, c.name, c.id), ...S.searchNames(cc, c.region, c.region, city: false), s.regionName(cc, c.region)]))
          .toList()
        ..sort((a, b) => s.cityName(cc, a).compareTo(s.cityName(cc, b)));
      final regions = data.regions.where((r) => match(S.searchNames(cc, r.name, r.code, city: false))).toList();
      if (cities.isEmpty && regions.isEmpty) continue;
      items.add(_Header('${s.t('country.${cc.name}')} — ${s.t('loc.cities')}'));
      for (final c in cities) {
        items.add(_PlaceTile(title: s.placeName('${cc.name}:city:${c.id}'), keyValue: '${cc.name}:city:${c.id}'));
      }
      items.add(_Header(s.t(cc == CountryCode.jp ? 'loc.regionsJp' : 'loc.regionsUs')));
      if (q.isEmpty) items.add(_PlaceTile(title: s.placeName('${cc.name}:national'), keyValue: '${cc.name}:national'));
      for (final r in regions) {
        items.add(_PlaceTile(title: s.regionName(cc, r.code), keyValue: '${cc.name}:region:${r.code}'));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.t('loc.choose'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            autofocus: false,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 30), hintText: s.t('loc.search')),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(s.t('loc.noResults'), style: Theme.of(context).textTheme.bodyLarge)))
              : ListView(padding: const EdgeInsets.only(bottom: 32), children: items),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.title, required this.keyValue});
  final String title, keyValue;
  @override
  Widget build(BuildContext context) {
    final selected = AppScope.of(context).inputs.location == keyValue;
    return ListTile(
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: selected ? FontWeight.w700 : null)),
      trailing: selected ? Icon(Icons.check_circle, size: 30, color: Theme.of(context).colorScheme.primary) : const Icon(Icons.chevron_right, size: 30),
      onTap: () => Navigator.pop(context, keyValue),
    );
  }
}

// ---------------- income ----------------

class IncomeStep extends StatelessWidget {
  const IncomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final i = app.inputs;
    final tt = Theme.of(context).textTheme;
    const freqs = [PayFrequency.monthly, PayFrequency.yearly, PayFrequency.biweekly, PayFrequency.weekly];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StepHeader(title: s.t('income.title'), body: s.t('income.body')),
      ChoiceTile(
        title: s.t('income.afterTax'), subtitle: s.t('income.afterTaxHint'), selected: i.incomeType == IncomeType.net,
        onTap: () => app.update((x) => x.copyWith(incomeType: IncomeType.net)),
      ),
      const SizedBox(height: 12),
      ChoiceTile(
        title: s.t('income.beforeTax'), subtitle: s.t('income.beforeTaxHint'), selected: i.incomeType == IncomeType.gross,
        onTap: () => app.update((x) => x.copyWith(incomeType: IncomeType.gross)),
      ),
      const SizedBox(height: 28),
      MoneyField(
        label: s.t('income.amount'),
        value: i.incomeAmount == 0 ? null : i.incomeAmount,
        step: app.country.amountStep * (i.frequency == PayFrequency.yearly ? 100 : 10),
        onChanged: (v) => app.update((x) => x.copyWith(incomeAmount: v ?? 0)),
      ),
      const SizedBox(height: 28),
      Text(s.t('income.howOften'), style: tt.titleMedium),
      const SizedBox(height: 8),
      for (final f in freqs) ...[
        ChoiceTile(
          title: s.t('freq.${f.name}'),
          selected: i.frequency == f,
          onTap: () {
            // Keep the same yearly income when switching how often.
            final yearly = i.incomeAmount * i.frequency.perYear;
            app.update((x) => x.copyWith(frequency: f, incomeAmount: (yearly / f.perYear).roundToDouble()));
          },
        ),
        const SizedBox(height: 10),
      ],
      if (i.incomeType == IncomeType.gross) ...[
        const SizedBox(height: 18),
        Text(s.t('income.married'), style: tt.titleMedium),
        const SizedBox(height: 8),
        YesNo(
          value: i.filingStatus == FilingStatus.married,
          onChanged: (v) => app.update((x) => x.copyWith(filingStatus: v ? FilingStatus.married : FilingStatus.single)),
        ),
      ],
    ]);
  }
}

// ---------------- household ----------------

class HouseholdStep extends StatelessWidget {
  const HouseholdStep({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final i = app.inputs;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StepHeader(title: s.t('house.title')),
      CountStepper(label: s.t('house.adults'), value: i.adults, min: 1, max: 6, onChanged: (v) => app.update((x) => x.copyWith(adults: v))),
      const SizedBox(height: 24),
      CountStepper(
        label: s.t('house.children'), value: i.children, min: 0, max: 8,
        onChanged: (v) => app.update((x) => x.copyWith(children: v, childcareKids: i.childcareKids.clamp(0, v))),
      ),
      if (i.children > 0) ...[
        const SizedBox(height: 24),
        CountStepper(
          label: s.t('house.childcare'), value: i.childcareKids, min: 0, max: i.children,
          onChanged: (v) => app.update((x) => x.copyWith(childcareKids: v)),
        ),
      ],
      const SizedBox(height: 28),
      Text(s.t('house.car'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      YesNo(value: i.hasCar, onChanged: (v) => app.update((x) => x.copyWith(hasCar: v))),
    ]);
  }
}

// ---------------- known bills ----------------

class BillsStep extends StatelessWidget {
  const BillsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final i = app.inputs;
    final typical = buildBudget(i.copyWith(known: i.known.withValue('rent', null), excluded: const {})).line('housing')?.estimate ?? 0;
    Widget field(String key, String label, {String? helper}) => Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: MoneyField(
            label: label,
            value: i.known[key],
            hint: '—',
            helper: helper ?? s.t('bills.unknown'),
            onChanged: (v) => app.update((x) => x.copyWith(known: x.known.withValue(key, v))),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StepHeader(title: s.t('bills.title'), body: s.t('bills.body')),
      field('rent', s.t('bills.rent'),
          helper: s.t('bills.rentHint', {'home': s.homeSize(app.cc, bedroomsNeeded(i.adults, i.children)), 'amount': app.money(typical)})),
      field('healthInsurance', s.t('bills.health')),
      field('debtPayments', s.t('bills.debt')),
      if (i.hasCar) field('carPayment', s.t('bills.carPayment')),
    ]);
  }
}
