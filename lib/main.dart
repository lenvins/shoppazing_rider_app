import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shoppazing_rider_app/services/in_app_update_service.dart';
import 'package:shoppazing_rider_app/services/version_service.dart';
import 'screens/phone_number_page.dart';
import 'screens/otp_page.dart';
import 'screens/registration_page.dart';
import 'screens/home_page.dart';
import 'screens/account_page.dart';
import 'screens/email_login_page.dart';
// import removed: enter_password_page
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/rider_orders_db.dart';
import 'services/device_service.dart';
import 'dart:convert';
import 'services/user_session_db.dart';
import 'dart:async';
import 'services/api_client.dart';
import 'services/api_config.dart';
import 'services/navigation_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Top-level function to fetch orders for background handler
Future<void> fetchOrdersInBackground({
  required int riderId,
  required int storeId,
  required int orderHeaderId,
  double? lat,
  double? lng,
}) async {
  double useLat = lat ?? 0;
  double useLng = lng ?? 0;
  // Optionally, you can try to get last known location here if needed
  final url = ApiConfig.apiUri('/getriderorders');
  final body = {
    'Lat': useLat,
    'Lng': useLng,
    'RiderId': riderId,
    'StoreId': storeId,
    'OrderHeaderId': orderHeaderId,
  };
  try {
    final response = await ApiClient.post(url,
        body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (data is Map && data['OrderHeaders'] is List) {
        var fetchedOrders = (data['OrderHeaders'] as List);
        if (orderHeaderId != 0) {
          final match = data['OrderHeaders'].firstWhere(
            (o) => o['ServerHeaderId'] == orderHeaderId,
            orElse: () => null,
          );
          if (match != null) {
            await RiderOrdersDB.upsertOrder(orderHeaderId, jsonEncode(match));
          }
        } else {
          for (final order in fetchedOrders) {
            await RiderOrdersDB.upsertOrder(
                int.tryParse(order['ServerHeaderId'].toString()) ?? 0,
                jsonEncode(order));
          }
        }
      }
    }
  } catch (e) {
  }
}

/// FCM background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.data.isNotEmpty &&
      message.data['EXTRA_ORDER_HEADER_ID'] != null) {
    final session = await UserSessionDB.getSession();
    final riderId = int.tryParse(session?['rider_id']?.toString() ?? '0') ?? 0;
    final storeId =
        int.tryParse(message.data['EXTRA_ORDER_STORE_ID']?.toString() ?? '0') ??
            0;
    final orderHeaderId = int.tryParse(
            message.data['EXTRA_ORDER_HEADER_ID']?.toString() ?? '0') ??
        0;
    await fetchOrdersInBackground(
      riderId: riderId,
      storeId: storeId,
      orderHeaderId: orderHeaderId,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Request notification permissions
  await _requestNotificationPermissions();

  // Initialize and test database
  try {
    final isDbAccessible = await UserSessionDB.isDatabaseAccessible();

    if (isDbAccessible) {
      await UserSessionDB.debugDatabaseInfo();
    }
  } catch (e) {
  }

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Debug print for foreground notifications and show local notification
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {

    // Show a local notification if present
    if (message.notification != null) {
      flutterLocalNotificationsPlugin.show(
        0,
        message.notification!.title,
        message.notification!.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel_id',
            'Default Channel',
            importance: Importance.defaultImportance,
          ),
        ),
      );
    }
    // Handle incoming order notification
    if (message.notification?.title == 'Incoming Order!' &&
        message.data.isNotEmpty) {
      await handleIncomingOrderNotification(message.data);
    } else {
    }
  });

  // Debug print for background notifications
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    if (message.notification?.title == 'Incoming Order!' &&
        message.data.isNotEmpty) {
      await handleIncomingOrderNotification(message.data);
    } else {
    }
  });

  // Debug print for notification that opened the app from terminated state
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    if (initialMessage.notification?.title == 'Incoming Order!' &&
        initialMessage.data.isNotEmpty) {
      await handleIncomingOrderNotification(initialMessage.data);
    } else {
    }
  }

  runApp(const MyApp());
}

/// Request notification permissions
Future<void> _requestNotificationPermissions() async {
  try {
    // Request permission for iOS
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );


    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
    } else {
    }
  } catch (e) {
  }
}

Future<void> handleIncomingOrderNotification(Map<String, dynamic> data) async {
  // Extract needed fields from notification data
  try {
    final session = await UserSessionDB.getSession();
    final riderId = int.tryParse(session?['rider_id']?.toString() ?? '0') ?? 0;
    final storeId =
        int.tryParse(data['EXTRA_ORDER_STORE_ID']?.toString() ?? '0') ?? 0;
    final orderHeaderId =
        int.tryParse(data['EXTRA_ORDER_HEADER_ID']?.toString() ?? '0') ?? 0;

    // Use the global key to access HomePage state
    final homeState = HomePage.getState();
    if (homeState != null) {
      await homeState.fetchOrdersFromApi(
        riderId: riderId,
        storeId: storeId,
        orderHeaderId: orderHeaderId,
      );
    } else {
    }
  } catch (e) {
  }
}

class StartupPage extends StatefulWidget {
  const StartupPage({Key? key}) : super(key: key);

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  bool _hasCheckedSession = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedSession) {
      _hasCheckedSession = true;
      // Add a small delay to ensure the widget tree is fully built
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _checkSession();
        }
      });
    }
  }

  Future<void> _checkSession() async {
    try {
      // Run session diagnosis
      await UserSessionDB.diagnoseSessionIssues();

      // 1) Check for in-app updates first
      final startedUpdate =
          await InAppUpdateService().requireImmediateUpdateIfAvailable();
      if (startedUpdate) {
        return;
      }

      // 2) Fallback: Firestore-based force-update (if configured and permitted)
      final versionService = VersionService();
      final result = await versionService.checkForForceUpdate();
      if (result.required) {
        _showForceUpdateDialog(result);
        return;
      }

      // Get valid session (this will automatically clear invalid ones)
      final session = await UserSessionDB.getValidSession();

      if (session == null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/phone_number');
        return;
      }

      // Post device token for auto-login
      final userId =
          session['user_id']?.toString() ?? session['userId']?.toString() ?? '';
      if (userId.isNotEmpty) {
        await DeviceService.updateDeviceInfo(userId, context);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      // On error, redirect to login
      Navigator.of(context).pushReplacementNamed('/phone_number');
    }
  }

  void _showForceUpdateDialog(dynamic result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Required'),
          content: Text(
            result.message ??
                'A new version of the app is available. Please update to continue.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // Open app store or Play Store
                // You can use url_launcher or platform channels to open the store
                // For now, just close the dialog and show a message
                Navigator.of(context).pop();
              },
              child: const Text('Update Now'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App came to foreground, post device token
      _postDeviceTokenOnResume();
    }
  }

  Future<void> _postDeviceTokenOnResume() async {
    try {
      final session = await UserSessionDB.getSession();
      final userId = session?['user_id']?.toString() ??
          session?['userId']?.toString() ??
          '';
      if (userId.isNotEmpty) {
        await DeviceService.updateDeviceInfo(
            userId, navigatorKey.currentContext!);
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shoppazing Rider App',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      theme: ThemeData(
        primaryColor: const Color(0xFF5D8AA8),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5D8AA8),
          primary: const Color(0xFF5D8AA8),
          secondary: const Color(0xFF5D8AA8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5D8AA8),
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF5D8AA8)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF5D8AA8),
          elevation: 0,
        ),
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const StartupPage(),
        '/phone_number': (context) => const PhoneNumberPage(),
        '/otp': (context) => const OtpPage(),
        '/register': (context) => const RegistrationPage(),
        '/home': (context) => HomePage(key: HomePage.globalKey),
        '/account': (context) => const AccountPage(),
        '/email_login': (context) => const EmailLoginPage(),
      },
    );
  }
}
