import 'dart:math' as math;

import 'countries.dart';
import 'models.dart';

const _avg = CostIndex(100, 100, 100, 100, 100);

/// Resolves a location key, falling back to the region, then the national average.
ResolvedLocation resolveLocation(String key) {
  final parts = key.split(':');
  final cc = parts.isNotEmpty && parts[0] == 'us' ? CountryCode.us : CountryCode.jp;
  final c = countries[cc]!;
  final kind = parts.length > 1 ? parts[1] : '';
  final id = parts.length > 2 ? parts[2] : '';

  if (kind == 'city') {
    for (final city in c.data.cities) {
      if (city.id != id) continue;
      final region = c.data.regions.where((r) => r.code == city.region).firstOrNull;
      return ResolvedLocation(
        key: key, country: cc, kind: 'city', id: id, regionCode: city.region, index: city.index,
        regionTaxRate: region?.taxRate ?? 0, localTaxRate: city.localTaxRate,
      );
    }
  }
  if (kind == 'region') {
    for (final r in c.data.regions) {
      if (r.code != id) continue;
      return ResolvedLocation(
        key: key, country: cc, kind: 'region', id: id, regionCode: r.code,
        index: CostIndex(r.housing, r.general, r.general, r.general, r.general),
        regionTaxRate: r.taxRate, localTaxRate: 0,
      );
    }
  }
  return ResolvedLocation(
    key: '${cc.name}:national', country: cc, kind: 'national', id: '', regionCode: '', index: _avg,
    regionTaxRate: cc == CountryCode.us ? 0.04 : 0, localTaxRate: 0,
  );
}

// ---------------- detection ----------------

double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const rad = math.pi / 180;
  final a = math.pow(math.sin((lat2 - lat1) * rad / 2), 2) +
      math.cos(lat1 * rad) * math.cos(lat2 * rad) * math.pow(math.sin((lng2 - lng1) * rad / 2), 2);
  return 6371 * 2 * math.asin(math.sqrt(a));
}

class Detected {
  const Detected(this.key, this.distanceKm);
  final String key;
  final int distanceKm;
  bool get isCity => key.contains(':city:');
}

/// A listed city if one is within this distance; otherwise the region you're in.
const cityRadiusKm = 25.0;
const regionRadiusKm = 350.0;

/// Nearest listed city, or the region of the nearest known point. Null if nothing is close.
Detected? nearestLocation(double lat, double lng) {
  String? bestKey, bestRegionKey;
  var best = double.infinity;
  for (final c in countries.values) {
    final cc = c.code.name;
    for (final city in c.data.cities) {
      final d = distanceKm(lat, lng, city.lat, city.lng);
      if (d < best) (best, bestKey, bestRegionKey) = (d, '$cc:city:${city.id}', '$cc:region:${city.region}');
    }
    for (final r in c.data.regions) {
      final d = distanceKm(lat, lng, r.lat, r.lng);
      if (d < best) (best, bestKey, bestRegionKey) = (d, '$cc:region:${r.code}', '$cc:region:${r.code}');
    }
  }
  if (bestKey == null || best > regionRadiusKm) return null;
  final useCity = bestKey.contains(':city:') && best <= cityRadiusKm;
  return Detected(useCity ? bestKey : bestRegionKey!, best.round());
}

/// What a reverse-geocoding service said about a point.
class GeocodeHint {
  const GeocodeHint({this.countryCode, this.subdivisionCode, this.city});
  final String? countryCode; // "JP"
  final String? subdivisionCode; // "JP-24", "US-TX"
  final String? city;
}

String _simplify(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z]'), '').replaceAll(RegExp(r'(shi|city)$'), '');

/// Trusts the official region from reverse geocoding (accurate at borders), then picks the
/// listed city by name or distance inside it. Falls back to pure distance.
Detected? locationFromGeocode(double lat, double lng, GeocodeHint? hint) {
  final cc = hint?.countryCode?.toLowerCase();
  final country = cc == 'us' ? countries[CountryCode.us] : cc == 'jp' ? countries[CountryCode.jp] : null;
  final parts = hint?.subdivisionCode?.split('-');
  final regionCode = parts != null && parts.length > 1 ? parts[1] : null;
  final region = country?.data.regions.where((r) => r.code == regionCode).firstOrNull;
  if (country == null || region == null) {
    if (cc != null && country == null) return null; // a country we don't cover yet
    return nearestLocation(lat, lng);
  }
  final inRegion = country.data.cities.where((c) => c.region == region.code).toList();
  CityRecord? city;
  if (hint?.city != null) city = inRegion.where((c) => _simplify(c.name) == _simplify(hint!.city!)).firstOrNull;
  if (city == null && inRegion.isNotEmpty) {
    inRegion.sort((a, b) => distanceKm(lat, lng, a.lat, a.lng).compareTo(distanceKm(lat, lng, b.lat, b.lng)));
    if (distanceKm(lat, lng, inRegion.first.lat, inRegion.first.lng) <= cityRadiusKm) city = inRegion.first;
  }
  final key = city != null ? '${country.code.name}:city:${city.id}' : '${country.code.name}:region:${region.code}';
  return Detected(key, city != null ? distanceKm(lat, lng, city.lat, city.lng).round() : 0);
}

/// Best guess without asking permission: the country from the device's time zone / locale.
String? guessFromTimeZone(String? tzName, {String? localeCountry}) {
  if (tzName == 'JST' || tzName == 'Asia/Tokyo' || localeCountry == 'JP') return 'jp:national';
  if (localeCountry == 'US' || const {'EST', 'EDT', 'CST', 'CDT', 'MST', 'MDT', 'PST', 'PDT', 'AKST', 'AKDT', 'HST'}.contains(tzName)) {
    return 'us:national';
  }
  return null;
}
