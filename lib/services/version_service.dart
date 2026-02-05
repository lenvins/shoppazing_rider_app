import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  VersionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Returns true if a forced update is required for this device.
  ///
  /// Reads from Firestore at `app_config/platform` where platform is
  /// `android` or `ios`, expecting fields:
  /// - `minVersionCode` (int): minimum accepted build number
  /// - `force` (bool, optional): whether update is mandatory (default true)
  /// - `message` (string, optional): message to show in the dialog
  /// - `storeUrl` (string, optional): custom store URL; if missing we derive
  ///   it from the package name.
  Future<ForceUpdateResult> checkForForceUpdate() async {
    if (kIsWeb) {
      return ForceUpdateResult.notRequired();
    }

    final targetPlatform =
        Platform.isAndroid
            ? 'android'
            : Platform.isIOS
            ? 'ios'
            : 'unknown';

    if (targetPlatform == 'unknown') {
      return ForceUpdateResult.notRequired();
    }

    try {
      final PackageInfo info = await PackageInfo.fromPlatform();

      // Firestore document path: app_config/<platform>
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('app_config').doc(targetPlatform).get();

      if (!snapshot.exists) {
        return ForceUpdateResult.notRequired();
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final dynamic minCodeRaw = data['minVersionCode'];
      final bool force = (data['force'] as bool?) ?? true;
      final String? message = data['message'] as String?;
      final String? storeUrlOverride = data['storeUrl'] as String?;

      if (minCodeRaw is! int) {
        return ForceUpdateResult.notRequired();
      }

      // On Android, versionCode maps to buildNumber (int). On iOS, buildNumber
      // is a string but we still treat it as an integer if possible.
      final int currentCode = int.tryParse(info.buildNumber) ?? 0;
      final bool requiresUpdate = currentCode < minCodeRaw;
      if (!requiresUpdate) {
        return ForceUpdateResult.notRequired();
      }

      final String storeUrl = storeUrlOverride ?? _deriveStoreUrl(info);
      return ForceUpdateResult.required(
        message: message,
        storeUrl: storeUrl,
        minVersionCode: minCodeRaw,
        currentVersionCode: currentCode,
        isForced: force,
      );
    } catch (_) {
      // If reading remote config fails (e.g., permission-denied), do not block the app.
      return ForceUpdateResult.notRequired();
    }
  }

  String _deriveStoreUrl(PackageInfo info) {
    if (Platform.isAndroid) {
      final String packageName = info.packageName;
      // Try market URL first; Play Store will handle it. Fallbacks handled by caller.
      return 'market://details?id=$packageName';
    }
    if (Platform.isIOS) {
      // Without App Store ID, fall back to a generic URL the app can override in Firestore.
      return 'https://apps.apple.com';
    }
    return '';
  }
}

class ForceUpdateResult {
  ForceUpdateResult._({
    required this.required,
    this.message,
    this.storeUrl,
    this.minVersionCode,
    this.currentVersionCode,
    this.isForced,
  });

  final bool required;
  final String? message;
  final String? storeUrl;
  final int? minVersionCode;
  final int? currentVersionCode;
  final bool? isForced;

  factory ForceUpdateResult.notRequired() =>
      ForceUpdateResult._(required: false);

  factory ForceUpdateResult.required({
    String? message,
    String? storeUrl,
    required int minVersionCode,
    required int currentVersionCode,
    bool isForced = true,
  }) => ForceUpdateResult._(
    required: true,
    message: message,
    storeUrl: storeUrl,
    minVersionCode: minVersionCode,
    currentVersionCode: currentVersionCode,
    isForced: isForced,
  );
}
