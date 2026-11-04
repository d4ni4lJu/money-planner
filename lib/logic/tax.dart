import 'dart:math' as math;

import 'models.dart';

double toAnnual(double amount, PayFrequency f) => math.max(0.0, amount) * f.perYear;

double _progressive(double taxable, List<(double, double)> brackets) {
  var left = math.max(0.0, taxable), tax = 0.0, floor = 0.0;
  for (final (upTo, rate) in brackets) {
    if (left <= 0) break;
    final slice = math.min(left, upTo - floor);
    tax += slice * rate;
    left -= slice;
    floor = upTo;
  }
  return tax;
}

const _inf = double.infinity;

// ---------------- United States (2026, IRS Rev. Proc. 2025-32) ----------------

const _usStd = {FilingStatus.single: 16100.0, FilingStatus.married: 32200.0};
const _usBrackets = {
  FilingStatus.single: [(12400.0, .10), (50400.0, .12), (105700.0, .22), (201775.0, .24), (256225.0, .32), (640600.0, .35), (_inf, .37)],
  FilingStatus.married: [(24800.0, .10), (100800.0, .12), (211400.0, .22), (403550.0, .24), (512450.0, .32), (768700.0, .35), (_inf, .37)],
};

double usFederalIncomeTax(double gross, FilingStatus s) => _progressive(gross - _usStd[s]!, _usBrackets[s]!);

/// Social Security + Medicare. Assumes one earner (a conservative simplification for couples).
double usFica(double gross, FilingStatus s) {
  final ss = math.min(gross, 184500.0) * 0.062;
  final threshold = s == FilingStatus.married ? 250000.0 : 200000.0;
  return ss + gross * 0.0145 + math.max(0.0, gross - threshold) * 0.009;
}

/// State tax is an approximate effective rate after the standard deduction; city tax is a flat wage tax.
List<TaxLine> usTaxLines(double gross, FilingStatus s, num stateRate, num localRate) {
  final g = math.max(0.0, gross);
  return [
    TaxLine('federal', usFederalIncomeTax(g, s)),
    TaxLine('fica', usFica(g, s)),
    TaxLine('state', math.max(0.0, g - _usStd[s]!) * stateRate),
    if (localRate > 0) TaxLine('local', g * localRate),
  ];
}

// ---------------- Japan (employees, 2025 tax reform rules) ----------------

/// 給与所得控除: employment income deduction (minimum ¥650,000 from 2025).
double jpEmploymentDeduction(double salary) {
  final s = math.max(0.0, salary);
  final double d;
  if (s <= 1800000) {
    d = s * 0.4 - 100000;
  } else if (s <= 3600000) {
    d = s * 0.3 + 80000;
  } else if (s <= 6600000) {
    d = s * 0.2 + 440000;
  } else if (s <= 8500000) {
    d = s * 0.1 + 1100000;
  } else {
    d = 1950000;
  }
  return math.min(s, math.max(650000.0, d));
}

/// 基礎控除 for national income tax (2025–2026 amounts, by total income).
double jpBasicDeduction(double income) {
  if (income <= 1320000) return 950000;
  if (income <= 3360000) return 880000;
  if (income <= 4890000) return 680000;
  if (income <= 6550000) return 630000;
  if (income <= 23500000) return 580000;
  if (income <= 24000000) return 480000;
  if (income <= 24500000) return 320000;
  if (income <= 25000000) return 160000;
  return 0;
}

const _jpBrackets = [(1950000.0, .05), (3300000.0, .10), (6950000.0, .20), (9000000.0, .23), (18000000.0, .33), (40000000.0, .40), (_inf, .45)];

/// "married" means a spouse with little or no income (配偶者控除). Bonuses are treated as salary.
List<TaxLine> jpTaxLines(double salary, FilingStatus status) {
  final s = math.max(0.0, salary);
  final monthly = s / 12;
  final health = math.min(monthly, 1390000.0) * 0.05 * 12;
  final pension = math.min(monthly, 650000.0) * 0.0915 * 12;
  final employment = s * 0.0055;
  final social = health + pension + employment;
  final income = math.max(0.0, s - jpEmploymentDeduction(s));
  final spouse = status == FilingStatus.married && income <= 9000000;
  final taxableNat = (math.max(0.0, income - social - jpBasicDeduction(income) - (spouse ? 380000 : 0)) / 1000).floor() * 1000.0;
  final incomeTax = _progressive(taxableNat, _jpBrackets) * 1.021;
  final taxableRes = math.max(0.0, income - social - 430000 - (spouse ? 330000 : 0));
  final resident = income <= 450000 ? 0.0 : taxableRes * 0.10 + 5000;
  return [
    TaxLine('income', incomeTax),
    TaxLine('resident', resident),
    TaxLine('pension', pension),
    TaxLine('health', health),
    TaxLine('employment', employment),
  ];
}
