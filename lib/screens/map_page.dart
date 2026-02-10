import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as lat_lng;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Position? currentPosition;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentPosition = position;
        isLoading = false;
      });

      // Print coordinates for debugging
      // ignore: avoid_print
      print('Latitude: ${position.latitude}');
      // ignore: avoid_print
      print('Longitude: ${position.longitude}');
    } catch (e) {
      // ignore: avoid_print
      print('Error getting location: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Location'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentPosition == null
              ? const Center(child: Text('Unable to get location'))
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: lat_lng.LatLng(
                      currentPosition!.latitude,
                      currentPosition!.longitude,
                    ),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.shoppazing_rider_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 40,
                          height: 40,
                          point: lat_lng.LatLng(
                            currentPosition!.latitude,
                            currentPosition!.longitude,
                          ),
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
    );
  }
}
