import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

class MapScreen extends StatefulWidget {
  final String pickup;
  final String destination;

  MapScreen({
    required this.pickup,
    required this.destination,
  });

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _controller = WebviewController();
  bool _isWebViewReady = false;
  String _selectedPickup = '';
  String _selectedDestination = '';

  @override
  void initState() {
    super.initState();
    _selectedPickup = widget.pickup;
    _selectedDestination = widget.destination;
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      await _controller.initialize();
      
      // Load Google Maps URL with pickup & destination
      await _loadMap();
      
      setState(() {
        _isWebViewReady = true;
      });
    } catch (e) {
      print('Error initializing WebView: $e');
    }
  }

  Future<void> _loadMap() async {
    final url = "https://www.openstreetmap.org/directions?from=${Uri.encodeComponent(_selectedPickup)}&to=${Uri.encodeComponent(_selectedDestination)}";
    await _controller.loadUrl(url);
  }

  void _updateMapLocations() async {
    if (_isWebViewReady) {
      await _loadMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Select Locations"),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, {
                'pickup': _selectedPickup,
                'destination': _selectedDestination,
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Location input fields
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Pickup Location',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    controller: TextEditingController(text: _selectedPickup),
                    onChanged: (value) {
                      _selectedPickup = value;
                    },
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _updateMapLocations,
                  child: Text('Search'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Destination',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              controller: TextEditingController(text: _selectedDestination),
              onChanged: (value) {
                _selectedDestination = value;
              },
            ),
          ),
          // Map WebView
          Expanded(
            child: _isWebViewReady
                ? Webview(_controller)
                : Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: EdgeInsets.symmetric(vertical: 15),
            ),
            onPressed: () {
              Navigator.pop(context, {
                'pickup': _selectedPickup,
                'destination': _selectedDestination,
              });
            },
            child: Text(
              'Confirm Locations',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}