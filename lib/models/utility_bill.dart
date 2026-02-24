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

/// One specific cost on a bill (e.g., "Electricity Usage" vs "Service Fee").
class UtilityLineItem {
  final String description;
  final double amount;
  final bool isWeighted; // true for usage-based, false for fixed fees

  const UtilityLineItem({
    required this.description,
    required this.amount,
    this.isWeighted = false,
  });

  Map<String, dynamic> toMap() => {
        'description': description,
        'amount': amount,
        'isWeighted': isWeighted,
      };

  factory UtilityLineItem.fromMap(Map<String, dynamic> m) => UtilityLineItem(
        description: m['description'] as String,
        amount: (m['amount'] as num).toDouble(),
        isWeighted: m['isWeighted'] as bool? ?? false,
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
  final List<UtilityLineItem> lineItems; // Added for granular tracking
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
    this.lineItems = const [],
    this.notes,
  });

  // ... (rest of the manual methods remain, but updated calcAmounts logic)
  
  /// Calculates splits based on user manual logic:
  /// - Fixed Line Items split evenly.
  /// - Weighted Line Items split according to roommate weights (e.g. 50/25/25).
  static List<UtilitySplit> distributeGranular({
    required List<UtilityLineItem> items,
    required List<UtilitySplit> currentSplits,
  }) {
    final roommateCount = currentSplits.length;
    if (roommateCount == 0) return currentSplits;

    final totals = <String, double>{};
    for (var split in currentSplits) {
      totals[split.userName] = 0.0;
    }

    // Process each line item
    for (var item in items) {
      if (item.isWeighted) {
        // Apply weighted split (e.g. 50/25/25)
        final totalWeight = currentSplits.fold<double>(0, (s, sp) => s + sp.weight);
        if (totalWeight > 0) {
          for (var split in currentSplits) {
            totals[split.userName] = totals[split.userName]! + (split.weight / totalWeight) * item.amount;
          }
        }
      } else {
        // Apply even split (1/3 each)
        final evenShare = item.amount / roommateCount;
        for (var split in currentSplits) {
          totals[split.userName] = totals[split.userName]! + evenShare;
        }
      }
    }

    return currentSplits.map((sp) => sp.copyWith(amount: totals[sp.userName])).toList();
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
        'lineItems':   lineItems.map((i) => i.toMap()).toList(),
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
      lineItems: d['lineItems'] != null 
          ? (d['lineItems'] as List).map((i) => UtilityLineItem.fromMap(Map<String, dynamic>.from(i))).toList()
          : [],
      notes:       d['notes'] as String?,
    );
  }

  UtilityBill copyWith({
    String? name,
    UtilityCategory? category,
    double? totalAmount,
    DateTime? dueDate,
    List<UtilitySplit>? splits,
    List<UtilityLineItem>? lineItems,
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
        lineItems:   lineItems     ?? this.lineItems,
        notes:       notes         ?? this.notes,
      );
}
