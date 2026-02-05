import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/device_service.dart';
import '../services/user_session_db.dart';
import '../services/network_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ChatPage extends StatefulWidget {
  final String orderId;
  final String customerFirebaseUID;
  final String customerName;
  final String?
      customerUserId; // NEW: Customer user ID for stable identification

  const ChatPage({
    super.key,
    required this.orderId,
    required this.customerFirebaseUID,
    required this.customerName,
    this.customerUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  String? _currentUserUID;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _getCurrentUserUID();
    _loadMessages();
    _checkConnectivity();
  }

  Future<void> _getCurrentUserUID() async {
    // Try to get user ID from session first, fallback to Firebase UID
    final session = await UserSessionDB.getSession();
    final userId = session?['user_id']?.toString();

    if (userId != null && userId.isNotEmpty) {
      setState(() {
        _currentUserUID = userId;
      });
    } else {
      // Fallback to Firebase UID if user ID not available
      final uid = await DeviceService.getFirebaseUID();
      setState(() {
        _currentUserUID = uid;
      });
    }
  }

  Future<void> _checkConnectivity() async {
    final hasConnection = await NetworkService.hasInternetConnection();
    setState(() {
      _isOnline = hasConnection;
    });
  }

  void _loadMessages() {
    ChatService.getMessagesStream(widget.orderId).listen((messages) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // Check internet connectivity before sending
    final hasConnection = await NetworkService.hasInternetConnection();
    setState(() {
      _isOnline = hasConnection;
    });

    if (!hasConnection) {
      NetworkService.showNetworkErrorSnackBar(
        context,
        customMessage: 'Cannot send message. No internet connection.',
      );
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      // Use customer user ID if available, otherwise fallback to Firebase UID
      final receiverUID = widget.customerUserId ?? widget.customerFirebaseUID;

      await ChatService.sendMessage(
        senderUID: _currentUserUID!,
        receiverUID: receiverUID,
        text: message,
        orderId: widget.orderId,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    // Check internet connectivity before picking image
    final hasConnection = await NetworkService.hasInternetConnection();
    if (!hasConnection) {
      NetworkService.showNetworkErrorSnackBar(
        context,
        customMessage: 'Cannot send image. No internet connection.',
      );
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      // Upload image to Firebase Storage
      final String imageUrl = await _uploadImageToFirebase(File(image.path));

      // Send image message
      final receiverUID = widget.customerUserId ?? widget.customerFirebaseUID;

      await ChatService.sendImageMessage(
        senderUID: _currentUserUID!,
        receiverUID: receiverUID,
        imageUrl: imageUrl,
        orderId: widget.orderId,
      );

      setState(() {
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: $e')),
      );
    }
  }

  Future<String> _uploadImageToFirebase(File imageFile) async {
    try {
      final String fileName =
          'chat_images/${widget.orderId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);

      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF5D8AA8)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF5D8AA8),
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customerName,
                    style: const TextStyle(
                      color: Color(0xFF5D8AA8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isOnline)
                    const Text(
                      'Offline - Messages will not be sent',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            // Connectivity indicator
            Icon(
              _isOnline ? Icons.wifi : Icons.wifi_off,
              color: _isOnline ? Colors.green : Colors.red,
              size: 20,
            ),
          ],
        ),
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet. Start the conversation!',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isRider = message.senderUID == _currentUserUID;
                          return _chatBubble(message, isRider);
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: _isOnline && !_isUploadingImage,
                    decoration: InputDecoration(
                      hintText: _isOnline
                          ? 'Type a message...'
                          : 'No internet connection',
                      fillColor:
                          _isOnline ? Colors.grey[100] : Colors.grey[300],
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 0,
                      ),
                    ),
                    onSubmitted: (_) => _isOnline ? _sendMessage() : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Image picker button
                CircleAvatar(
                  backgroundColor:
                      _isOnline ? Colors.grey[600] : Colors.grey[400],
                  child: IconButton(
                    icon: const Icon(Icons.image, color: Colors.white),
                    onPressed: (_isOnline && !_isUploadingImage)
                        ? _pickAndSendImage
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                CircleAvatar(
                  backgroundColor:
                      _isOnline ? const Color(0xFF5D8AA8) : Colors.grey[400],
                  child: IconButton(
                    icon: _isUploadingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed:
                        (_isOnline && !_isUploadingImage) ? _sendMessage : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(ChatMessage message, bool isRider) {
    return Align(
      alignment: isRider ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isRider ? const Color(0xFF5D8AA8) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isRider ? 18 : 4),
            bottomRight: Radius.circular(isRider ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image message
            if (message.messageType == 'image' && message.imageUrl != null)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.imageUrl!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 50,
                          ),
                        );
                      },
                    ),
                  ),
                  if (message.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isRider ? Colors.white : const Color(0xFF5D8AA8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              )
            else
              // Text message
              Text(
                message.text,
                style: TextStyle(
                  color: isRider ? Colors.white : const Color(0xFF5D8AA8),
                  fontSize: 16,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                color: isRider ? Colors.white70 : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
