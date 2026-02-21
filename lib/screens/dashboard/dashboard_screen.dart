import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../services/remember_me_service.dart';
import '../../models/rent_payment.dart';
import '../../services/rent_calculator_service.dart';
import '../../widgets/month_calendar_widget.dart';
import '../../widgets/avatar_selector_widget.dart';
import '../../widgets/app_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _avatarId = 0;

  @override
  void initState() {
    super.initState();
    // Load saved avatar once we have the email
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final email = context.read<FirebaseService>().currentUser?.email ?? '';
      final id = await AvatarSelectorWidget.getSavedAvatarId(_nameFrom(email));
      if (mounted) setState(() => _avatarId = id);
    });
  }

  String _nameFrom(String email) {
    final base = email.split('@').first;
    return base.isEmpty ? '' : base[0].toUpperCase() + base.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.watch<FirebaseService>();
    final userId = firebaseService.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final displayName = _nameFrom(firebaseService.currentUser?.email ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent Calculator'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: AvatarBadge(userName: displayName, size: 36),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<List<RentPayment>>(
        stream: firebaseService.getRentPayments(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final err = snapshot.error.toString();
            final isIndex = err.contains('failed-precondition') ||
                err.contains('requires an index');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isIndex ? Icons.hourglass_top : Icons.error_outline,
                        size: 48, color: isIndex ? Colors.orange : Colors.red),
                    const SizedBox(height: 16),
                    Text(isIndex ? 'Database index building…' : 'Something went wrong',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(isIndex
                        ? 'Only takes a minute on first setup. Wait then refresh.'
                        : err,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/dashboard'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            );
          }

          final payments = snapshot.data ?? [];
          final now = DateTime.now();
          final upcoming = RentCalculatorService.getUpcomingPayments(payments, 30);
          final totalDue = RentCalculatorService.calculateTotalRentDue(
              payments, now, now.add(const Duration(days: 30)));

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Quick Actions (NOW AT TOP) ──────────────────────────
                    Text('Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 12, 
                        runSpacing: 12,
                        alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
                        children: [
                          _ActionButton(icon: Icons.add,
                              label: 'Add Rent', onTap: () => context.go('/rent/add')),
                          _ActionButton(icon: Icons.receipt_long,
                              label: 'View Rent', onTap: () => context.go('/rent')),
                          _ActionButton(icon: Icons.account_balance,
                              label: 'Budget', onTap: () => context.go('/budget')),
                          _ActionButton(icon: Icons.attach_money,
                              label: 'Expenses', onTap: () => context.go('/expenses')),
                          _ActionButton(icon: Icons.account_balance_wallet,
                              label: 'Connect Bank', onTap: () => context.go('/plaid')),
                          _ActionButton(icon: Icons.water_drop_outlined,
                              label: 'Cost Split', onTap: () => context.go('/utilities')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Summary Section ─────────────────────────────────────
                    Text('Overview',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (isMobile) 
                      Column(
                        children: [
                          _SummaryCard(
                            title: 'Total Due (30 days)',
                            value: '\$${totalDue.toStringAsFixed(2)}',
                            icon: Icons.account_balance_wallet, color: Colors.blue),
                          const SizedBox(height: 12),
                          _SummaryCard(
                            title: 'Upcoming Payments',
                            value: upcoming.length.toString(),
                            icon: Icons.calendar_today, color: Colors.orange),
                          const SizedBox(height: 12),
                          _SummaryCard(
                            title: 'Paid This Month',
                            value: '\$${payments.where((p) => p.isPaid && p.paidDate != null && p.paidDate!.month == now.month).fold<double>(0, (s, p) => s + p.amount).toStringAsFixed(2)}',
                            icon: Icons.check_circle, color: Colors.green),
                          const SizedBox(height: 12),
                          _SummaryCard(
                            title: 'Monthly Average',
                            value: '\$${RentCalculatorService.calculateMonthlyAverage(payments).toStringAsFixed(2)}',
                            icon: Icons.trending_up, color: Colors.purple),
                        ],
                      )
                    else 
                      Column(
                        children: [
                          Row(children: [
                            Expanded(child: _SummaryCard(
                              title: 'Total Due (30 days)',
                              value: '\$${totalDue.toStringAsFixed(2)}',
                              icon: Icons.account_balance_wallet, color: Colors.blue)),
                            const SizedBox(width: 16),
                            Expanded(child: _SummaryCard(
                              title: 'Upcoming Payments',
                              value: upcoming.length.toString(),
                              icon: Icons.calendar_today, color: Colors.orange)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: _SummaryCard(
                              title: 'Paid This Month',
                              value: '\$${payments.where((p) => p.isPaid && p.paidDate != null && p.paidDate!.month == now.month).fold<double>(0, (s, p) => s + p.amount).toStringAsFixed(2)}',
                              icon: Icons.check_circle, color: Colors.green)),
                            const SizedBox(width: 16),
                            Expanded(child: _SummaryCard(
                              title: 'Monthly Average',
                              value: '\$${RentCalculatorService.calculateMonthlyAverage(payments).toStringAsFixed(2)}',
                              icon: Icons.trending_up, color: Colors.purple)),
                          ]),
                        ],
                      ),
                    const SizedBox(height: 32),

                    // ── Calendar Section ────────────────────────────────────
                    Text('Payments Calendar',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: MonthCalendarWidget(
                          onDateTap: (date) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(DateFormat('EEEE, MMMM d, yyyy').format(date)),
                              duration: const Duration(seconds: 2),
                            ));
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Upcoming Payments ────────────────────────────────────
                    Text('Upcoming Payments',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (upcoming.isEmpty)
                      Card(child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('No upcoming payments',
                            style: TextStyle(color: Colors.grey[600]))),
                      ))
                    else
                      ...upcoming.take(5).map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: p.isPaid ? Colors.green : Colors.orange,
                            child: Icon(p.isPaid ? Icons.check : Icons.pending,
                                color: Colors.white),
                          ),
                          title: Text('\$${p.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text(
                              'Due: ${DateFormat('MMM dd, yyyy').format(p.dueDate)}'),
                          trailing: p.isPaid
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                        ),
                      )),
                  ],
                ),
              );
            },
          );
        },
      ),
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title, required this.value,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
