import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  factory GoogleSignInService() => _instance;
  GoogleSignInService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Sign in with Google and return user data
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In process...');

      // Initialize Google Sign-In with proper configuration
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      debugPrint('Google Sign-In initialized, attempting sign in...');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      debugPrint(
          'Google Sign-In result: ${googleUser != null ? "Success" : "Cancelled"}');

      if (googleUser == null) {
        return GoogleSignInResult(
          success: false,
          error: 'Sign in was cancelled by user',
        );
      }

      // Obtain the auth details from the account
      debugPrint('Getting Google authentication details...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint(
          'Google auth details obtained, creating Firebase credential...');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('Firebase credential created, signing in to Firebase...');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      debugPrint(
          'Firebase sign-in result: ${firebaseUser != null ? "Success" : "Failed"}');

      if (firebaseUser == null) {
        return GoogleSignInResult(
          success: false,
          error: 'Failed to authenticate with Firebase',
        );
      }

      // Extract user data
      final userData = GoogleUserData(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? '',
        firstName: _extractFirstName(firebaseUser.displayName ?? ''),
        lastName: _extractLastName(firebaseUser.displayName ?? ''),
        photoUrl: firebaseUser.photoURL ?? '',
        idToken: googleAuth.idToken ?? '',
        accessToken: googleAuth.accessToken ?? '',
      );

      return GoogleSignInResult(success: true, userData: userData);
    } catch (e) {
      debugPrint('Google Sign In Error: $e');

      // Handle specific Google Sign-In errors
      String errorMessage = 'Sign in failed: ${e.toString()}';

      if (e.toString().contains('ApiException: 10')) {
        errorMessage =
            'Google Sign-In configuration error. Please check your Google Services configuration.';
      } else if (e.toString().contains('ApiException: 7')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('ApiException: 8')) {
        errorMessage = 'Internal error. Please try again.';
      } else if (e.toString().contains('ApiException: 12501')) {
        errorMessage = 'Sign in was cancelled by user.';
      }

      return GoogleSignInResult(
        success: false,
        error: errorMessage,
      );
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Google Sign Out Error: $e');
    }
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    // Use FirebaseAuth as the source of truth for app session
    return _firebaseAuth.currentUser != null;
  }

  /// Get current Google user
  Future<GoogleSignInAccount?> getCurrentUser() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      return await googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  /// Extract first name from display name
  String _extractFirstName(String displayName) {
    if (displayName.isEmpty) return '';
    final parts = displayName.split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  /// Extract last name from display name
  String _extractLastName(String displayName) {
    if (displayName.isEmpty) return '';
    final parts = displayName.split(' ');
    if (parts.length > 1) {
      return parts.sublist(1).join(' ');
    }
    return '';
  }
}

/// Result class for Google Sign In operations
class GoogleSignInResult {
  final bool success;
  final GoogleUserData? userData;
  final String? error;

  GoogleSignInResult({required this.success, this.userData, this.error});
}

/// User data from Google Sign In
class GoogleUserData {
  final String id;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String photoUrl;
  final String idToken;
  final String accessToken;

  GoogleUserData({
    required this.id,
    required this.email,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.photoUrl,
    required this.idToken,
    required this.accessToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'photoUrl': photoUrl,
      'idToken': idToken,
      'accessToken': accessToken,
    };
  }
}
