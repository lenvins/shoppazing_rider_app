import 'package:firebase_database/firebase_database.dart';

class ChatMessage {
  final String id;
  final String senderUID;
  final String receiverUID;
  final String text;
  final DateTime timestamp;
  final String orderId;
  final String? imageUrl; // NEW: Support for image messages
  final String? messageType; // NEW: 'text' or 'image'

  ChatMessage({
    required this.id,
    required this.senderUID,
    required this.receiverUID,
    required this.text,
    required this.timestamp,
    required this.orderId,
    this.imageUrl,
    this.messageType,
  });

  Map<String, dynamic> toJson() {
    return {
      'senderUID': senderUID,
      'receiverUID': receiverUID,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'orderId': orderId,
      'imageUrl': imageUrl,
      'messageType': messageType ?? 'text',
    };
  }

  factory ChatMessage.fromJson(String id, Map<String, dynamic> json) {
    return ChatMessage(
      id: id,
      senderUID: json['senderUID'] ?? '',
      receiverUID: json['receiverUID'] ?? '',
      text: json['text'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      orderId: json['orderId'] ?? '',
      imageUrl: json['imageUrl']?.toString(),
      messageType: json['messageType']?.toString() ?? 'text',
    );
  }
}

class ChatService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Send a text message
  static Future<void> sendMessage({
    required String senderUID,
    required String receiverUID,
    required String text,
    required String orderId,
  }) async {
    try {
      print('[DEBUG] sendMessage called');
      print(
          '[DEBUG] Sending message: "$text" from $senderUID to $receiverUID for order $orderId');

      final messageRef =
          _database.child('chats').child(orderId).child('messages').push();

      final message = ChatMessage(
        id: messageRef.key!,
        senderUID: senderUID,
        receiverUID: receiverUID,
        text: text,
        timestamp: DateTime.now(),
        orderId: orderId,
        messageType: 'text',
      );

      print('[DEBUG] Message object: ' + message.toJson().toString());

      await messageRef.set(message.toJson());
      print('[DEBUG] Message sent successfully: ${message.id}');
    } catch (e) {
      print('[DEBUG] Error sending message: $e');
      rethrow;
    }
  }

  // Send an image message
  static Future<void> sendImageMessage({
    required String senderUID,
    required String receiverUID,
    required String imageUrl,
    required String orderId,
    String? caption,
  }) async {
    try {
      print('[DEBUG] sendImageMessage called');
      print(
          '[DEBUG] Sending image: "$imageUrl" from $senderUID to $receiverUID for order $orderId');

      final messageRef =
          _database.child('chats').child(orderId).child('messages').push();

      final message = ChatMessage(
        id: messageRef.key!,
        senderUID: senderUID,
        receiverUID: receiverUID,
        text: caption ?? '',
        timestamp: DateTime.now(),
        orderId: orderId,
        imageUrl: imageUrl,
        messageType: 'image',
      );

      print('[DEBUG] Image message object: ' + message.toJson().toString());

      await messageRef.set(message.toJson());
      print('[DEBUG] Image message sent successfully: ${message.id}');
    } catch (e) {
      print('[DEBUG] Error sending image message: $e');
      rethrow;
    }
  }

  // Listen to messages for a specific order
  static Stream<List<ChatMessage>> getMessagesStream(String orderId) {
    return _database
        .child('chats')
        .child(orderId)
        .child('messages')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) {
        return <ChatMessage>[];
      }

      final Map<dynamic, dynamic> messagesMap =
          event.snapshot.value as Map<dynamic, dynamic>;

      List<ChatMessage> messages = [];

      messagesMap.forEach((key, value) {
        if (value is Map) {
          final message = ChatMessage.fromJson(
            key.toString(),
            Map<String, dynamic>.from(value),
          );
          messages.add(message);
        }
      });

      // Sort messages by timestamp
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return messages;
    });
  }

  // Get messages for a specific order (one-time fetch)
  static Future<List<ChatMessage>> getMessages(String orderId) async {
    try {
      final snapshot =
          await _database.child('chats').child(orderId).child('messages').get();

      if (snapshot.value == null) {
        return <ChatMessage>[];
      }

      final Map<dynamic, dynamic> messagesMap =
          snapshot.value as Map<dynamic, dynamic>;

      List<ChatMessage> messages = [];

      messagesMap.forEach((key, value) {
        if (value is Map) {
          final message = ChatMessage.fromJson(
            key.toString(),
            Map<String, dynamic>.from(value),
          );
          messages.add(message);
        }
      });

      // Sort messages by timestamp
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return messages;
    } catch (e) {
      print('Error getting messages: $e');
      return <ChatMessage>[];
    }
  }

  // Delete all messages for an order (useful for cleanup)
  static Future<void> deleteOrderChat(String orderId) async {
    try {
      await _database.child('chats').child(orderId).remove();
      print('Chat deleted for order: $orderId');
    } catch (e) {
      print('Error deleting chat: $e');
      rethrow;
    }
  }
}
