import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
// import removed: http
import 'api_client.dart';
import 'dart:convert';
import 'api_config.dart';

class RiderOrdersDB {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rider_orders.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE rider_orders (
            orderHeaderId INTEGER PRIMARY KEY,
            orderJson TEXT NOT NULL,
            isDeleted INTEGER DEFAULT 0,
            endpoint TEXT NOT NULL DEFAULT 'test'
          )
        ''');
        await db.execute('''
          CREATE TABLE accepted_orders (
            orderHeaderId INTEGER PRIMARY KEY,
            endpoint TEXT NOT NULL DEFAULT 'test'
          )
        ''');
        await db.execute('''
          CREATE TABLE load_transactions (
            id TEXT PRIMARY KEY,
            dateLoaded TEXT,
            amount REAL,
            remarks TEXT,
            referenceNo TEXT,
            isConfirmed INTEGER DEFAULT 0,
            lastUpdated TEXT,
            endpoint TEXT NOT NULL DEFAULT 'test'
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS accepted_orders (
              orderHeaderId INTEGER PRIMARY KEY,
              endpoint TEXT NOT NULL DEFAULT 'test'
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS load_transactions (
              id TEXT PRIMARY KEY,
              dateLoaded TEXT,
              amount REAL,
              remarks TEXT,
              referenceNo TEXT,
              isConfirmed INTEGER DEFAULT 0,
              lastUpdated TEXT,
              endpoint TEXT NOT NULL DEFAULT 'test'
            )
          ''');
        }
        if (oldVersion < 4) {
          // Add endpoint column to existing tables
          await db.execute('''
            ALTER TABLE rider_orders ADD COLUMN endpoint TEXT NOT NULL DEFAULT 'test'
          ''');
          await db.execute('''
            ALTER TABLE accepted_orders ADD COLUMN endpoint TEXT NOT NULL DEFAULT 'test'
          ''');
          await db.execute('''
            ALTER TABLE load_transactions ADD COLUMN endpoint TEXT NOT NULL DEFAULT 'test'
          ''');
        }
      },
    );
  }

  static Future<void> upsertOrder(int orderHeaderId, String orderJson) async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    await db.insert(
      'rider_orders',
      {
        'orderHeaderId': orderHeaderId,
        'orderJson': orderJson,
        'isDeleted': 0,
        'endpoint': endpoint,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> markOrderDeleted(int orderHeaderId) async {
    final db = await database;
    await db.update(
      'rider_orders',
      {'isDeleted': 1},
      where: 'orderHeaderId = ?',
      whereArgs: [orderHeaderId],
    );
  }

  static Future<List<Map<String, dynamic>>> getAllActiveOrders() async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    return await db.query(
      'rider_orders',
      where: 'isDeleted = 0 AND endpoint = ?',
      whereArgs: [endpoint],
    );
  }

  static Future<void> clear() async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    await db.delete(
      'rider_orders',
      where: 'endpoint = ?',
      whereArgs: [endpoint],
    );
  }

  /// Clear all local data for current endpoint
  static Future<void> clearCurrentEndpointData() async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    await db.delete(
      'rider_orders',
      where: 'endpoint = ?',
      whereArgs: [endpoint],
    );
    await db.delete(
      'accepted_orders',
      where: 'endpoint = ?',
      whereArgs: [endpoint],
    );
    await db.delete(
      'load_transactions',
      where: 'endpoint = ?',
      whereArgs: [endpoint],
    );
    print('[DEBUG] Local data cleared for endpoint: $endpoint');
  }

  /// Clear all local data including orders, accepted orders, and load transactions (ALL endpoints)
  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('rider_orders');
    await db.delete('accepted_orders');
    await db.delete('load_transactions');
    print('[DEBUG] All local data cleared from database');
  }

  // Accepted orders methods
  static Future<void> addAcceptedOrder(int orderHeaderId) async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    await db.insert(
        'accepted_orders',
        {
          'orderHeaderId': orderHeaderId,
          'endpoint': endpoint,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<bool> isOrderAccepted(int orderHeaderId) async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    final result = await db.query('accepted_orders',
        where: 'orderHeaderId = ? AND endpoint = ?',
        whereArgs: [orderHeaderId, endpoint],
        limit: 1);
    return result.isNotEmpty;
  }

  static Future<List<int>> getAllAcceptedOrderIds() async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    final result = await db
        .query('accepted_orders', where: 'endpoint = ?', whereArgs: [endpoint]);
    return result.map((row) => row['orderHeaderId'] as int).toList();
  }

  static Future<void> clearAcceptedOrders() async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    await db.delete('accepted_orders',
        where: 'endpoint = ?', whereArgs: [endpoint]);
  }

  static Future<void> removeOrder(int orderHeaderId) async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    // Remove from rider_orders table
    await db.delete(
      'rider_orders',
      where: 'orderHeaderId = ? AND endpoint = ?',
      whereArgs: [orderHeaderId, endpoint],
    );
    // Remove from accepted_orders table
    await db.delete(
      'accepted_orders',
      where: 'orderHeaderId = ? AND endpoint = ?',
      whereArgs: [orderHeaderId, endpoint],
    );
  }

  // New method to handle order cancellation
  static Future<void> cancelAcceptedOrder(int orderHeaderId) async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    print('[DEBUG] Cancelling accepted order: $orderHeaderId');

    // Remove from accepted_orders table only (keep in rider_orders for history)
    final result = await db.delete(
      'accepted_orders',
      where: 'orderHeaderId = ? AND endpoint = ?',
      whereArgs: [orderHeaderId, endpoint],
    );

    if (result > 0) {
      print('[DEBUG] Successfully cancelled accepted order: $orderHeaderId');
    } else {
      print('[DEBUG] Order was not in accepted_orders table: $orderHeaderId');
    }
  }

  // Method to check if rider has any accepted orders
  static Future<bool> hasAcceptedOrders() async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    final result = await db.query('accepted_orders',
        where: 'endpoint = ?', whereArgs: [endpoint], limit: 1);
    return result.isNotEmpty;
  }

  // Method to get the currently accepted order ID (if any)
  static Future<int?> getCurrentAcceptedOrderId() async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    final result = await db.query('accepted_orders',
        where: 'endpoint = ?', whereArgs: [endpoint], limit: 1);
    if (result.isNotEmpty) {
      return result.first['orderHeaderId'] as int;
    }
    return null;
  }

  // Load transaction history methods
  static Future<void> saveLoadTransactions(List<dynamic> transactions) async {
    final db = await database;
    final batch = db.batch();
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';

    print('[DEBUG] Saving ${transactions.length} transactions to database');

    for (final tx in transactions) {
      print('[DEBUG] Processing transaction: $tx');
      print('[DEBUG] Transaction keys: ${tx.keys.toList()}');

      // Try to find the correct field names by checking multiple possibilities
      final id = tx['Id'] ?? tx['id'] ?? tx['ID'] ?? '';
      final dateLoaded = tx['DateLoaded'] ??
          tx['dateLoaded'] ??
          tx['Date'] ??
          tx['date'] ??
          '';
      final amount = tx['Amount'] ?? tx['amount'] ?? 0.0;
      final remarks =
          tx['Remarks'] ?? tx['remarks'] ?? tx['Remark'] ?? tx['remark'] ?? '';
      final referenceNo = tx['ReferrenceNo'] ??
          tx['ReferenceNo'] ??
          tx['referenceNo'] ??
          tx['RefNo'] ??
          tx['refNo'] ??
          tx['Reference'] ??
          tx['reference'] ??
          '';
      final isConfirmed = tx['IsConfirmed'] ??
          tx['isConfirmed'] ??
          tx['Confirmed'] ??
          tx['confirmed'] ??
          false;

      print('[DEBUG] Extracted fields:');
      print('[DEBUG]   id: $id (from ${tx['Id'] ?? tx['id'] ?? tx['ID']})');
      print(
          '[DEBUG]   dateLoaded: $dateLoaded (from ${tx['DateLoaded'] ?? tx['dateLoaded'] ?? tx['Date'] ?? tx['date']})');
      print('[DEBUG]   amount: $amount (from ${tx['Amount'] ?? tx['amount']})');
      print(
          '[DEBUG]   remarks: $remarks (from ${tx['Remarks'] ?? tx['remarks'] ?? tx['Remark'] ?? tx['remark']})');
      print(
          '[DEBUG]   referenceNo: $referenceNo (from ${tx['ReferrenceNo'] ?? tx['ReferenceNo'] ?? tx['referenceNo'] ?? tx['RefNo'] ?? tx['refNo'] ?? tx['Reference'] ?? tx['reference']})');
      print(
          '[DEBUG]   isConfirmed: $isConfirmed (from ${tx['IsConfirmed'] ?? tx['isConfirmed'] ?? tx['Confirmed'] ?? tx['confirmed']})');

      // Skip transactions with missing essential data
      if (id.toString().isEmpty || referenceNo.toString().isEmpty) {
        print(
            '[DEBUG] Skipping transaction with missing essential data: id=$id, referenceNo=$referenceNo');
        continue;
      }

      final transactionData = {
        'id': id.toString(),
        'dateLoaded': dateLoaded.toString(),
        'amount':
            amount is num ? amount : double.tryParse(amount.toString()) ?? 0.0,
        'remarks': remarks.toString(),
        'referenceNo': referenceNo.toString(),
        'isConfirmed':
            (isConfirmed == true || isConfirmed == 'true' || isConfirmed == 1)
                ? 1
                : 0,
        'lastUpdated': DateTime.now().toIso8601String(),
        'endpoint': endpoint,
      };

      print('[DEBUG] Mapped transaction data: $transactionData');

      batch.insert(
        'load_transactions',
        transactionData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    try {
      await batch.commit(noResult: true);
      print(
          '[DEBUG] Successfully saved ${transactions.length} transactions to database');
    } catch (e) {
      print('[ERROR] Failed to save transactions to database: $e');
      throw Exception('Failed to save transactions to database: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getLoadTransactions() async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    try {
      final result = await db.query(
        'load_transactions',
        where: 'endpoint = ?',
        whereArgs: [endpoint],
        orderBy: 'dateLoaded DESC',
      );
      print('[DEBUG] Retrieved ${result.length} transactions from database');
      if (result.isNotEmpty) {
        print('[DEBUG] Sample transaction: ${result.first}');
        print('[DEBUG] Sample transaction keys: ${result.first.keys.toList()}');
        print(
            '[DEBUG] Sample transaction values: ${result.first.values.toList()}');
      } else {
        print('[DEBUG] No transactions found in database');
      }
      return result;
    } catch (e) {
      print('[ERROR] Failed to retrieve transactions from database: $e');
      throw Exception('Failed to retrieve transactions from database: $e');
    }
  }

  static Future<void> debugDatabaseContents() async {
    final db = await database;
    try {
      print('[DEBUG] === DATABASE DEBUG INFO ===');

      // Check table structure
      final tableInfo =
          await db.rawQuery("PRAGMA table_info(load_transactions)");
      print('[DEBUG] Table structure: $tableInfo');

      // Check row count
      final count = await getLoadTransactionsCount();
      print('[DEBUG] Total rows in load_transactions: $count');

      // Get all data
      final allData = await db.query('load_transactions');
      print('[DEBUG] All data in load_transactions: $allData');

      print('[DEBUG] === END DATABASE DEBUG ===');
    } catch (e) {
      print('[ERROR] Failed to debug database: $e');
    }
  }

  static Future<void> insertTestTransaction() async {
    final db = await database;
    try {
      final testData = {
        'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'dateLoaded': DateTime.now().toIso8601String(),
        'amount': 100.0,
        'remarks': 'Test transaction for debugging',
        'referenceNo': 'TEST_REF_001',
        'isConfirmed': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await db.insert('load_transactions', testData);
      print('[DEBUG] Test transaction inserted successfully: $testData');
    } catch (e) {
      print('[ERROR] Failed to insert test transaction: $e');
    }
  }

  static Future<int> getLoadTransactionsCount() async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    try {
      final result = Sqflite.firstIntValue(
        await db.rawQuery(
            'SELECT COUNT(*) FROM load_transactions WHERE endpoint = ?',
            [endpoint]),
      );
      return result ?? 0;
    } catch (e) {
      print('[ERROR] Failed to get transaction count: $e');
      return 0;
    }
  }

  static Future<bool> hasLoadTransactions() async {
    final count = await getLoadTransactionsCount();
    return count > 0;
  }

  static Future<void> clearLoadTransactions() async {
    final db = await database;
    final endpoint = ApiConfig.useSellerCenter ? 'live' : 'test';
    await db.delete('load_transactions',
        where: 'endpoint = ?', whereArgs: [endpoint]);
    print('[DEBUG] Cleared load transactions for endpoint: $endpoint');
  }

  static Future<void> resetDatabase() async {
    final db = await database;
    try {
      // Drop and recreate the table
      await db.execute('DROP TABLE IF EXISTS load_transactions');
      await db.execute('''
        CREATE TABLE load_transactions (
          id TEXT PRIMARY KEY,
          dateLoaded TEXT,
          amount REAL,
          remarks TEXT,
          referenceNo TEXT,
          isConfirmed INTEGER DEFAULT 0,
          lastUpdated TEXT
        )
      ''');
      print('[DEBUG] Database reset successfully');
    } catch (e) {
      print('[ERROR] Failed to reset database: $e');
    }
  }

  static Future<void> testAndFixTransactions(String userId) async {
    try {
      print('[DEBUG] === TESTING AND FIXING TRANSACTIONS ===');

      // Clear existing data
      await clearLoadTransactions();

      // Get fresh data from API
      final transactions =
          await RiderOrdersService.getRiderLoadTrans(userId: userId);
      print('[DEBUG] API returned ${transactions.length} transactions');

      // Save to database
      await saveLoadTransactions(transactions);

      // Verify database contents
      await debugDatabaseContents();

      print('[DEBUG] === END TESTING AND FIXING ===');
    } catch (e) {
      print('[ERROR] Test and fix failed: $e');
      throw e;
    }
  }

  static Future<void> refreshTransactionsFromAPI(String userId) async {
    try {
      print('[DEBUG] Refreshing transactions from API for user: $userId');

      // Get fresh data from API
      final transactions =
          await RiderOrdersService.getRiderLoadTrans(userId: userId);

      // Clear existing data
      await clearLoadTransactions();

      // Save new data
      await saveLoadTransactions(transactions);

      print('[DEBUG] Successfully refreshed transactions from API');
    } catch (e) {
      print('[ERROR] Failed to refresh transactions from API: $e');
      throw Exception('Failed to refresh transactions from API: $e');
    }
  }
}

class RiderOrdersService {
  static String get baseUrl => ApiConfig.apiBase + '/';

  static Future<Map<String, dynamic>> postLoadRiderWallet({
    required String riderId,
    required int amount,
  }) async {
    final url = Uri.parse(baseUrl + 'PostLoadRiderWallet');
    final response = await ApiClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'RiderId': riderId,
        'IsCredit': true,
        'Amount': amount,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final err = 'Failed to post load: ${response.body}';
      print('[ERROR] ' + err);
      throw Exception(err);
    }
  }

  static Future<List<dynamic>> getRiderLoadTrans({
    required String userId,
  }) async {
    final url = Uri.parse(baseUrl + 'getriderloadtrans');
    print('[DEBUG] Calling getRiderLoadTrans with userId: $userId');
    print('[DEBUG] URL: $url');

    try {
      final response = await ApiClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'UserId': userId}),
      );

      print('[DEBUG] Response status: ${response.statusCode}');
      print('[DEBUG] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decodedResponse = jsonDecode(response.body);
        print('[DEBUG] Decoded response type: ${decodedResponse.runtimeType}');
        print('[DEBUG] Decoded response: $decodedResponse');

        // Check if response has LoadWallets array
        if (decodedResponse is Map &&
            decodedResponse.containsKey('LoadWallets')) {
          final loadWallets = decodedResponse['LoadWallets'];
          print(
              '[DEBUG] Found LoadWallets array with ${loadWallets.length} items');

          if (loadWallets is List) {
            print(
                '[DEBUG] LoadWallets is a list, returning ${loadWallets.length} transactions');
            if (loadWallets.isNotEmpty) {
              print('[DEBUG] First LoadWallet item: ${loadWallets.first}');
              print(
                  '[DEBUG] First LoadWallet keys: ${loadWallets.first.keys.toList()}');
            }
            return loadWallets;
          } else {
            print(
                '[DEBUG] LoadWallets is not a list, type: ${loadWallets.runtimeType}');
            return [loadWallets];
          }
        }

        // Fallback for other response structures
        if (decodedResponse is List) {
          print(
              '[DEBUG] Response is a list, length: ${decodedResponse.length}');
          if (decodedResponse.isNotEmpty) {
            print(
                '[DEBUG] First item keys: ${decodedResponse.first.keys.toList()}');
            print('[DEBUG] First item values: ${decodedResponse.first}');
            print(
                '[DEBUG] First item type: ${decodedResponse.first.runtimeType}');
          }
          return decodedResponse;
        } else if (decodedResponse is Map) {
          print(
              '[DEBUG] Response is a Map, converting to list with single item');
          print('[DEBUG] Map keys: ${decodedResponse.keys.toList()}');
          print('[DEBUG] Map values: $decodedResponse');
          // Convert Map to List so UI can display it
          return [decodedResponse];
        } else {
          print(
              '[DEBUG] Unexpected response type: ${decodedResponse.runtimeType}');
          return [decodedResponse];
        }
      } else {
        print('[ERROR] API returned status code: ${response.statusCode}');
        print('[ERROR] Response body: ${response.body}');
        throw Exception(
            'Failed to get load transactions: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[ERROR] Exception in getRiderLoadTrans: $e');
      if (e is FormatException) {
        throw Exception('Invalid response format from server: $e');
      } else if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Network error: $e');
      }
    }
  }

  static Future<Map<String, dynamic>> postCheckRiderLoadStatus({
    required String loadRefNo,
    required String riderId,
  }) async {
    final url = Uri.parse(baseUrl + 'postCheckRiderLoadStatus');
    final response = await ApiClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'LoadRefNo': loadRefNo,
        'RiderId': riderId,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to check load status: ${response.body}');
    }
  }
}
