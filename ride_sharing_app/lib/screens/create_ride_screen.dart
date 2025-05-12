// lib/screens/create_ride_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'my_rides_screen.dart';

class CreateRideScreen extends StatefulWidget {
  @override
  _CreateRideScreenState createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _fareController = TextEditingController();
  DateTime? _departureTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _fareController.dispose();
    super.dispose();
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

  Future<void> _createRide() async {
    if (_pickupController.text.isEmpty || 
        _destinationController.text.isEmpty || 
        _fareController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    // Validate fare is a positive number
    final fare = double.tryParse(_fareController.text);
    if (fare == null || fare <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid fare amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.requestRide(
        _pickupController.text,
        _destinationController.text,
        _departureTime,
        fare: fare,
      );

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ride created successfully')),
      );

      // Navigate to My Rides screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyRidesScreen()),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating ride: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Ride'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pickupController,
              decoration: InputDecoration(
                labelText: 'Pickup Location',
                prefixIcon: Icon(Icons.location_on, color: Colors.green),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: 'Destination',
                prefixIcon: Icon(Icons.location_on, color: Colors.red),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _fareController,
              decoration: InputDecoration(
                labelText: 'Fare Amount',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
                hintText: 'Enter fare amount',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            InkWell(
              onTap: _selectTime,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Departure Time',
                  prefixIcon: Icon(Icons.access_time),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _departureTime != null
                      ? '${_departureTime!.hour}:${_departureTime!.minute.toString().padLeft(2, '0')}'
                      : 'Select Time',
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _createRide,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Create Ride'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}