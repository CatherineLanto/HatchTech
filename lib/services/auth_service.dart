// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // ignore: unused_field
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static User? get currentUser => _auth.currentUser;

  // ✅ Save or refresh FCM token
  static Future<void> saveFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        print('⚠️ No FCM token generated.');
        return;
      }

      // Fetch user doc
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await userRef.get();

      // 🧩 Allow multiple devices per account:
      // Store tokens in an array (so each device keeps its own)
      List<dynamic> tokens = [];
      if (doc.exists && doc.data()!.containsKey('fcmTokens')) {
        tokens = List<String>.from(doc.data()!['fcmTokens']);
      }

      if (!tokens.contains(token)) tokens.add(token);

      await userRef.update({'fcmTokens': tokens});
      print('✅ FCM token saved for ${user.email}: $token');

      // Automatically update when token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final snap = await userRef.get();
        List<dynamic> currentTokens = [];
        if (snap.exists && snap.data()!.containsKey('fcmTokens')) {
          currentTokens = List<String>.from(snap.data()!['fcmTokens']);
        }

        if (!currentTokens.contains(newToken)) {
          currentTokens.add(newToken);
          await userRef.update({'fcmTokens': currentTokens});
        }
        print('🔄 Token refreshed: $newToken');
      });
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // ✅ Update user email
  static Future<Map<String, dynamic>> updateUserEmail({
    required String userId,
    required String newEmail,
  }) async {
    try {
      if (currentUser != null && currentUser!.uid == userId) {
        await currentUser!.verifyBeforeUpdateEmail(newEmail);
      }
      await _firestore.collection('users').doc(userId).update({'email': newEmail});
      return {'success': true, 'message': 'Email updated successfully!'};
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'requires-recent-login':
          message = 'Please re-authenticate and try again.';
          break;
        default:
          message = 'An error occurred. Please try again.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update email. Please try again.'};
    }
  }

  // ✅ Sign up with email
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String username,
    required String role,
  }) async {
    try {
      final usernameQuery = await _firestore
          .collection('users')
          .where('username_lower', isEqualTo: username.toLowerCase())
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Username already exists. Please choose a different one.'
        };
      }

      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(email: email, password: password);

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': username,
        'username_lower': username.toLowerCase(),
        'email': email,
        'role': role,
        'created_at': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
        'fcmTokens': [], // initialize
      });

      await userCredential.user!.updateDisplayName(username);

      // 🟢 Save device FCM token
      await saveFcmToken();

      return {
        'success': true,
        'message': 'Account created successfully!',
        'user': userCredential.user,
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        default:
          message = 'An error occurred. Please try again.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Failed to create account. Please try again.'};
    }
  }

  // ✅ Sign in with email
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(email: email, password: password);

      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'last_login': FieldValue.serverTimestamp(),
      });

      // 🟢 Save device FCM token
      await saveFcmToken();

      return {
        'success': true,
        'message': 'Signed in successfully!',
        'user': userCredential.user,
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email address.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        default:
          message = 'Invalid email or password.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred. Please try again.'};
    }
  }

  // ✅ Sign in with username
  static Future<Map<String, dynamic>> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      final usernameQuery = await _firestore
          .collection('users')
          .where('username_lower', isEqualTo: username.toLowerCase())
          .get();

      if (usernameQuery.docs.isEmpty) {
        return {'success': false, 'message': 'No account found with this username.'};
      }

      final userDoc = usernameQuery.docs.first;
      final email = userDoc.data()['email'] as String;

      final result = await signIn(email: email, password: password);

      // 🟢 Save device FCM token (redundant safety)
      await saveFcmToken();

      return result;
    } catch (e) {
      return {'success': false, 'message': 'An error occurred. Please try again.'};
    }
  }

  // ✅ Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // ✅ Reset password
  static Future<Map<String, dynamic>> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {'success': true, 'message': 'Password reset email sent successfully!'};
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email address.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        default:
          message = 'An error occurred. Please try again.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred. Please try again.'};
    }
  }

  // ✅ Get user data
  static Future<Map<String, dynamic>?> getUserData() async {
    if (currentUser == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // ✅ Stream user data
  static Stream<Map<String, dynamic>?> getUserDataStream() {
    if (currentUser == null) return Stream.value(null);
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  // ✅ Update username
  static Future<Map<String, dynamic>> updateUserProfile({
    required String username,
  }) async {
    if (currentUser == null) {
      return {'success': false, 'message': 'No user logged in'};
    }

    try {
      if (username.isEmpty) {
        return {'success': false, 'message': 'Username cannot be empty'};
      }

      final usernameQuery = await _firestore
          .collection('users')
          .where('username_lower', isEqualTo: username.toLowerCase())
          .get();

      final hasConflict = usernameQuery.docs.any((doc) => doc.id != currentUser!.uid);

      if (hasConflict) {
        return {
          'success': false,
          'message': 'Username already exists. Please choose a different one.'
        };
      }

      await currentUser!.updateDisplayName(username);
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'username': username,
        'username_lower': username.toLowerCase(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'message': 'Username updated successfully!'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update username. Please try again.'};
    }
  }

  // ✅ Utility
  static bool get isLoggedIn => currentUser != null;

  static Future<bool> isNewUser() async {
    if (currentUser == null) return false;
    try {
      final userData = await getUserData();
      if (userData == null) return false;
      final createdAt = userData['created_at'] as Timestamp?;
      if (createdAt == null) return false;
      return DateTime.now().difference(createdAt.toDate()).inMinutes <= 5;
    } catch (_) {
      return false;
    }
  }
}
