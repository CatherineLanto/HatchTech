import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class InviteService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String generateCode({int length = 6}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  static Future<String> createInviteCode(String role, String uid) async {
    final code = generateCode();
    await _firestore.collection('invite_codes').doc(code).set({
      'role': role,
      'created_at': FieldValue.serverTimestamp(),
      'used': false,
    });
    return code;
  }

  static Future<String?> validateInviteCode(String code) async {
    final doc = await _firestore.collection('invite_codes').doc(code).get();
    if (!doc.exists || doc['used'] == true) return null;
    return doc['role'] as String?;
  }

  static Future<void> markCodeUsed(String code) async {
    await _firestore.collection('invite_codes').doc(code).update({'used': true});
  }
}