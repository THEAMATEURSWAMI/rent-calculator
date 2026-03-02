import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/utility_bill.dart';
import '../../widgets/app_drawer.dart';

class PaymentDiscrepancyScreen extends StatelessWidget {
  const PaymentDiscrepancyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fb = context.read<FirebaseService>();
    final fmt = NumberFormat.currency(symbol: r'$');

    // Data from the user's Zelle screenshot
    final actualPayments = [
      {'date': DateTime(2026, 1, 29), 'amount': 544.47, 'note': 'February Rent', 'type': 'You paid'},
      {'date': DateTime(2026, 1, 24), 'amount': 39.00, 'note': 'Grocery', 'type': 'They paid'},
      {'date': DateTime(2026, 1, 22), 'amount': 6.70, 'note': 'Utility', 'type': 'You paid'},
      {'date': DateTime(2026, 1, 5), 'amount': 375.60, 'note': '', 'type': 'You paid'},
    ];

    // Filter payments for February period (mostly Jan late payments)
    final febPeriodPayments = actualPayments.where((p) => 
      (p['note'] as String).toLowerCase().contains('february') ||
      (p['note'] as String).toLowerCase().contains('utility') ||
      (p['date'] as DateTime).isAfter(DateTime(2026, 1, 15))
    ).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Payment Audit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoCard(),
              const SizedBox(height: 24),
              Text(
                'Actual Zelle Activity (Feb Period)',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...febPeriodPayments.map((p) => _ZelleTransactionCard(
                    date: p['date'] as DateTime,
                    amount: p['amount'] as double,
                    note: p['note'] as String,
                    type: p['type'] as String,
                    fmt: fmt,
                  )),
              const SizedBox(height: 32),
              Text(
                'Comparison (Jacob)',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _ComparisonCard(fb: fb, fmt: fmt, actualPayments: febPeriodPayments),
              const SizedBox(height: 40),
              _AutomatedVerificationSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'This page compares your actual Zelle transfers (from screenshots) against what the app calculated you owe for February.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZelleTransactionCard extends StatelessWidget {
  final DateTime date;
  final double amount;
  final String note;
  final String type;
  final NumberFormat fmt;

  const _ZelleTransactionCard({
    required this.date,
    required this.amount,
    required this.note,
    required this.type,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = type == 'They paid';
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.02),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome ? Colors.green.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? Colors.green : Colors.blue,
            size: 20,
          ),
        ),
        title: Text(note.isEmpty ? 'Transfer' : note),
        subtitle: Text(DateFormat('MMM dd, yyyy').format(date)),
        trailing: Text(
          '${isIncome ? "+" : "-"}${fmt.format(amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isIncome ? Colors.green : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final FirebaseService fb;
  final NumberFormat fmt;
  final List<Map<String, dynamic>> actualPayments;

  const _ComparisonCard({required this.fb, required this.fmt, required this.actualPayments});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UtilityBill>>(
      stream: fb.getUtilityBills(month: 2, year: 2026),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        final bills = snap.data!;
        double jacobOwed = 0;
        for (final bill in bills) {
          final jacobSplit = bill.splits.firstWhere(
            (s) => s.userName == 'Jacob',
            orElse: () => UtilitySplit(userName: 'Jacob', weight: 0, amount: 0, isPaid: false),
          );
          jacobOwed += jacobSplit.amount;
        }

        double jacobPaid = 0;
        for (final p in actualPayments) {
          if (p['type'] == 'You paid') {
            jacobPaid += p['amount'] as double;
          } else {
            // Nico paid Jacob (e.g. for groceries), so this reduces what Jacob "effectively" paid
            // Or rather, it's a separate credit. Let's keep it simple:
            // jacobPaid -= p['amount'] as double; 
          }
        }

        final diff = jacobPaid - jacobOwed;
        final isUnderpaid = diff < -0.01;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _auditRow('App Calculated (Owed)', fmt.format(jacobOwed), bold: true),
                const Divider(height: 24),
                _auditRow('Actual Paid (Zelle)', fmt.format(jacobPaid), color: Colors.green),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnderpaid ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _auditRow(
                    isUnderpaid ? 'Still Owed' : 'Credit Balance',
                    fmt.format(diff.abs()),
                    color: isUnderpaid ? Colors.orange : Colors.green,
                    bold: true,
                  ),
                ),
                if (isUnderpaid) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Note: Your "February Rent" payment of \$544.47 was slightly more than the rent split (\$512.24), but less than the total including utilities (\$626.06).',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _auditRow(String label, String value, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
          fontSize: bold ? 16 : 14,
        )),
      ],
    );
  }
}

class _AutomatedVerificationSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Automated Verification',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.auto_awesome, color: Colors.purple),
                  title: Text('Upcoming: Auto-Sync'),
                  subtitle: Text('Connect your bank or scan Zelle emails to confirm payments automatically.'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plaid integration coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.account_balance),
                  label: const Text('Connect Bank via Plaid'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
