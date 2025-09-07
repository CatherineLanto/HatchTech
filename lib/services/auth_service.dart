import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  // Sign up with email and password
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // Check if username already exists
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

      // Create user with email and password
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store user data in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': username,
        'username_lower': username.toLowerCase(),
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
      });

      // Update display name
      await userCredential.user!.updateDisplayName(username);

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

  // Sign in with email and password
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login time
      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'last_login': FieldValue.serverTimestamp(),
      });

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

  // Sign in with username and password
  static Future<Map<String, dynamic>> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      // Find user by username
      final usernameQuery = await _firestore
          .collection('users')
          .where('username_lower', isEqualTo: username.toLowerCase())
          .get();

      if (usernameQuery.docs.isEmpty) {
        return {'success': false, 'message': 'No account found with this username.'};
      }

      final userDoc = usernameQuery.docs.first;
      final email = userDoc.data()['email'] as String;

      // Sign in with email
      return await signIn(email: email, password: password);
    } catch (e) {
      return {'success': false, 'message': 'An error occurred. Please try again.'};
    }
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  static Future<Map<String, dynamic>> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Password reset email sent successfully!'
      };
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

  // Get user data
  static Future<Map<String, dynamic>?> getUserData() async {
    if (currentUser == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Stream user data changes
  static Stream<Map<String, dynamic>?> getUserDataStream() {
    if (currentUser == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  // Update user profile (username only)
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

      // Check if username already exists (excluding current user)
      final usernameQuery = await _firestore
          .collection('users')
          .where('username_lower', isEqualTo: username.toLowerCase())
          .get();

      // Check if any other user has this username
      final hasConflict = usernameQuery.docs.any((doc) => doc.id != currentUser!.uid);

      if (hasConflict) {
        return {
          'success': false,
          'message': 'Username already exists. Please choose a different one.'
        };
      }

      final updates = <String, dynamic>{
        'username': username,
        'username_lower': username.toLowerCase(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      // Update display name in Firebase Auth
      await currentUser!.updateDisplayName(username);
      
      // Update username in Firestore
      await _firestore.collection('users').doc(currentUser!.uid).update(updates);

      return {
        'success': true,
        'message': 'Username updated successfully!',
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': 'An error occurred: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update username. Please try again.'};
    }
  }

  // Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  // Check if user is new (created account within last 5 minutes)
  static Future<bool> isNewUser() async {
    if (currentUser == null) return false;

    try {
      final userData = await getUserData();
      if (userData == null) return false;

      final createdAt = userData['created_at'] as Timestamp?;
      if (createdAt == null) return false;

      final now = DateTime.now();
      final accountCreated = createdAt.toDate();
      final difference = now.difference(accountCreated);

      // Consider user "new" if account was created within last 5 minutes
      return difference.inMinutes <= 5;
    } catch (e) {
      return false;
    }
  }
}
