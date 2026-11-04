// Core data types for the budget engine. Pure Dart: no Flutter imports, so it is unit-testable.

enum PayFrequency {
  weekly(52),
  biweekly(26),
  semimonthly(24),
  monthly(12),
  yearly(1);

  const PayFrequency(this.perYear);
  final int perYear;
}

enum IncomeType { gross, net }

enum FilingStatus { single, married }

enum BudgetMethod { realistic, rule503020, payYourselfFirst }

enum Group { needs, wants, savings }

enum CountryCode { us, jp }

enum Status { good, tight, short, high, none }

class CostIndex {
  const CostIndex(this.housing, this.groceries, this.transport, this.healthcare, this.other);
  final num housing, groceries, transport, healthcare, other;
}

class CityRecord {
  const CityRecord(this.id, this.name, this.region, this.index, this.localTaxRate, this.lat, this.lng);
  final String id, name, region;
  final CostIndex index;
  final num localTaxRate;
  final double lat, lng;
}

class RegionRecord {
  const RegionRecord(this.code, this.name, this.housing, this.general, this.taxRate, this.lat, this.lng);
  final String code, name;
  final num housing, general, taxRate;
  final double lat, lng;
}

class Baseline {
  const Baseline({
    required this.rentByBedrooms,
    required this.utilitiesBase,
    required this.utilitiesPerExtraPerson,
    required this.internet,
    required this.phonePerAdult,
    required this.groceriesPerAdult,
    required this.groceriesPerChild,
    required this.carRunningCost,
    required this.transitPerAdult,
    required this.healthcarePerAdult,
    required this.healthcarePerChild,
    required this.childcarePerChild,
    required this.diningPerAdult,
    required this.diningPerChild,
    required this.entertainmentPerAdult,
    required this.entertainmentPerChild,
    required this.personalPerAdult,
    required this.personalPerChild,
    required this.subscriptions,
    required this.bufferPercent,
  });

  /// Index 0 = 1 bedroom ... index 3 = 4 bedrooms.
  final List<num> rentByBedrooms;
  final num utilitiesBase, utilitiesPerExtraPerson, internet, phonePerAdult;
  final num groceriesPerAdult, groceriesPerChild, carRunningCost, transitPerAdult;
  final num healthcarePerAdult, healthcarePerChild, childcarePerChild;
  final num diningPerAdult, diningPerChild, entertainmentPerAdult, entertainmentPerChild;
  final num personalPerAdult, personalPerChild, subscriptions, bufferPercent;
}

class CountryData {
  const CountryData({required this.dataYear, required this.sources, required this.baseline, required this.cities, required this.regions});
  final int dataYear;
  final List<String> sources;
  final Baseline baseline;
  final List<CityRecord> cities;
  final List<RegionRecord> regions;
}

/// Monthly costs the user already knows. Null = estimate it for me.
class KnownCosts {
  const KnownCosts({this.rent, this.carPayment, this.debtPayments, this.healthInsurance, this.subscriptions});
  final double? rent, carPayment, debtPayments, healthInsurance, subscriptions;

  static const fields = ['rent', 'carPayment', 'debtPayments', 'healthInsurance', 'subscriptions'];

  double? operator [](String k) => switch (k) {
        'rent' => rent,
        'carPayment' => carPayment,
        'debtPayments' => debtPayments,
        'healthInsurance' => healthInsurance,
        'subscriptions' => subscriptions,
        _ => null,
      };

  KnownCosts withValue(String k, double? v) {
    final m = toJson()..[k] = v;
    return KnownCosts.fromJson(m);
  }

  KnownCosts map(double Function(double) f) => KnownCosts.fromJson({
        for (final k in fields)
          if (this[k] != null) k: f(this[k]!),
      });

  Map<String, double?> toJson() => {for (final k in fields) k: this[k]};

  factory KnownCosts.fromJson(Map<String, dynamic> j) => KnownCosts(
        rent: (j['rent'] as num?)?.toDouble(),
        carPayment: (j['carPayment'] as num?)?.toDouble(),
        debtPayments: (j['debtPayments'] as num?)?.toDouble(),
        healthInsurance: (j['healthInsurance'] as num?)?.toDouble(),
        subscriptions: (j['subscriptions'] as num?)?.toDouble(),
      );
}

/// An expense the user added themselves (gym, pet, medicine...).
class CustomItem {
  const CustomItem({required this.id, required this.name, required this.amount, required this.group});
  final String id, name;
  final double amount;
  final Group group; // needs or wants

  CustomItem copyWith({String? name, double? amount, Group? group}) =>
      CustomItem(id: id, name: name ?? this.name, amount: amount ?? this.amount, group: group ?? this.group);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'amount': amount, 'group': group.name};
  factory CustomItem.fromJson(Map<String, dynamic> j) => CustomItem(
        id: j['id'] as String,
        name: j['name'] as String,
        amount: (j['amount'] as num).toDouble(),
        group: Group.values.byName(j['group'] as String),
      );
}

class BudgetInputs {
  const BudgetInputs({
    this.incomeAmount = 0,
    this.frequency = PayFrequency.monthly,
    this.incomeType = IncomeType.net,
    this.filingStatus = FilingStatus.single,
    this.location = 'jp:national',
    this.adults = 1,
    this.children = 0,
    this.childcareKids = 0,
    this.hasCar = false,
    this.known = const KnownCosts(),
    this.method = BudgetMethod.realistic,
    this.excluded = const {},
    this.custom = const [],
  });

  final double incomeAmount;
  final PayFrequency frequency;
  final IncomeType incomeType;
  final FilingStatus filingStatus;

  /// `<country>:city:<id>`, `<country>:region:<code>` or `<country>:national`
  final String location;
  final int adults, children, childcareKids;
  final bool hasCar;
  final KnownCosts known;
  final BudgetMethod method;

  /// Things the user switched off: category ids, or `tax:<lineId>`.
  final Set<String> excluded;
  final List<CustomItem> custom;

  BudgetInputs copyWith({
    double? incomeAmount,
    PayFrequency? frequency,
    IncomeType? incomeType,
    FilingStatus? filingStatus,
    String? location,
    int? adults,
    int? children,
    int? childcareKids,
    bool? hasCar,
    KnownCosts? known,
    BudgetMethod? method,
    Set<String>? excluded,
    List<CustomItem>? custom,
  }) =>
      BudgetInputs(
        incomeAmount: incomeAmount ?? this.incomeAmount,
        frequency: frequency ?? this.frequency,
        incomeType: incomeType ?? this.incomeType,
        filingStatus: filingStatus ?? this.filingStatus,
        location: location ?? this.location,
        adults: adults ?? this.adults,
        children: children ?? this.children,
        childcareKids: childcareKids ?? this.childcareKids,
        hasCar: hasCar ?? this.hasCar,
        known: known ?? this.known,
        method: method ?? this.method,
        excluded: excluded ?? this.excluded,
        custom: custom ?? this.custom,
      );

  Map<String, dynamic> toJson() => {
        'incomeAmount': incomeAmount,
        'frequency': frequency.name,
        'incomeType': incomeType.name,
        'filingStatus': filingStatus.name,
        'location': location,
        'adults': adults,
        'children': children,
        'childcareKids': childcareKids,
        'hasCar': hasCar,
        'known': known.toJson(),
        'method': method.name,
        'excluded': excluded.toList(),
        'custom': custom.map((c) => c.toJson()).toList(),
      };

  factory BudgetInputs.fromJson(Map<String, dynamic> j) {
    const d = BudgetInputs();
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    return BudgetInputs(
      incomeAmount: (j['incomeAmount'] as num?)?.toDouble() ?? d.incomeAmount,
      frequency: pick(PayFrequency.values, j['frequency'], d.frequency),
      incomeType: pick(IncomeType.values, j['incomeType'], d.incomeType),
      filingStatus: pick(FilingStatus.values, j['filingStatus'], d.filingStatus),
      location: j['location'] as String? ?? d.location,
      adults: j['adults'] as int? ?? d.adults,
      children: j['children'] as int? ?? d.children,
      childcareKids: j['childcareKids'] as int? ?? d.childcareKids,
      hasCar: j['hasCar'] as bool? ?? d.hasCar,
      known: j['known'] is Map ? KnownCosts.fromJson(Map<String, dynamic>.from(j['known'] as Map)) : d.known,
      method: pick(BudgetMethod.values, j['method'], d.method),
      excluded: {...?(j['excluded'] as List?)?.cast<String>()},
      custom: [...?(j['custom'] as List?)?.map((e) => CustomItem.fromJson(Map<String, dynamic>.from(e as Map)))],
    );
  }
}

class ResolvedLocation {
  const ResolvedLocation({
    required this.key,
    required this.country,
    required this.kind,
    required this.id,
    required this.regionCode,
    required this.index,
    required this.regionTaxRate,
    required this.localTaxRate,
  });
  final String key;
  final CountryCode country;

  /// 'city', 'region' or 'national'
  final String kind;
  final String id;
  final String regionCode;
  final CostIndex index;
  final num regionTaxRate, localTaxRate;
  bool get isAverage => kind != 'city';
}

class TaxLine {
  const TaxLine(this.id, this.amount, {this.included = true});
  final String id;

  /// yearly amount
  final double amount;
  final bool included;
  TaxLine withIncluded(bool v) => TaxLine(id, amount, included: v);
}

class CategoryLine {
  CategoryLine({
    required this.id,
    required this.group,
    required this.amount,
    required this.estimate,
    required this.fixed,
    this.locked = false,
    this.customName,
  });

  /// Built-in id like `housing`, or `custom:<id>`.
  final String id;
  final Group group;

  /// recommended monthly amount
  double amount;

  /// what this typically costs locally for this household (0 for savings)
  final double estimate;

  /// amount came from the user (known costs / custom items): never flexed
  final bool fixed;

  /// user edited this row: never flexed by rebalancing
  bool locked;
  final String? customName;
  bool get isCustom => customName != null;

  CategoryLine copy() =>
      CategoryLine(id: id, group: group, amount: amount, estimate: estimate, fixed: fixed, locked: locked, customName: customName);
}
