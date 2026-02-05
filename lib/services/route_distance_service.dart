import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RouteDistanceService {
  /// Create HTTP client with proper configuration
  static http.Client _getHttpClient() {
    final httpClient = http.Client();
    return httpClient;
  }

  /// Calculate route distance between two points using OSRM (Open Source Routing Machine)
  /// OSRM is free and doesn't require an API key
  static Future<double?> getMotorcycleRouteDistance({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    try {
      // OSRM API endpoint - completely free, no API key required
      // Format: /route/v1/{profile}/{coordinates}?overview=false
      // Using 'driving' profile (closest to motorcycle routing)
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/'
          '$originLng,$originLat;$destinationLng,$destinationLat'
          '?overview=false&alternatives=false&steps=false');

      final client = _getHttpClient();
      final response = await client.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('OSRM request timed out after 15 seconds');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final distance = route['distance'] as num; // Distance in meters
          final distanceKm = distance / 1000.0; // Convert to kilometers
          return distanceKm;
        } else {
          debugPrint("OSRM API returned no routes or error code");
          return null;
        }
      } else {
        debugPrint("OSRM API error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching route distance: $e");
      debugPrint("Connection issue - ensure device has internet access and OSRM service is reachable");
    }

    return null; // Return null if API fails
  }

  /// Calculate motorcycle route distance with fallback to straight-line distance
  static Future<double> getDistanceWithFallback({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    // Try to get motorcycle route distance first
    final motorcycleDistance = await getMotorcycleRouteDistance(
      originLat: originLat,
      originLng: originLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
    );

    if (motorcycleDistance != null) {
      return motorcycleDistance;
    }

    // Fallback to straight-line distance using Haversine formula
    return _calculateStraightLineDistance(
      originLat,
      originLng,
      destinationLat,
      destinationLng,
    );
  }

  /// Calculate straight-line distance using Haversine formula (fallback)
  static double _calculateStraightLineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    // Convert degrees to radians
    final double lat1Rad = lat1 * (pi / 180);
    final double lng1Rad = lng1 * (pi / 180);
    final double lat2Rad = lat2 * (pi / 180);
    final double lng2Rad = lng2 * (pi / 180);

    // Differences in coordinates
    final double deltaLat = lat2Rad - lat1Rad;
    final double deltaLng = lng2Rad - lng1Rad;

    // Haversine formula
    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}
