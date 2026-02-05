import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shoppazing_rider_app/services/api_config.dart';
import '../services/api_client.dart';
import 'dart:convert';
import '../services/user_session_db.dart';
import '../services/device_service.dart';
import '../services/validation_service.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  late String mobileNumber;
  bool _isInitialized = false;
  bool _isFromGoogleSignIn = false;
  bool _isFromMobileNumber = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // Get the arguments passed from phone number page or Google Sign-In
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      mobileNumber = args?['mobileNo'] ?? '';

      // Check if coming from Google Sign-In
      if (args?['email'] != null) {
        _isFromGoogleSignIn = true;
        emailController.text = args?['email'] ?? '';
        firstNameController.text = args?['firstname'] ?? '';
        lastNameController.text = args?['lastname'] ?? '';
        print(
            '[DEBUG] Pre-filled Google Sign-In data: email=${args?['email']}, firstname=${args?['firstname']}, lastname=${args?['lastname']}');
      }
      // Check if coming from mobile number registration
      else if (mobileNumber.isNotEmpty) {
        _isFromMobileNumber = true;
        mobileController.text = mobileNumber;
        print('[DEBUG] Pre-filled mobile number data: $mobileNumber');
      }

      _isInitialized = true;
    }
  }

  Future<void> _register() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final url = ApiConfig.apiUri('/registeruser');
      // Register user
      final registerResponse = await ApiClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Email': emailController.text.trim(),
          'Firstname': firstNameController.text.trim(),
          'Lastname': lastNameController.text.trim(),
          'MobileNo': mobileController.text.trim(),
          'Password': passwordController.text,
          'RoleName': 'RIDER',
        }),
      );

      print('Registration Response Status: ${registerResponse.statusCode}');
      print('Registration Response Body: ${registerResponse.body}');

      final registerData = jsonDecode(registerResponse.body);

      if (registerResponse.statusCode == 200 ||
          registerData['status_code'] == 200) {
        // Get token
        final tokenResponse = await http.post(
          Uri.parse(ApiConfig.tokenUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'password',
            'username': emailController.text.trim(),
            'password': passwordController.text,
          },
        );

        print('Token Response Status: ${tokenResponse.statusCode}');
        print('Token Response Body: ${tokenResponse.body}');

        if (tokenResponse.statusCode == 200) {
          try {
            final tokenData = jsonDecode(tokenResponse.body);
            print('[DEBUG] Full Token API Response: ' + tokenResponse.body);
            print('Parsed Token Data: $tokenData');

            // Save session in SQLite
            print('Token Response: ${tokenResponse.body}');
            print('[DEBUG] Full token response data: $tokenData');
            print('[DEBUG] .issued field: ${tokenData['.issued']}');
            print('[DEBUG] .issued type: ${tokenData['.issued'].runtimeType}');

            // Determine the issued date
            final issuedDate =
                (tokenData['.issued']?.toString().isNotEmpty == true)
                    ? tokenData['.issued']
                    : DateTime.now().toIso8601String();
            print('[DEBUG] Final issued date to be saved: $issuedDate');
            print('[DEBUG] Issued date type: ${issuedDate.runtimeType}');

            await UserSessionDB.saveSession(
              accessToken: tokenData['access_token'],
              tokenType: tokenData['token_type'],
              expiresIn: tokenData['expires_in'],
              email: tokenData['userName'],
              businessName: tokenData['BusinessName'],
              merchantId: tokenData['MerchantId'],
              userId: tokenData['UserId'],
              firstname: tokenData['Firstname'],
              lastname: tokenData['Lastname'],
              mobileNo: tokenData['PhoneNumber'],
              mobileConfirmed: tokenData['PhoneNumberConfirmed'],
              riderId: tokenData['RiderId'],
              roleName: tokenData['RoleName'],
              issued: issuedDate,
              expires: tokenData['.expires'],
            );

            // Post device token after successful registration
            await DeviceService.updateDeviceInfo(
                tokenData['UserId'].toString(), context);

            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            }
          } catch (e) {
            print('Token Parse Error: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to parse token response: $e\nResponse: ${tokenResponse.body}',
                  ),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to get token: ${tokenResponse.body}'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Registration failed: ${registerData['message'] ?? 'Unknown error'}'),
            ),
          );
        }
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
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Create Your Account',
                    style: TextStyle(
                      color: Color(0xFF5D8AA8),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join Shoppazing Rider and start earning today!',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  if (_isFromGoogleSignIn) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/google.png',
                            width: 20,
                            height: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Signed in with Google - Complete your profile below',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_isFromMobileNumber) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone,
                            color: Colors.green[800],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Mobile number verified - Complete your profile below',
                              style: TextStyle(
                                color: Colors.green[800],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildTextField(
                    'First Name',
                    controller: firstNameController,
                    readOnly: _isFromGoogleSignIn,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Last Name',
                    controller: lastNameController,
                    readOnly: _isFromGoogleSignIn,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Email',
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: _isFromGoogleSignIn,
                  ),
                  if (_isFromGoogleSignIn) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Email verified by Google',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Mobile Number',
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    readOnly: _isFromMobileNumber,
                  ),
                  if (_isFromMobileNumber) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mobile number verified',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Password',
                    controller: passwordController,
                    isPassword: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Confirm Password',
                    controller: confirmPasswordController,
                    isPassword: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D8AA8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: isLoading ? null : _register,
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text('Register'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label, {
    bool isPassword = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword &&
            !(label == 'Password' ? showPassword : showConfirmPassword),
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: TextStyle(
          fontSize: 16,
          color: readOnly ? Colors.grey[600] : null,
        ),
        validator: (value) {
          switch (label) {
            case 'First Name':
              return ValidationService.validateName(value, 'First Name');
            case 'Last Name':
              return ValidationService.validateName(value, 'Last Name');
            case 'Email':
              return ValidationService.validateEmail(value);
            case 'Mobile Number':
              return ValidationService.validatePhoneNumber(value);
            case 'Password':
              return ValidationService.validatePassword(value);
            case 'Confirm Password':
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != passwordController.text) {
                return 'Passwords do not match';
              }
              break;
          }
          return null;
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[100],
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    label == 'Password'
                        ? (showPassword
                            ? Icons.visibility_off
                            : Icons.visibility)
                        : (showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                    color: Colors.grey[600],
                  ),
                  onPressed: () {
                    setState(() {
                      if (label == 'Password') {
                        showPassword = !showPassword;
                      } else {
                        showConfirmPassword = !showConfirmPassword;
                      }
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }
}
