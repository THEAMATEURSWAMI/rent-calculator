import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/default_users.dart';

class UserSetupService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates the 3 default user accounts (Jacob, Nico, Eddy) in Firebase
  /// if they don't already exist. Safe to call multiple times.
  static Future<void> createDefaultUsersIfNeeded() async {
    for (final user in DefaultUsers.users) {
      await _createOrUpdateUser(user);
    }
  }

  static Future<void> _createOrUpdateUser(DefaultUser user) async {
    try {
      // Try to create the account
      await _auth.createUserWithEmailAndPassword(
        email: user.email,
        password: user.password,
      );
      debugPrint('Created default user: ${user.name} (${user.email})');
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Account already exists — that's fine
        debugPrint('Default user already exists: ${user.name}');
      } else {
        debugPrint('Error creating user ${user.name}: ${e.message}');
      }
    }
  }
}
