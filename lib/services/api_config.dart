import 'rider_orders_db.dart';

class ApiConfig {
  // Toggle this or assign at runtime to switch environments
  static bool useSellerCenter = true;
  static bool? _lastUseSellerCenter;

  // Base originss
  static const String testOrigin = 'http://jaramburo19-001-site11.ftempurl.com';
  static const String sellerCenterOrigin =
      'https://sellercenter.shoppazing.com';

  static String get baseOrigin =>
      useSellerCenter ? sellerCenterOrigin : testOrigin;

  // Common base paths
  static String get baseUrl => baseOrigin + '/api';
  static String get apiBase => baseOrigin + '/api/shop';
  static String get tokenUrl => baseOrigin + '/api/token';
  static String get paymentStartLoadPurchase =>
      baseOrigin + '/OnlinePayment/StartLoadPurchase';

  // Helpers
  static Uri apiUri(String path) {
    final normalized = path.startsWith('/') ? path : '/' + path;
    return Uri.parse(apiBase + normalized);
  }

  static Uri absolute(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Uri.parse(pathOrUrl);
    }
    final normalized = pathOrUrl.startsWith('/') ? pathOrUrl : '/' + pathOrUrl;
    return Uri.parse(baseOrigin + normalized);
  }

  /// Switch to a different endpoint and optionally clear local data
  static Future<void> switchEndpoint(bool newUseSellerCenter,
      {bool clearLocalData = true}) async {
    final bool endpointChanged = _lastUseSellerCenter != null &&
        _lastUseSellerCenter != newUseSellerCenter;

    _lastUseSellerCenter = newUseSellerCenter;
    useSellerCenter = newUseSellerCenter;

    if (endpointChanged && clearLocalData) {
      await RiderOrdersDB.clearCurrentEndpointData();
    }
  }

  /// Check if the endpoint has changed since last check
  static bool hasEndpointChanged() {
    return _lastUseSellerCenter != null &&
        _lastUseSellerCenter != useSellerCenter;
  }

  /// Switch to test endpoint (http://test.shoppazing.com)
  static Future<void> switchToTestEndpoint({bool clearLocalData = true}) async {
    await switchEndpoint(false, clearLocalData: clearLocalData);
  }

  /// Switch to live endpoint (https://sellercenter.shoppazing.com)
  static Future<void> switchToLiveEndpoint({bool clearLocalData = true}) async {
    await switchEndpoint(true, clearLocalData: clearLocalData);
  }
}
