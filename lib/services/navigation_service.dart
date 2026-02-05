import 'package:flutter/material.dart';
import 'user_session_db.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> redirectToOtpAndClearSession({String? mobileNo}) async {
    try {
      await UserSessionDB.clearSession();
    } catch (_) {}
    final state = navigatorKey.currentState;
    if (state != null) {
      state.pushNamedAndRemoveUntil(
        '/phone_number',
        (route) => false,
      );
    }
  }

  static Future<void> showSessionExpiredDialogAndRedirect(
      {String? mobileNo}) async {
    final state = navigatorKey.currentState;
    if (state != null && state.mounted) {
      // Show dialog first
      await showDialog(
        context: state.context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Session Expired'),
            content: const Text('Session expired. Please Login again'),
            actions: [
              TextButton(
                onPressed: () async {
                  // Clear session and redirect to login
                  try {
                    await UserSessionDB.clearSession();
                  } catch (_) {}

                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/phone_number',
                      (route) => false,
                    );
                  }
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }
}
