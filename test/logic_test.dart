import 'package:budget_compass/logic/budget.dart';
import 'package:budget_compass/logic/countries.dart';
import 'package:budget_compass/logic/location.dart';
import 'package:budget_compass/logic/models.dart';
import 'package:budget_compass/logic/tax.dart';
import 'package:flutter_test/flutter_test.dart';

double total(Iterable<TaxLine> l) => l.fold(0.0, (t, x) => t + x.amount);
double sumLines(Budget b) => b.lines.fold(0.0, (t, l) => t + l.amount);

const usBase = BudgetInputs(
  incomeAmount: 5000, frequency: PayFrequency.monthly, incomeType: IncomeType.net,
  location: 'us:region:TX', hasCar: true,
);
const tsu = BudgetInputs(
  incomeAmount: 4600000, frequency: PayFrequency.yearly, incomeType: IncomeType.gross,
  location: 'jp:city:tsu', hasCar: true,
);

void main() {
  group('tax: United States', () {
    test('zero below the standard deduction', () => expect(usFederalIncomeTax(15000, FilingStatus.single), 0));
    test('progressive brackets (single, \$60k)', () => expect(usFederalIncomeTax(60000, FilingStatus.single), closeTo(1240 + 3780, 0.01)));
    test('Social Security wage base', () => expect(usFica(184500, FilingStatus.single), closeTo(184500 * 0.0765, 0.01)));
    test('city tax line only where there is one', () {
      expect(usTaxLines(80000, FilingStatus.single, 0.05, 0).map((l) => l.id), ['federal', 'fica', 'state']);
      expect(usTaxLines(80000, FilingStatus.single, 0.05, 0.035).last.amount, closeTo(2800, 0.01));
    });
  });

  group('tax: Japan', () {
    test('employment income deduction', () {
      expect(jpEmploymentDeduction(1000000), 650000);
      expect(jpEmploymentDeduction(3000000), 980000);
      expect(jpEmploymentDeduction(5000000), 1440000);
      expect(jpEmploymentDeduction(20000000), 1950000);
    });
    test('basic deduction', () {
      expect(jpBasicDeduction(1000000), 950000);
      expect(jpBasicDeduction(5000000), 630000);
      expect(jpBasicDeduction(10000000), 580000);
    });
    test('¥4M salary breakdown, ~79% take-home', () {
      final l = {for (final t in jpTaxLines(4000000, FilingStatus.single)) t.id: t.amount};
      expect(l['pension'], closeTo(366000, 100));
      expect(l['health'], closeTo(200000, 100));
      expect(l['income'], closeTo(65957, 100));
      expect(l['resident'], closeTo(179200, 100));
      final net = 4000000 - total(jpTaxLines(4000000, FilingStatus.single));
      expect(net / 4000000, inInclusiveRange(0.77, 0.81));
    });
    test('spouse deduction lowers tax', () {
      expect(total(jpTaxLines(5000000, FilingStatus.married)), lessThan(total(jpTaxLines(5000000, FilingStatus.single))));
    });
  });

  group('location', () {
    test('resolves Tsu and falls back', () {
      final l = resolveLocation('jp:city:tsu');
      expect(l.country, CountryCode.jp);
      expect(l.regionCode, '24');
      expect(l.index.housing, lessThan(100));
      expect(resolveLocation('jp:region:13').kind, 'region');
      expect(resolveLocation('jp:city:atlantis').key, 'jp:national');
      expect(resolveLocation('us:city:new-york-ny').localTaxRate, greaterThan(0));
    });
    test('data is complete and consistent', () {
      expect(countries[CountryCode.jp]!.data.regions.length, 47);
      expect(countries[CountryCode.us]!.data.regions.length, 51);
      for (final c in countries.values) {
        for (final city in c.data.cities) {
          expect(c.data.regions.any((r) => r.code == city.region), isTrue, reason: city.id);
        }
      }
    });
    test('nearestLocation', () {
      expect(nearestLocation(34.72, 136.51)!.key, 'jp:city:tsu');
      expect(nearestLocation(34.07, 136.19)!.key, 'jp:region:24'); // Owase
      expect(nearestLocation(30.28, -97.74)!.key, 'us:city:austin-tx');
      expect(nearestLocation(48.85, 2.35), isNull); // Paris
    });
    test('locationFromGeocode trusts the official prefecture', () {
      expect(locationFromGeocode(34.77, 136.13, const GeocodeHint(countryCode: 'JP', subdivisionCode: 'JP-24', city: 'Iga'))!.key, 'jp:region:24');
      expect(locationFromGeocode(34.72, 136.5, const GeocodeHint(countryCode: 'JP', subdivisionCode: 'JP-24', city: 'Tsu'))!.key, 'jp:city:tsu');
      expect(locationFromGeocode(34.72, 136.51, null)!.key, 'jp:city:tsu');
      expect(locationFromGeocode(48.85, 2.35, const GeocodeHint(countryCode: 'FR', subdivisionCode: 'FR-IDF')), isNull);
    });
    test('guessFromTimeZone', () {
      expect(guessFromTimeZone('JST'), 'jp:national');
      expect(guessFromTimeZone('CET', localeCountry: 'JP'), 'jp:national');
      expect(guessFromTimeZone('PST'), 'us:national');
      expect(guessFromTimeZone('CET'), isNull);
    });
  });

  group('budget', () {
    test('after-tax income is take-home', () => expect(buildBudget(usBase).takeHome, 5000));
    test('every method assigns every unit exactly', () {
      for (final m in BudgetMethod.values) {
        for (final loc in ['us:city:austin-tx', 'jp:city:tsu', 'jp:city:tokyo']) {
          for (var income = 3000.0; income < 3000000; income *= 1.37) {
            final b = buildBudget(usBase.copyWith(method: m, location: loc, incomeAmount: income.roundToDouble()));
            if (b.unassigned < 0) continue; // genuine shortfall
            expect(b.unassigned, 0, reason: '$m $loc $income');
          }
        }
      }
    });
    test('50/30/20 split', () {
      final b = buildBudget(usBase.copyWith(method: BudgetMethod.rule503020));
      expect(b.groupTotal(Group.needs), closeTo(2500, 10));
      expect(b.groupTotal(Group.wants), closeTo(1500, 10));
      expect(b.groupTotal(Group.savings), closeTo(1000, 10));
    });
    test('Japan: Tsu take-home and rent are realistic; Tokyo rent much higher', () {
      final b = buildBudget(tsu);
      expect(b.takeHome, inInclusiveRange(280000, 310000));
      expect(b.line('housing')!.estimate, inInclusiveRange(35000, 60000));
      final tokyo = buildBudget(tsu.copyWith(location: 'jp:city:tokyo'));
      expect(tokyo.line('housing')!.estimate, greaterThan(b.line('housing')!.estimate * 2));
    });
    test('known costs are fixed', () {
      final b = buildBudget(usBase.copyWith(known: const KnownCosts(rent: 1234, debtPayments: 300)));
      expect(b.line('housing')!.amount, 1234);
      expect(b.line('housing')!.fixed, isTrue);
      expect(b.line('debt')!.amount, 300);
    });
    test('protects a 10% savings rate when tight', () {
      final b = buildBudget(usBase.copyWith(incomeAmount: 3800));
      expect(b.savingsRate, greaterThanOrEqualTo(0.099));
      expect(b.line('dining')!.amount, lessThan(b.line('dining')!.estimate));
    });
    test('shortfall is critical', () {
      final i = usBase.copyWith(incomeAmount: 2000, known: const KnownCosts(rent: 2500));
      final b = buildBudget(i);
      expect(b.unassigned, lessThan(0));
      expect(warnings(b, i).first.code, 'shortfall');
    });
  });

  group('include / exclude', () {
    test('switching off a tax raises take-home', () {
      final ny = usBase.copyWith(incomeType: IncomeType.gross, frequency: PayFrequency.yearly, incomeAmount: 80000, location: 'us:city:new-york-ny');
      final diff = buildBudget(ny.copyWith(excluded: {'tax:local'})).takeHome - buildBudget(ny).takeHome;
      expect(diff, closeTo(80000 * 0.035 / 12, 2));
    });
    test('taxes can\'t change entered take-home', () => expect(buildBudget(usBase.copyWith(excluded: {'tax:federal'})).takeHome, 5000));
    test('removed categories are reallocated', () {
      final e = buildBudget(usBase.copyWith(excluded: {'dining', 'entertainment'}));
      expect(e.line('dining'), isNull);
      expect(e.savingsRate, greaterThan(buildBudget(usBase).savingsRate));
      expect(e.unassigned, 0);
    });
    test('savings off leaves money unassigned', () {
      final i = usBase.copyWith(excluded: {'emergency', 'investing'});
      final e = buildBudget(i);
      expect(e.unassigned, greaterThan(0));
      expect(warnings(e, i).any((w) => w.code == 'leftover'), isTrue);
    });
    test('custom expenses', () {
      final i = usBase.copyWith(custom: const [CustomItem(id: 'gym', name: 'Gym', amount: 60, group: Group.wants)]);
      final b = buildBudget(i);
      final gym = b.line('custom:gym')!;
      expect(gym.amount, 60);
      expect(gym.fixed, isTrue);
      expect(lineStatus(gym, b), Status.none);
      expect(b.unassigned, 0);
      expect(buildBudget(i.copyWith(excluded: {'custom:gym'})).line('custom:gym'), isNull);
    });
  });

  group('editing', () {
    test('overspend comes out of savings first', () {
      final b = buildBudget(usBase);
      final before = b.groupTotal(Group.savings);
      final e = applyEdit(b, 'entertainment', b.line('entertainment')!.amount + 200);
      expect(e.unassigned, 0);
      expect(e.groupTotal(Group.savings), closeTo(before - 200, 1));
      expect(e.line('groceries')!.amount, b.line('groceries')!.amount);
    });
    test('freed money goes to investing', () {
      final b = buildBudget(usBase);
      final e = applyEdit(b, 'dining', 0);
      expect(e.line('investing')!.amount, b.line('investing')!.amount + b.line('dining')!.amount);
    });
  });

  group('status', () {
    test('flags', () {
      final b = buildBudget(usBase);
      final g = b.line('groceries')!;
      CategoryLine at(double r) => g.copy()..amount = g.estimate * r;
      expect(lineStatus(at(1), b), Status.good);
      expect(lineStatus(at(0.8), b), Status.tight);
      expect(lineStatus(at(0.5), b), Status.short);
      expect(lineStatus(at(2), b), Status.high);
    });
  });

  group('switchLocation', () {
    test('same country only changes location', () {
      final r = switchLocation(usBase, 'us:city:austin-tx');
      expect(r.countryChanged, isFalse);
      expect(r.inputs.location, 'us:city:austin-tx');
      expect(r.inputs.incomeAmount, 5000);
    });
    test('across countries converts money', () {
      final r = switchLocation(usBase.copyWith(known: const KnownCosts(rent: 1200), excluded: {'tax:state', 'dining'}), 'jp:city:tsu');
      expect(r.countryChanged, isTrue);
      expect(r.inputs.incomeAmount, 750000);
      expect(r.inputs.known.rent, 180000);
      expect(r.inputs.excluded, {'dining'});
    });
  });

  test('inputs survive a JSON round trip', () {
    final i = tsu.copyWith(excluded: {'dining'}, custom: const [CustomItem(id: 'a', name: 'Pet', amount: 5000, group: Group.needs)], known: const KnownCosts(rent: 40000));
    final back = BudgetInputs.fromJson(i.toJson());
    expect(back.toJson(), i.toJson());
  });
}
