import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MobilePhoneButton extends StatelessWidget {
  final String mobileNumber;

  const MobilePhoneButton({
    Key? key,
    required this.mobileNumber,
  }) : super(key: key);

  Future<void> _launchPhoneCall() async {
    final url = 'tel:$mobileNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchSms() async {
    final url = 'sms:$mobileNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchWhatsApp() async {
    // Note: The phone number must be in international format.
    // This implementation assumes the number is already correctly formatted.
    final url = 'https://wa.me/$mobileNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      // Fallback to regular SMS if WhatsApp fails
      await _launchSms();
    }
  }

  // Copy the mobile number to clipboard
  Future<void> _copyAddress(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: mobileNumber));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mobile number copied to clipboard')),
      );
    }
  }

  Future<void> _showPhoneOptions(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.call, color: Colors.blue),
              title: const Text('Call'),
              subtitle: Text(mobileNumber),
              onTap: () {
                Navigator.pop(context);
                _launchPhoneCall();
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green),
              title: const Text('SMS'),
              subtitle: Text(mobileNumber),
              onTap: () {
                Navigator.pop(context);
                _launchSms();
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble, color: Colors.green),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _launchWhatsApp();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Address'),
              onTap: () {
                Navigator.pop(context);
                _copyAddress(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _showPhoneOptions(context),
      child: Text(mobileNumber),
    );
  }
}