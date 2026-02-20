import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  final String? id;
  final String userId;
  final String category;
  final double limit;
  final DateTime startDate;
  final DateTime endDate;
  final double spent; // Calculated from expenses

  Budget({
    this.id,
    required this.userId,
    required this.category,
    required this.limit,
    required this.startDate,
    required this.endDate,
    this.spent = 0.0,
  });

  factory Budget.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Budget(
      id: doc.id,
      userId: data['userId'] ?? '',
      category: data['category'] ?? '',
      limit: (data['limit'] ?? 0).toDouble(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      spent: (data['spent'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'category': category,
      'limit': limit,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'spent': spent,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  double get remaining => limit - spent;
  double get percentageUsed => limit > 0 ? (spent / limit) * 100 : 0;
  bool get isOverBudget => spent > limit;

  Budget copyWith({
    String? id,
    String? userId,
    String? category,
    double? limit,
    DateTime? startDate,
    DateTime? endDate,
    double? spent,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      spent: spent ?? this.spent,
    );
  }
}
