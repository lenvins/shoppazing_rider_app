import 'package:flutter/material.dart';
import 'package:shoppazing_rider_app/services/google_signin_service.dart';
import 'package:shoppazing_rider_app/services/user_session_db.dart';
// import removed: http
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/auth_context.dart';
import '../services/network_service.dart';
import 'dart:convert';

class PhoneNumberPage extends StatefulWidget {
  const PhoneNumberPage({super.key});

  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  final TextEditingController controller = TextEditingController();
  bool isLoading = false;

  Future<void> _loginWithOTP() async {
    final phoneNumber = controller.text.trim();

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    // Validate phone number format
    if (!phoneNumber.startsWith('9') || phoneNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must start with 9 and be 10 digits long'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Add '63' prefix for API calls
      final formattedPhoneNumber = '63$phoneNumber';

      // Remember mobile for OTP page fallback
      AuthContext.lastMobileNo = formattedPhoneNumber;

      // First check if user is registered
      final verifyResponse = await ApiClient.post(
        ApiConfig.apiUri('verifyotplogin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'OTP': '', 'MobileNo': formattedPhoneNumber, 'UserId': ''}),
        skipAuth: true,
      );


      final responseData = jsonDecode(verifyResponse.body);

      // Check if the response indicates the user is registered
      // A 403 status_code with "Invalid OTP" message means the user exists
      final isRegistered = responseData['status_code'] == 403 &&
          responseData['message']?.toLowerCase().contains('invalid otp') ==
              true;

      if (!isRegistered) {
        // User is not registered, redirect to registration
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/register',
            arguments: {'mobileNo': formattedPhoneNumber},
          );
        }
        return;
      }

      // User is registered, proceed with sending OTP
      final response = await ApiClient.post(
        ApiConfig.apiUri('sendotp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'MobileNo': formattedPhoneNumber}),
        skipAuth: true,
      );


      final otpResponseData = jsonDecode(response.body);
      if (otpResponseData['status_code'] == 200) {
        if (mounted) {
          // Navigate to OTP page with the phone number
          await Navigator.pushReplacementNamed(
            context,
            '/otp',
            arguments: {'mobileNo': formattedPhoneNumber},
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send OTP: ${response.body}')),
          );
        }
      }
    } on NetworkException catch (e) {
      if (mounted) {
        NetworkService.showNetworkErrorSnackBar(context,
            customMessage: e.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loginWithGmail() async {
    try {
      final googleservice = GoogleSignInService();
      final result = await googleservice.signInWithGoogle();

      if (!result.success) {
        throw Exception(result.error ?? "Gmail Sign in failed");
      }

      final googleUser = result.userData!;

      final requestBody = {
        'idToken': googleUser.idToken,
        'encryptedSecretKey': 'rOUiWiiqxr6Ot/5K03uLleWNBQutrIAwjPnyHeTP/rc=',
        'issuer': 'com.byteswiz.shoppazing',
        'audience': 'ShoppaZing',
      };

      final requestUrl = ApiConfig.absolute('/api/auth/google');

      // Test basic connectivity first
      try {
        final testResponse = await ApiClient.get(
          ApiConfig.absolute('/api/auth/google'),
          skipAuth: true,
        );
      } catch (e) {
      }

      final response = await ApiClient.post(
        requestUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
        skipAuth: true,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);

        // Extract user data from the response
        final userData = responseData['User'] as Map?;
        final userId = userData?['UserId']?.toString();
        final email = userData?['Email']?.toString() ??
            responseData['UserEmail']?.toString() ??
            '';
        final firstName = userData?['FirstName']?.toString() ?? '';
        final lastName = userData?['LastName']?.toString() ?? '';
        final roleName = userData?['RoleName']?.toString() ?? '';
        final message = responseData['Message']?.toString().toLowerCase() ?? '';

        // Check if user has CUSTOMER role - restrict registration
        if (roleName.toUpperCase() == 'CUSTOMER') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Customer accounts cannot register as riders. Please contact support.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Check if user is not found or incomplete (should go to registration)
        if (userId == null ||
            userId == 'null' ||
            userId.isEmpty ||
            (userData?['RiderId'] == null || userData?['RiderId'] == 'null') ||
            message.contains('authentication successful') &&
                (firstName.isEmpty || lastName.isEmpty)) {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/register',
              arguments: {
                'email': email.isNotEmpty ? email : googleUser.email,
                'firstname':
                    firstName.isNotEmpty ? firstName : googleUser.firstName,
                'lastname':
                    lastName.isNotEmpty ? lastName : googleUser.lastName,
              },
            );
          }
          return;
        }

        // If user is found with complete profile, proceed with login
        if (userId.isNotEmpty && userData?['RiderId'] != null) {

          // Double-check customer role restriction for existing users
          if (roleName.toUpperCase() == 'CUSTOMER') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Customer accounts cannot login as riders. Please contact support.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          // If API returns BearerToken, persist it to session immediately
          final bearerToken =
              responseData['token'] ?? responseData['BearerToken'];
          if (bearerToken is Map) {
            try {
              final issuedDate =
                  (bearerToken['.issued']?.toString().isNotEmpty == true)
                      ? bearerToken['.issued']
                      : DateTime.now().toIso8601String();
              await UserSessionDB.saveSession(
                accessToken: bearerToken['access_token']?.toString() ?? '',
                tokenType: bearerToken['token_type']?.toString() ?? 'bearer',
                expiresIn: int.tryParse(
                        bearerToken['expires_in']?.toString() ?? '0') ??
                    0,
                email: email,
                businessName: userData?['BusinessName']?.toString() ?? '',
                merchantId: userData?['MerchantId']?.toString() ?? '',
                userId: userId,
                firstname: firstName,
                lastname: lastName,
                mobileNo: userData?['PhoneNumber']?.toString() ?? '',
                mobileConfirmed:
                    userData?['PhoneNumberConfirmed']?.toString() ?? '',
                riderId: userData?['RiderId']?.toString() ?? '',
                roleName: userData?['RoleName']?.toString() ?? '',
                issued: issuedDate,
                expires: bearerToken['.expires']?.toString() ?? '',
              );
            } catch (e) {
            }
          } else if (bearerToken is String && bearerToken.isNotEmpty) {
            try {
              // Parse JWT exp to compute expiresIn
              int expiresInSeconds = 0;
              try {
                final parts = bearerToken.split('.');
                if (parts.length == 3) {
                  String payload =
                      parts[1].replaceAll('-', '+').replaceAll('_', '/');
                  while (payload.length % 4 != 0) {
                    payload += '=';
                  }
                  final decoded = utf8.decode(base64.decode(payload));
                  final payloadMap =
                      jsonDecode(decoded) as Map<String, dynamic>;
                  final exp =
                      int.tryParse(payloadMap['exp']?.toString() ?? '0') ?? 0;
                  if (exp > 0) {
                    final nowSec =
                        DateTime.now().millisecondsSinceEpoch ~/ 1000;
                    expiresInSeconds = exp - nowSec;
                    if (expiresInSeconds < 0) expiresInSeconds = 0;
                  }
                }
              } catch (e) {
                expiresInSeconds = 0;
              }

              final issuedIso = DateTime.now().toIso8601String();

              await UserSessionDB.saveSession(
                accessToken: bearerToken,
                tokenType: 'bearer',
                expiresIn: expiresInSeconds,
                email: email,
                businessName: userData?['BusinessName']?.toString() ?? '',
                merchantId: userData?['MerchantId']?.toString() ?? '',
                userId: userId,
                firstname: firstName,
                lastname: lastName,
                mobileNo: userData?['PhoneNumber']?.toString() ?? '',
                mobileConfirmed:
                    userData?['PhoneNumberConfirmed']?.toString() ?? '',
                riderId: userData?['RiderId']?.toString() ?? '',
                roleName: userData?['RoleName']?.toString() ?? '',
                issued: issuedIso,
                expires: '',
              );
            } catch (e) {
            }
          }

          // Always navigate to home after successful OTP
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/home', (route) => false);
          }
          return;
        } else {
          // If we reach here, it means the user data is incomplete, redirect to registration
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/register',
              arguments: {
                'email': email.isNotEmpty ? email : googleUser.email,
                'firstname':
                    firstName.isNotEmpty ? firstName : googleUser.firstName,
                'lastname':
                    lastName.isNotEmpty ? lastName : googleUser.lastName,
              },
            );
          }
        }
      } else {

        String errorMessage = 'Google login failed. Please try again.';

        // Handle specific HTTP status codes
        if (response.statusCode == 503) {
          errorMessage =
              'Server is temporarily unavailable. Please try again later.';
        } else if (response.statusCode == 500) {
          errorMessage = 'Internal server error. Please try again.';
        } else if (response.statusCode == 400) {
          errorMessage = 'Invalid request. Please check your Google account.';
        } else if (response.statusCode == 401) {
          errorMessage = 'Authentication failed. Please try again.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/shoppazing_logo.jpg',
                        height: 80,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Shoppazing Rider App',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5D8AA8),
                        ),
                      ),
                      const Text(
                        'Your trusted delivery partner',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Enter your phone number',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D8AA8),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We will send you a verification code',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixText: '+63 ',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _loginWithOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D8AA8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/email_login');
                    },
                    child: const Text(
                      'Login with Email',
                      style: TextStyle(
                        color: Color(0xFF5D8AA8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _loginWithGmail();
                    },
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: Color(0xFF2F4F4F)),
                    icon: Image.asset('assets/images/google.png',
                        width: 20, height: 20),
                    label: const Text('Sign in with Google'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
