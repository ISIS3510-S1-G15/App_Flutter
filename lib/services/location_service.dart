import 'package:geolocator/geolocator.dart';

// Result of asking for the user's location: the position, or why it could not be read
class LocationResult {
  final Position? position;
  final String? error; // Message shown to the user when the location is not available

  const LocationResult.found(Position this.position) : error = null;
  const LocationResult.unavailable(String this.error) : position = null;
}

// Wraps the phone's GPS (geolocator package): permissions, current position and distances.
// The screens only ask for "where is the user" and "how far is this place", never talk to the plugin directly
class LocationService {
  // Center of Universidad de los Andes (used to know if the user is on campus)
  static const double campusLat = 4.6018;
  static const double campusLng = -74.0661;
  static const double campusRadiusMeters = 600;

  // Average walking speed, to turn a distance into minutes walking
  static const double _walkingMetersPerMinute = 80;

  // Reads the GPS once. Asks for permission the first time; if it is denied or the GPS is off, returns why
  static Future<LocationResult> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.unavailable('Turn on your location to see the closest spots');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return const LocationResult.unavailable('Allow location access to see the closest spots');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      return LocationResult.found(position);
    } catch (e) {
      return const LocationResult.unavailable('Could not get your location');
    }
  }

  // Straight-line distance in meters between the user and a point
  static double distanceTo(Position from, double lat, double lng) =>
      Geolocator.distanceBetween(from.latitude, from.longitude, lat, lng);

  static bool isOnCampus(Position p) => distanceTo(p, campusLat, campusLng) <= campusRadiusMeters;

  static int walkingMinutes(double meters) => (meters / _walkingMetersPerMinute).ceil().clamp(1, 999);

  // "350 m" or "1.2 km"
  static String formatDistance(double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';
}
