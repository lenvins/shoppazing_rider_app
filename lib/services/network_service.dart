import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkService {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      // If no connectivity at all, return false
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Try to reach a reliable server to confirm internet access
      try {
        final result = await InternetAddress.lookup('google.com');
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Check if device has any network connection (WiFi, mobile, etc.)
  static Future<bool> hasNetworkConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Get user-friendly error message for network issues
  static String getNetworkErrorMessage(dynamic error) {
    if (error is SocketException) {
      if (error.osError?.errorCode == 7) {
        return 'No internet connection. Please check your data or WiFi connection.';
      } else if (error.osError?.errorCode == 8) {
        return 'Server not found. Please check your internet connection.';
      } else if (error.osError?.errorCode == 110) {
        return 'Connection timed out. Please check your internet connection.';
      } else {
        return 'Network error. Please check your internet connection.';
      }
    } else if (error.toString().contains('Failed host lookup')) {
      return 'No internet connection. Please check your data or WiFi connection.';
    } else if (error.toString().contains('Connection refused')) {
      return 'Unable to connect to server. Please try again later.';
    } else if (error.toString().contains('Connection timed out')) {
      return 'Connection timed out. Please check your internet connection.';
    } else {
      return 'Network error. Please check your internet connection.';
    }
  }

  /// Show network error dialog
  static void showNetworkErrorDialog(BuildContext context,
      {String? customMessage}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 8),
              Text('No Internet Connection'),
            ],
          ),
          content: Text(
            customMessage ??
                'Please check your internet connection and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show network error snackbar
  static void showNetworkErrorSnackBar(BuildContext context,
      {String? customMessage}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                customMessage ??
                    'No internet connection. Please check your data or WiFi.',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            // You can add retry logic here if needed
          },
        ),
      ),
    );
  }

  /// Check connectivity and show appropriate message if offline
  static Future<bool> checkConnectivityAndShowMessage(
      BuildContext context) async {
    final hasConnection = await hasInternetConnection();

    if (!hasConnection) {
      showNetworkErrorSnackBar(context);
      return false;
    }

    return true;
  }
}
