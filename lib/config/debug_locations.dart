// lib/config/debug_locations.dart

import 'package:latlong2/latlong.dart';

class DebugLocations {
  // ============================================
  // DEBUG STARTING LOCATIONS
  // Uncomment ONE location to use it as starting point
  // If all are commented, uses actual user location
  // ============================================
  
  static LatLng? get debugStartLocation {
    // Uncomment ONE location below to use as debug start point
    // If ALL are commented, returns null and uses actual GPS location
    
    // return LatLng(10.731068, 122.551723); // Sarap Station
    // return LatLng(10.732143, 122.559791); // Tabuc Suba Jollibee
    // return LatLng(10.715609, 122.562715); // ColdZone West
    // return LatLng(10.716225933976629, 122.56377696990968); // Somewhere further ColdZone West
    // return LatLng(10.733472, 122.548947); // Tubang CPU
    return LatLng(10.732610, 122.548220); // CPU (Alternative) - MT Building
    // return LatLng(10.696694, 122.545582); // Molo Plaza
    // return LatLng(10.694928, 122.564686); // Rob Main
    // return LatLng(10.753623, 122.538430); // GT Mall
    // return LatLng(10.727482, 122.558188); // Alicia's
    // return LatLng(10.714335, 122.551852); // SM City
    // return LatLng(10.697643, 122.543888); // Molo
    // return LatLng(10.693202, 122.500595); // Mohon Terminal
    // return LatLng(10.725203, 122.556715); // Jaro Plaza
    
    // If all commented out, return null to use actual GPS
    // return null;
  }

  // ============================================
  // DEBUG DESTINATION LOCATIONS
  // Uncomment ONE location to auto-set destination
  // If all are commented, user must select destination
  // ============================================
  
  static LatLng? get debugDestinationLocation {
    // Uncomment ONE location below to use as debug destination
    // If ALL are commented, returns null and user must select destination
    
    // return LatLng(10.731068, 122.551723); // Sarap Station
    // return LatLng(10.732143, 122.559791); // Tabuc Suba Jollibee
    // return LatLng(10.715609, 122.562715); // ColdZone West
    // return LatLng(10.716225933976629, 122.56377696990968); // Somewhere further ColdZone West
    // return LatLng(10.733472, 122.548947); // Tubang CPU
    // return LatLng(10.732610, 122.548220); // CPU (Alternative) - MT Building
    // return LatLng(10.696694, 122.545582); // Molo Plaza
    // return LatLng(10.694928, 122.564686); // Rob Main
    // return LatLng(10.753623, 122.538430); // GT Mall
    // return LatLng(10.727482, 122.558188); // Alicia's
    // return LatLng(10.714335, 122.551852); // SM City
    // return LatLng(10.697643, 122.543888); // Molo
    // return LatLng(10.693202, 122.500595); // Mohon Terminal
    // return LatLng(10.725203, 122.556715); // Jaro Plaza
    
    // If all commented out, return null and user selects destination
    return null;
  }

  // Helper to check if debug mode is active
  static bool get isDebugStartActive => debugStartLocation != null;
  static bool get isDebugDestinationActive => debugDestinationLocation != null;
  
  // Get location name for display
  static String getStartLocationName() {
    final loc = debugStartLocation;
    if (loc == null) return "Actual GPS Location";
    
    if (loc.latitude == 10.731068) return "Sarap Station";
    if (loc.latitude == 10.732143) return "Tabuc Suba Jollibee";
    if (loc.latitude == 10.715609) return "ColdZone West";
    if (loc.latitude == 10.716225933976629) return "Further ColdZone West";
    if (loc.latitude == 10.733472) return "Tubang CPU";
    if (loc.latitude == 10.732610) return "CPU (Alternative)";
    if (loc.latitude == 10.696694) return "Molo Plaza";
    if (loc.latitude == 10.694928) return "Rob Main";
    if (loc.latitude == 10.753623) return "GT Mall";
    if (loc.latitude == 10.727482) return "Alicia's";
    if (loc.latitude == 10.714335) return "SM City";
    if (loc.latitude == 10.697643) return "Molo";
    if (loc.latitude == 10.693202) return "Mohon Terminal";
    if (loc.latitude == 10.725203) return "Jaro Plaza";
    
    return "Custom Location";
  }
  
  static String getDestinationLocationName() {
    final loc = debugDestinationLocation;
    if (loc == null) return "User Selected";
    
    if (loc.latitude == 10.731068) return "Sarap Station";
    if (loc.latitude == 10.732143) return "Tabuc Suba Jollibee";
    if (loc.latitude == 10.715609) return "ColdZone West";
    if (loc.latitude == 10.716225933976629) return "Further ColdZone West";
    if (loc.latitude == 10.733472) return "Tubang CPU";
    if (loc.latitude == 10.732610) return "CPU (Alternative)";
    if (loc.latitude == 10.696694) return "Molo Plaza";
    if (loc.latitude == 10.694928) return "Rob Main";
    if (loc.latitude == 10.753623) return "GT Mall";
    if (loc.latitude == 10.727482) return "Alicia's";
    if (loc.latitude == 10.714335) return "SM City";
    if (loc.latitude == 10.697643) return "Molo";
    if (loc.latitude == 10.693202) return "Mohon Terminal";
    if (loc.latitude == 10.725203) return "Jaro Plaza";
    
    return "Custom Location";
  }
}