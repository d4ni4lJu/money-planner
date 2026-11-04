import 'data.dart';
import 'models.dart';
import 'tax.dart';

class Country {
  const Country({
    required this.code,
    required this.currency,
    required this.defaultMonthlyNet,
    required this.perUSD,
    required this.amountStep,
    required this.data,
    required this.taxLines,
  });

  final CountryCode code;
  final String currency;

  /// a typical monthly take-home amount, used as a starting point
  final double defaultMonthlyNet;

  /// rough units of local currency per U.S. dollar, for converting typed amounts
  final double perUSD;

  /// what the +/- buttons on money fields add or remove
  final double amountStep;
  final CountryData data;
  final List<TaxLine> Function(double gross, FilingStatus status, ResolvedLocation loc) taxLines;
}

final countries = <CountryCode, Country>{
  CountryCode.jp: Country(
    code: CountryCode.jp,
    currency: 'JPY',
    defaultMonthlyNet: 250000,
    perUSD: 150,
    amountStep: 1000,
    data: jpData,
    taxLines: (g, s, _) => jpTaxLines(g, s),
  ),
  CountryCode.us: Country(
    code: CountryCode.us,
    currency: 'USD',
    defaultMonthlyNet: 4000,
    perUSD: 1,
    amountStep: 10,
    data: usData,
    taxLines: (g, s, loc) => usTaxLines(g, s, loc.regionTaxRate, loc.localTaxRate),
  ),
};

CountryCode countryOf(String locationKey) => locationKey.startsWith('us:') ? CountryCode.us : CountryCode.jp;
