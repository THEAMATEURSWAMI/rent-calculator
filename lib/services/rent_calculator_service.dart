import '../models/rent_payment.dart';
import '../models/expense.dart';
import '../models/payment_record.dart';


class RentCalculatorService {
  // Calculate total rent due for a specific period
  static double calculateTotalRentDue(
    List<RentPayment> payments,
    DateTime startDate,
    DateTime endDate,
  ) {
    return payments
        .where((payment) =>
            !payment.isPaid &&
            payment.dueDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            payment.dueDate.isBefore(endDate.add(const Duration(days: 1))))
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
  }

  // Calculate rent split among roommates
  static Map<String, double> calculateRentSplit(
    double totalRent,
    List<String> roommateIds,
  ) {
    if (roommateIds.isEmpty) return {};

    final totals = <String, double>{};
    
    // Check for our specific household logic:
    // If Jacob, Eddy, and Nico are present:
    // Jacob & Eddy pay 1/4th (25%) each.
    // Nico pays 1/2 (50%).
    final names = roommateIds.map((id) => id.split('@').first.toLowerCase()).toList();
    if (names.contains('Roommate A') && names.contains('Roommate C') && names.contains('Roommate B')) {
      for (final id in roommateIds) {
        final name = id.split('@').first.toLowerCase();
        if (name == 'Roommate A' || name == 'Roommate C') {
          totals[id] = totalRent * 0.25;
        } else if (name == 'Roommate B') {
          totals[id] = totalRent * 0.50;
        } else {
          totals[id] = totalRent / roommateIds.length;
        }
      }
      return totals;
    }

    // Default: even split
    final splitAmount = totalRent / roommateIds.length;
    for (final roommateId in roommateIds) {
      totals[roommateId] = splitAmount;
    }
    return totals;
  }

  // Calculate monthly rent average
  static double calculateMonthlyAverage(List<RentPayment> payments) {
    if (payments.isEmpty) return 0.0;
    final total = payments.fold<double>(0.0, (sum, payment) => sum + payment.amount);
    return total / payments.length;
  }

  // Get upcoming rent payments
  static List<RentPayment> getUpcomingPayments(
    List<RentPayment> payments,
    int daysAhead,
  ) {
    final now = DateTime.now();
    final cutoffDate = now.add(Duration(days: daysAhead));
    
    return payments
        .where((payment) =>
            !payment.isPaid &&
            payment.dueDate.isAfter(now.subtract(const Duration(days: 1))) &&
            payment.dueDate.isBefore(cutoffDate.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  // Calculate total expenses for a category
  static double calculateCategoryExpenses(
    List<Expense> expenses,
    String category,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    var filteredExpenses = expenses.where((expense) => expense.category == category);
    if (startDate != null) {
      filteredExpenses = filteredExpenses.where((expense) => expense.date.isAfter(startDate.subtract(const Duration(days: 1))));
    }
    if (endDate != null) {
      filteredExpenses = filteredExpenses.where((expense) => expense.date.isBefore(endDate.add(const Duration(days: 1))));
    }
    return filteredExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  // Calculate remaining budget after expenses
  static double calculateRemainingBudget(
    double budgetLimit,
    List<Expense> expenses,
    String category,
    DateTime startDate,
    DateTime endDate,
  ) {
    final spent = calculateCategoryExpenses(expenses, category, startDate, endDate);
    return budgetLimit - spent;
  }

  /// Specialized split for Electricity/Utilities:
  /// 1. Shared Fixed Fees split evenly (1/3 each).
  /// 2. Variable Usage (Actual Electricity) split: 50% for Jacob, 25% each for others.
  static Map<String, double> calculateWeightedUtilitySplit({
    required double fixedFeesTotal,
    required double usageTotal,
    required String primaryRoommateId,
    required List<String> otherRoommateIds,
  }) {
    final totals = <String, double>{};
    final allRoommatesCount = otherRoommateIds.length + 1;
    
    // 1. Split Fixed Fees evenly (1/3)
    final fixedShare = fixedFeesTotal / allRoommatesCount;
    
    // 2. Split Usage weighted (50% for Jacob, 25% each for others)
    final primaryUsageShare = usageTotal * 0.5;
    final otherUsageShare = (usageTotal * 0.5) / otherRoommateIds.length;

    totals[primaryRoommateId] = fixedShare + primaryUsageShare;
    for (final id in otherRoommateIds) {
      totals[id] = fixedShare + otherUsageShare;
    }

    return totals;
  }

  // ── Credits / Reconciliation ─────────────────────────────────────────────

  /// Sum of all prior credits for a given person (positive = they are owed money back).
  static double runningCredit({
    required String userName,
    required List<PaymentRecord> allRecords,
    int? upToMonth,
    int? upToYear,
  }) {
    return allRecords
        .where((r) {
          if (r.userName != userName) return false;
          if (upToMonth == null || upToYear == null) return true;
          // Only include records strictly before the target month
          final recordDate  = DateTime(r.year, r.month);
          final targetDate  = DateTime(upToYear, upToMonth);
          return recordDate.isBefore(targetDate);
        })
        .fold<double>(0, (sum, r) => sum + r.credit);
  }

  /// What they actually owe next month after applying their running credit.
  static double adjustedOwed({
    required double baseOwed,
    required double priorCredit,
  }) => (baseOwed - priorCredit).clamp(0, double.infinity);
}
