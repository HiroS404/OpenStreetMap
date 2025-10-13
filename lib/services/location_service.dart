import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static LatLng? _cachedLocation;

  static Future<LatLng?> getCurrentLocation() async {
    // Return cached location if available
    if (_cachedLocation != null) {
      return _cachedLocation;
    }

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return null;
    }

    // Check and request permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permissions are denied.");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permissions are permanently denied.");
      return null;
    }

    // Get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _cachedLocation = LatLng(position.latitude, position.longitude);
      print("📍 Got GPS location: $_cachedLocation");
      return _cachedLocation;
    } catch (e) {
      print("Error getting location: $e");
      return null;
    }
  }

  // Clear cached location (call this when you want to refresh)
  static void clearCache() {
    _cachedLocation = null;
  }

  // Get fresh location (bypasses cache)
  static Future<LatLng?> getFreshLocation() async {
    clearCache();
    return getCurrentLocation();
  }
}
