import 'dart:math' as math;

import 'countries.dart';
import 'location.dart';
import 'models.dart';
import 'tax.dart';

/// Built-in categories in display order, with their group.
const categoryGroups = <String, Group>{
  'housing': Group.needs,
  'utilities': Group.needs,
  'groceries': Group.needs,
  'transportation': Group.needs,
  'carPayment': Group.needs,
  'healthcare': Group.needs,
  'childcare': Group.needs,
  'debt': Group.needs,
  'buffer': Group.needs,
  'dining': Group.wants,
  'entertainment': Group.wants,
  'personal': Group.wants,
  'subscriptions': Group.wants,
  'emergency': Group.savings,
  'investing': Group.savings,
};

const _emergencyShare = 0.4;
const minSavingsRate = 0.1;

String taxKey(String id) => 'tax:$id';
double _sum(Iterable<CategoryLine> l) => l.fold(0.0, (t, x) => t + x.amount);
bool _flexible(CategoryLine l) => !l.fixed && !l.locked;

// ---------- income ----------

class IncomeResult {
  const IncomeResult({required this.grossAnnual, required this.netAnnual, required this.taxes});
  final double grossAnnual, netAnnual;

  /// every tax line; `included` is false for ones the user switched off
  final List<TaxLine> taxes;
  double get takeHome => netAnnual / 12;
  double get grossMonthly => grossAnnual / 12;
  double get taxTotal => taxes.where((t) => t.included).fold(0.0, (s, t) => s + t.amount);
}

IncomeResult computeIncome(BudgetInputs inputs, ResolvedLocation loc) {
  final country = countries[loc.country]!;
  final annual = toAnnual(inputs.incomeAmount, inputs.frequency);
  List<TaxLine> all(double g) => country.taxLines(g, inputs.filingStatus, loc);

  var gross = annual;
  if (inputs.incomeType == IncomeType.net) {
    // Back-solve with every tax included so the gross figure is realistic.
    double net(double g) => g - all(g).fold(0.0, (s, t) => s + t.amount);
    var lo = annual, hi = annual * 2 + 1;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (net(mid) < annual) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    gross = (lo + hi) / 2;
  }
  final lines = [for (final t in all(gross)) t.withIncluded(!inputs.excluded.contains(taxKey(t.id)))];
  final total = lines.where((t) => t.included).fold(0.0, (s, t) => s + t.amount);
  return IncomeResult(grossAnnual: gross, netAnnual: inputs.incomeType == IncomeType.net ? annual : gross - total, taxes: lines);
}

// ---------- local cost estimates ----------

int bedroomsNeeded(int adults, int children) => math.min<int>(4, 1 + math.max<int>(0, adults - 2) + (children / 2).ceil());

typedef Estimate = ({double estimate, double? fixed});

/// What each category typically costs this household in this location, per month.
Map<String, Estimate> localEstimates(BudgetInputs inputs, ResolvedLocation loc, double takeHome) {
  final b = countries[loc.country]!.data.baseline;
  final a = math.max(1, inputs.adults), c = math.max(0, inputs.children);
  final ix = loc.index;
  double f(num base, num idx) => (base * idx / 100).roundToDouble();
  final k = inputs.known;
  final people = a + c;
  final est = <String, Estimate>{
    'housing': (estimate: f(b.rentByBedrooms[bedroomsNeeded(a, c) - 1], ix.housing), fixed: k.rent),
    'utilities': (estimate: f(b.utilitiesBase + b.utilitiesPerExtraPerson * (people - 1) + b.internet + b.phonePerAdult * a, ix.other), fixed: null),
    'groceries': (estimate: f(b.groceriesPerAdult * a + b.groceriesPerChild * c, ix.groceries), fixed: null),
    'transportation': (estimate: inputs.hasCar ? f(b.carRunningCost, ix.transport) : f(b.transitPerAdult * a, ix.transport), fixed: null),
    'healthcare': (estimate: f(b.healthcarePerAdult * a + b.healthcarePerChild * c, ix.healthcare), fixed: k.healthInsurance),
    'buffer': (estimate: (takeHome * b.bufferPercent).roundToDouble(), fixed: null),
    'dining': (estimate: f(b.diningPerAdult * a + b.diningPerChild * c, ix.other), fixed: null),
    'entertainment': (estimate: f(b.entertainmentPerAdult * a + b.entertainmentPerChild * c, ix.other), fixed: null),
    'personal': (estimate: f(b.personalPerAdult * a + b.personalPerChild * c, ix.other), fixed: null),
    'subscriptions': (estimate: b.subscriptions.toDouble(), fixed: k.subscriptions),
  };
  if (inputs.hasCar && (k.carPayment ?? 0) > 0) est['carPayment'] = (estimate: k.carPayment!, fixed: k.carPayment);
  final kids = math.min(inputs.childcareKids, c);
  if (kids > 0) est['childcare'] = (estimate: f(b.childcarePerChild * kids, ix.other), fixed: null);
  if ((k.debtPayments ?? 0) > 0) est['debt'] = (estimate: k.debtPayments!, fixed: k.debtPayments);
  return est;
}

/// Categories that apply to this household (whether or not the user switched them off).
List<String> applicableCategories(BudgetInputs inputs) {
  final est = localEstimates(inputs, resolveLocation(inputs.location), 1);
  return [for (final id in categoryGroups.keys) if (est.containsKey(id) || categoryGroups[id] == Group.savings) id];
}

// ---------- allocation helpers ----------

void _fillGroup(List<CategoryLine> lines, double budget) {
  final flex = lines.where(_flexible).toList();
  if (flex.isEmpty) return;
  final room = math.max(0.0, budget - _sum(lines.where((l) => !_flexible(l))));
  final weight = flex.fold(0.0, (t, l) => t + l.estimate);
  for (final l in flex) {
    l.amount = weight > 0 ? room * l.estimate / weight : room / flex.length;
  }
}

/// Removes up to `amount` from flexible lines, group by group in `order`. Returns what's left.
double _absorb(List<CategoryLine> lines, double amount, List<Group> order, [double Function(CategoryLine)? floor]) {
  floor ??= (_) => 0;
  var left = amount;
  for (final g in order) {
    if (left <= 0) break;
    final adj = lines.where((l) => l.group == g && _flexible(l)).toList();
    final room = adj.fold(0.0, (t, l) => t + math.max(0.0, l.amount - floor!(l)));
    if (room <= 0) continue;
    final take = math.min(left, room);
    for (final l in adj) {
      l.amount -= take * math.max(0.0, l.amount - floor(l)) / room;
    }
    left -= take;
  }
  return left;
}

void _setSavings(List<CategoryLine> lines, double total) {
  final em = lines.where((l) => l.id == 'emergency' && _flexible(l)).firstOrNull;
  final inv = lines.where((l) => l.id == 'investing' && _flexible(l)).firstOrNull;
  final t = math.max(0.0, total);
  if (em != null && inv != null) {
    em.amount = t * _emergencyShare;
    inv.amount = t * (1 - _emergencyShare);
  } else {
    em?.amount = t;
    inv?.amount = t;
  }
}

/// Rounds every line, then folds the few units of rounding error into a flexible line (savings first).
void _roundLines(List<CategoryLine> lines, double takeHome) {
  final before = _sum(lines);
  for (final l in lines) {
    l.amount = l.amount.roundToDouble();
  }
  if ((takeHome.roundToDouble() - before.roundToDouble()).abs() > 1) return; // genuinely unbalanced
  final drift = takeHome.roundToDouble() - _sum(lines);
  if (drift == 0) return;
  final sink = lines.reversed.where((l) => _flexible(l) && l.group == Group.savings).firstOrNull ??
      lines.where((l) => _flexible(l) && l.amount > 0).firstOrNull;
  if (sink != null) sink.amount = math.max(0, sink.amount + drift);
}

// ---------- main entry ----------

class Budget {
  Budget({required this.takeHome, required this.lines, required this.location, required this.income});
  final double takeHome;
  final List<CategoryLine> lines;
  final ResolvedLocation location;
  final IncomeResult income;
  Country get country => countries[location.country]!;

  /// money still unassigned (positive) or overspent (negative)
  double get unassigned => takeHome - _sum(lines);
  double groupTotal(Group g) => _sum(lines.where((l) => l.group == g));
  double get savingsRate => takeHome > 0 ? groupTotal(Group.savings) / takeHome : 0;
  CategoryLine? line(String id) => lines.where((l) => l.id == id).firstOrNull;

  Budget withLines(List<CategoryLine> l) => Budget(takeHome: takeHome, lines: l, location: location, income: income);
}

Budget buildBudget(BudgetInputs inputs) {
  final location = resolveLocation(inputs.location);
  final income = computeIncome(inputs, location);
  final t = income.takeHome;
  final est = localEstimates(inputs, location, t);

  final lines = <CategoryLine>[
    for (final MapEntry(key: id, value: group) in categoryGroups.entries)
      if ((est.containsKey(id) || group == Group.savings) && !inputs.excluded.contains(id))
        CategoryLine(
          id: id,
          group: group,
          estimate: est[id]?.estimate ?? 0,
          amount: est[id]?.fixed ?? est[id]?.estimate ?? 0,
          fixed: est[id]?.fixed != null,
        ),
    for (final c in inputs.custom)
      if (!inputs.excluded.contains('custom:${c.id}'))
        CategoryLine(
          id: 'custom:${c.id}', group: c.group, estimate: math.max(0, c.amount), amount: math.max(0, c.amount),
          fixed: true, customName: c.name.trim().isEmpty ? '?' : c.name.trim(),
        ),
  ];
  List<CategoryLine> group(Group g) => lines.where((l) => l.group == g).toList();
  double spending() => _sum(group(Group.needs)) + _sum(group(Group.wants));

  switch (inputs.method) {
    case BudgetMethod.rule503020:
      _fillGroup(group(Group.needs), t * 0.5);
      _fillGroup(group(Group.wants), t * 0.3);
      _setSavings(lines, t * 0.2);
      final over = _sum(lines) - t;
      if (over > 0) _absorb(lines, over, [Group.wants, Group.savings]);
    case BudgetMethod.payYourselfFirst:
      _setSavings(lines, t * 0.25);
      _fillGroup(group(Group.wants), math.max(0, t - _sum(group(Group.needs)) - _sum(group(Group.savings))));
      // Don't inflate wants past 1.5x typical; the excess goes back to savings.
      var excess = 0.0;
      for (final l in group(Group.wants).where(_flexible)) {
        final cap = l.estimate * 1.5;
        if (l.amount > cap) {
          excess += l.amount - cap;
          l.amount = cap;
        }
      }
      if (excess > 0) _setSavings(lines, _sum(group(Group.savings)) + excess);
      final over = _sum(lines) - t;
      if (over > 0) _absorb(lines, over, [Group.wants, Group.savings]);
    case BudgetMethod.realistic:
      // Every unit of money is assigned; savings get what's left, but wants are trimmed
      // (down to half of typical) to keep at least a 10% savings rate.
      final shortBy = t * minSavingsRate - (t - spending());
      if (shortBy > 0 && group(Group.savings).isNotEmpty) {
        final left = _absorb(lines, shortBy, [Group.wants], (l) => l.estimate * 0.5);
        if (left > 0) _absorb(lines, left, [Group.needs], (l) => l.id == 'buffer' ? 0 : l.amount);
      }
      _setSavings(lines, t - spending());
  }
  _roundLines(lines, t);
  return Budget(takeHome: t.roundToDouble(), lines: lines, location: location, income: income);
}

/// Sets one category to a chosen amount and rebalances so the budget still adds up:
/// overspending comes out of savings first, then wants, then needs; freed money goes to savings.
Budget applyEdit(Budget b, String id, double amount) {
  final lines = [for (final l in b.lines) l.copy()];
  final target = lines.where((l) => l.id == id).firstOrNull;
  if (target == null) return b;
  target
    ..amount = math.max(0, amount)
    ..locked = true;
  final diff = _sum(lines) - b.takeHome;
  if (diff > 0) {
    _absorb(lines, diff, [Group.savings, Group.wants, Group.needs]);
  } else if (diff < 0) {
    final sink = lines.where((l) => l.id == 'investing' && _flexible(l)).firstOrNull ??
        lines.where((l) => l.id == 'emergency' && _flexible(l)).firstOrNull;
    sink?.amount += -diff;
  }
  _roundLines(lines, b.takeHome);
  return b.withLines(lines);
}

Budget applyEdits(Budget b, Map<String, double> edits) => edits.entries.fold(b, (acc, e) => applyEdit(acc, e.key, e.value));

// ---------- analysis ----------

Status lineStatus(CategoryLine line, Budget b) {
  if (line.group == Group.savings) {
    final r = b.savingsRate;
    return r >= 0.15 ? Status.good : r >= minSavingsRate ? Status.tight : Status.short;
  }
  if (line.estimate <= 0 || line.isCustom || line.id == 'debt' || line.id == 'carPayment') return Status.none;
  final ratio = line.amount / line.estimate;
  if (line.group == Group.needs && ratio > 1.3) return Status.high;
  if (line.fixed) return Status.good; // a known cost below typical is good news
  if (ratio >= 0.9) return Status.good;
  if (ratio >= 0.7) return Status.tight;
  return Status.short;
}

enum WarningLevel { critical, warning, info }

/// A warning as a code plus values; the UI turns it into words in the chosen language.
class BudgetWarning {
  const BudgetWarning(this.level, this.code, [this.values = const {}]);
  final WarningLevel level;
  final String code;
  final Map<String, Object> values;
}

List<BudgetWarning> warnings(Budget b, BudgetInputs inputs) {
  final out = <BudgetWarning>[];
  final t = b.takeHome;
  if (t <= 0) return const [BudgetWarning(WarningLevel.info, 'noIncome')];

  if (b.unassigned < -1) {
    final wants = b.lines.where((l) => l.group == Group.wants && l.amount > 0).toList()..sort((x, y) => y.amount.compareTo(x.amount));
    out.add(BudgetWarning(WarningLevel.critical, 'shortfall', {'amount': -b.unassigned, 'trim': wants.take(2).map((l) => l.id).toList()}));
  }
  final housing = b.line('housing');
  if (housing != null && b.income.grossMonthly > 0) {
    final share = housing.amount / b.income.grossMonthly;
    if (share > 0.3) out.add(BudgetWarning(share > 0.4 ? WarningLevel.critical : WarningLevel.warning, 'housingShare', {'pct': share}));
    if (housing.fixed && housing.amount > housing.estimate * 1.2) {
      out.add(BudgetWarning(WarningLevel.warning, 'rentHigh', {'pct': housing.amount / housing.estimate - 1, 'typical': housing.estimate}));
    }
  }
  final debt = b.line('debt');
  if (debt != null && debt.amount > t * 0.2) out.add(BudgetWarning(WarningLevel.warning, 'debtHigh', {'pct': debt.amount / t}));

  final off = b.income.taxes.where((x) => !x.included).toList();
  if (off.isNotEmpty && inputs.incomeType == IncomeType.gross) {
    out.add(BudgetWarning(WarningLevel.info, 'taxesOff', {'ids': off.map((x) => x.id).toList(), 'amount': off.fold(0.0, (s, x) => s + x.amount) / 12}));
  }
  final hasSavings = b.lines.any((l) => l.group == Group.savings);
  if (b.unassigned > math.max(1, t * 0.01)) out.add(BudgetWarning(WarningLevel.info, 'leftover', {'amount': b.unassigned}));
  if (hasSavings && b.unassigned >= -1 && b.savingsRate < minSavingsRate) {
    out.add(BudgetWarning(WarningLevel.warning, 'lowSavings', {'pct': b.savingsRate}));
  }
  if (out.isEmpty) out.add(BudgetWarning(WarningLevel.info, 'healthy', {'pct': b.savingsRate}));
  return out;
}

// ---------- switching location ----------

/// Within a country only the location changes. Across countries, typed money (income, known
/// costs, custom items) is converted at a rough exchange rate and country-specific tax switches clear.
({BudgetInputs inputs, bool countryChanged}) switchLocation(BudgetInputs inputs, String key) {
  final from = countries[countryOf(inputs.location)]!, to = countries[countryOf(key)]!;
  if (from.code == to.code) return (inputs: inputs.copyWith(location: key), countryChanged: false);
  final rate = to.perUSD / from.perUSD;
  double conv(double v) => (v * rate).roundToDouble();
  return (
    countryChanged: true,
    inputs: inputs.copyWith(
      location: key,
      incomeAmount: conv(inputs.incomeAmount),
      known: inputs.known.map(conv),
      custom: [for (final c in inputs.custom) c.copyWith(amount: conv(c.amount))],
      excluded: inputs.excluded.where((e) => !e.startsWith('tax:')).toSet(),
    ),
  );
}
