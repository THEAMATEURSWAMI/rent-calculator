import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rent_payment.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/plaid_account.dart';
import '../models/utility_bill.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Auth Methods
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Rent Payment Methods
  Stream<List<RentPayment>> getRentPayments(String userId) {
    return _firestore
        .collection('rent_payments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final payments = snapshot.docs
              .map((doc) => RentPayment.fromFirestore(doc))
              .toList();
          // Sort client-side — no composite index needed
          payments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return payments;
        });
  }

  Future<void> addRentPayment(RentPayment payment) async {
    await _firestore.collection('rent_payments').add(payment.toFirestore());
  }

  Future<void> updateRentPayment(RentPayment payment) async {
    if (payment.id != null) {
      await _firestore
          .collection('rent_payments')
          .doc(payment.id)
          .update(payment.toFirestore());
    }
  }

  Future<void> deleteRentPayment(String paymentId) async {
    await _firestore.collection('rent_payments').doc(paymentId).delete();
  }

  Future<void> markRentPaymentAsPaid(String paymentId) async {
    await _firestore.collection('rent_payments').doc(paymentId).update({
      'isPaid': true,
      'paidDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Expense Methods
  Stream<List<Expense>> getExpenses(String userId, {DateTime? startDate, DateTime? endDate}) {
    return _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          var expenses = snapshot.docs
              .map((doc) => Expense.fromFirestore(doc))
              .toList();
          // Filter and sort client-side — no composite index needed
          if (startDate != null) {
            expenses = expenses
                .where((e) => !e.date.isBefore(startDate))
                .toList();
          }
          if (endDate != null) {
            expenses = expenses
                .where((e) => !e.date.isAfter(endDate))
                .toList();
          }
          expenses.sort((a, b) => b.date.compareTo(a.date));
          return expenses;
        });
  }

  Future<void> addExpense(Expense expense) async {
    await _firestore.collection('expenses').add(expense.toFirestore());
  }

  Future<void> updateExpense(Expense expense) async {
    if (expense.id != null) {
      await _firestore
          .collection('expenses')
          .doc(expense.id)
          .update(expense.toFirestore());
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    await _firestore.collection('expenses').doc(expenseId).delete();
  }

  // Budget Methods
  Stream<List<Budget>> getBudgets(String userId) {
    return _firestore
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final budgets = snapshot.docs
              .map((doc) => Budget.fromFirestore(doc))
              .toList();
          // Sort client-side — no composite index needed
          budgets.sort((a, b) => a.startDate.compareTo(b.startDate));
          return budgets;
        });
  }

  Future<void> addBudget(Budget budget) async {
    await _firestore.collection('budgets').add(budget.toFirestore());
  }

  Future<void> updateBudget(Budget budget) async {
    if (budget.id != null) {
      await _firestore
          .collection('budgets')
          .doc(budget.id)
          .update(budget.toFirestore());
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    await _firestore.collection('budgets').doc(budgetId).delete();
  }

  // ── Utility Bills / Cost Splitting ──────────────────────────────────────────

  /// Stream of all utility bills for a given month/year, sorted by due date.
  Stream<List<UtilityBill>> getUtilityBills({
    required int month,
    required int year,
  }) {
    // Query by year only — no composite index needed.
    // Month filter applied client-side.
    return _firestore
        .collection('utility_bills')
        .where('year', isEqualTo: year)
        .snapshots()
        .map((snap) {
          final bills = snap.docs
              .map((d) => UtilityBill.fromFirestore(d))
              .where((b) => b.month == month)
              .toList();
          bills.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return bills;
        });
  }

  Future<void> addUtilityBill(UtilityBill bill) async {
    await _firestore.collection('utility_bills').add(bill.toFirestore());
  }

  Future<void> updateUtilityBill(UtilityBill bill) async {
    if (bill.id == null) return;
    final data = bill.toFirestore()
      ..remove('createdAt');  // don't overwrite the original create time
    await _firestore
        .collection('utility_bills')
        .doc(bill.id)
        .update(data);
  }

  Future<void> deleteUtilityBill(String billId) async {
    await _firestore.collection('utility_bills').doc(billId).delete();
  }

  /// Marks one person's split as paid (or unpaid).
  Future<void> markSplitPaid({
    required String billId,
    required String userName,
    required bool isPaid,
    required List<UtilitySplit> currentSplits,
  }) async {
    final updated = currentSplits.map((s) {
      if (s.userName != userName) return s.toMap();
      return s
          .copyWith(
            isPaid:   isPaid,
            paidDate: isPaid ? DateTime.now() : null,
          )
          .toMap();
    }).toList();

    await _firestore
        .collection('utility_bills')
        .doc(billId)
        .update({
          'splits':    updated,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // ── Plaid / Bank connection ─────────────────────────────────────────────────

  /// Saves (or overwrites) the list of linked Plaid accounts for a user.
  Future<void> savePlaidConnection({
    required String userId,
    required String institutionId,
    required String institutionName,
    required List<PlaidAccount> accounts,
  }) async {
    final data = {
      'institutionId': institutionId,
      'institutionName': institutionName,
      'connectedAt': FieldValue.serverTimestamp(),
      'lastSynced': FieldValue.serverTimestamp(),
      'accounts': accounts.map((a) => a.toJson()).toList(),
    };
    await _firestore
        .collection('plaid_connections')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  /// Returns the most recent Plaid connection doc for a user (or null).
  Future<Map<String, dynamic>?> getPlaidConnection(String userId) async {
    final doc = await _firestore
        .collection('plaid_connections')
        .doc(userId)
        .get();
    return doc.exists ? doc.data() : null;
  }

  /// Returns a live stream of the user's Plaid connection doc.
  Stream<Map<String, dynamic>?> plaidConnectionStream(String userId) {
    return _firestore
        .collection('plaid_connections')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  /// Removes the Plaid connection for a user.
  Future<void> disconnectPlaid(String userId) async {
    await _firestore
        .collection('plaid_connections')
        .doc(userId)
        .delete();
  }

  /// Updates `lastSynced` timestamp after a transaction sync.
  Future<void> touchPlaidSyncTime(String userId) async {
    await _firestore
        .collection('plaid_connections')
        .doc(userId)
        .update({'lastSynced': FieldValue.serverTimestamp()});
  }

  // Calculate spent amount for a budget
  Future<double> calculateBudgetSpent(String userId, String category, DateTime startDate, DateTime endDate) async {
    final expenses = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    return expenses.docs.fold<double>(
      0.0,
      (total, doc) => total + (doc.data()['amount'] as num).toDouble(),
    );
  }
}
