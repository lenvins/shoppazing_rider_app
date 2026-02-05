import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_update/in_app_update.dart';

class InAppUpdateService {
  /// Checks Google Play for updates and, if an immediate update is available
  /// and allowed, starts the immediate update flow.
  ///
  /// Returns true if an update flow was started, false otherwise.
  Future<bool> requireImmediateUpdateIfAvailable() async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.immediateUpdateAllowed == true) {
        // This will display Google's immediate update UI and block usage
        // until the update completes or fails.
        await InAppUpdate.performImmediateUpdate();
        return true;
      }
    } catch (_) {
      // Silently ignore errors; app will proceed without forced update.
    }
    return false;
  }
}
