import '../models/rent_payment.dart';
import '../models/expense.dart';

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
    if (roommateIds.isEmpty) {
      return {};
    }

    final splitAmount = totalRent / roommateIds.length;
    final split = <String, double>{};
    for (final roommateId in roommateIds) {
      split[roommateId] = splitAmount;
    }
    return split;
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
}
