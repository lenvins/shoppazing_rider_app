import 'package:flutter/material.dart';
import 'package:shoppazing_rider_app/services/rider_orders_db.dart';
import 'dart:convert';

import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/user_session_db.dart';
import 'map_page.dart';
import 'account_activation_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _riderInfo;
  bool _loadingRiderInfo = true;
  String? _riderInfoError;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadRiderInfo();
  }

  Future<void> _loadSession() async {
    final session = await UserSessionDB.getSession();
    if (!mounted) return;
    setState(() {
      _session = session != null ? Map<String, dynamic>.from(session) : null;
    });
  }

  Future<void> _loadRiderInfo() async {
    final session = await UserSessionDB.getSession();
    final userId = session?['user_id']?.toString();
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingRiderInfo = false;
          _riderInfoError = 'No user session';
        });
      }
      return;
    }

    setState(() {
      _loadingRiderInfo = true;
      _riderInfoError = null;
    });

    try {
      final url = ApiConfig.apiUri('/GetRiderInfo');
      final response = await ApiClient.post(
        url,
        body: jsonEncode({'UserId': userId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }
        if (data is Map<String, dynamic>) {
          final statusCode = data['status_code'];
          if (statusCode == 200) {
            setState(() {
              _riderInfo = data;
              _loadingRiderInfo = false;
              _riderInfoError = null;
            });
            return;
          }
        }
      }

      setState(() {
        _loadingRiderInfo = false;
        _riderInfo = null;
        _riderInfoError = 'Could not load rider info';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRiderInfo = false;
        _riderInfo = null;
        _riderInfoError = e.toString();
      });
    }
  }

  String _profileImageUrl() {
    final path = _riderInfo?['ProfilePic']?.toString();
    if (path == null || path.isEmpty) return '';
    final normalized = path.replaceAll(r'\', '/');
    final base = ApiConfig.baseOrigin.endsWith('/')
        ? ApiConfig.baseOrigin
        : '${ApiConfig.baseOrigin}/';
    debugPrint(base + (normalized.startsWith('/') ? normalized.substring(1) : normalized));
    return "${base}api/${normalized.startsWith('/') ? normalized.substring(1) : normalized}";
  }

  bool get _isAccountActivated =>
      _riderInfo?['IsAccountActivated'] == true;

  @override
  Widget build(BuildContext context) {
    final name = _riderInfo?['Name']?.toString() ??
        '${_session?['firstname'] ?? ''} ${_session?['lastname'] ?? ''}'.trim();
    final email = _session?['email']?.toString() ?? '';
    final mobile = _riderInfo?['MobileNo']?.toString() ??
        _session?['mobile_no']?.toString() ??
        '';
    final userId = _session?['user_id']?.toString();
    final riderId = _session?['rider_id']?.toString();
    final String addressLine1 = _riderInfo?['AddressLine1']?.toString() ?? '';
    final String addressLine2 = _riderInfo?['AddressLine2']?.toString() ?? '';
    final String streetNo = '${addressLine1.trim()} ${addressLine2.trim()}'.trim();

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
                MaterialPageRoute(builder: (context) => const MapPage()),
              );
            },
            icon: const Icon(Icons.map, size: 16),
            label: const Text('View Location', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D8AA8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: const TextStyle(fontSize: 13),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: _profileAvatar(name),
        ),
        const SizedBox(height: 12),
        Text(
          name.isEmpty ? 'Rider' : name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D8AA8),
          ),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
        if (mobile.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            mobile,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
        const SizedBox(height: 12),
        _buildStatusChip(),
        const SizedBox(height: 20),
        if (_loadingRiderInfo)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Color(0xFF5D8AA8)),
            ),
          )
        else if (_riderInfoError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _riderInfoError!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          _buildInfoCard(
            title: 'Account',
            children: [
              if (userId != null) _buildInfoRow('User ID', userId),
              if (riderId != null) _buildInfoRow('Rider ID', riderId),
            ],
          ),
          if (_riderInfo != null) ...[
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Rider details',
              children: [
                _buildInfoRow('Vehicle', _riderInfo!['Vehicle']?.toString() ?? '—'),
                _buildInfoRow('Plate No', _riderInfo!['PlateNo']?.toString() ?? '—'),
                _buildInfoRow('Driver\'s license', _riderInfo!['DriversLicenseNo']?.toString() ?? '—'),
                _buildInfoRow('TIN', _riderInfo!['TINNo']?.toString() ?? '—'),
                _buildInfoRow('SSS', _riderInfo!['SSS']?.toString() ?? '—'),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildInfoCard(
              title: 'Address',
              children: [
                _buildInfoRow('Street No.', streetNo),
                _buildInfoRow('City', _riderInfo!['City']?.toString() ?? '—'),
                _buildInfoRow('State', _riderInfo!['State']?.toString() ?? '—'),
              ],
            ),
          ],
        ],
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'Settings',
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF5D8AA8)),
              title: const Text('Edit Profile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountActivationPage(
                      initialRiderInfo: _riderInfo,
                    ),
                  ),
                );
                if (updated == true && mounted) {
                  _loadRiderInfo();
                }
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await UserSessionDB.clearSession();
              await RiderOrdersDB.clearAllData();
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

  Widget _profileAvatar(String name) {
    final url = _profileImageUrl();
    if (url.isEmpty) {
      return const CircleAvatar(
        radius: 50,
        backgroundColor: Color(0xFF5D8AA8),
        child: Icon(Icons.person, size: 50, color: Colors.white),
      );
    }
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }

  Widget _buildStatusChip() {
    final activated = _isAccountActivated;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activated
              ? Colors.green.shade50
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activated ? Colors.green : Colors.orange,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activated ? Icons.check_circle : Icons.pending,
              size: 18,
              color: activated ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              activated ? 'Account activated' : 'Account not activated',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: activated ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
          ],
        ),
      ),
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
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
