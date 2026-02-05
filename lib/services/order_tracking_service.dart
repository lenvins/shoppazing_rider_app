import 'package:cloud_firestore/cloud_firestore.dart';

class RiderOrderTrackingService {
  final String orderId;
  RiderOrderTrackingService(this.orderId);

  Future<void> updateTracking(
      double latitude, double longitude, String status, DateTime eta) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'riderLocation': {'lat': latitude, 'lng': longitude},
      'status': status,
      'eta': eta.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
