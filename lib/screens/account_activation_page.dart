import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/network_service.dart';
import '../services/user_session_db.dart';
import 'select_address_map_page.dart';

class AccountActivationPage extends StatefulWidget {
  const AccountActivationPage({super.key});

  @override
  State<AccountActivationPage> createState() => _AccountActivationPageState();
}

class _AccountActivationPageState extends State<AccountActivationPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _plateNoController = TextEditingController();
  final TextEditingController _driversLicenseNoController =
      TextEditingController();
  final TextEditingController _tinNoController = TextEditingController();
  final TextEditingController _sssNoController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  String? _firstName;
  String? _lastName;
  String? _riderId;
  bool _isSubmitting = false;

  String? _address;
  double? _addressLat;
  double? _addressLng;

  String? _profilePicPath;
  String? _driversLicensePath;
  String? _plateNoPath;
  String? _selfieWithIdPath;
  String? _selfieWithPlateNoPath;
  String? _tinNoPath;
  String? _sssNoPath;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final session = await UserSessionDB.getSession();
    debugPrint('[AccountActivation] _loadUserDetails: session present=${session != null}');
    if (!mounted) return;
    setState(() {
      _firstName = session?['firstname']?.toString();
      _lastName = session?['lastname']?.toString();
      _riderId = session?['rider_id']?.toString();
    });
    debugPrint('[AccountActivation] _loadUserDetails: riderId=$_riderId firstName=$_firstName lastName=$_lastName');
  }

  @override
  void dispose() {
    _middleNameController.dispose();
    _vehicleModelController.dispose();
    _plateNoController.dispose();
    _driversLicenseNoController.dispose();
    _tinNoController.dispose();
    _sssNoController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(String path) onSelected) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) {
      debugPrint('[AccountActivation] _pickImage: user cancelled or no image');
      return;
    }

    debugPrint('[AccountActivation] _pickImage: selected path=${image.path}');
    setState(() {
      onSelected(image.path);
    });
  }

  Future<void> _openMapForAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectAddressMapPage(),
      ),
    );

    if (result is Map) {
      final lat = result['lat'];
      final lng = result['lng'];
      debugPrint('[AccountActivation] _openMapForAddress: result lat=$lat lng=$lng keys=${result.keys.toList()}');
      if (lat is num && lng is num) {
        setState(() {
          _addressLat = lat.toDouble();
          _addressLng = lng.toDouble();
          _address = result['address']?.toString() ?? 
              'Lat: ${_addressLat!.toStringAsFixed(5)}, Lng: ${_addressLng!.toStringAsFixed(5)}';
          
          // Auto-fill address fields
          final city = result['city']?.toString() ?? '';
          final state = result['state']?.toString() ?? '';
          final road = result['road']?.toString() ?? '';
          
          if (city.isNotEmpty) {
            _cityController.text = city;
          }
          if (state.isNotEmpty) {
            _stateController.text = state;
          }
          if (road.isNotEmpty) {
            _addressLine1Controller.text = road;
          }
        });
        debugPrint('[AccountActivation] _openMapForAddress: set address lat=$_addressLat lng=$_addressLng city=${_cityController.text} state=${_stateController.text}');
      } else {
        debugPrint('[AccountActivation] _openMapForAddress: invalid lat/lng types');
      }
    } else {
      debugPrint('[AccountActivation] _openMapForAddress: no result or back pressed');
    }
  }

  Future<void> _submit() async {
    debugPrint('[AccountActivation] _submit: started');
    if (!_formKey.currentState!.validate()) {
      debugPrint('[AccountActivation] _submit: form validation failed');
      return;
    }

    final missingUploads = <String>[];
    if (_profilePicPath == null) missingUploads.add('Profile Picture');
    if (_driversLicensePath == null) {
      missingUploads.add('Driver\'s License');
    }
    if (_plateNoPath == null) missingUploads.add('Plate Number Photo');
    if (_selfieWithIdPath == null) {
      missingUploads.add('Selfie with ID');
    }
    if (_selfieWithPlateNoPath == null) {
      missingUploads.add('Selfie with Plate Number');
    }
    if (_tinNoPath == null) missingUploads.add('TIN Document');
    if (_sssNoPath == null) missingUploads.add('SSS Document');

    if (_addressLat == null || _addressLng == null) {
      debugPrint('[AccountActivation] _submit: address not selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your address on the map.'),
        ),
      );
      return;
    }

    if (missingUploads.isNotEmpty) {
      debugPrint('[AccountActivation] _submit: missing uploads: $missingUploads');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please upload the following: ${missingUploads.join(', ')}',
          ),
        ),
      );
      return;
    }

    final hasConnection = await NetworkService.hasInternetConnection();
    if (!hasConnection) {
      NetworkService.showNetworkErrorSnackBar(
        context,
        customMessage: 'No internet connection. Please try again later.',
      );
      return;
    }

    if (_riderId == null || _riderId!.isEmpty) {
      debugPrint('[AccountActivation] _submit: no RiderId in session');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to find Rider ID. Please log in again.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final url = ApiConfig.apiUri('/updateRiderProfile');
      debugPrint('[AccountActivation] _submit: url=$url');
      final request = http.MultipartRequest('POST', url);

      // Attach bearer token (same behavior as ApiClient)
      final session = await UserSessionDB.getSession();
      final token = session?['access_token']?.toString();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
        debugPrint('[AccountActivation] _submit: auth token attached');
      } else {
        debugPrint('[AccountActivation] _submit: no auth token in session');
      }

      // Fields (multipart form data requires string values)
      final fields = {
        'RiderId': (int.tryParse(_riderId!) ?? _riderId!).toString(),
        'FirstName': _firstName ?? '',
        'LastName': _lastName ?? '',
        'MiddleName': _middleNameController.text.trim(),
        'VehicleModel': _vehicleModelController.text.trim(),
        'PlateNo': _plateNoController.text.trim(),
        'DriversLicenseNo': _driversLicenseNoController.text.trim(),
        'City': _cityController.text.trim(),
        'State': _stateController.text.trim(),
        'AddressLine1': _addressLine1Controller.text.trim(),
        'AddressLine2': _addressLine2Controller.text.trim(),
        'AddressLat': _addressLat!.toString(),
        'AddressLng': _addressLng!.toString(),
        'TINNo': _tinNoController.text.trim(),
        'SSSNo': _sssNoController.text.trim(),
      };
      request.fields.addAll(fields);
      debugPrint('[AccountActivation] _submit: fields=${fields.toString()}');

      Future<void> addFileIfPresent(String fieldName, String? path) async {
        if (path == null || path.trim().isEmpty) return;
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('[AccountActivation] _submit: file not found for $fieldName: $path');
          return;
        }
        request.files.add(await http.MultipartFile.fromPath(fieldName, path));
        debugPrint('[AccountActivation] _submit: added file $fieldName -> $path');
      }

      // Files (use the API's parameter names)
      await addFileIfPresent('ProfilePicPath', _profilePicPath);
      await addFileIfPresent('DriversLicensePath', _driversLicensePath);
      await addFileIfPresent('PlateNoPath', _plateNoPath);
      await addFileIfPresent('SelfieWithIdPath', _selfieWithIdPath);
      await addFileIfPresent('SelfieWithPlateNoPath', _selfieWithPlateNoPath);
      await addFileIfPresent('TINNoPath', _tinNoPath);
      await addFileIfPresent('SSSNoPath', _sssNoPath);
      debugPrint('[AccountActivation] _submit: total files=${request.files.length}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[AccountActivation] _submit: statusCode=${response.statusCode} body=${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }

        String? message;
        bool success = false;

        if (data is Map<String, dynamic>) {
          success = (data['status_code'] == 200) ||
              (data['StatusCode'] == 200) ||
              (data['success'] == true);
          message = data['message']?.toString();
        } else if (data is String) {
          // JSON body was a string (e.g. "User ... saved with image.")
          success = true;
          message = data;
        } else {
          // HTTP 200/201 with plain text or unparseable body → treat as success
          success = true;
          final body = response.body.trim();
          if (body.isNotEmpty) {
            message = body.startsWith('"') && body.endsWith('"')
                ? body.substring(1, body.length - 1) // strip JSON string quotes
                : body;
          }
        }

        if (success) {
          debugPrint('[AccountActivation] _submit: success message=$message');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Profile updated successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          debugPrint('[AccountActivation] _submit: API returned not success data=$data');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message ??
                    'Failed to update profile. Please try again later.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        debugPrint('[AccountActivation] _submit: HTTP error ${response.statusCode} body=${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile. (${response.statusCode})',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on SocketException catch (e) {
      debugPrint('[AccountActivation] _submit: SocketException $e');
      if (!mounted) return;
      NetworkService.showNetworkErrorSnackBar(
        context,
        customMessage: NetworkService.getNetworkErrorMessage(e),
      );
    } on NetworkException catch (e) {
      debugPrint('[AccountActivation] _submit: NetworkException ${e.message}');
      if (!mounted) return;
      NetworkService.showNetworkErrorSnackBar(
        context,
        customMessage: e.message,
      );
    } catch (e, stackTrace) {
      debugPrint('[AccountActivation] _submit: unexpected error $e');
      debugPrint('[AccountActivation] _submit: stackTrace $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5D8AA8),
        ),
      ),
    );
  }

  Widget _buildImagePickerTile({
    required String label,
    required String? path,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: const Icon(Icons.image, color: Color(0xFF5D8AA8)),
        title: Text(label),
        subtitle: Text(
          path ?? 'No file selected',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.upload_file, color: Color(0xFF5D8AA8)),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activate your Account'),
        backgroundColor: const Color(0xFF5D8AA8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_firstName != null || _lastName != null)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rider Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D8AA8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_firstName ?? ''} ${_lastName ?? ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_riderId != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Rider ID: $_riderId',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _buildSectionTitle('Vehicle Information'),
              TextFormField(
                controller: _middleNameController,
                decoration: const InputDecoration(
                  labelText: 'Middle Name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleModelController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Model',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your vehicle model';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plateNoController,
                decoration: const InputDecoration(
                  labelText: 'Plate Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your plate number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _driversLicenseNoController,
                decoration: const InputDecoration(
                  labelText: 'Driver\'s License Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your driver\'s license number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildSectionTitle('Address'),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your city';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stateController,
                decoration: const InputDecoration(
                  labelText: 'State / Province',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your state or province';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 1',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your primary address line';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressLine2Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 2 (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const Icon(Icons.map, color: Color(0xFF5D8AA8)),
                  title: Text(
                    _address ?? 'No address selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Tap to open map for address selection'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openMapForAddress,
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionTitle('Profile Photo'),
              _buildImagePickerTile(
                label: 'Profile Picture',
                path: _profilePicPath,
                onTap: () => _pickImage(
                  (path) => _profilePicPath = path,
                ),
              ),
              const SizedBox(height: 8),
              _buildSectionTitle('Driver & Vehicle Documents'),
              _buildImagePickerTile(
                label: 'Driver\'s License',
                path: _driversLicensePath,
                onTap: () => _pickImage(
                  (path) => _driversLicensePath = path,
                ),
              ),
              _buildImagePickerTile(
                label: 'Plate Number Photo',
                path: _plateNoPath,
                onTap: () => _pickImage(
                  (path) => _plateNoPath = path,
                ),
              ),
              _buildImagePickerTile(
                label: 'Selfie with ID',
                path: _selfieWithIdPath,
                onTap: () => _pickImage(
                  (path) => _selfieWithIdPath = path,
                ),
              ),
              _buildImagePickerTile(
                label: 'Selfie with Plate Number',
                path: _selfieWithPlateNoPath,
                onTap: () => _pickImage(
                  (path) => _selfieWithPlateNoPath = path,
                ),
              ),
              const SizedBox(height: 8),
              _buildSectionTitle('Government IDs'),
              TextFormField(
                controller: _tinNoController,
                decoration: const InputDecoration(
                  labelText: 'TIN Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your TIN number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildImagePickerTile(
                label: 'TIN Document',
                path: _tinNoPath,
                onTap: () => _pickImage(
                  (path) => _tinNoPath = path,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sssNoController,
                decoration: const InputDecoration(
                  labelText: 'SSS Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your SSS number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildImagePickerTile(
                label: 'SSS Document',
                path: _sssNoPath,
                onTap: () => _pickImage(
                  (path) => _sssNoPath = path,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSubmitting
                        ? const Color(0xFF5D8AA8).withOpacity(0.7)
                        : const Color(0xFF5D8AA8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Submit for Verification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

