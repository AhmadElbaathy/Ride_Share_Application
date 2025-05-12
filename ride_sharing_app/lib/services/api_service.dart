// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/map_utils.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000'; // Change as needed
  
  // Store the JWT token
  static String? _token;
  
  // Get the token
  static Future<String?> getToken() async {
    if (_token != null) return _token;
    
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }
  
  // Set the token
  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
  
  // Clear the token (logout)
  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
  
  // Register a new user
  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      print('Registration error: $e');
      throw Exception('Registration failed: $e');
    }
  }
  
  // Login a user
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/user'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': email,
          'password': password,
        },
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['access_token'] != null) {
          await setToken(data['access_token']);
        }
        
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      print('Login error: $e');
      throw Exception('Login failed: $e');
    }
  }
  
  // Request a ride (with authentication) - Updated to include departure time
  static Future<Map<String, dynamic>> requestRide(
    String pickup, 
    String destination, 
    DateTime? departureTime,
    {double? fare}
  ) async {
    try {
      // Validate pickup and destination
      if (pickup.isEmpty || destination.isEmpty) {
        throw Exception('Pickup and destination locations are required');
      }

      // Validate fare is provided
      if (fare == null) {
        throw Exception('Fare amount is required');
      }

      // Prepare the request body
      final requestBody = {
        'pickup': pickup,
        'destination': destination,
        'departure_time': departureTime?.toIso8601String(),
        'fare': fare,
      };

      print('Creating ride request with data: $requestBody');

      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/ride-request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('Ride request response status: ${response.statusCode}');
      print('Ride request response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 500) {
        // Handle 500 error specifically
        try {
          final errorData = jsonDecode(response.body);
          throw Exception('Server error: ${errorData['detail'] ?? 'Internal server error'}');
        } catch (e) {
          throw Exception('Server error: The server encountered an unexpected error. Please try again later.');
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['detail'] ?? 'Failed to create ride request: ${response.statusCode}');
        } catch (e) {
          throw Exception('Failed to create ride request: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      print('Error creating ride request: $e');
      throw Exception('Failed to create ride request: $e');
    }
  }
  
  // Get matched rides (with authentication)
  static Future<Map<String, dynamic>> getMatchedRides(String pickup, String destination) async {
    try {
      final token = await getToken();
      
      final response = await http.get(
        Uri.parse('$baseUrl/match-rides?pickup=$pickup&destination=$destination'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to get matched rides');
      }
    } catch (e) {
      print('Exception: $e');
      throw Exception('Network error: $e');
    }
  }
  
  // Join a ride
  static Future<Map<String, dynamic>> joinRide(int rideId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/join-ride/$rideId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Join ride response status: ${response.statusCode}');
      print('Join ride response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to join ride: Status ${response.statusCode}');
      }
    } catch (e) {
      print('Error joining ride: $e');
      throw Exception('Failed to join ride: $e');
    }
  }

  // Leave a ride
  static Future<Map<String, dynamic>> leaveRide(int rideId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/leave-ride/$rideId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Leave ride response status: ${response.statusCode}');
      print('Leave ride response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to leave ride: Status ${response.statusCode}');
      }
    } catch (e) {
      print('Error leaving ride: $e');
      throw Exception('Failed to leave ride: $e');
    }
  }
  static Future<Map<String, dynamic>> getRideDetails(int rideId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ride/$rideId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // If the ride details don't include fare, try to get it from the user's rides
        if (data['ride'] != null && data['ride']['fare'] == null) {
          final userRides = await getUserRides();
          final rides = userRides['rides'] ?? [];
          final matchingRide = rides.firstWhere(
            (ride) => ride['id'] == rideId,
            orElse: () => null,
          );
          if (matchingRide != null) {
            data['ride']['fare'] = matchingRide['fare'];
          }
        }
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get ride details: Status ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting ride details: $e');
      throw Exception('Failed to get ride details: $e');
    }
  }
  // Get user's joined rides
  static Future<Map<String, dynamic>> getUserJoinedRides() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/user/joined-rides'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load joined rides: ${response.body}');
    }
  }
  
  // Get user's created rides
  static Future<Map<String, dynamic>> getUserRides() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Authentication token is missing');
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/user/rides'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to get user rides: ${response.body}');
      }
    } catch (e) {
      print('Exception in getUserRides: $e');
      throw Exception('Network error: $e');
    }
  }
  
  // Delete a ride
  static Future<void> deleteRide(int rideId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/ride/$rideId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Delete ride response status: ${response.statusCode}');
      print('Delete ride response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to delete ride: Status ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting ride: $e');
      throw Exception('Failed to delete ride: $e');
    }
  }

  // Register a new driver
  static Future<Map<String, dynamic>> registerDriver(String name, String email, String password, String licenseNumber, String vehicleType, String vehicleNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/driver'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'license_number': licenseNumber,
          'vehicle_type': vehicleType,
          'vehicle_number': vehicleNumber,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to register driver: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to register driver: $e');
    }
  }

  // Set driver availability
  static Future<Map<String, dynamic>> setDriverAvailability(bool isAvailable) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      // First check if we can toggle availability
      print('Checking if driver can toggle availability...');
      final availabilityResponse = await http.get(
        Uri.parse('$baseUrl/driver/availability'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (availabilityResponse.statusCode != 200) {
        throw Exception('Failed to check driver availability');
      }

      final availabilityData = json.decode(availabilityResponse.body);
      final canToggle = availabilityData['can_toggle_availability'] ?? false;
      final hasActiveRides = availabilityData['has_active_rides'] ?? false;
      final activeRidesCount = availabilityData['active_rides_count'] ?? 0;

      if (!canToggle) {
        if (hasActiveRides) {
          throw Exception('Cannot toggle availability while having $activeRidesCount active ride(s). Please complete or cancel your current ride(s) first.');
        } else {
          throw Exception('Cannot toggle availability at this time. Please try again later.');
        }
      }

      print('Toggling driver availability...');
      final response = await http.post(
        Uri.parse('$baseUrl/driver/toggle-availability'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Toggle availability response status: ${response.statusCode}');
      print('Toggle availability response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded availability response: $data');
        return data;
      } else {
        final errorData = json.decode(response.body);
        print('Error toggling availability: $errorData');
        throw Exception(errorData['detail'] ?? 'Failed to toggle driver availability');
      }
    } catch (e) {
      print('Error toggling driver availability: $e');
      throw Exception('Failed to toggle driver availability: $e');
    }
  }

  // Login a driver
  static Future<Map<String, dynamic>> loginDriver(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/driver'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': email,
          'password': password,
        },
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['access_token'] != null) {
          await setToken(data['access_token']);
          // Set driver availability to true after successful login
          try {
            await setDriverAvailability(true);
          } catch (e) {
            print('Warning: Could not set driver availability: $e');
            // Continue with login even if setting availability fails
          }
        }
        
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      print('Login error: $e');
      throw Exception('Login failed: $e');
    }
  }

  // Get available rides for drivers
  static Future<Map<String, dynamic>> getAvailableRides() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      print('Making request to get available rides...');
      final response = await http.get(
        Uri.parse('$baseUrl/available-rides'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Available rides response status: ${response.statusCode}');
      print('Available rides response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded available rides data: $data');
        return data;
      } else {
        final errorData = json.decode(response.body);
        print('Error getting available rides: $errorData');
        throw Exception(errorData['detail'] ?? 'Failed to get available rides');
      }
    } catch (e) {
      print('Error getting available rides: $e');
      throw Exception('Failed to get available rides: $e');
    }
  }

  // Accept a ride
  static Future<Map<String, dynamic>> acceptRide(int rideId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      // First, check driver availability
      print('Checking driver availability before accepting ride...');
      final availabilityResponse = await http.get(
        Uri.parse('$baseUrl/driver/availability'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      print('Driver availability response status: ${availabilityResponse.statusCode}');
      print('Driver availability response body: ${availabilityResponse.body}');
      
      if (availabilityResponse.statusCode != 200) {
        throw Exception('Failed to check driver availability');
      }
      
      final availabilityData = json.decode(availabilityResponse.body);
      final isAvailable = availabilityData['is_available'] ?? false;
      final hasActiveRides = availabilityData['has_active_rides'] ?? false;
      final activeRidesCount = availabilityData['active_rides_count'] ?? 0;
      final canToggleAvailability = availabilityData['can_toggle_availability'] ?? false;
      
      if (!isAvailable) {
        if (hasActiveRides) {
          throw Exception('You have $activeRidesCount active ride(s). Please complete or cancel your current ride(s) before accepting new ones.');
        } else if (canToggleAvailability) {
          print('Driver is not available, toggling availability...');
          await setDriverAvailability(true);
        } else {
          throw Exception('Cannot accept rides at this time. Please try again later.');
        }
      }

      print('Making request to accept ride $rideId...');
      final response = await http.post(
        Uri.parse('$baseUrl/accept-ride/$rideId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Accept ride response status: ${response.statusCode}');
      print('Accept ride response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded accept ride response: $data');
        return data;
      } else {
        final errorData = json.decode(response.body);
        print('Error accepting ride: $errorData');
        throw Exception(errorData['detail'] ?? 'Failed to accept ride');
      }
    } catch (e) {
      print('Error accepting ride: $e');
      throw Exception('Failed to accept ride: $e');
    }
  }

  // Get driver's accepted rides
  static Future<Map<String, dynamic>> getDriverRides() async {
    final token = await getToken();
    print('Making request to get driver rides...');
    print('Using token: ${token?.substring(0, 10)}...');
    
    final response = await http.get(
      Uri.parse('$baseUrl/driver/my-rides'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    print('Driver rides response status: ${response.statusCode}');
    print('Driver rides response body: ${response.body}');
    
    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        print('Decoded data: $data');
        return data;
      } catch (e) {
        print('Error decoding JSON: $e');
        throw Exception('Invalid response format: $e');
      }
    } else if (response.statusCode == 500) {
      print('Server error (500) details: ${response.body}');
      throw Exception('Server error: ${response.body}');
    } else {
      try {
        final errorData = json.decode(response.body);
        print('Error response: $errorData');
        throw Exception('Error getting driver rides: $errorData');
      } catch (e) {
        print('Non-JSON error response: ${response.body}');
        throw Exception('Server error: ${response.body}');
      }
    }
  }

  // Complete a ride
  static Future<Map<String, dynamic>> completeRide(int rideId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/complete-ride/$rideId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to complete ride');
      }
    } catch (e) {
      print('Error completing ride: $e');
      throw Exception('Failed to complete ride: $e');
    }
  }

  // Cancel a ride
  static Future<Map<String, dynamic>> cancelRide(int rideId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      print('Making request to cancel ride $rideId...');
      final response = await http.post(
        Uri.parse('$baseUrl/cancel-ride/$rideId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Cancel ride response status: ${response.statusCode}');
      print('Cancel ride response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded cancel ride response: $data');
        return data;
      } else {
        final errorData = json.decode(response.body);
        print('Error cancelling ride: $errorData');
        throw Exception(errorData['detail'] ?? 'Failed to cancel ride');
      }
    } catch (e) {
      print('Error cancelling ride: $e');
      throw Exception('Failed to cancel ride: $e');
    }
  }
}