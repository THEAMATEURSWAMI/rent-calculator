import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories of shared household costs.
enum UtilityCategory {
  rent,
  electricity,
  water,
  gas,
  internet,
  trash,
  other;

  String get label => switch (this) {
        rent        => 'Rent',
        electricity => 'Electricity',
        water       => 'Water',
        gas         => 'Gas',
        internet    => 'Internet',
        trash       => 'Trash',
        other       => 'Other',
      };

  String get emoji => switch (this) {
        rent        => '🏠',
        electricity => '⚡',
        water       => '💧',
        gas         => '🔥',
        internet    => '🌐',
        trash       => '🗑️',
        other       => '📦',
      };

  static UtilityCategory fromString(String s) =>
      UtilityCategory.values.firstWhere(
        (c) => c.name == s,
        orElse: () => UtilityCategory.other,
      );
}

/// One person's share of a utility bill.
class UtilitySplit {
  final String userName;  // "Jacob" | "Nico" | "Eddy"
  final double weight;    // relative weight — higher = larger share
  final double amount;    // calculated: (weight / totalWeight) * totalAmount
  final bool isPaid;
  final DateTime? paidDate;

  const UtilitySplit({
    required this.userName,
    required this.weight,
    required this.amount,
    this.isPaid = false,
    this.paidDate,
  });

  UtilitySplit copyWith({
    double? weight,
    double? amount,
    bool? isPaid,
    DateTime? paidDate,
  }) =>
      UtilitySplit(
        userName: userName,
        weight:   weight   ?? this.weight,
        amount:   amount   ?? this.amount,
        isPaid:   isPaid   ?? this.isPaid,
        paidDate: paidDate ?? this.paidDate,
      );

  Map<String, dynamic> toMap() => {
        'userName': userName,
        'weight':   weight,
        'amount':   amount,
        'isPaid':   isPaid,
        'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      };

  factory UtilitySplit.fromMap(Map<String, dynamic> m) => UtilitySplit(
        userName: m['userName'] as String,
        weight:   (m['weight']  as num).toDouble(),
        amount:   (m['amount']  as num).toDouble(),
        isPaid:   m['isPaid']  as bool? ?? false,
        paidDate: m['paidDate'] != null
            ? (m['paidDate'] as Timestamp).toDate()
            : null,
      );
}

/// A shared household bill with weighted per-person splits.
class UtilityBill {
  final String? id;
  final String name;
  final UtilityCategory category;
  final double totalAmount;
  final DateTime dueDate;
  final int month;
  final int year;
  final List<UtilitySplit> splits;
  final String? notes;

  const UtilityBill({
    this.id,
    required this.name,
    required this.category,
    required this.totalAmount,
    required this.dueDate,
    required this.month,
    required this.year,
    required this.splits,
    this.notes,
  });

  // ── computed ──────────────────────────────────────────────────────────────

  double get paidAmount =>
      splits.where((s) => s.isPaid).fold(0, (acc, s) => acc + s.amount);

  double get remainingAmount => totalAmount - paidAmount;

  bool get isFullyPaid => splits.every((s) => s.isPaid);

  UtilitySplit? splitFor(String userName) {
    try {
      return splits.firstWhere((s) => s.userName == userName);
    } catch (_) {
      return null;
    }
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'name':        name,
        'category':    category.name,
        'totalAmount': totalAmount,
        'dueDate':     Timestamp.fromDate(dueDate),
        'month':       month,
        'year':        year,
        'splits':      splits.map((s) => s.toMap()).toList(),
        'notes':       notes,
        'createdAt':   FieldValue.serverTimestamp(),
        'updatedAt':   FieldValue.serverTimestamp(),
      };

  factory UtilityBill.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UtilityBill(
      id:          doc.id,
      name:        d['name']     as String,
      category:    UtilityCategory.fromString(d['category'] as String),
      totalAmount: (d['totalAmount'] as num).toDouble(),
      dueDate:     (d['dueDate'] as Timestamp).toDate(),
      month:       d['month'] as int,
      year:        d['year']  as int,
      splits:      (d['splits'] as List)
          .map((s) => UtilitySplit.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      notes:       d['notes'] as String?,
    );
  }

  UtilityBill copyWith({
    String? name,
    UtilityCategory? category,
    double? totalAmount,
    DateTime? dueDate,
    List<UtilitySplit>? splits,
    String? notes,
  }) =>
      UtilityBill(
        id:          id,
        name:        name          ?? this.name,
        category:    category      ?? this.category,
        totalAmount: totalAmount   ?? this.totalAmount,
        dueDate:     dueDate       ?? this.dueDate,
        month:       dueDate?.month ?? month,
        year:        dueDate?.year  ?? year,
        splits:      splits        ?? this.splits,
        notes:       notes         ?? this.notes,
      );

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Recalculates each split's `amount` from the current weights.
  static List<UtilitySplit> calcAmounts(
      List<UtilitySplit> splits, double total) {
    final totalWeight = splits.fold<double>(0, (s, sp) => s + sp.weight);
    if (totalWeight == 0) return splits;
    return splits
        .map((sp) => sp.copyWith(
              amount: (sp.weight / totalWeight) * total,
            ))
        .toList();
  }
}
