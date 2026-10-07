import 'package:geolocator/geolocator.dart';

enum LocationResultStatus { granted, serviceOff, denied, deniedForever, error }

class LocationResult {
  final LocationResultStatus status;
  final Position? position;

  const LocationResult(this.status, [this.position]);
}

class LocationService {
  /// Checks the device location service and permission, then returns the
  /// current position if everything is allowed.
  static Future<LocationResult> getCurrentPosition() async {
    // 1. Is location turned on in device settings?
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      return const LocationResult(LocationResultStatus.serviceOff);
    }

    // 2. Do we have permission?
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult(LocationResultStatus.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(LocationResultStatus.deniedForever);
    }

    // 3. Get the position.
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LocationResult(LocationResultStatus.granted, position);
    } catch (_) {
      return const LocationResult(LocationResultStatus.error);
    }
  }

  /// Straight-line distance in meters.
  static double distanceMeters(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) {
    return Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  static Future<void> openAppSettings() => Geolocator.openAppSettings();
  static Future<void> openLocationSettings() =>
      Geolocator.openLocationSettings();
}
