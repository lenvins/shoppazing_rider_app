import 'dart:convert';
import 'dart:math';
// import removed: http
import 'package:shoppazing_rider_app/services/api_config.dart';

import 'api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class DeviceService {
  static Future<String?> getDeviceToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      // Debug print
      return token;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getFirebaseUID() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return user.uid;
      } else {
        // Try to sign in anonymously to get a UID
        UserCredential userCredential =
            await FirebaseAuth.instance.signInAnonymously();
        return userCredential.user?.uid;
      }
    } catch (e) {
      // Fallback to custom UID if Firebase Auth fails
      return _generateCustomUID();
    }
  }

  static String _generateCustomUID() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final uid = String.fromCharCodes(Iterable.generate(
        28, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
    return uid;
  }

  static Future<Position?> getCurrentLocation(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        // Show dialog to enable location services
        bool? shouldOpenSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text(
                'Location services are required for this app. Please enable location services in your device settings.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        );

        if (shouldOpenSettings == true) {
          await Geolocator.openLocationSettings();
          // Wait for user to return from settings
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            return null;
          }
        } else {
          return null;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Show dialog to open app settings
        bool? shouldOpenSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location permission is permanently denied. Please enable it in app settings.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        );

        if (shouldOpenSettings == true) {
          await Geolocator.openAppSettings();
          // Check permission again after returning from settings
          permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            return null;
          }
        } else {
          return null;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      // Validate the position
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        return null;
      }

      return position;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateDeviceInfo(
      String userId, BuildContext context) async {
    try {
      String? deviceToken = await getDeviceToken();
      Position? position = await getCurrentLocation(context);
      String? firebaseUID = await getFirebaseUID();

      if (deviceToken == null) {
        return false;
      }

      if (position == null) {
        return false;
      }


      final response = await ApiClient.post(
        ApiConfig.apiUri('/postridertoken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'UserId': userId,
          'FirebaseDeviceToken': deviceToken,
          'Lat': position.latitude,
          'Lng': position.longitude,
          'FirebaseUID': firebaseUID,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
