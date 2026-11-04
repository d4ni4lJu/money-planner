import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../logic/location.dart';

enum DetectStatus { found, denied, off, notCovered, error }

class DetectResult {
  const DetectResult(this.status, [this.found]);
  final DetectStatus status;
  final Detected? found;
}

/// Finds the user's area: device location (coarse is enough) + reverse geocoding for the
/// official prefecture/state, falling back to the nearest known place if offline.
class Locator {
  const Locator();

  Future<DetectResult> detect() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const DetectResult(DetectStatus.off);
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return const DetectResult(DetectStatus.denied);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
      );
      final hint = await _reverseGeocode(pos.latitude, pos.longitude);
      final found = locationFromGeocode(pos.latitude, pos.longitude, hint);
      return found == null ? const DetectResult(DetectStatus.notCovered) : DetectResult(DetectStatus.found, found);
    } catch (_) {
      return const DetectResult(DetectStatus.error);
    }
  }

  /// Free, key-less reverse geocoding. Null on any failure (then we use distance only).
  Future<GeocodeHint?> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
        'latitude': '$lat',
        'longitude': '$lng',
        'localityLanguage': 'en',
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return GeocodeHint(
        countryCode: j['countryCode'] as String?,
        subdivisionCode: j['principalSubdivisionCode'] as String?,
        city: (j['city'] as String?)?.isNotEmpty == true ? j['city'] as String : j['locality'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
