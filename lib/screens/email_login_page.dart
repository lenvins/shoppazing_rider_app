import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/device_service.dart';
import '../services/user_session_db.dart';
import '../services/api_config.dart';
import '../services/validation_service.dart';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Validate form before proceeding
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'password',
          'username': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final userId = data['UserId'].toString();
        final riderId = data['RiderId']?.toString() ?? '0';
        final roleName = data['RoleName']?.toString() ?? '';

        // Check if user has CUSTOMER role - restrict login
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

        // Determine the issued date
        final issuedDate = (data['.issued']?.toString().isNotEmpty == true)
            ? data['.issued']
            : DateTime.now().toIso8601String();

        // Save session in SQLite
        await UserSessionDB.saveSession(
          accessToken: data['access_token'],
          tokenType: data['token_type'],
          expiresIn: data['expires_in'],
          email: data['userName'],
          businessName: data['BusinessName'],
          merchantId: data['MerchantId'],
          userId: data['UserId'],
          firstname: data['Firstname'],
          lastname: data['Lastname'],
          mobileNo: data['PhoneNumber'],
          mobileConfirmed: data['PhoneNumberConfirmed'],
          riderId: data['RiderId'],
          roleName: data['RoleName'],
          issued: issuedDate,
          expires: data['.expires'],
        );

        // Update device info after successful login
        await DeviceService.updateDeviceInfo(userId, context);

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        }
      } else {
        throw Exception('Invalid email or password');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login with Email'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF5D8AA8),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: ValidationService.validateEmail,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D8AA8),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Login',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
