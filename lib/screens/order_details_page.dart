import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shoppazing_rider_app/services/api_config.dart';
import 'package:shoppazing_rider_app/widgets/mobilephone_button.dart';
import 'chat_page.dart';
import 'home_page.dart'; // For OrderData
import '../services/api_client.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/rider_orders_db.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/user_session_db.dart';
import '../widgets/address_button.dart';

class OrderDetailsPage extends StatefulWidget {
  final OrderData order;
  final bool showAccept;
  final VoidCallback? onAccept;

  const OrderDetailsPage({
    Key? key,
    required this.order,
    this.showAccept = false,
    this.onAccept,
  }) : super(key: key);

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  bool _isAccepting = false;
  String? _error;
  bool _accepted = false;
  String? _userId;
  bool _delivered = false;
  bool _isCancelling = false;
  Timer? _autoRefreshTimer;

  // Keep a live copy of the order that can be updated by auto-refresh
  OrderData? _currentOrder;

  final TextEditingController _pinController = TextEditingController();
  String? _pinError;
  bool _isSubmittingPickupPin = false;

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
  void initState() {
    super.initState();
    _loadUserId();
    _currentOrder = widget.order;
    _startAutoRefresh();
  }

  Future<void> _loadUserId() async {
    final session = await UserSessionDB.getSession();
    setState(() {
      _userId = session?['user_id'];
    });
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final session = await UserSessionDB.getSession();
        final riderId = int.tryParse(session?['rider_id']?.toString() ??
                session?['riderId']?.toString() ??
                '0') ??
            0;
        if (riderId <= 0) return;
        final homeState = HomePage.getState();
        if (homeState == null) return;
        final results = await homeState.fetchOrdersFromApi(
          riderId: riderId,
          storeId: 0,
          orderHeaderId: widget.order.serverHeaderId,
        );
        if (results.isNotEmpty) {
          final latest = results.first;
          // If status or assignment changed, update UI
          if (!mounted) return;
          setState(() {
            _currentOrder = latest;
          });
        }
      } catch (_) {
        // Silent fail for background refresh
      }
    });
  }

  Future<void> _acceptOrder() async {
    setState(() {
      _isAccepting = true;
      _error = null;
    });

    try {
      // Use the same race condition handling as the main page
      await HomePage.getState()
          ?.acceptOrderWithRaceConditionHandling(widget.order);

      // Check if the order was successfully accepted by checking the current state
      final homeState = HomePage.getState();
      if (homeState != null) {
        final isAccepted =
            homeState.acceptedOrderIds.contains(widget.order.serverHeaderId) ||
                (widget.order.assignedTo != null &&
                    _userId != null &&
                    widget.order.assignedTo == _userId);

        if (isAccepted) {
          setState(() {
            _isAccepting = false;
            _accepted = true;
          });
        } else {
          setState(() {
            _isAccepting = false;
            _error = 'Order acceptance failed. Please try again.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isAccepting = false;
      });
    }
  }

  Future<void> _showDeliveredPinDialog() async {
    _pinController.clear();
    _pinError = null;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Delivery PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4, // Changed from 6 to 4
                decoration: InputDecoration(
                  labelText: 'Enter 4-digit PIN', // Changed from 6-digit
                  errorText: _pinError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _submitDeliveredPin();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPickupPinDialog() async {
    _pinController.clear();
    _pinError = null;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Pickup PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Enter 4-digit PIN',
                  errorText: _pinError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isSubmittingPickupPin
                  ? null
                  : () {
                      Navigator.of(context).pop();
                    },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSubmittingPickupPin ? null : _submitPickupPin,
              child: _isSubmittingPickupPin
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitPickupPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() {
        _pinError = 'PIN must be 4 digits';
      });
      return;
    }

    setState(() {
      _pinError = null;
      _isSubmittingPickupPin = true;
    });

    try {
      final order = _currentOrder ?? widget.order;
      final session = await UserSessionDB.getSession();
      final userId = session?['user_id']?.toString() ?? '';
      if (userId.isEmpty) {
        throw Exception('Unable to find user session. Please log in again.');
      }

      final url = ApiConfig.apiUri('/PostPickupOrderByPIN');
      final body = <String, dynamic>{
        'OrderNo': order.orderNumber,
        'UserId': userId,
        'PaidByCash': false,
        'IsPaid': order.isPaid,
        'IsPickup': false,
        'OrderPIN': pin,
      };

      final response = await ApiClient.post(
        url,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

      final responseData = jsonDecode(response.body);

      debugPrint('response: ${response.body}');

      if (responseData['status_code'] == 200) {
        if (!mounted) return;

        // Best-effort immediate UI update; auto-refresh will reconcile.
        setState(() {
          _currentOrder = OrderData(
            serverHeaderId: order.serverHeaderId,
            orderNumber: order.orderNumber,
            status: '6', // In Transit
            dateTimeCreated: order.dateTimeCreated,
            storeName: order.storeName,
            storeImageUrl: order.storeImageUrl,
            storeAddress: order.storeAddress,
            customerName: order.customerName,
            customerAddress: order.customerAddress,
            customerMobileNo: order.customerMobileNo,
            storeLat: order.storeLat,
            storeLng: order.storeLng,
            customerLat: order.customerLat,
            customerLng: order.customerLng,
            deliveryFee: order.deliveryFee,
            onlineServiceCharge: order.onlineServiceCharge,
            subTotal: order.subTotal,
            totalDue: order.totalDue,
            rawDetails: order.rawDetails,
            assignedTo: order.assignedTo,
            OtherChatUserFirebaseUID: order.OtherChatUserFirebaseUID,
            OtherChatUserName: order.OtherChatUserName,
            OtherChatUserId: order.OtherChatUserId,
            customerPin: order.customerPin,
            isPaid: order.isPaid,
            isManualDelivered: order.isManualDelivered,
            isOrderRated: order.isOrderRated,
            paymentTypeId: order.paymentTypeId,
            onlinePaymentTypeId: order.onlinePaymentTypeId,
            useLoyaltyPoints: order.useLoyaltyPoints,
            saleHeaderId: order.saleHeaderId,
            redeemedCash: order.redeemedCash,
            dfDiscount: order.dfDiscount,
            riderProfilePic: order.riderProfilePic,
            riderFullName: order.riderFullName,
            riderPlateNo: order.riderPlateNo,
            riderDriversLicenseNo: order.riderDriversLicenseNo,
            riderUserId: order.riderUserId,
            riderLat: order.riderLat,
            riderLng: order.riderLng,
          );
          _isSubmittingPickupPin = false;
        });

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order picked up successfully.')),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _isSubmittingPickupPin = false;
          _pinError = 'Wrong PIN';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingPickupPin = false;
        _pinError = 'Error: $e';
      });
    }
  }

  Future<void> _submitDeliveredPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      // Changed from 6 to 4
      setState(() {
        _pinError = 'PIN must be 4 digits'; // Changed from 6 digits
      });
      return;
    }
    setState(() {
      _pinError = null;
    });
    final session = await UserSessionDB.getSession();
    final userId = session?['user_id'] ?? '';
    final url = ApiConfig.apiUri('/postdeliverorder');
    final body = {
      'OrderNo': (_currentOrder ?? widget.order).orderNumber,
      'OrderHeaderId': (_currentOrder ?? widget.order).serverHeaderId,
      'UserId': userId,
      'PIN': pin,
      'DeliveryFee': (_currentOrder ?? widget.order).deliveryFee,
      'TotalAmount':
          _calculateTotalWithModifiers(_currentOrder ?? widget.order) +
              (_currentOrder ?? widget.order)
                  .onlineServiceCharge + // Use API value
              (_currentOrder ?? widget.order).deliveryFee,
    };
    try {
      final response = await ApiClient.post(url,
          body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success: mark as delivered, allow accepting new orders
        setState(() {
          _delivered = true;
        });
        // Clear accepted state and keep order as completed in local DB
        await RiderOrdersDB.cancelAcceptedOrder(
            (_currentOrder ?? widget.order).serverHeaderId);
        HomePage.getState()?.cancelOrder();

        final Map<String, dynamic> updated = {
          'ServerHeaderId': (_currentOrder ?? widget.order).serverHeaderId,
          'OrderNo': (_currentOrder ?? widget.order).orderNumber,
          'OrderStatusId': '7',
          'OrderDate': DateTime.now().toIso8601String(),
          'StoreName': (_currentOrder ?? widget.order).storeName,
          'StoreImageUrl': (_currentOrder ?? widget.order).storeImageUrl,
          'StoreAddress': (_currentOrder ?? widget.order).storeAddress,
          'CustomerName': (_currentOrder ?? widget.order).customerName,
          'CustomerAddressLine1':
              (_currentOrder ?? widget.order).customerAddress,
          'CustomerMobileNo': (_currentOrder ?? widget.order).customerMobileNo,
          'StoreLat': (_currentOrder ?? widget.order).storeLat,
          'StoreLng': (_currentOrder ?? widget.order).storeLng,
          'CustomerLAT': (_currentOrder ?? widget.order).customerLat,
          'CustomerLNG': (_currentOrder ?? widget.order).customerLng,
          'DeliveryFee': (_currentOrder ?? widget.order).deliveryFee,
          'SubTotal': (_currentOrder ?? widget.order).subTotal,
          'TotalDue': (_currentOrder ?? widget.order).totalDue,
          'OrderDetails': (_currentOrder ?? widget.order).rawDetails,
          'AssignedTo': null,
          'OtherChatUserFirebaseUID':
              (_currentOrder ?? widget.order).OtherChatUserFirebaseUID,
          'OtherChatUserName':
              (_currentOrder ?? widget.order).OtherChatUserName,
        };
        await RiderOrdersDB.upsertOrder(
            (_currentOrder ?? widget.order).serverHeaderId,
            jsonEncode(updated));

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order marked as delivered!')));
      } else {
        setState(() {
          _pinError = 'Wrong PIN';
        });
      }
    } catch (e) {
      setState(() {
        _pinError = 'Error: $e';
      });
    }
  }

  Future<void> _showCancelOrderDialog() async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          String? errorText;
          return AlertDialog(
            title: const Text('Cancel Order'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please let us know why you are cancelling this order.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Cancel Reason',
                    hintText: 'Describe the issue or reason',
                    errorText: errorText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isCancelling
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                child: const Text('Keep Order'),
              ),
              ElevatedButton(
                onPressed: _isCancelling
                    ? null
                    : () {
                        final reason = reasonController.text.trim();
                        if (reason.isEmpty) {
                          setStateDialog(() {
                            errorText = 'Please enter a cancel reason.';
                          });
                          return;
                        }
                        reasonController.dispose();
                        Navigator.of(context).pop(reason);
                      },
                child: const Text('Cancel Order'),
              ),
            ],
          );
        });
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      await _cancelOrder(result.trim());
    } else {
      reasonController.dispose();
    }
  }

  Future<void> _cancelOrder(String reason) async {
    final order = _currentOrder ?? widget.order;
    debugPrint(
        '[CANCEL_ORDER] start orderHeaderId=${order.serverHeaderId} orderNo=${order.orderNumber} reason="$reason"');
    setState(() {
      _isCancelling = true;
      _error = null;
    });

    try {
      debugPrint('[CANCEL_ORDER] reading session...');
      final session = await UserSessionDB.getSession();
      final userId = session?['user_id']?.toString() ?? '';
      debugPrint(
          '[CANCEL_ORDER] session userId="$userId" (empty=${userId.isEmpty})');

      if (userId.isEmpty) {
        throw Exception('Unable to find user session. Please log in again.');
      }

      // ApiConfig.apiUri() already prepends `/api/shop`
      final url = ApiConfig.apiUri('/postcancelriderorder');
      debugPrint('[CANCEL_ORDER] url=$url');

      final payload = {
        'OrderHeaderId': order.serverHeaderId,
        'UserId': userId,
        'CancelReason': reason,
      };
      debugPrint('[CANCEL_ORDER] payload=${jsonEncode(payload)}');

      debugPrint('[CANCEL_ORDER] sending request...');
      final response = await ApiClient.post(
        url,
        body: jsonEncode(payload),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint('[CANCEL_ORDER] response http_status=${response.statusCode}');
      debugPrint('[CANCEL_ORDER] response body=${response.body}');

      // If HTTP request was not successful, handle it as a primary error
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String errorMessage = 'Failed to cancel order.';
        try {
          // Try to parse for a more specific server message, but don't require it
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded.containsKey('message')) {
            errorMessage = decoded['message'];
          } else {
            errorMessage = response.body;
          }
        } catch (_) {
          // If body is not JSON, use the reason phrase or the raw body
          errorMessage = response.reasonPhrase ?? response.body;
        }
        throw Exception(errorMessage);
      }

      // If HTTP is OK, then parse the custom status code from the body
      dynamic responseData;
      int customStatusCode = 400;
      String message = 'Unknown error';

      try {
        responseData = jsonDecode(response.body);
        if (responseData is Map) {
          customStatusCode = responseData['status_code'] ?? 400;
          message = responseData['message'] ?? 'Unknown error';
          debugPrint(
              '[CANCEL_ORDER] parsed custom status_code=$customStatusCode, message=$message');
        }
      } catch (e) {
        debugPrint('[CANCEL_ORDER] failed to parse response body: $e');
        // Even if HTTP was 200, the body might be malformed.
        throw Exception(
            'Successfully sent request, but failed to understand server response.');
      }

      // Check the custom status_code from the response body
      if (customStatusCode == 200) {
        debugPrint('[CANCEL_ORDER] success -> updating local DB/UI state');
        await RiderOrdersDB.cancelAcceptedOrder(order.serverHeaderId);
        HomePage.getState()?.cancelOrder();
        if (!mounted) return;
        setState(() {
          _isCancelling = false;
          _accepted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully.')),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        debugPrint('[CANCEL_ORDER] done');
      } else {
        debugPrint(
            '[CANCEL_ORDER] error from server: status_code=$customStatusCode, message=$message');
        throw Exception('Failed to cancel order: $message');
      }
    } catch (e, st) {
      debugPrint('[CANCEL_ORDER] error=$e');
      debugPrint('[CANCEL_ORDER] stackTrace=$st');
      if (!mounted) return;
      setState(() {
        _isCancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder ?? widget.order;
    final acceptedOrderIds = HomePage.getState()?.acceptedOrderIds ?? {};
    final userId = _userId;
    final isAccepted = acceptedOrderIds.contains(order.serverHeaderId) ||
        _accepted ||
        (order.assignedTo != null &&
            userId != null &&
            order.assignedTo == userId);
    String qrData = '';
    if (isAccepted &&
        userId != null &&
        userId.isNotEmpty &&
        (order.status.toString() == '4' ||
            getOrderStatusLabel(order.status) == 'Ready')) {
      qrData = widget.order.orderNumber + '_' + userId;
    }

    // Show loading indicator if userId is not loaded yet
    if (userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final showAccept = widget.showAccept && !_accepted && !isAccepted;
    final showDeliveredButton =
        isAccepted && order.status == '6' && !_delivered;
    final showPickupByPinButton = isAccepted &&
        (order.status.toString() == '4' ||
            getOrderStatusLabel(order.status) == 'Ready');
    // Generate QR code data if accepted and status is '4' or 'Ready'
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Number: ${order.orderNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Order Date: ${order.dateTimeCreated}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Store: ${order.storeName}'),
            const SizedBox(height: 12),
            AddressButton(
              label: 'Store Address',
              address: order.storeAddress,
              latitude: order.storeLat,
              longitude: order.storeLng,
            ),
            const SizedBox(height: 12),
            Text('Customer: ${order.customerName}'),
            Row(children: [
              Text('Mobile: '),
              MobilePhoneButton(mobileNumber: order.customerMobileNo),
            ],),
            const SizedBox(height: 12),
            AddressButton(
              label: 'Customer Address',
              address: order.customerAddress,
              latitude: order.customerLat,
              longitude: order.customerLng,
            ),
            Divider(height: 32),
            Row(
              children: [
                const Text('Status: '),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: getOrderStatusColor(order.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    getOrderStatusLabel(order.status),
                    style: TextStyle(
                      color: getOrderStatusColor(order.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Order Items:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _OrderItemsTable(order: order),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SubTotal:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(NumberFormat.currency(locale: 'en_PH', symbol: '₱')
                    .format(order.subTotal)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Convenience Fee:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(NumberFormat.currency(locale: 'en_PH', symbol: '₱')
                    .format(order.onlineServiceCharge)), // Use API value
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Delivery Fee:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(NumberFormat.currency(locale: 'en_PH', symbol: '₱')
                    .format(order.deliveryFee)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(
                    order.subTotal +
                        _calculateConvenienceFee(order) +
                        order.deliveryFee)),
              ],
            ),
            SizedBox(
              height: 20,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (showAccept)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAccepting
                      ? null
                      : () async {
                          // Prevent accepting if already have an ongoing order
                          final acceptedOrder =
                              HomePage.getState()?.acceptedOrder;
                          if (acceptedOrder != null &&
                              (acceptedOrder.assignedTo != null &&
                                  _userId != null &&
                                  acceptedOrder.assignedTo == _userId)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'You already have an ongoing order. Please complete it before accepting a new one.'),
                              ),
                            );
                            return;
                          }
                          await _acceptOrder();
                        },
                  child: _isAccepting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Accept Job'),
                ),
              ),
            if (showDeliveredButton)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _showDeliveredPinDialog,
                ),
              ),
            SizedBox(height: 12),
            if (isAccepted && int.parse(order.status) < 6)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _isCancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel, color: Colors.red),
                  label: Text(
                    _isCancelling ? 'Cancelling...' : 'Cancel Order',
                    style: TextStyle(
                      color: _isCancelling ? Colors.red.shade300 : Colors.red,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isCancelling ? null : _showCancelOrderDialog,
                ),
              ),
            SizedBox(height: 12),
            if (_delivered)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Delivered!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            if (isAccepted && qrData.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(
                child: QrImageView(
                  data: qrData,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text('Show this QR code for order validation')),
            ],
            if (showPickupByPinButton) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.pin),
                  label: const Text('Pickup via PIN'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF5D8AA8)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _showPickupPinDialog,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isAccepted && order.status != '8' && order.status != '7') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat, color: Colors.white),
                  label: const Text('Chat with Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF5D8AA8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final customerUID = order.OtherChatUserFirebaseUID;
                    final customerUserId = order.OtherChatUserId;
                    final customerName = order.OtherChatUserName;
                    if (customerUID != null &&
                        customerUID.isNotEmpty &&
                        customerName != null &&
                        customerName.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            orderId: order.serverHeaderId.toString(),
                            customerFirebaseUID: customerUID,
                            customerName: customerName,
                            customerUserId: customerUserId,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Chat is not available: missing customer information.')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }
}

class _OrderItemsTable extends StatelessWidget {
  final OrderData order;
  const _OrderItemsTable({required this.order});

  @override
  Widget build(BuildContext context) {
    final details = (order as dynamic).rawDetails ?? [];
    if (details.isEmpty) {
      return const Text('No items found.');
    }
    return Column(
      children: details.map<Widget>((item) {
        final String itemName = item['ItemName']?.toString() ?? 'N/A';
        final String combiName = item['CombiName']?.toString() ?? '';
        final String mergedName =
            combiName.isNotEmpty ? (itemName + ' - ' + combiName) : itemName;
        final String qty = _formatQty(item['Qty']);
        final String unitPrice = NumberFormat.currency(
          locale: 'en_PH',
          symbol: '₱',
        ).format(item['UnitPrice'] ?? 0);

        final modifiers = _extractModifiers(item);

        final Widget headerRow = Row(
          children: [
            _QtyChip(text: qty),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mergedName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              unitPrice,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        );

        if (modifiers.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: (Colors.grey[300])!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: headerRow,
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border.all(color: (Colors.grey[300])!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              title: headerRow,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: modifiers.map<Widget>((mod) {
                    final String optionName = _readModifierValue(
                      mod,
                      'ModifierOptionName',
                    );
                    final String modifierName = _readModifierValue(
                      mod,
                      'ModifierName',
                    );
                    final double modifierPrice = _readModifierPrice(mod);

                    final List<Widget> lines = [];
                    if (optionName.isNotEmpty) {
                      lines.add(Text(optionName));
                    }
                    if (modifierName.isNotEmpty) {
                      if (lines.isNotEmpty)
                        lines.add(const SizedBox(height: 2));
                      lines.add(Text(modifierName));
                    }
                    if (lines.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: lines,
                            ),
                          ),
                          if (modifierPrice > 0)
                            Text(
                              NumberFormat.currency(
                                      locale: 'en_PH', symbol: '₱')
                                  .format(modifierPrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatQty(dynamic qty) {
    if (qty == null) return '';
    if (qty is int) return qty.toString();
    if (qty is double) {
      final intPart = qty.truncate();
      if (qty == intPart.toDouble()) return intPart.toString();
      return qty.toString();
    }
    final parsed = double.tryParse(qty.toString());
    if (parsed != null) {
      final intPart = parsed.truncate();
      if (parsed == intPart.toDouble()) return intPart.toString();
      return parsed.toString();
    }
    return qty.toString();
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
}

class _QtyChip extends StatelessWidget {
  final String text;
  const _QtyChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF5D8AA8).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF5D8AA8)),
      ),
      child: Text(
        'Qty: ' + text,
        style: const TextStyle(
          color: Color(0xFF5D8AA8),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
