import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class DriverScreen extends StatefulWidget {
  @override
  _DriverScreenState createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLoggedIn = false;
  List<dynamic> _availableRides = [];
  List<dynamic> _acceptedRides = [];
  bool _isLoadingRides = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.loginDriver(
        _emailController.text,
        _passwordController.text,
      );
      
      setState(() {
        _isLoggedIn = true;
      });
      
      await _fetchAllRides();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAllRides() async {
    setState(() {
      _isLoadingRides = true;
    });

    try {
      print('Fetching available rides...');
      final availableResponse = await ApiService.getAvailableRides();
      print('Available rides response: $availableResponse');
      
      print('Fetching driver rides...');
      final driverResponse = await ApiService.getDriverRides();
      print('Driver rides response: $driverResponse');
      
      if (availableResponse != null) {
        // Get available rides from the response
        final List<Map<String, dynamic>> availableRides = [];
        for (var ride in (availableResponse['available_rides'] ?? [])) {
          try {
            final rideDetails = await ApiService.getRideDetails(ride['id']);
            availableRides.add({
              ...Map<String, dynamic>.from(ride),
              'fare': rideDetails['ride']?['fare'],
            });
          } catch (e) {
            print('Error fetching fare for ride ${ride['id']}: $e');
            availableRides.add(Map<String, dynamic>.from(ride));
          }
        }
        
        // Get accepted rides from driver response
        final List<Map<String, dynamic>> acceptedRides = [];
        for (var ride in (driverResponse?['rides'] ?? [])) {
          acceptedRides.add(Map<String, dynamic>.from(ride));
        }
        
        print('Available rides received: ${availableRides.length}');
        print('Accepted rides received: ${acceptedRides.length}');
        
        setState(() {
          _availableRides = availableRides;
          _acceptedRides = acceptedRides;
        });
        
        print('Updated available rides: $_availableRides');
        print('Updated accepted rides: $_acceptedRides');
      } else {
        print('Response is null');
        setState(() {
          _errorMessage = 'Failed to load rides: Invalid response';
        });
      }
    } catch (e) {
      print('Error fetching rides: $e');
      setState(() {
        _errorMessage = 'Failed to load rides: $e';
      });
    } finally {
      setState(() {
        _isLoadingRides = false;
      });
    }
  }

  Future<void> _acceptRide(int rideId) async {
    try {
      print('Attempting to accept ride $rideId...');
      final response = await ApiService.acceptRide(rideId);
      print('Accept ride response: $response');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride accepted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Force a refresh of both lists
      await _fetchAllRides();
      
      // Switch to the My Rides tab to show the accepted ride
      if (_tabController.index != 1) {
        _tabController.animateTo(1);
      }
      
      // Add a small delay to ensure the UI updates
      await Future.delayed(Duration(milliseconds: 500));
      
      // Force another refresh to ensure we have the latest data
      await _fetchAllRides();
    } catch (e) {
      print('Error accepting ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeRide(int rideId) async {
    try {
      await ApiService.completeRide(rideId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ride marked as completed!')),
      );
      await _fetchAllRides();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete ride: $e')),
      );
    }
  }

  Future<void> _cancelRide(int rideId) async {
    // Show confirmation dialog
    bool shouldCancel = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cancel Ride'),
          content: Text('Are you sure you want to cancel this ride? The ride will be available for other drivers.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text('Yes, Cancel'),
            ),
          ],
        );
      },
    ) ?? false;

    if (!shouldCancel) return;

    try {
      await ApiService.cancelRide(rideId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ride cancelled successfully!')),
      );
      
      // Force a refresh of both lists
      await _fetchAllRides();
      
      // Switch to the Available Rides tab to show the cancelled ride
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel ride: $e')),
      );
    }
  }

  Widget _buildRideCard(Map<String, dynamic> ride, {bool isAccepted = false}) {
    final departureTime = ride['departure_time'] != null
        ? DateTime.parse(ride['departure_time'])
        : null;
    
    // Handle empty pickup and destination
    final pickup = ride['pickup']?.toString().trim() ?? 'Not specified';
    final destination = ride['destination']?.toString().trim() ?? 'Not specified';
    final creatorName = ride['creator_name'] ?? 'Unknown';
    
    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From: $pickup',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('To: $destination'),
            SizedBox(height: 8),
            if (departureTime != null)
              Text(
                'Departure: ${DateFormat('MMM dd, yyyy HH:mm').format(departureTime)}',
              ),
            SizedBox(height: 8),
            Text('Fare: \$${ride['fare']?['amount']?.toStringAsFixed(2) ?? '0.00'}'),
            SizedBox(height: 8),
            Text('Created by: $creatorName'),
            SizedBox(height: 8),
            Text('Passengers: ${ride['participant_count'] ?? 0}'),
            if (isAccepted) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ride['status'] == 'completed' ? Colors.blue.withOpacity(0.2) : 
                         ride['status'] == 'accepted' ? Colors.green.withOpacity(0.2) :
                         Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ride['status'] == 'completed' ? Colors.blue :
                           ride['status'] == 'accepted' ? Colors.green :
                           Colors.orange,
                  ),
                ),
                child: Text(
                  ride['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                  style: TextStyle(
                    color: ride['status'] == 'completed' ? Colors.blue :
                           ride['status'] == 'accepted' ? Colors.green :
                           Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            SizedBox(height: 16),
            if (isAccepted && ride['status'] != 'completed')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _completeRide(ride['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: Text('Complete Ride'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _cancelRide(ride['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: Text('Cancel Ride'),
                    ),
                  ),
                ],
              )
            else if (!isAccepted)
              ElevatedButton(
                onPressed: () => _acceptRide(ride['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: Size(double.infinity, 40),
                ),
                child: Text('Accept Ride'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Driver Login'),
          backgroundColor: Colors.green,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Email Field
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16),
                    
                    // Password Field
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 24),
                    
                    // Error Message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Login as Driver',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text('Driver Dashboard'),
          backgroundColor: Colors.green,
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Available Rides'),
              Tab(text: 'My Rides'),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _fetchAllRides,
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Available Rides Tab
            _isLoadingRides
                ? Center(child: CircularProgressIndicator())
                : _availableRides.isEmpty
                    ? Center(
                        child: Text(
                          'No available rides at the moment',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _availableRides.length,
                        itemBuilder: (context, index) => _buildRideCard(_availableRides[index]),
                      ),

            // My Rides Tab
            _isLoadingRides
                ? Center(child: CircularProgressIndicator())
                : _acceptedRides.isEmpty
                    ? Center(
                        child: Text(
                          'No accepted rides',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _acceptedRides.length,
                        itemBuilder: (context, index) => _buildRideCard(_acceptedRides[index], isAccepted: true),
                      ),
          ],
        ),
      );
    }
  }
} 