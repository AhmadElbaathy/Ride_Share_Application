import 'dart:convert';
import 'package:http/http.dart' as http;

class MapUtils {
  // OSRM API endpoint for distance calculation
  static const String OSRM_BASE_URL = 'http://router.project-osrm.org/route/v1/driving';

  // Calculate distance between two points using OSRM
  static Future<double> calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final url = Uri.parse(
        '$OSRM_BASE_URL/$startLng,$startLat;$endLng,$endLat?overview=false',
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Distance is returned in meters, convert to kilometers
        return data['routes'][0]['distance'] / 1000.0;
      } else {
        throw Exception('Failed to calculate distance: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calculating distance: $e');
      throw Exception('Failed to calculate distance: $e');
    }
  }

  // Helper method to get coordinates from address using Nominatim (OSM's geocoding service)
  static Future<Map<String, double>> getCoordinatesFromAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$encodedAddress',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'RideSharingApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lng': double.parse(data[0]['lon']),
          };
        }
      }
      throw Exception('Failed to get coordinates for address: $address');
    } catch (e) {
      print('Error getting coordinates: $e');
      throw Exception('Failed to get coordinates: $e');
    }
  }

  // Calculate distance between two addresses
  static Future<double> calculateDistanceBetweenAddresses(
    String startAddress,
    String endAddress,
  ) async {
    try {
      final startCoords = await getCoordinatesFromAddress(startAddress);
      final endCoords = await getCoordinatesFromAddress(endAddress);

      return await calculateDistance(
        startCoords['lat']!,
        startCoords['lng']!,
        endCoords['lat']!,
        endCoords['lng']!,
      );
    } catch (e) {
      print('Error calculating distance between addresses: $e');
      throw Exception('Failed to calculate distance between addresses: $e');
    }
  }
} 