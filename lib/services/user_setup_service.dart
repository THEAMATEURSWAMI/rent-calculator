import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/default_users.dart';

class UserSetupService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates the 3 default user accounts in Firebase
  /// if they don't already exist. Safe to call multiple times.
  static Future<void> createDefaultUsersIfNeeded() async {
    for (final user in DefaultUsers.users) {
      await _createOrUpdateUser(user);
    }
    // Auto-seed February 2026 data as requested
    await _seedFebruaryData();
  }

  static Future<void> _seedFebruaryData() async {
    final firestore = FirebaseFirestore.instance;
    final febBills = await firestore
        .collection('utility_bills')
        .where('month', isEqualTo: 2)
        .where('year', isEqualTo: 2026)
        .limit(1)
        .get();

    if (febBills.docs.isNotEmpty) return; // Already seeded

    debugPrint('Seeding February 2026 data...');

    // 1. Building Bill
    await firestore.collection('utility_bills').add({
      'name': 'February Building Bill',
      'category': 'rent',
      'totalAmount': 2030.99,
      'month': 2,
      'year': 2026,
      'dueDate': Timestamp.fromDate(DateTime(2026, 2, 15)),
      'notes': 'Auto-filled from ResMan screenshot',
      'lineItems': [
        {'description': 'Rent', 'amount': 1803.0, 'isWeighted': false},
        {'description': 'Resident Services', 'amount': 97.0, 'isWeighted': false},
        {'description': 'Wi-Fi', 'amount': 70.0, 'isWeighted': false},
        {'description': 'Smart Home', 'amount': 40.0, 'isWeighted': false},
        {'description': 'CAM Fee', 'amount': 12.0, 'isWeighted': false},
        {'description': 'Trash Admin', 'amount': 3.0, 'isWeighted': false},
        {'description': 'Credit Builder', 'amount': 5.99, 'isWeighted': true},
      ],
      'splits': [
        {'userName': 'Roommate A', 'weight': 0.25, 'amount': 512.24, 'isPaid': false},
        {'userName': 'Roommate B', 'weight': 0.25, 'amount': 506.25, 'isPaid': false},
        {'userName': 'Roommate C', 'weight': 0.50, 'amount': 1012.50, 'isPaid': false},
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Utility Bill
    await firestore.collection('utility_bills').add({
      'name': 'February Utilities',
      'category': 'electricity',
      'totalAmount': 303.23,
      'month': 2,
      'year': 2026,
      'dueDate': Timestamp.fromDate(DateTime(2026, 2, 15)),
      'notes': r'Auto-filled from Austin Energy screenshot (includes $200 deposit)',
      'lineItems': [
        {'description': 'Electric Usage', 'amount': 76.41, 'isWeighted': true},
        {'description': 'Anti-litter', 'amount': 10.25, 'isWeighted': false},
        {'description': 'Transportation Fee', 'amount': 16.57, 'isWeighted': false},
        {'description': 'Other (Deposit)', 'amount': 200.0, 'isWeighted': false},
      ],
      'splits': [
        {'userName': 'Roommate A', 'weight': 1.0, 'amount': 113.82, 'isPaid': false},
        {'userName': 'Roommate B', 'weight': 0.5, 'amount': 94.71, 'isPaid': false},
        {'userName': 'Roommate C', 'weight': 0.5, 'amount': 94.71, 'isPaid': false},
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });
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
