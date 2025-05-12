// lib/screens/my_rides_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'ride_details_screen.dart';
import 'package:intl/intl.dart';

class MyRidesScreen extends StatefulWidget {
  @override
  _MyRidesScreenState createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _createdRides = [];
  List<dynamic> _joinedRides = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load created rides
      print('Loading created rides...');
      final createdResult = await ApiService.getUserRides();
      print('Created rides response: $createdResult');
      
      // Load joined rides
      print('Loading joined rides...');
      final joinedResult = await ApiService.getUserJoinedRides();
      print('Joined rides response: $joinedResult');
      
      final createdRides = (createdResult['rides'] ?? [])
          .where((ride) => !(joinedResult['rides'] ?? []).any((joinedRide) => joinedRide['id'] == ride['id']))
          .toList();
      
      // Get fare information for joined rides
      final List<dynamic> joinedRides = [];
      for (var ride in (joinedResult['rides'] ?? [])) {
        try {
          final rideDetails = await ApiService.getRideDetails(ride['id']);
          joinedRides.add({
            ...ride,
            'fare': rideDetails['ride']?['fare'],
          });
        } catch (e) {
          print('Error fetching fare for ride ${ride['id']}: $e');
          joinedRides.add(ride);
        }
      }
      
      // Debug log for fare data
      print('Created rides fare structure:');
      for (var ride in createdRides) {
        print('Ride ${ride['id']} fare: ${ride['fare']}');
      }
      print('Joined rides fare structure:');
      for (var ride in joinedRides) {
        print('Ride ${ride['id']} fare: ${ride['fare']}');
      }
      
      print('Created rides count: ${createdRides.length}');
      print('Joined rides count: ${joinedRides.length}');
      
      // Log each ride's status
      for (var ride in createdRides) {
        print('Created ride ${ride['id']} status: ${ride['status']}, driver: ${ride['current_driver']}');
      }
      for (var ride in joinedRides) {
        print('Joined ride ${ride['id']} status: ${ride['status']}, driver: ${ride['current_driver']}');
      }
      
      setState(() {
        _createdRides = createdRides;
        _joinedRides = joinedRides;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading rides: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Rides'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Created Rides'),
            Tab(text: 'Joined Rides'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Created rides tab
                    _createdRides.isEmpty
                        ? _buildEmptyRidesWidget('created')
                        : _buildRidesList(_createdRides, isJoined: false),
                    
                    // Joined rides tab
                    _joinedRides.isEmpty
                        ? _buildEmptyRidesWidget('joined')
                        : _buildRidesList(_joinedRides, isJoined: true),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadRides,
        child: Icon(Icons.refresh),
        tooltip: 'Refresh Rides',
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
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
            onPressed: _loadRides,
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRidesWidget(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            type == 'created' 
                ? 'You haven\'t created any rides yet.'
                : type == 'joined' 
                    ? 'You haven\'t joined any rides yet.'
                    : 'You haven\'t accepted any rides yet.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (type == 'created') {
                Navigator.pop(context); // Go back to create a ride
              } else if (type == 'joined') {
                // Navigate to available rides screen
                Navigator.pop(context); // For now, just go back
              } else {
                // Navigate to available rides screen
                Navigator.pop(context); // For now, just go back
              }
            },
            child: Text(type == 'created' ? 'Create a Ride' : type == 'joined' ? 'Find Rides' : 'Find Rides'),
          ),
        ],
      ),
    );
  }

  Widget _buildRidesList(List<dynamic> rides, {required bool isJoined}) {
    return ListView.builder(
      itemCount: rides.length,
      itemBuilder: (context, index) {
        final ride = rides[index];
        final driver = ride['current_driver'];
        final isAccepted = ride['status'] == 'accepted';
        final isCompleted = ride['status'] == 'completed';
        
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ride #${ride['id']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Row(
                      children: [
                        if (isJoined)
                          Container(
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple),
                            ),
                            child: Text(
                              'Joined',
                              style: TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAccepted ? Colors.green.withOpacity(0.2) : 
                                   isCompleted ? Colors.blue.withOpacity(0.2) :
                                   Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAccepted ? Colors.green :
                                     isCompleted ? Colors.blue :
                                     Colors.orange,
                            ),
                          ),
                          child: Text(
                            isAccepted ? 'Accepted' :
                            isCompleted ? 'Completed' :
                            'Pending',
                            style: TextStyle(
                              color: isAccepted ? Colors.green :
                                     isCompleted ? Colors.blue :
                                     Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'From: ${ride['pickup'] ?? 'Not specified'}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'To: ${ride['destination'] ?? 'Not specified'}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                if (ride['departure_time'] != null) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Departure: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(ride['departure_time']))}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Fare: \$${ride['fare'] != null ? (ride['fare'] is Map ? ride['fare']['amount']?.toStringAsFixed(2) : ride['fare'].toStringAsFixed(2)) : '0.00'}',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                if (isAccepted && driver != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver: ${driver['name']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                'Email: ${driver['email']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 12),
                Text(
                  'Created: ${_formatDate(ride['created_at'])}',
                  style: TextStyle(color: Colors.grey),
                ),
                if (isJoined && ride['joined_at'] != null)
                  Text(
                    'Joined: ${_formatDate(ride['joined_at'])}',
                    style: TextStyle(color: Colors.grey),
                  ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Add a details button
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RideDetailsScreen(
                              rideId: ride['id'],
                              isCreator: !isJoined,
                              hasJoined: isJoined,
                            ),
                          ),
                        ).then((_) {
                          // Refresh rides when returning
                          _loadRides();
                        });
                      },
                      child: Text('Details'),
                    ),
                    SizedBox(width: 8),
                    if (isJoined)
                      ElevatedButton.icon(
                        onPressed: () {
                          _leaveRide(ride['id']);
                        },
                        icon: Icon(Icons.exit_to_app),
                        label: Text('Leave Ride'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () {
                          _deleteRide(ride['id']);
                        },
                        icon: Icon(Icons.delete),
                        label: Text('Delete Ride'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _leaveRide(int rideId) async {
    try {
      await ApiService.leaveRide(rideId);
      // Refresh rides after leaving
      _loadRides();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have left the ride')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error leaving ride: $e')),
      );
    }
  }

  Future<void> _deleteRide(int rideId) async {
    // Show confirmation dialog
    bool shouldDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Ride'),
          content: Text('Are you sure you want to delete this ride? This action cannot be undone.'),
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
              child: Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;

    if (!shouldDelete) return;

    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.deleteRide(rideId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the rides list
      _loadRides();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to format date
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
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

  // Helper method to show status badge
  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'matched':
        color = Colors.green;
        label = 'Matched';
        break;
      case 'completed':
        color = Colors.blue;
        label = 'Completed';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}