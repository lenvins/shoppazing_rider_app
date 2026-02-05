import 'package:flutter/material.dart';
import 'package:shoppazing_rider_app/services/api_config.dart';
import 'dashboard_page.dart';
import 'account_page.dart';
import 'order_details_page.dart';
// import removed: http
import '../services/api_client.dart';
import 'dart:convert';
import '../services/device_service.dart';
import 'package:intl/intl.dart';
import '../services/rider_orders_db.dart';
import 'dart:async';
import '../services/user_session_db.dart';
import '../services/network_service.dart';
import '../services/route_distance_service.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../widgets/address_button.dart';

class HomePage extends StatefulWidget {
  // Add a global key to access the HomePage state
  static final GlobalKey<_HomePageState> globalKey =
      GlobalKey<_HomePageState>();

  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();

  static _HomePageState? of(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomePageState>();
    return state;
  }

  // Add a static method to access the state via global key
  static _HomePageState? getState() {
    return globalKey.currentState;
  }
}

class OrderData {
  final int serverHeaderId;
  final String orderNumber;
  final String status;
  final String dateTimeCreated;
  final String storeName;
  final String storeImageUrl;
  final String storeAddress;
  final String customerName;
  final String customerAddress;
  final String customerMobileNo;
  final double storeLat;
  final double storeLng;
  final double customerLat;
  final double customerLng;
  final double deliveryFee;
  final double onlineServiceCharge;
  final double subTotal;
  final String totalDue;
  final List<dynamic> rawDetails;
  final String? assignedTo; // NEW: Assigned rider id
  final String? OtherChatUserFirebaseUID;
  final String? OtherChatUserName;
  final String?
      OtherChatUserId; // NEW: Customer user ID for stable chat identification
  final String? customerPin;
  final bool isPaid;
  final bool isManualDelivered;
  final bool isOrderRated;
  final int? paymentTypeId;
  final int? onlinePaymentTypeId;
  final bool useLoyaltyPoints;
  final int? saleHeaderId;
  final double redeemedCash;
  final double dfDiscount;
  final String? riderProfilePic;
  final String? riderFullName;
  final String? riderPlateNo;
  final String? riderDriversLicenseNo;
  final String? riderUserId;
  final double? riderLat;
  final double? riderLng;

  OrderData({
    required this.serverHeaderId,
    required this.orderNumber,
    required this.status,
    required this.dateTimeCreated,
    required this.storeName,
    required this.storeImageUrl,
    required this.storeAddress,
    required this.customerName,
    required this.customerAddress,
    required this.customerMobileNo,
    required this.storeLat,
    required this.storeLng,
    required this.customerLat,
    required this.customerLng,
    required this.deliveryFee,
    required this.onlineServiceCharge,
    required this.subTotal,
    required this.totalDue,
    required this.rawDetails,
    this.assignedTo,
    this.OtherChatUserFirebaseUID,
    this.OtherChatUserName,
    this.OtherChatUserId,
    this.customerPin,
    this.isPaid = false,
    this.isManualDelivered = false,
    this.isOrderRated = false,
    this.paymentTypeId,
    this.onlinePaymentTypeId,
    this.useLoyaltyPoints = false,
    this.saleHeaderId,
    this.redeemedCash = 0.0,
    this.dfDiscount = 0.0,
    this.riderProfilePic,
    this.riderFullName,
    this.riderPlateNo,
    this.riderDriversLicenseNo,
    this.riderUserId,
    this.riderLat,
    this.riderLng,
  });

  factory OrderData.fromJson(Map<String, dynamic> json) {
    String formattedTime = '';
    if (json['OrderDate'] != null) {
      try {
        DateTime parsedDate = DateTime.parse(json['OrderDate']);
        formattedTime = DateFormat('HH:mm:ss').format(parsedDate);
      } catch (e) {
        print('Error parsing date:  [38;5;9m${json['OrderDate']} [0m');
      }
    }

    return OrderData(
      serverHeaderId:
          int.tryParse(json['ServerHeaderId']?.toString() ?? '0') ?? 0,
      orderNumber: json['OrderNo']?.toString() ?? '',
      status: json['OrderStatusId']?.toString() ?? '',
      dateTimeCreated: formattedTime,
      storeName: json['StoreName']?.toString() ?? 'N/A',
      storeImageUrl: json['StoreImageUrl']?.toString() ?? '',
      storeAddress: json['StoreAddress']?.toString() ?? 'N/A',
      customerName: json['CustomerName']?.toString() ?? '',
      customerAddress: json['CustomerAddressLine1']?.toString() ?? '',
      customerMobileNo: json['CustomerMobileNo']?.toString() ?? '',
      storeLat: double.tryParse(json['StoreLat']?.toString() ?? '0') ?? 0.0,
      storeLng: double.tryParse(json['StoreLng']?.toString() ?? '0') ?? 0.0,
      customerLat:
          double.tryParse(json['CustomerLAT']?.toString() ?? '0') ?? 0.0,
      customerLng:
          double.tryParse(json['CustomerLNG']?.toString() ?? '0') ?? 0.0,
      deliveryFee:
          double.tryParse(json['DeliveryFee']?.toString() ?? '0') ?? 0.0,
      onlineServiceCharge:
          double.tryParse(json['OnlineServiceCharge']?.toString() ?? '0') ??
              0.0,
      subTotal: double.tryParse(json['SubTotal']?.toString() ?? '0') ?? 0.0,
      totalDue: json['TotalDue']?.toString() ?? '0',
      rawDetails: json['OrderDetails'] is List ? json['OrderDetails'] : [],
      assignedTo: json['AssignedTo']?.toString(),
      OtherChatUserFirebaseUID: json['OtherChatUserFirebaseUID']?.toString(),
      OtherChatUserName: json['OtherChatUserName']?.toString(),
      OtherChatUserId: json['UserId']?.toString(),
      customerPin: json['CustomerPIN']?.toString(),
      isPaid: (json['IsPaid'] as bool?) ?? false,
      isManualDelivered: (json['IsManualDelivered'] as bool?) ?? false,
      isOrderRated: (json['IsOrderRated'] as bool?) ?? false,
      paymentTypeId:
          int.tryParse(json['PaymentTypeId']?.toString() ?? '') ?? null,
      onlinePaymentTypeId:
          int.tryParse(json['OnlinePaymentTypeId']?.toString() ?? '') ?? null,
      useLoyaltyPoints: (json['UseLoyaltyPoints'] as bool?) ?? false,
      saleHeaderId:
          int.tryParse(json['SaleHeaderId']?.toString() ?? '') ?? null,
      redeemedCash:
          double.tryParse(json['RedeemedCash']?.toString() ?? '0') ?? 0.0,
      dfDiscount: double.tryParse(json['DFDiscount']?.toString() ?? '0') ?? 0.0,
      riderProfilePic: json['RiderProfilePic']?.toString(),
      riderFullName: json['RiderFullName']?.toString(),
      riderPlateNo: json['RiderPlateNo']?.toString(),
      riderDriversLicenseNo: json['RiderDriversLicenseNo']?.toString(),
      riderUserId: json['RiderUserId']?.toString(),
      riderLat: double.tryParse(json['RiderLat']?.toString() ?? '') ?? null,
      riderLng: double.tryParse(json['RiderLng']?.toString() ?? '') ?? null,
    );
  }
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  Timer? _autoRefreshTimer;
  bool _isRefreshing = false;

  static const List<String> _pageTitles = [
    'Orders',
    'Dashboard',
    'Account'
  ];

  // For testing: set these to override location, or leave null to use real location
  static double? testLat;
  static double? testLng;

  // Test coordinates for debugging (uncomment to test)
  // static double? testLat = 14.5995; // Manila coordinates for testing
  // static double? testLng = 120.9842;

  List<OrderData> _orders = [];
  OrderData? _acceptedOrder;
  Set<int> _acceptedOrderIds = {};
  bool _isAcceptingOrder = false;
  int? _acceptingOrderId;
  double _balance = 0.0;
  bool _balanceLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAcceptedOrderIds();
    _loadInitialOrders();
    _fetchBalance();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadInitialOrders();
        _fetchBalance();
      } else {
        timer.cancel();
      }
    });

    // Handle permissions after successful auto-login
    _handlePermissionsAfterLogin();
  }

  Future<void> _handlePermissionsAfterLogin() async {
    try {
      // Add a small delay to ensure the page is fully loaded
      await Future.delayed(const Duration(milliseconds: 500));

      // Ensure location permission
      await _ensureLocationPermission();
    } catch (e) {
      print('[ERROR] Error handling permissions in HomePage: $e');
    }
  }

  Future<void> _ensureLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are disabled, but don't show dialog immediately
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        print('[DEBUG] Location permission denied forever');
        // Could show a dialog here if needed
      }
    } catch (e) {
      print('[ERROR] Error ensuring location permission: $e');
    }
  }

  Future<void> _fetchBalance() async {
    if (_balanceLoading) return;
    _balanceLoading = true;
    try {
      final session = await UserSessionDB.getSession();
      final userId = session?['user_id'] ?? '';
      if (userId.isEmpty) {
        _balanceLoading = false;
        return;
      }
      final url = ApiConfig.absolute('/api/shop/getriderdashboard');
      final body = {'UserId': userId};
      final response = await ApiClient.post(url,
          body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _balance = (data['LoadBalance'] is num)
              ? data['LoadBalance'].toDouble()
              : double.tryParse(data['LoadBalance']?.toString() ?? '0') ?? 0.0;
        });
      }
    } catch (e) {
      print('[ERROR] Error fetching balance: $e');
    } finally {
      _balanceLoading = false;
    }
  }

  bool _isBalanceLow() {
    return _balance < 0;
  }

  Future<void> _loadAcceptedOrderIds() async {
    final ids = await RiderOrdersDB.getAllAcceptedOrderIds();
    setState(() {
      _acceptedOrderIds = ids.toSet();
    });
  }

  Future<void> _addAcceptedOrderId(int id) async {
    await RiderOrdersDB.addAcceptedOrder(id);
    await _loadAcceptedOrderIds();
  }

  double _calculateTotalWithModifiers(OrderData order) {
    double total = order.subTotal;

    // Add raw modifier prices (without convenience fee)
    final details = order.rawDetails;

    for (final item in details) {
      final modifiers = _extractModifiers(item);

      for (final mod in modifiers) {
        final modifierPrice = _readModifierPrice(mod);
        if (modifierPrice > 0) {
          // Add raw modifier price
          total += modifierPrice;
        }
      }
    }

    return total;
  }

  double _calculateConvenienceFee(OrderData order) {
    // Use the API-provided onlineServiceCharge instead of calculating 10%
    return order.onlineServiceCharge;
  }

  List<Map<String, dynamic>> _extractModifiers(Map<String, dynamic> item) {
    // Try 'OrderDetailModifiers' first (API response), then 'Modifiers' (fallback)
    final dynamic direct = item['OrderDetailModifiers'] ?? item['Modifiers'];
    if (direct is List && direct.isNotEmpty) {
      return direct
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList();
    }

    for (final entry in item.entries) {
      final value = entry.value;
      if (value is List) {
        final asMaps = value.whereType<Map>().toList();
        if (asMaps.isNotEmpty) {
          final hasModifierKeys = asMaps.first.keys.any((k) {
            final lower = k.toString().toLowerCase();
            return lower.contains('modifiername') ||
                lower.contains('modifieroptionname');
          });
          if (hasModifierKeys) {
            return asMaps
                .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
                .cast<Map<String, dynamic>>()
                .toList();
          }
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  String _readModifierValue(
    Map<String, dynamic> mod,
    String targetKey,
  ) {
    if (mod.isEmpty) return '';
    final String targetLower = targetKey.toLowerCase();

    // Exact key match (case-insensitive)
    for (final entry in mod.entries) {
      if (entry.key.toString().toLowerCase() == targetLower) {
        final val = entry.value?.toString().trim();
        if (val != null && val.isNotEmpty && val.toLowerCase() != 'n/a') {
          return val;
        }
        return '';
      }
    }

    // Fallback: any key that contains the target token
    for (final entry in mod.entries) {
      final keyLower = entry.key.toString().toLowerCase();
      if (keyLower.contains(targetLower)) {
        final val = entry.value?.toString().trim();
        if (val != null && val.isNotEmpty && val.toLowerCase() != 'n/a') {
          return val;
        }
      }
    }

    return '';
  }

  double _readModifierPrice(Map<String, dynamic> mod) {
    if (mod.isEmpty) return 0.0;


    // Look for common price field names
    final priceKeys = ['Price', 'ModifierPrice', 'OptionPrice', 'UnitPrice'];

    for (final key in priceKeys) {
      final priceValue = _readModifierValue(mod, key);
      if (priceValue.isNotEmpty) {
        final price = double.tryParse(priceValue);
        if (price != null && price > 0) {
          return price;
        }
      }
    }

    return 0.0;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialOrders() async {
    if (_isRefreshing || !mounted) return;
    _isRefreshing = true;

    // Check if API endpoint has changed and clear local data if needed
    if (ApiConfig.hasEndpointChanged()) {
      await RiderOrdersDB.clearCurrentEndpointData();
      if (mounted) {
        _acceptedOrderIds.clear();
        _acceptedOrder = null;
      }
    }

    final session = await UserSessionDB.getSession();
    final riderId =
        int.tryParse(session?['rider_id'] ?? session?['riderId'] ?? '0') ?? 0;

    List<OrderData> loadedOrders = [];

    // Always fetch from API to get the latest status
    if (riderId > 0) {
      try {
        // Fetch fresh data from API
        final freshOrders = await fetchOrdersFromApi(
          riderId: riderId,
          storeId: 0,
          orderHeaderId: 0,
        );

        // Use the fresh API data directly
        if (freshOrders.isNotEmpty) {
          loadedOrders = freshOrders;
        } else {
          // Fallback to local DB only if API returns no data
          final localOrders = await RiderOrdersDB.getAllActiveOrders();
          loadedOrders = localOrders
              .map((row) => OrderData.fromJson(jsonDecode(row['orderJson'])))
              .toList();
        }
      } catch (e) {
        // Fallback to local DB if API fails
        final localOrders = await RiderOrdersDB.getAllActiveOrders();
        loadedOrders = localOrders
            .map((row) => OrderData.fromJson(jsonDecode(row['orderJson'])))
            .toList();
      }
    } else {
      // No rider ID, load from local DB
      final localOrders = await RiderOrdersDB.getAllActiveOrders();
      loadedOrders = localOrders
          .map((row) => OrderData.fromJson(jsonDecode(row['orderJson'])))
          .toList();
    }

    // Keep delivered orders (status '7') so they appear in the Completed tab

    // Check if any previously accepted orders are now cancelled and remove them from accepted orders
    final cancelledAcceptedOrders = _acceptedOrderIds.where((id) {
      final order =
          loadedOrders.firstWhereOrNull((o) => o.serverHeaderId == id);
      // Remove from accepted list if order is missing, cancelled (8), or delivered (7)
      return order == null || order.status == '8' || order.status == '7';
    }).toList();

    if (cancelledAcceptedOrders.isNotEmpty) {
      for (final cancelledId in cancelledAcceptedOrders) {
        await RiderOrdersDB.cancelAcceptedOrder(cancelledId);
        _acceptedOrderIds.remove(cancelledId);
      }

      // Update _acceptedOrder if it was cancelled
      if (_acceptedOrder != null &&
          cancelledAcceptedOrders.contains(_acceptedOrder!.serverHeaderId)) {
        _acceptedOrder = null;
      }
    }

    // Sync accepted orders with server: if any order is assigned to this rider, treat as accepted
    final assignedOrder = loadedOrders.firstWhereOrNull(
      (o) =>
          o.assignedTo != null &&
          o.assignedTo == riderId.toString() &&
          o.status != '7' &&
          o.status != '8',
    );
    if (assignedOrder != null) {
      // Only allow one accepted order at a time
      _acceptedOrderIds = {assignedOrder.serverHeaderId};
      _acceptedOrder = assignedOrder;
    } else if (_acceptedOrderIds.isEmpty) {
      // Clear accepted order if no accepted orders remain
      _acceptedOrder = null;
    }

    // Move accepted orders to the top
    loadedOrders.sort((a, b) {
      final aAccepted = _acceptedOrderIds.contains(a.serverHeaderId);
      final bAccepted = _acceptedOrderIds.contains(b.serverHeaderId);
      if (aAccepted && !bAccepted) return -1;
      if (!aAccepted && bAccepted) return 1;
      return 0;
    });

    if (mounted) {
      setState(() {
        _orders = loadedOrders;
      });
    }
    _isRefreshing = false;
  }

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _cancelOrder() {
    if (mounted) {
      setState(() {
        _acceptedOrder = null;
      });
    }
  }

  // Public accessors for OrderDetailsPage
  Set<int> get acceptedOrderIds => _acceptedOrderIds;
  OrderData? get acceptedOrder => _acceptedOrder;
  void cancelOrder() => _cancelOrder();
  Future<void> acceptOrderWithRaceConditionHandling(OrderData order) async =>
      await _acceptOrderWithRaceConditionHandling(order);

  /// Handles order acceptance with proper race condition handling
  Future<void> _acceptOrderWithRaceConditionHandling(OrderData order) async {
    // Prevent multiple simultaneous acceptance attempts
    if (_isAcceptingOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, an order is being processed...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAcceptingOrder = true;
      _acceptingOrderId = order.serverHeaderId;
    });

    try {
      // First, refresh the order list to get the latest status
      await _loadInitialOrders();

      // Check if the order is still available after refresh
      final currentOrder = _orders.firstWhereOrNull(
        (o) => o.serverHeaderId == order.serverHeaderId,
      );

      if (currentOrder == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Order is no longer available. It may have been accepted by another rider.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check if order is already assigned to someone else
      if (currentOrder.assignedTo != null &&
          currentOrder.assignedTo!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order has already been accepted by another rider.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if order status allows acceptance
      if (currentOrder.status == '8' || currentOrder.status == '7') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order is no longer available for acceptance.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Proceed with acceptance
      await _performOrderAcceptance(currentOrder);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isAcceptingOrder = false;
        _acceptingOrderId = null;
      });
    }
  }

  /// Performs the actual order acceptance API call
  Future<void> _performOrderAcceptance(OrderData order) async {
    final session = await UserSessionDB.getSession();
    final userId = session?['user_id'] ?? '';
    final url = ApiConfig.apiUri('/postacceptriderorder');
    final body = {
      'OrderHeaderId': order.serverHeaderId,
      'OrderNo': order.orderNumber,
      'UserId': userId,
      'TotalAmount': _calculateTotalWithModifiers(order) +
          order.onlineServiceCharge + // Use API value
          order.deliveryFee,
    };

    try {
      final response = await ApiClient.post(url,
          body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'});

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['status_code'] == 200) {
          // Success
          await _addAcceptedOrderId(order.serverHeaderId);
          setState(() {
            _acceptedOrderIds.add(order.serverHeaderId);
            _acceptedOrder = order;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order accepted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailsPage(
                order: order,
                showAccept: false,
                onAccept: () async {
                  await _loadInitialOrders();
                },
              ),
            ),
          );
        } else {
          String errorMessage = data['message'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
          await _loadInitialOrders();
        }
      } else {
        // Handle different error scenarios
        final responseBody = response.body.toLowerCase();
        String errorMessage = 'Failed to accept order';

        // Handle specific status codes
        if (response.statusCode == 414) {
          errorMessage =
              'Order does not exist or has already been accepted by another rider.';
          // Refresh the order list to update the UI and remove the order
          await _loadInitialOrders();
        } else if (response.statusCode == 409) {
          errorMessage = 'Order has already been accepted by another rider.';
          // Refresh the order list to update the UI
          await _loadInitialOrders();
        } else if (response.statusCode == 404) {
          errorMessage = 'Order not found or no longer available.';
          // Refresh the order list to update the UI
          await _loadInitialOrders();
        } else if (responseBody.contains('already assigned') ||
            responseBody.contains('already accepted') ||
            responseBody.contains('taken')) {
          errorMessage = 'Order has already been accepted by another rider.';
          // Refresh the order list to update the UI
          await _loadInitialOrders();
        } else if (responseBody.contains('not available') ||
            responseBody.contains('unavailable')) {
          errorMessage = 'Order is no longer available for acceptance.';
          // Refresh the order list to update the UI
          await _loadInitialOrders();
        } else {
          errorMessage = 'Failed to accept order: ${response.body}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on NetworkException catch (e) {
      NetworkService.showNetworkErrorSnackBar(context,
          customMessage: e.message);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<OrderData>> fetchOrdersFromApi({
    required int riderId,
    required int storeId,
    required int orderHeaderId,
    double? lat,
    double? lng,
  }) async {
    double? useLat = lat ?? testLat;
    double? useLng = lng ?? testLng;
    if (useLat == null || useLng == null) {
      // Get real location if not overridden
      final position = await DeviceService.getCurrentLocation(context);
      if (position != null) {
        useLat = position.latitude;
        useLng = position.longitude;
      } else {
        useLat = 0;
        useLng = 0;
      }
    } else {
    }
    final url = ApiConfig.apiUri('/getriderorders');
    final body = {
      'Lat': useLat,
      'Lng': useLng,
      'RiderId': riderId,
    };
    try {
      final response = await ApiClient.post(url,
          body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'});
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data is Map && data['OrderHeaders'] is List) {
          var fetchedOrders = (data['OrderHeaders'] as List)
              .map<OrderData>((json) => OrderData.fromJson(json))
              .toList();

          // Save to local DB
          if (orderHeaderId != 0) {
            // Only save the order matching the notification's orderHeaderId
            final match = data['OrderHeaders'].firstWhere(
              (o) => o['ServerHeaderId'] == orderHeaderId,
              orElse: () => null,
            );
            if (match != null) {
              await RiderOrdersDB.upsertOrder(orderHeaderId, jsonEncode(match));
            }
          } else {
            // Save all orders
            for (final order in fetchedOrders) {
              final orderJson = data['OrderHeaders'].firstWhere(
                  (o) => o['ServerHeaderId'] == order.serverHeaderId);
              await RiderOrdersDB.upsertOrder(
                  order.serverHeaderId, jsonEncode(orderJson));
            }
          }

          // If a specific order was requested, find it.
          if (orderHeaderId != 0) {
            fetchedOrders = fetchedOrders
                .where((order) => order.serverHeaderId == orderHeaderId)
                .toList();
          }

          return fetchedOrders;
        } else if (data is List) {
          return data
              .map<OrderData>((json) => OrderData.fromJson(json))
              .toList();
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          _pageTitles[_selectedIndex],
          style: const TextStyle(color: Color(0xFF5D8AA8)),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_isBalanceLow())
            _BalanceWarningBanner(
              balance: _balance,
              onTap: () {
                setState(() {
                  _selectedIndex = 1; // Navigate to Dashboard
                });
              },
            ),
          Expanded(
            child: Stack(
              children: [
                _selectedIndex == 0
                    ? DefaultTabController(
                        length: 3,
                        child: Column(
                          children: [
                            const TabBar(
                              labelColor: Color(0xFF5D8AA8),
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Color(0xFF5D8AA8),
                              tabs: [
                                Tab(text: 'Active'),
                                Tab(text: 'Cancelled'),
                                Tab(text: 'Completed'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  RefreshIndicator(
                                    onRefresh: () async => _loadInitialOrders(),
                                    child: _buildOrdersList(
                                      _orders
                                          .where((o) =>
                                              o.status != '8' &&
                                              o.status != '7')
                                          .toList(),
                                    ),
                                  ),
                                  RefreshIndicator(
                                    onRefresh: () async => _loadInitialOrders(),
                                    child: _buildOrdersList(
                                      _orders
                                          .where((o) => o.status == '8')
                                          .toList(),
                                      forceNoAccept: true,
                                    ),
                                  ),
                                  RefreshIndicator(
                                    onRefresh: () async => _loadInitialOrders(),
                                    child: _buildOrdersList(
                                      _orders
                                          .where((o) => o.status == '7')
                                          .toList(),
                                      forceNoAccept: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _selectedIndex == 1
                        ? const DashboardPage()
                        : const AccountPage(),
                // Loading overlay when accepting orders
                if (_isAcceptingOrder)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF5D8AA8),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Accepting order...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Please wait while we process your request',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF5D8AA8),
        onTap: _isAcceptingOrder ? null : _onItemTapped,
      ),
    );
  }

  Widget _buildEmptyOrdersState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delivery_dining_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Orders Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pull down to refresh or check back later for new delivery opportunities.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 32),
            // Removed manual refresh button; use pull-to-refresh instead
          ],
        ),
      ),
    );
  }

  // Build list for a given set of orders; optionally force hide Accept button
  Widget _buildOrdersList(List<OrderData> items, {bool forceNoAccept = false}) {
    if (items.isEmpty) return _buildEmptyOrdersState();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final order = items[index];
        final bool canShowAccept = !forceNoAccept &&
            !_acceptedOrderIds.contains(order.serverHeaderId) &&
            order.status != '8' &&
            order.status != '7';
        final bool isAcceptingThisOrder =
            _isAcceptingOrder && _acceptingOrderId == order.serverHeaderId;
        return _OrderCard(
          orderNumber: order.orderNumber,
          pickup: order.storeName,
          dropoff: order.customerAddress,
          orderTime: order.dateTimeCreated,
          storeImageUrl: order.storeImageUrl,
          deliveryFee: order.deliveryFee,
          subTotal: order.subTotal,
          showAccept: canShowAccept,
          isAccepting: isAcceptingThisOrder,
          orderStatusId: order.status,
          storeAddress: order.storeAddress,
          customerName: order.customerName,
          customerAddress: order.customerAddress,
          customerMobileNo: order.customerMobileNo,
          storeLat: order.storeLat,
          storeLng: order.storeLng,
          customerLat: order.customerLat,
          customerLng: order.customerLng,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailsPage(
                  order: order,
                  showAccept: canShowAccept,
                  onAccept: () async {
                    await _loadInitialOrders();
                  },
                ),
              ),
            );
          },
          onAccept: () async {
            if (_acceptedOrderIds.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'You already have an ongoing order. Please complete it before accepting a new one.')),
              );
              return;
            }
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Accept Job'),
                content:
                    const Text('Are you sure you want to accept this job?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Accept'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await _acceptOrderWithRaceConditionHandling(order);
            }
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderNumber;
  final String pickup;
  final String dropoff;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final String orderTime;
  final String storeImageUrl;
  final double deliveryFee;
  final double subTotal;
  final bool showAccept;
  final bool isAccepting;
  final String orderStatusId;
  final String storeAddress;
  final String customerName;
  final String customerAddress;
  final String customerMobileNo;
  final double storeLat;
  final double storeLng;
  final double customerLat;
  final double customerLng;

  const _OrderCard({
    required this.orderNumber,
    required this.pickup,
    required this.dropoff,
    required this.onTap,
    required this.onAccept,
    required this.orderTime,
    required this.storeImageUrl,
    required this.deliveryFee,
    required this.subTotal,
    required this.showAccept,
    this.isAccepting = false,
    required this.orderStatusId,
    required this.storeAddress,
    required this.customerName,
    required this.customerAddress,
    required this.customerMobileNo,
    required this.storeLat,
    required this.storeLng,
    required this.customerLat,
    required this.customerLng,
  });

  @override
  Widget build(BuildContext context) {
    // Fix store image URL if needed
    String imageUrl = storeImageUrl;
    if (imageUrl.isNotEmpty && imageUrl.startsWith('/')) {
      // Avoid double slashes
      imageUrl = ApiConfig.baseUrl +
          (imageUrl.startsWith('/') ? imageUrl : '/$imageUrl');
    }
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with order number, status, timer
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF5D8AA8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Order #$orderNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: getOrderStatusColor(orderStatusId)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            getOrderStatusLabel(orderStatusId),
                            style: TextStyle(
                              color: getOrderStatusColor(orderStatusId),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Text(
                  //   orderTime,
                  //   style: const TextStyle(
                  //     color: Colors.white,
                  //     fontWeight: FontWeight.bold,
                  //     fontSize: 14,
                  //   ),
                  // ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pickup image
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                        child: imageUrl.isEmpty
                            ? const Icon(
                                Icons.restaurant,
                                color: Color(0xFF5D8AA8),
                                size: 24,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickup,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            AddressButton(
                              address: storeAddress,
                              latitude: storeLat,
                              longitude: storeLng,
                              isCompact: true,
                            ),
                            const SizedBox(height: 2),
                            FutureBuilder<Position?>(
                              future: DeviceService.getCurrentLocation(context),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  final riderLat = snapshot.data!.latitude;
                                  final riderLng = snapshot.data!.longitude;

                                  // Debug logging

                                  // Validate coordinates
                                  if (riderLat == 0.0 && riderLng == 0.0) {
                                    return const Text(
                                      'Distance from you: Location unavailable',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }

                                  // Use FutureBuilder for async distance calculation
                                  return FutureBuilder<double>(
                                    future: RouteDistanceService
                                        .getDistanceWithFallback(
                                      originLat: riderLat,
                                      originLng: riderLng,
                                      destinationLat: storeLat,
                                      destinationLng: storeLng,
                                    ),
                                    builder: (context, distanceSnapshot) {
                                      if (distanceSnapshot.hasData) {
                                        final distance = distanceSnapshot.data!;


                                        if (distance < 0) {
                                          return const Text(
                                            'Distance from you: Invalid location',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        }

                                        return Text(
                                          'Distance from you: ${distance.toStringAsFixed(1)}KM',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      } else if (distanceSnapshot.hasError) {
                                        return const Text(
                                          'Distance from you: Calculation error',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      } else {
                                        return const Text(
                                          'Distance from you: Calculating route...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      }
                                    },
                                  );
                                }
                                if (snapshot.hasError) {
                                  return const Text(
                                    'Distance from you: Location error',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }
                                return const Text(
                                  'Distance from you: Calculating...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                    height: 28,
                    thickness: 1,
                    color: Color(0xFFE0E0E0),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.home,
                        color: Color(0xFF5D8AA8),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black.withOpacity(0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            AddressButton(
                              address: customerAddress,
                              latitude: customerLat,
                              longitude: customerLng,
                              isCompact: true,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              customerMobileNo,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            FutureBuilder<double>(
                              future:
                                  RouteDistanceService.getDistanceWithFallback(
                                originLat: storeLat,
                                originLng: storeLng,
                                destinationLat: customerLat,
                                destinationLng: customerLng,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  final distance = snapshot.data!;
                                  return Text(
                                    'Distance from store: ${distance.toStringAsFixed(1)}KM',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                } else if (snapshot.hasError) {
                                  return const Text(
                                    'Distance from store: Calculation error',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                } else {
                                  return const Text(
                                    'Distance from store: Calculating...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'Delivery Fee: ',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      Text(
                        NumberFormat.currency(locale: 'en_PH', symbol: '₱')
                            .format(deliveryFee),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'Sub Total: ',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      Text(
                        NumberFormat.currency(locale: 'en_PH', symbol: '₱')
                            .format(subTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (showAccept)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAccepting
                              ? const Color(0xFF5D8AA8).withOpacity(0.7)
                              : const Color(0xFF5D8AA8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                        onPressed: isAccepting ? null : onAccept,
                        child: isAccepting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'ACCEPTING...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'ACCEPT JOB',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  // Show "Unavailable" for cancelled orders
                  if (!showAccept && orderStatusId == '8')
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'UNAVAILABLE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryConfirmationSheet extends StatefulWidget {
  final VoidCallback onDelivered;
  const _DeliveryConfirmationSheet({required this.onDelivered});

  @override
  State<_DeliveryConfirmationSheet> createState() =>
      _DeliveryConfirmationSheetState();
}

class _DeliveryConfirmationSheetState
    extends State<_DeliveryConfirmationSheet> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorText;
  bool _showPin = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confirm Delivery',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D8AA8),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D8AA8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              // Placeholder for QR scan success
              widget.onDelivered();
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.pin),
            label: const Text('Enter PIN'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF5D8AA8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              setState(() {
                _showPin = !_showPin;
              });
            },
          ),
          if (_showPin) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4, // Changed from 6 to 4
              decoration: InputDecoration(
                labelText: 'Enter 4-digit PIN', // Changed from 6-digit
                errorText: _errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                if (_pinController.text == '123456') {
                  widget.onDelivered();
                } else {
                  setState(() {
                    _errorText = 'Invalid PIN';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Confirm Delivery'),
            ),
          ],
        ],
      ),
    );
  }
}

// Calculate distance between two coordinates using Haversine formula
double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  // Validate input coordinates
  if (lat1 == 0.0 && lng1 == 0.0) {
    return -1; // Return -1 to indicate invalid location
  }
  if (lat2 == 0.0 && lng2 == 0.0) {
    return -1; // Return -1 to indicate invalid location
  }

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

  final double distance = earthRadius * c;

  // Debug logging

  return distance;
}

// Move getOrderStatusLabel to top-level (outside any class)
String getOrderStatusLabel(String statusId) {
  switch (statusId) {
    case '0':
    case '1':
      return 'Pending';
    case '2':
      return 'Confirmed';
    case '3':
      return 'Preparing';
    case '4':
      return 'Ready';
    case '6':
      return 'In Transit';
    case '7':
      return 'Delivered';
    case '8':
      return 'Cancelled';
    default:
      return 'Unknown';
  }
}

Color getOrderStatusColor(String statusId) {
  switch (statusId) {
    case '0':
    case '1':
    case '2':
      return Colors.blue;
    case '3':
    case '4':
      return Colors.orange;
    case '6':
    case '7':
      return Colors.green;
    case '8':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

class _BalanceWarningBanner extends StatelessWidget {
  final double balance;
  final VoidCallback? onTap;

  const _BalanceWarningBanner({
    required this.balance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(
            color: Colors.orange.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Low balance: ₱${balance.toStringAsFixed(2)}. Please top up to continue.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Top Up',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
