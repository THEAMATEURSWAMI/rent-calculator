import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String? id;
  final String userId;
  final double amount;
  final DateTime date;
  final String category; // e.g., "food", "transport", "entertainment", "rent"
  final String description;
  final String? plaidTransactionId; // If synced from Plaid
  final String? accountId; // Plaid account ID if applicable

  Expense({
    this.id,
    required this.userId,
    required this.amount,
    required this.date,
    required this.category,
    required this.description,
    this.plaidTransactionId,
    this.accountId,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      plaidTransactionId: data['plaidTransactionId'],
      accountId: data['accountId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'category': category,
      'description': description,
      'plaidTransactionId': plaidTransactionId,
      'accountId': accountId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Expense copyWith({
    String? id,
    String? userId,
    double? amount,
    DateTime? date,
    String? category,
    String? description,
    String? plaidTransactionId,
    String? accountId,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      plaidTransactionId: plaidTransactionId ?? this.plaidTransactionId,
      accountId: accountId ?? this.accountId,
    );
  }
}
