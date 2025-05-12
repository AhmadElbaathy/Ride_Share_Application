import 'package:flutter/material.dart';
import 'matches_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart'; // Import the MapScreen to navigate to it
import '../services/api_service.dart';
import 'my_rides_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  void _submitRideRequest() {
    String pickup = _pickupController.text;
    String destination = _destinationController.text;

    // Navigate to the Matches Screen, passing the pickup and destination
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchesScreen(
          pickup: pickup,
          destination: destination,
        ),
      ),
    );
  }

  void _logout() async {
    // Show confirmation dialog
    bool confirmLogout = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Logout'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false; // Default to false if dialog is dismissed
    
    // Proceed with logout if confirmed
    if (confirmLogout) {
      try {
        await ApiService.clearToken();
        
        // Navigate to login screen and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false, // This removes all previous routes
        );
      } catch (e) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

void _openMap() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MapScreen(
        pickup: _pickupController.text,
        destination: _destinationController.text,
      ),
    ),
  );

  if (result != null && result is Map) {
    setState(() {
      _pickupController.text = result['pickup'] ?? _pickupController.text;
      _destinationController.text = result['destination'] ?? _destinationController.text;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Ride Information'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Pickup input field
            TextField(
              controller: _pickupController,
              decoration: InputDecoration(
                labelText: 'Pickup Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            SizedBox(height: 20),

            // Destination input field
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: 'Destination',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            SizedBox(height: 30),

            // Submit Ride Request button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: Size(double.infinity, 50), // Full width
              ),
              onPressed: _submitRideRequest,
              child: Text(
                'Submit Ride Request',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

            // Add space before Open Map button
            SizedBox(height: 20),

            // Open Map button
            ElevatedButton(
              onPressed: _openMap,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.green, // Different color for Map button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: Size(double.infinity, 50), // Full width
              ),
              child: Text(
                'Open Map',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

            // Add space before My Rides button
            SizedBox(height: 20),

            // My Rides button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyRidesScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.purple, // Different color for My Rides button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: Size(double.infinity, 50), // Full width
              ),
              child: Text(
                'My Rides',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            
            // Add space before logout button
            SizedBox(height: 40),
            
            // Distinctive logout button
            OutlinedButton.icon(
              icon: Icon(Icons.logout, color: Colors.red),
              label: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
