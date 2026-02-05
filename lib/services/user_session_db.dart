import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class UserSessionDB {
  static Completer<Database>? _dbCompleter;

  static Future<Database> get database async {
    if (_dbCompleter == null) {
      _dbCompleter = Completer();
      _initDB().then((db) {
        _dbCompleter!.complete(db);
      }).catchError((error, stackTrace) {
        _dbCompleter!.completeError(error, stackTrace);
        _dbCompleter = null; // Allow retrying
      });
    }
    return _dbCompleter!.future;
  }

  // Helper method to parse different date formats
  static DateTime parseDateString(String dateString) {
    if (dateString.isEmpty) {
      return DateTime.now();
    }

    try {
      // Try standard ISO format first
      final parsed = DateTime.parse(dateString);
      return parsed;
    } catch (e) {
      try {
        // Try RFC 2822 format (e.g., "Sat, 16 Aug 2025 06:00:23 GMT")
        if (dateString.contains(',')) {
          // Remove day of week and parse the rest
          final parts = dateString.split(', ');
          if (parts.length == 2) {
            final dateTimePart = parts[1]; // "16 Aug 2025 06:00:23 GMT"
            final parsed = DateTime.parse(dateTimePart);
            return parsed;
          }
        }

        // Try other common formats
        if (dateString.contains('GMT')) {
          final cleanDate = dateString.replaceAll('GMT', '').trim();
          final parsed = DateTime.parse(cleanDate);
          return parsed;
        }

        // Try to handle various date formats by cleaning them up
        String cleanedDate = dateString;

        // Remove common problematic parts
        cleanedDate = cleanedDate.replaceAll('GMT', '');
        cleanedDate = cleanedDate.replaceAll('UTC', '');
        cleanedDate = cleanedDate.replaceAll('Z', '');
        cleanedDate = cleanedDate.trim();

        final parsed = DateTime.parse(cleanedDate);
        return parsed;
      } catch (e2) {
        // Try one more approach - handle common API date formats
        try {
          // Handle formats like "2024-01-15T10:30:00.000Z" or "2024-01-15T10:30:00Z"
          if (dateString.contains('T') &&
              (dateString.endsWith('Z') || dateString.contains('+'))) {
            final cleanDate =
                dateString.replaceAll('.000Z', 'Z').replaceAll('Z', '+00:00');
            final parsed = DateTime.parse(cleanDate);
            return parsed;
          }
        } catch (e3) {}

        // Last resort: try to create a date from current time
        return DateTime.now();
      }
    }
  }

  static Future<Database> _initDB() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'user_session.db');

      final db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // Create users table
          await db.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              access_token TEXT NOT NULL,
              token_type TEXT NOT NULL,
              expires_in INTEGER NOT NULL,
              email TEXT NOT NULL,
              business_name TEXT NOT NULL,
              merchant_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              firstname TEXT NOT NULL,
              lastname TEXT NOT NULL,
              mobile_no TEXT NOT NULL,
              mobile_confirmed TEXT NOT NULL,
              rider_id TEXT NOT NULL,
              role_name TEXT NOT NULL,
              issued TEXT NOT NULL,
              expires TEXT NOT NULL
            )
          ''');
        },
      );

      return db;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> saveSession({
    required String accessToken,
    required String tokenType,
    required int expiresIn,
    required String email,
    required String businessName,
    required String merchantId,
    required String userId,
    required String firstname,
    required String lastname,
    required String mobileNo,
    required String mobileConfirmed,
    required String riderId,
    required String roleName,
    required String issued,
    required String expires,
  }) async {
    try {
      final db = await database;
      await db.delete('users'); // Only one session at a time

      final sessionData = {
        'access_token': accessToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
        'email': email,
        'business_name': businessName,
        'merchant_id': merchantId,
        'user_id': userId,
        'firstname': firstname,
        'lastname': lastname,
        'mobile_no': mobileNo,
        'mobile_confirmed': mobileConfirmed,
        'rider_id': riderId,
        'role_name': roleName,
        'issued': issued,
        'expires': expires,
      };

      await db.insert('users', sessionData);

      // Verify the session was saved
      final savedSession = await getSession();
      if (savedSession != null) {
      } else {}
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getSession() async {
    try {
      final db = await database;
      final result = await db.query('users', limit: 1);

      if (result.isNotEmpty) {
        return result.first;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final db = await database;
    await db.delete('users');
  }

  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    final db = await database;
    final result = await db.query('users',
        where: 'user_id = ?', whereArgs: [userId], limit: 1);
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  static Future<void> clearInvalidSession() async {
    try {
      final session = await getSession();
      if (session != null) {
        final isValid = await isSessionValid();
        if (!isValid) {
          await clearSession();
        }
      }
    } catch (e) {}
  }

  static Future<bool> isSessionValid() async {
    final session = await getSession();
    if (session == null) {
      return false;
    }

    try {
      final issuedStr = session['issued'] as String;
      final expiresIn = session['expires_in'] as int;

      // Handle different date formats
      DateTime issued;
      try {
        issued = parseDateString(issuedStr);
      } catch (e) {
        return false;
      }

      // expires_in is typically in seconds, not hours
      final expiry = issued.add(Duration(seconds: expiresIn));

      final isValid = DateTime.now().isBefore(expiry);

      return isValid;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isTokenExpiringSoon({int thresholdMinutes = 5}) async {
    try {
      final session = await getSession();
      if (session == null) return false;

      final issuedStr = session['issued'] as String;
      final expiresIn = session['expires_in'] as int;

      final issued = parseDateString(issuedStr);
      final expiry = issued.add(Duration(seconds: expiresIn));
      final threshold = DateTime.now().add(Duration(minutes: thresholdMinutes));

      return expiry.isBefore(threshold);
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getValidSession() async {
    try {
      final session = await getSession();
      if (session == null) {
        return null;
      }

      final isValid = await isSessionValid();
      if (isValid) {
        return session;
      } else {
        // Clear invalid session
        await clearSession();
        return null;
      }
    } catch (e) {
      // Clear session on error to prevent stuck states
      try {
        await clearSession();
      } catch (clearError) {}
      return null;
    }
  }

  static Future<bool> isDatabaseAccessible() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT 1');
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<void> debugDatabaseInfo() async {
    try {
      final db = await database;
      final tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");

      if (tables.any((t) => t['name'] == 'users')) {
        final userCount =
            await db.rawQuery('SELECT COUNT(*) as count FROM users');

        if (userCount.first['count'] as int > 0) {
          final sampleUser = await db.rawQuery('SELECT * FROM users LIMIT 1');
        }
      }
    } catch (e) {}
  }

  static Future<void> diagnoseSessionIssues() async {
    try {
      // Check database accessibility
      final isDbAccessible = await isDatabaseAccessible();

      if (!isDbAccessible) {
        return;
      }

      // Get database info
      await debugDatabaseInfo();

      // Check session
      final session = await getSession();
      if (session == null) {
        return;
      }

      // Validate session
      final isValid = await isSessionValid();

      if (!isValid) {
        try {
          final issuedStr = session['issued'] as String;
          final expiresIn = session['expires_in'] as int;

          final issued = parseDateString(issuedStr);

          final expiry = issued.add(Duration(seconds: expiresIn));
          final now = DateTime.now();
        } catch (e) {}
      }
    } catch (e) {}
  }
}
