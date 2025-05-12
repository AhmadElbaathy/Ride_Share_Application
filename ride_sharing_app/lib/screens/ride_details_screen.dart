// lib/screens/ride_details_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'my_rides_screen.dart';
import 'map_screen.dart'; // Import your MapScreen
import 'dart:convert';

class RideDetailsScreen extends StatefulWidget {
  final int rideId;
  final bool isCreator;
  final bool hasJoined;

  RideDetailsScreen({
    required this.rideId,
    this.isCreator = false,
    this.hasJoined = false,
  });

  @override
  _RideDetailsScreenState createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _rideDetails = {};
  List<dynamic> _participants = [];
  bool _isJoining = false;
  bool _isLeaving = false;
  bool _isMapLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRideDetails();
  }

  Future<void> _loadRideDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.getRideDetails(widget.rideId);
      print('Ride details response: $result'); // Debug log
      setState(() {
        _rideDetails = result['ride'] ?? {};
        print('Ride details after setting: $_rideDetails'); // Debug log
        print('Fare data: ${_rideDetails['fare']}'); // Debug log
        _participants = result['participants'] ?? [];
        _isLoading = false;
        _isMapLoading = false;
      });
    } catch (e) {
      print('Error loading ride details: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isMapLoading = false;
      });
    }
  }

  void _openMap() {
    if (_rideDetails['pickup'] == null || _rideDetails['destination'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location information is missing')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          pickup: _rideDetails['pickup'],
          destination: _rideDetails['destination'],
        ),
      ),
    );
  }

  Future<void> _joinRide() async {
    if (_isJoining) return;

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
      _isJoining = true;
    });

    try {
      await ApiService.joinRide(widget.rideId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined the ride!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the ride details
      _loadRideDetails();
      
      // Navigate back to My Rides screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyRidesScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  Future<void> _leaveRide() async {
    if (_isLeaving) return;

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
      _isLeaving = true;
    });

    try {
      await ApiService.leaveRide(widget.rideId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully left the ride'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back to My Rides screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyRidesScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLeaving = false;
      });
    }
  }

    Future<void> _deleteRide() async {
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

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.deleteRide(widget.rideId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back to My Rides screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyRidesScreen()),
      );
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

  // Helper method to get static map URL
  String _getStaticMapUrl() {
    // Replace with your actual API key
    const apiKey = 'AIzaSyBUD_8k6oVXoGfOErCPZprXBobAOihjcKQ';
    
    final pickup = _rideDetails['pickup'];
    final destination = _rideDetails['destination'];
    
    if (pickup == null || destination == null) {
      return '';
    }
    
    // URL encode the addresses
    final encodedPickup = Uri.encodeComponent(pickup);
    final encodedDestination = Uri.encodeComponent(destination);
    
    // Create a static map URL with markers and path
    return 'https://maps.googleapis.com/maps/api/staticmap?'
        'size=600x300&scale=2'
        '&markers=color:green|label:A|$encodedPickup'
        '&markers=color:red|label:B|$encodedDestination'
        '&path=color:0x0000ff|weight:5|$encodedPickup|$encodedDestination'
        '&key=$apiKey';
  }

  // GridPainter for the fallback map
  Widget _buildFallbackMapPreview() {
    final pickup = _rideDetails['pickup'] ?? 'Unknown';
    final destination = _rideDetails['destination'] ?? 'Unknown';
    
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Background grid pattern
          CustomPaint(
            size: Size.infinite,
            painter: GridPainter(),
          ),
          
          // Route visualization
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pickup,
                        style: TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: EdgeInsets.only(left: 12),
                  height: 40,
                  width: 2,
                  color: Colors.blue,
                ),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        destination,
                        style: TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Overlay to make the entire area clickable
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openMap,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Tap to view full map',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ride Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadRideDetails,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildRideDetailsContent(),
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
            onPressed: _loadRideDetails,
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildRideDetailsContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ride info card
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ride #${_rideDetails['id']}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInfoRow(Icons.person, 'Created by', _rideDetails['creator_name'] ?? 'Unknown'),
                  SizedBox(height: 12),
                  _buildInfoRow(Icons.location_on, 'From', _rideDetails['pickup'] ?? 'Unknown'),
                  SizedBox(height: 12),
                  _buildInfoRow(Icons.location_on, 'To', _rideDetails['destination'] ?? 'Unknown'),
                  if (_rideDetails['departure_time'] != null) ...[
                    SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.access_time, 
                      'Departure Time', 
                      _formatTime(_rideDetails['departure_time'])
                    ),
                  ],
                  SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.group, 
                    'Participants', 
                    '${_rideDetails['participant_count'] ?? 1} people'
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.attach_money,
                    'Fare',
                    '\$${_rideDetails['fare']?['amount']?.toStringAsFixed(2) ?? '0.00'}'
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.calendar_today, 
                    'Created', 
                    _formatDate(_rideDetails['created_at'])
                  ),
                  SizedBox(height: 16),
                  // View on map button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openMap,
                      icon: Icon(Icons.map),
                      label: Text('View Route on Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Map preview (static image or mini map)
          Card(
            elevation: 4,
            child: Container(
              height: 200,
              width: double.infinity,
              child: _isMapLoading
                ? Center(child: CircularProgressIndicator())
                : _buildMapPreview(),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Participants section
          Text(
            'Participants',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          
          // Participants list
          _participants.isEmpty
              ? Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No participants yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              : Card(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      final participant = _participants[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(participant['name'] ?? 'Unknown'),
                        subtitle: Text('Joined: ${_formatDate(participant['joined_at'])}'),
                      );
                    },
                  ),
                ),

                          SizedBox(height: 24),
          
          // Action buttons
          if (widget.isCreator)
            ElevatedButton.icon(
              onPressed: _deleteRide,
              icon: Icon(Icons.delete),
              label: Text('Delete Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: Size(double.infinity, 50),
              ),
            )
          else if (widget.hasJoined)
            ElevatedButton.icon(
              onPressed: _isLeaving ? null : _leaveRide,
              icon: Icon(Icons.exit_to_app),
              label: _isLeaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Leave Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: Size(double.infinity, 50),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _isJoining ? null : _joinRide,
              icon: Icon(Icons.directions_car),
              label: _isJoining
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Join Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapPreview() {
    final mapUrl = _getStaticMapUrl();
    
    // If we have valid pickup and destination locations, show the static map
    if (mapUrl.isNotEmpty) {
      return Stack(
        children: [
          // Static map image
          Positioned.fill(
            child: Image.network(
              mapUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / 
                          loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('Error loading map image: $error');
                return _buildFallbackMapPreview();
              },
            ),
          ),
          
          // Overlay to make the entire map clickable
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openMap,
              ),
            ),
          ),
          
          // "View full map" indicator
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fullscreen, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'View full map',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Fallback when we don't have location data
      return _buildFallbackMapPreview();
    }
  }
}

// Custom painter for grid pattern in the fallback map
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    // Draw horizontal lines
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += 20;
    }

    // Draw vertical lines
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      x += 20;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}