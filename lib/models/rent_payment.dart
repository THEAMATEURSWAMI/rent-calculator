import 'package:cloud_firestore/cloud_firestore.dart';

class RentPayment {
  final String? id;
  final String userId;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidDate;
  final bool isPaid;
  final String? notes;
  final String? category; // e.g., "rent", "utilities", "maintenance"
  final List<String>? roommates; // IDs of roommates who share this payment

  RentPayment({
    this.id,
    required this.userId,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    this.isPaid = false,
    this.notes,
    this.category,
    this.roommates,
  });

  factory RentPayment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RentPayment(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      paidDate: data['paidDate'] != null
          ? (data['paidDate'] as Timestamp).toDate()
          : null,
      isPaid: data['isPaid'] ?? false,
      notes: data['notes'],
      category: data['category'],
      roommates: data['roommates'] != null
          ? List<String>.from(data['roommates'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      'isPaid': isPaid,
      'notes': notes,
      'category': category,
      'roommates': roommates,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  RentPayment copyWith({
    String? id,
    String? userId,
    double? amount,
    DateTime? dueDate,
    DateTime? paidDate,
    bool? isPaid,
    String? notes,
    String? category,
    List<String>? roommates,
  }) {
    return RentPayment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      isPaid: isPaid ?? this.isPaid,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      roommates: roommates ?? this.roommates,
    );
  }
}
