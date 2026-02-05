import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/user_session_db.dart';
import '../services/api_config.dart';

class EnterPasswordPage extends StatefulWidget {
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String mobileNo;

  const EnterPasswordPage({
    Key? key,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.mobileNo,
  }) : super(key: key);

  @override
  State<EnterPasswordPage> createState() => _EnterPasswordPageState();
}

class _EnterPasswordPageState extends State<EnterPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'password',
          'username': widget.email,
          'password': _passwordController.text,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final roleName = data['RoleName']?.toString() ?? '';

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

        final issuedDate = (data['.issued']?.toString().isNotEmpty == true)
            ? data['.issued']
            : DateTime.now().toIso8601String();
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
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error:  {e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Password'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF5D8AA8),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Email: ${widget.email}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text('Password:'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
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
                onPressed: _isLoading ? null : _onLogin,
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
    );
  }
}
