import 'package:http/http.dart' as http;
import 'dart:io';
import 'user_session_db.dart';
import 'navigation_service.dart';
import 'network_service.dart';

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static Future<Map<String, String>> _buildHeaders(Map<String, String>? headers,
      {bool skipAuth = false}) async {
    final merged = <String, String>{};
    if (headers != null) {
      merged.addAll(headers);
    }

    // Only set default content-type if caller did not supply one
    if (!merged.keys.any((k) => k.toLowerCase() == 'content-type')) {
      merged['Content-Type'] = 'application/json';
    }

    // Attach bearer token if available
    if (!skipAuth) {
      try {
        final session = await UserSessionDB.getSession();
        final token = session?['access_token']?.toString();
        if (token != null && token.isNotEmpty) {
          merged['Authorization'] = 'Bearer ' + token;
        }
      } catch (_) {
        // Ignore session errors; proceed without token
      }
    }
    return merged;
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool skipAuth = false,
  }) async {
    try {
      final mergedHeaders = await _buildHeaders(headers, skipAuth: skipAuth);
      final response = await http.post(url, headers: mergedHeaders, body: body);
      await _handleAuthFailure(response);
      return response;
    } on SocketException catch (e) {
      throw NetworkException(NetworkService.getNetworkErrorMessage(e));
    } on HttpException catch (e) {
      throw NetworkException(NetworkService.getNetworkErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out')) {
        throw NetworkException(NetworkService.getNetworkErrorMessage(e));
      }
      rethrow;
    }
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    bool skipAuth = false,
  }) async {
    try {
      final mergedHeaders = await _buildHeaders(headers, skipAuth: skipAuth);
      final response = await http.get(url, headers: mergedHeaders);
      await _handleAuthFailure(response);
      return response;
    } on SocketException catch (e) {
      throw NetworkException(NetworkService.getNetworkErrorMessage(e));
    } on HttpException catch (e) {
      throw NetworkException(NetworkService.getNetworkErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out')) {
        throw NetworkException(NetworkService.getNetworkErrorMessage(e));
      }
      rethrow;
    }
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool skipAuth = false,
  }) async {
    try {
      final mergedHeaders = await _buildHeaders(headers, skipAuth: skipAuth);
      final response = await http.put(url, headers: mergedHeaders, body: body);
      await _handleAuthFailure(response);
      return response;
    } on SocketException catch (e) {
      throw NetworkException(NetworkService.getNetworkErrorMessage(e));
    } on HttpException catch (e) {
      throw NetworkException(NetworkService.getNetworkErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out')) {
        throw NetworkException(NetworkService.getNetworkErrorMessage(e));
      }
      rethrow;
    }
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool skipAuth = false,
  }) async {
    try {
      final mergedHeaders = await _buildHeaders(headers, skipAuth: skipAuth);
      final response =
          await http.delete(url, headers: mergedHeaders, body: body);
      await _handleAuthFailure(response);
      return response;
    } on SocketException catch (e) {
      throw NetworkException(NetworkService.getNetworkErrorMessage(e));
    } on HttpException catch (e) {
      throw NetworkException(NetworkService.getNetworkErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out')) {
        throw NetworkException(NetworkService.getNetworkErrorMessage(e));
      }
      rethrow;
    }
  }

  static Future<void> _handleAuthFailure(http.Response response) async {
    try {
      if (response.statusCode == 401 || response.statusCode == 403) {
        final session = await UserSessionDB.getSession();
        String? rawMobile = session?['mobile_no']?.toString();

        // Normalize mobile to 63XXXXXXXXXX
        String? normalizedMobile;
        if (rawMobile != null) {
          final m = rawMobile.replaceAll(RegExp(r'[^0-9]'), '');
          if (m.startsWith('0') && m.length == 11) {
            normalizedMobile = '63${m.substring(1)}';
          } else if (m.length == 10 && m.startsWith('9')) {
            normalizedMobile = '63$m';
          } else if (m.startsWith('63')) {
            normalizedMobile = m;
          } else {
            normalizedMobile = m;
          }
        }
      }
    } catch (_) {
      // Ignore
    }
  }
}
