// lib/screens/matches_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'my_rides_screen.dart';
import 'ride_details_screen.dart';

class MatchesScreen extends StatefulWidget {
  final String pickup;
  final String destination;

  MatchesScreen({
    required this.pickup,
    required this.destination,
  });

  @override
  _MatchesScreenState createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _matches = [];
  Set<int> _joiningRides = {}; // Track rides that are in the process of being joined
  Set<int> _leavingRides = {}; // Track rides that are in the process of being left 
  DateTime? _departureTime; // For creating new rides
  final _fareController = TextEditingController(); // Add fare controller

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshData();
  }

  @override
  void dispose() {
    _fareController.dispose();
    super.dispose();
  }

  void _refreshData() {
    _fetchMatches();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      final DateTime now = DateTime.now();
      final DateTime selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      
      setState(() {
        _departureTime = selectedDateTime;
      });
    }
  }

  Future<void> _leaveRide(int rideId) async {
    // Show confirmation dialog
    bool shouldLeave = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Leave Ride'),
          content: Text('Are you sure you want to leave this ride?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text('Leave'),
            ),
          ],
        );
      },
    ) ?? false;

    if (!shouldLeave) return;

    setState(() {
      _leavingRides.add(rideId);
    });

    try {
      await ApiService.leaveRide(rideId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully left the ride'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the matches list
      _fetchMatches();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _leavingRides.remove(rideId);
      });
    }
  }

  // Update your existing _joinRide method to show a confirmation dialog
  Future<void> _joinRide(int rideId) async {
    // Show confirmation dialog
    bool shouldJoin = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Join Ride'),
          content: Text('Are you sure you want to join this ride?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
              child: Text('Join'),
            ),
          ],
        );
      },
    ) ?? false;

    if (!shouldJoin) return;

    setState(() {
      _joiningRides.add(rideId);
    });

    try {
      await ApiService.joinRide(rideId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined the ride!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MyRidesScreen()),
      ).then((_) {
        _fetchMatches();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _joiningRides.remove(rideId);
      });
    }
  }

  Future<void> _fetchMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.getMatchedRides(widget.pickup, widget.destination);
      setState(() {
        _matches = result['matches'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching matches: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _createNewRide() async {
    // Show fare input dialog
    final fare = await showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Fare Amount'),
          content: TextField(
            controller: _fareController,
            decoration: InputDecoration(
              labelText: 'Fare Amount',
              prefixIcon: Icon(Icons.attach_money),
              hintText: 'Enter fare amount',
            ),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final fare = double.tryParse(_fareController.text);
                if (fare != null && fare > 0) {
                  Navigator.of(context).pop(fare);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid fare amount')),
                  );
                }
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );

    if (fare == null) return; // User canceled

    // Show time picker
    await _selectTime();
    
    // If user canceled time selection, don't proceed
    if (_departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a departure time')),
      );
      return;
    }
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Creating ride request...")
              ],
            ),
          );
        },
      );
      
      // Call the API to create a ride request with departure time and fare
      final result = await ApiService.requestRide(
        widget.pickup, 
        widget.destination,
        _departureTime,
        fare: fare,
      );
      
      // Close loading indicator
      Navigator.pop(context);
      
      // Show success dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Success'),
            content: Text('Your ride request has been created successfully!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  
                  // Navigate to My Rides screen and then return to this screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyRidesScreen()),
                  ).then((_) {
                    // This code runs when returning from MyRidesScreen
                    // Refresh the matches to show the new ride
                    _fetchMatches();
                  });
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Error handling
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to format time
  String _formatTime(String? timeStr) {
    if (timeStr == null) return 'Not specified';
    try {
      final date = DateTime.parse(timeStr);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Matched Rides'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Add a button to view my rides
          IconButton(
            icon: Icon(Icons.list),
            tooltip: 'My Rides',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MyRidesScreen()),
              ).then((_) {
                // Refresh matches when returning from MyRidesScreen
                _fetchMatches();
              });
            },
          ),
          // Add a refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchMatches,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ride information card
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'From: ${widget.pickup}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'To: ${widget.destination}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyRidesScreen()),
                      ).then((_) {
                        // Refresh matches when returning from MyRidesScreen
                        _fetchMatches();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: Size(double.infinity, 40), // full width button
                    ),
                    child: Text('View My Rides'),
                  ),
                ],
              ),
            ),
          ),
          
          // Section title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Available Matches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Matches list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 60),
                            SizedBox(height: 16),
                            Text(
                              'Error: $_errorMessage',
                              style: TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _fetchMatches,
                              child: Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : _matches.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 60, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No matches found'),
                                SizedBox(height: 24),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  onPressed: _createNewRide,
                                  child: Text(
                                    'Create New Ride',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'This will create a ride request that others can match with.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _matches.length,
                            itemBuilder: (context, index) {
                              final match = _matches[index];
                              final rideId = match['id'] ?? 0;
                              final isJoining = _joiningRides.contains(rideId);
                              final isLeaving = _leavingRides.contains(rideId);
                              final hasJoined = match['has_joined'] ?? false;
                              
                              return Card(
                                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: CircleAvatar(
                                        child: Icon(Icons.person),
                                      ),
                                      title: Text(match['user_name'] ?? 'Unknown'),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 4),
                                          Text('From: ${match['pickup']}'),
                                          Text('To: ${match['destination']}'),
                                          if (match['departure_time'] != null)
                                            Text('Departure: ${_formatTime(match['departure_time'])}'),
                                          Text('Participants: ${match['participant_count'] ?? 1}'),
                                        ],
                                      ),
                                      isThreeLine: true,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => RideDetailsScreen(
                                                    rideId: rideId,
                                                    isCreator: false,
                                                    hasJoined: hasJoined,
                                                  ),
                                                ),
                                              ).then((_) {
                                                // Refresh matches when returning
                                                _fetchMatches();
                                              });
                                            },
                                            child: Text('Details'),
                                          ),
                                          SizedBox(width: 8),
                                          if (hasJoined)
                                            ElevatedButton(
                                              onPressed: isLeaving ? null : () => _leaveRide(rideId),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: isLeaving
                                                  ? SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                      ),
                                                    )
                                                  : Text('Leave Ride'),
                                            )
                                          else
                                            ElevatedButton(
                                              onPressed: isJoining ? null : () => _joinRide(rideId),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: isJoining
                                                  ? SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                      ),
                                                    )
                                                  : Text('Join Ride'),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      // Add a floating action button to create a new ride
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewRide,
        child: Icon(Icons.add),
        tooltip: 'Create New Ride',
      ),
    );
  }
}