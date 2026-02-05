import 'package:flutter/material.dart';
// import removed: http
import '../services/api_client.dart';
import 'dart:convert';
import '../services/user_session_db.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/auth_context.dart';
import '../services/api_config.dart';
import '../services/network_service.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final List<TextEditingController> controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  bool isLoading = false;
  String? mobileNo;
  bool _isInitialized = false;
  String _otp = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      String? argMobile = args != null ? args['mobileNo'] as String? : null;
      final fallback = AuthContext.lastMobileNo;
      final chosen = argMobile ?? fallback;
      if (chosen != null && chosen.isNotEmpty) {
        AuthContext.lastMobileNo = chosen;
      }
      setState(() {
        mobileNo = chosen;
      });
      _isInitialized = true;
    }
  }

  Future<void> _verifyOTP() async {
    // Get OTP from pin code field
    final otp = _otp;
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter complete OTP')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Normalize mobile format: ensure it has country code 63
      String? normalizedMobile = mobileNo;
      if (normalizedMobile != null) {
        final m = normalizedMobile.replaceAll(RegExp(r'[^0-9]'), '');
        if (m.startsWith('0') && m.length == 11) {
          normalizedMobile = '63' + m.substring(1);
        } else if (m.length == 10 && m.startsWith('9')) {
          normalizedMobile = '63' + m;
        } else if (m.startsWith('63')) {
          normalizedMobile = m;
        } else {
          normalizedMobile = m;
        }
      }

      print('Verifying OTP: $otp for mobile: $normalizedMobile');

      if (normalizedMobile == null || normalizedMobile.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Missing phone number. Please go back and enter your number again.')),
          );
        }
        return;
      }
      final response = await ApiClient.post(
        ApiConfig.apiUri('/verifyotplogin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'OTP': otp,
          'MobileNo': normalizedMobile,
          'UserId': '', // This will be empty for initial verification
          'issuer': 'com.byteswiz.shoppazing',
          'audience': 'ShoppaZing',
          'encryptedSecretKey': 'rOUiWiiqxr6Ot/5K03uLleWNBQutrIAwjPnyHeTP/rc='
        }),
        skipAuth: true,
      );

      print('Verify OTP Response Status: ${response.statusCode}');
      print('Verify OTP Response Body: ${response.body}');
      final responseData = jsonDecode(response.body);
      print('[DEBUG] Full OTP API Response: ' + response.body);

      // Check if user not found

      if (responseData['status_code'] == 3 &&
          responseData['message']?.toLowerCase().contains('no user found') ==
              true) {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/register',
            arguments: {'mobileNo': mobileNo},
          );
        }
        return;
      }

      final int apiStatus =
          int.tryParse(responseData['status_code']?.toString() ?? '') ?? 0;
      if (apiStatus == 200 || apiStatus == 201) {
        final userId = responseData['UserId']?.toString() ?? '';
        final email = responseData['Email']?.toString() ?? '';
        final firstName = responseData['FirstName']?.toString() ?? '';
        final lastName = responseData['LastName']?.toString() ?? '';
        final roleName = responseData['RoleName']?.toString() ?? '';

        // Check if user has CUSTOMER role - restrict login
        if (roleName.toUpperCase() == 'CUSTOMER') {
          print('[DEBUG] User has CUSTOMER role, login not allowed');
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
        final bearerToken = responseData['BearerToken'];
        if (bearerToken is Map) {
          try {
            final issuedDate =
                (bearerToken['.issued']?.toString().isNotEmpty == true)
                    ? bearerToken['.issued']
                    : DateTime.now().toIso8601String();
            await UserSessionDB.saveSession(
              accessToken: bearerToken['access_token']?.toString() ?? '',
              tokenType: bearerToken['token_type']?.toString() ?? 'bearer',
              expiresIn:
                  int.tryParse(bearerToken['expires_in']?.toString() ?? '0') ??
                      0,
              email: email,
              businessName: responseData['BusinessName']?.toString() ?? '',
              merchantId: responseData['MerchantId']?.toString() ?? '',
              userId: userId,
              firstname: firstName,
              lastname: lastName,
              mobileNo: normalizedMobile,
              mobileConfirmed:
                  responseData['PhoneNumberConfirmed']?.toString() ?? '',
              riderId: responseData['RiderId']?.toString() ?? '',
              roleName: responseData['RoleName']?.toString() ?? '',
              issued: issuedDate,
              expires: bearerToken['.expires']?.toString() ?? '',
            );
          } catch (e) {
            print('Error saving BearerToken from OTP: $e');
          }
        } else if (bearerToken is String) {
          try {
            // Extract user details from UserGoogleAuthModel
            final userModel = responseData['UserGoogleAuthModel'] as Map?;
            final userEmail = email.isNotEmpty
                ? email
                : (userModel?['Email']?.toString() ?? '');
            final fn = firstName.isNotEmpty
                ? firstName
                : (userModel?['FirstName']?.toString() ?? '');
            final ln = lastName.isNotEmpty
                ? lastName
                : (userModel?['LastName']?.toString() ?? '');
            final phone = normalizedMobile;
            final phoneConfirmed =
                userModel?['PhoneNumberConfirmed']?.toString() ?? '';
            final riderId = userModel?['RiderId']?.toString() ?? '';
            final roleName = userModel?['RoleName']?.toString() ?? '';
            final businessName = userModel?['BusinessName']?.toString() ?? '';
            final merchantId = userModel?['MerchantId']?.toString() ?? '';

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
                final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;
                final exp =
                    int.tryParse(payloadMap['exp']?.toString() ?? '0') ?? 0;
                if (exp > 0) {
                  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
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
              email: userEmail,
              businessName: businessName,
              merchantId: merchantId,
              userId: userId,
              firstname: fn,
              lastname: ln,
              mobileNo: phone,
              mobileConfirmed: phoneConfirmed,
              riderId: riderId,
              roleName: roleName,
              issued: issuedIso,
              expires: '',
            );
          } catch (e) {
            print('Error saving string BearerToken from OTP: $e');
          }
        }

        // Always navigate to home after successful OTP
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? 'Invalid OTP')),
          );
        }
      }
    } on NetworkException catch (e) {
      print('Network error during OTP verification: $e');
      if (mounted) {
        NetworkService.showNetworkErrorSnackBar(context,
            customMessage: e.message);
      }
    } catch (e) {
      print('Error verifying OTP: $e');
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

  Future<void> _resendOTP() async {
    if (mobileNo == null || mobileNo!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Missing phone number. Please go back and enter your number again.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Normalize mobile format
      String normalized = mobileNo!;
      final m = normalized.replaceAll(RegExp(r'[^0-9]'), '');
      if (m.startsWith('0') && m.length == 11) {
        normalized = '63' + m.substring(1);
      } else if (m.length == 10 && m.startsWith('9')) {
        normalized = '63' + m;
      } else if (m.startsWith('63')) {
        normalized = m;
      } else {
        normalized = m;
      }

      final response = await ApiClient.post(
        ApiConfig.apiUri('/loginbyotp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'UserId': '', 'MobileNo': normalized, 'AppHash': ''}),
        skipAuth: true,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP resent successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
              const SnackBar(content: Text('OTP resend successfully')));
        }
      }
    } on NetworkException catch (e) {
      print('Network error during OTP resend: $e');
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

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Enter OTP',
                style: TextStyle(
                  color: Color(0xFF5D8AA8),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We sent a code to +63 ${mobileNo ?? '••• ••• ••••'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate available width for the fields
                  double availableWidth = constraints.maxWidth;
                  // Subtract a little for spacing between fields (5 gaps for 6 fields, e.g. 8px each)
                  double spacing = 8.0;
                  double totalSpacing = spacing * 5;
                  double fieldWidth = (availableWidth - totalSpacing) / 6;
                  // Clamp fieldWidth to a minimum/maximum if you want
                  fieldWidth = fieldWidth.clamp(40.0, 60.0);

                  return PinCodeTextField(
                    appContext: context,
                    length: 6,
                    obscureText: false,
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(8),
                      fieldHeight: 60,
                      fieldWidth: fieldWidth,
                      activeFillColor: Colors.white,
                      selectedFillColor: Colors.white,
                      inactiveFillColor: Colors.white,
                      activeColor: const Color(0xFF5D8AA8),
                      selectedColor: const Color(0xFF5D8AA8),
                      inactiveColor: Colors.grey,
                    ),
                    animationDuration: const Duration(milliseconds: 300),
                    backgroundColor: Colors.white,
                    enableActiveFill: true,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _otp = value;
                      });
                    },
                    onCompleted: (value) {
                      _otp = value;
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive code? ",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: isLoading ? null : _resendOTP,
                    child: const Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: Color(0xFF5D8AA8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D8AA8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isLoading ? null : _verifyOTP,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Validate'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
