import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/budget.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.watch<FirebaseService>();
    final userId = firebaseService.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/budget/add'),
          ),
        ],
      ),
      body: StreamBuilder<List<Budget>>(
        stream: firebaseService.getBudgets(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final isIndexError = snapshot.error.toString().contains('failed-precondition');
            return Center(
              child: Text(isIndexError
                  ? 'Database index building — please wait a moment and refresh.'
                  : 'Error: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
            );
          }

          final budgets = snapshot.data ?? [];

          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No budgets set up yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/budget/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Budget'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            budget.category.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '\$${budget.limit.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: budget.isOverBudget ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Period: ${DateFormat('MMM dd').format(budget.startDate)} - ${DateFormat('MMM dd, yyyy').format(budget.endDate)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: budget.percentageUsed / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          budget.isOverBudget ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Spent: \$${budget.spent.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: budget.isOverBudget ? Colors.red : null,
                            ),
                          ),
                          Text(
                            'Remaining: \$${budget.remaining.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: budget.isOverBudget ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
