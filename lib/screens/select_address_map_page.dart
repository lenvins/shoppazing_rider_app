import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as lat_lng;
import 'package:http/http.dart' as http;
import 'dart:convert';

class SelectAddressMapPage extends StatefulWidget {
  const SelectAddressMapPage({super.key});

  @override
  State<SelectAddressMapPage> createState() => _SelectAddressMapPageState();
}

class _SelectAddressMapPageState extends State<SelectAddressMapPage> {
  Position? _currentPosition;
  bool _isLoading = true;
  lat_lng.LatLng? _selectedPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _selectedPosition =
            lat_lng.LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _confirmSelection() {
    if (_selectedPosition == null) return;
    _getAddressFromCoordinates(_selectedPosition!.latitude, _selectedPosition!.longitude);
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng',
      );
      
      final response = await http.get(
        url,
        headers: {'User-Agent': 'shoppazing_rider_app'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        Navigator.pop(context, {
          'lat': lat,
          'lng': lng,
          'address': data['display_name']?.toString() ?? '',
          'city': address?['city']?.toString() ?? 
                  address?['town']?.toString() ?? 
                  address?['village']?.toString() ?? '',
          'state': address?['state']?.toString() ?? '',
          'country': address?['country']?.toString() ?? '',
          'road': address?['road']?.toString() ?? '',
        });
      } else {
        _returnBasicCoordinates(lat, lng);
      }
    } catch (e) {
      _returnBasicCoordinates(lat, lng);
    }
  }

  void _returnBasicCoordinates(double lat, double lng) {
    Navigator.pop(context, {
      'lat': lat,
      'lng': lng,
      'address': 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}',
      'city': '',
      'state': '',
      'country': '',
      'road': '',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Address on Map'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentPosition == null
              ? const Center(
                  child: Text('Unable to get current location'),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: lat_lng.LatLng(
                          _selectedPosition?.latitude ??
                              _currentPosition!.latitude,
                          _selectedPosition?.longitude ??
                              _currentPosition!.longitude,
                        ),
                        initialZoom: 16,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _selectedPosition = point;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.example.shoppazing_rider_app',
                        ),
                        if (_selectedPosition != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 40,
                                height: 40,
                                point: _selectedPosition!,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.blue,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedPosition != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Lat: ${_selectedPosition!.latitude.toStringAsFixed(5)}, '
                                'Lng: ${_selectedPosition!.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  _selectedPosition == null ? null : _confirmSelection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5D8AA8),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Use this location'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

