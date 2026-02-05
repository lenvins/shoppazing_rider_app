import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class AddressButton extends StatelessWidget {
  final String address;
  final double? latitude;
  final double? longitude;
  final String? label;
  final bool isCompact;

  const AddressButton({
    Key? key,
    required this.address,
    this.latitude,
    this.longitude,
    this.label,
    this.isCompact = false,
  }) : super(key: key);

  Future<void> _showMapOptions(BuildContext context) async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Open with',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            // Google Maps option
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text('Google Maps'),
              onTap: () {
                Navigator.pop(context);
                _launchGoogleMaps(context);
              },
            ),
            // Waze option
            ListTile(
              leading: const Icon(Icons.navigation, color: Colors.green),
              title: const Text('Waze'),
              onTap: () {
                Navigator.pop(context);
                _launchWaze(context);
              },
            ),
            // Apple Maps (iOS only)
            if (!kIsWeb && Platform.isIOS)
              ListTile(
                leading: const Icon(Icons.map_outlined, color: Colors.blue),
                title: const Text('Apple Maps'),
                onTap: () {
                  Navigator.pop(context);
                  _launchAppleMaps(context);
                },
              ),
            // OpenStreetMap option (web fallback)
            if (kIsWeb)
              ListTile(
                leading: const Icon(Icons.map, color: Colors.orange),
                title: const Text('OpenStreetMap'),
                onTap: () {
                  Navigator.pop(context);
                  _launchOpenStreetMap(context);
                },
              ),
            // Copy address option
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Address'),
              onTap: () {
                Navigator.pop(context);
                _copyAddress(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchGoogleMaps(BuildContext context) async {
    if (latitude == null || longitude == null) return;

    // Use different URL schemes for Android and iOS
    String urlString;
    if (!kIsWeb && Platform.isAndroid) {
      // Android: Use intent URL for better compatibility
      urlString = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    } else if (!kIsWeb && Platform.isIOS) {
      // iOS: Use Google Maps app URL scheme
      urlString = 'comgooglemaps://?q=$latitude,$longitude&center=$latitude,$longitude&zoom=14';
    } else {
      // Web fallback
      urlString = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    }

    try {
      final Uri url = Uri.parse(urlString);
      // Try launching directly - don't check canLaunchUrl as it's unreliable
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && !kIsWeb && Platform.isAndroid) {
        // Fallback to web version on Android if app not installed
        final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // If app-specific URL fails, try web version
      try {
        final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open Google Maps: $e2')),
          );
        }
      }
    }
  }

  Future<void> _launchWaze(BuildContext context) async {
    if (latitude == null || longitude == null) return;

    String urlString;
    if (!kIsWeb && Platform.isAndroid) {
      urlString = 'waze://?ll=$latitude,$longitude&navigate=yes';
    } else if (!kIsWeb && Platform.isIOS) {
      urlString = 'waze://?ll=$latitude,$longitude&navigate=yes';
    } else {
      urlString = 'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes';
    }

    try {
      final Uri url = Uri.parse(urlString);
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      // If Waze app not installed, fallback to web
      if (!launched) {
        final webUrl = Uri.parse('https://waze.com/ul?ll=$latitude,$longitude&navigate=yes');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Fallback to web version
      try {
        final webUrl = Uri.parse('https://waze.com/ul?ll=$latitude,$longitude&navigate=yes');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open Waze: $e2')),
          );
        }
      }
    }
  }

  Future<void> _launchAppleMaps(BuildContext context) async {
    if (latitude == null || longitude == null) return;

    // iOS Apple Maps URL scheme
    final urlString = 'http://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d';

    try {
      final Uri url = Uri.parse(urlString);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Apple Maps: $e')),
        );
      }
    }
  }

  Future<void> _launchOpenStreetMap(BuildContext context) async {
    if (latitude == null || longitude == null) return;

    final urlString = 'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude&zoom=15';

    try {
      final Uri url = Uri.parse(urlString);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open OpenStreetMap: $e')),
        );
      }
    }
  }

  Future<void> _copyAddress(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      // Compact version: Just a clickable text with icon
      return GestureDetector(
        onTap: () => _showMapOptions(context),
        child: Row(
          children: [
            Expanded(
              child: Text(
                address,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.location_on, color: Colors.red, size: 18),
          ],
        ),
      );
    }

    // Full version: Clickable button with label and icon
    return GestureDetector(
      onTap: () => _showMapOptions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(
                      label!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  if (label != null) const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}
