// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class FcmService {
  static Future<void> updateTokenForCurrentUser(User user) async {
    String? fcmToken = await FirebaseMessaging.instance.getToken();

    if (fcmToken == null) {

      await FirebaseMessaging.instance.deleteToken();

      fcmToken = await FirebaseMessaging.instance.getToken();
      
      if (fcmToken == null) {
        print('❌ Error: Could not generate a new token after deletion.');
        return;
      }
    }

    print('Attempting to save FRESH FCM Token for user ${user.uid}: $fcmToken');

    try {
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([fcmToken]),
        'last_token_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      await FirebaseDatabase.instance.ref('fcmTokens/${user.uid}').set(fcmToken);

      print('FCM Token successfully saved for user ${user.uid}.');
    } catch (e) {
      print('❌ Error saving FCM token for user ${user.uid}: $e');
    }
  }
}