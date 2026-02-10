import 'package:flutter/material.dart';
import '../services/user_session_db.dart';
import 'map_page.dart';
import 'account_activation_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? firstName;
  String? lastName;
  String? email;
  String? mobileNo;
  String? userId;
  String? riderId;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final session = await UserSessionDB.getSession();
    setState(() {
      firstName = session?['firstname'];
      lastName = session?['lastname'];
      email = session?['email'];
      mobileNo = session?['mobile_no'];
      userId = session?['user_id'];
      riderId = session?['rider_id'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        SizedBox(
          width: 160,
          height: 36,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MapPage()),
              );
            },
            icon: const Icon(Icons.map, size: 16),
            label: const Text('View Location', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D8AA8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: const TextStyle(fontSize: 13),
              minimumSize: Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const CircleAvatar(
          radius: 50,
          backgroundColor: Color(0xFF5D8AA8),
          child: Icon(Icons.person, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          '${firstName ?? ''} ${lastName ?? ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D8AA8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          email ?? 'No email set',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 40),
        _buildInfoCard(
          title: 'Personal Information',
          children: [
            _buildInfoRow('First Name', firstName ?? 'Not set'),
            _buildInfoRow('Last Name', lastName ?? 'Not set'),
            _buildInfoRow('Email', email ?? 'Not set'),
            _buildInfoRow('Mobile Number', mobileNo ?? 'Not set'),
            _buildInfoRow('User ID', userId ?? 'Not set'),
            _buildInfoRow('Rider ID', riderId ?? 'Not set'),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'Account Settings',
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF5D8AA8)),
              title: const Text('Edit Profile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement edit profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Color(0xFF5D8AA8)),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement change password
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountActivationPage(),
                ),
              );
            },
            child: const Text('Activate your Account'),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await UserSessionDB.clearSession();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D8AA8),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
