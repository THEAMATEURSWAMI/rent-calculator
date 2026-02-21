import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/rent_payment.dart';
import '../../services/rent_calculator_service.dart';
import '../../widgets/month_calendar_widget.dart';
import '../../widgets/avatar_selector_widget.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/animate_in.dart';
import '../../utils/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load saved avatar once we have the email
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final email = context.read<FirebaseService>().currentUser?.email ?? '';
      await AvatarSelectorWidget.getSavedAvatarId(_nameFrom(email));
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.8),
                AppTheme.primaryTeal.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Rent Calculator Pro'),
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
                padding: const EdgeInsets.fromLTRB(16, 120, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Quick Actions ────────────────────────────────────
                    const AnimateIn(
                      delay: Duration(milliseconds: 100),
                      child: Text('Quick Actions',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    AnimateIn(
                      delay: const Duration(milliseconds: 200),
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 12, 
                          runSpacing: 12,
                          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
                          children: [
                            _ActionButton(icon: Icons.add,
                                label: 'Add Rent', color: AppTheme.primaryBlue,
                                onTap: () => context.go('/rent/add')),
                            _ActionButton(icon: Icons.receipt_long,
                                label: 'View Rent', color: AppTheme.primaryTeal,
                                onTap: () => context.go('/rent')),
                            _ActionButton(icon: Icons.account_balance,
                                label: 'Budget', color: AppTheme.accentOrange,
                                onTap: () => context.go('/budget')),
                            _ActionButton(icon: Icons.attach_money,
                                label: 'Expenses', color: AppTheme.accentGreen,
                                onTap: () => context.go('/expenses')),
                            _ActionButton(icon: Icons.account_balance_wallet,
                                label: 'Connect Bank', color: Colors.blueAccent,
                                onTap: () => context.go('/plaid')),
                            _ActionButton(icon: Icons.water_drop_outlined,
                                label: 'Cost Split', color: Colors.indigo,
                                onTap: () => context.go('/utilities')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Summary Section ─────────────────────────────────────
                    const AnimateIn(
                      delay: Duration(milliseconds: 300),
                      child: Text('Overview',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    AnimateIn(
                      delay: const Duration(milliseconds: 400),
                      child: Column(
                        children: [
                          if (isMobile) 
                            ...[
                              _SummaryCard(
                                title: 'Total Due (30 days)',
                                value: '\$${totalDue.toStringAsFixed(2)}',
                                icon: Icons.account_balance_wallet, color: AppTheme.primaryBlue),
                              const SizedBox(height: 12),
                              _SummaryCard(
                                title: 'Upcoming Payments',
                                value: upcoming.length.toString(),
                                icon: Icons.calendar_today, color: AppTheme.accentOrange),
                              const SizedBox(height: 12),
                              _SummaryCard(
                                title: 'Paid This Month',
                                value: '\$${payments.where((p) => p.isPaid && p.paidDate != null && p.paidDate!.month == now.month).fold<double>(0, (s, p) => s + p.amount).toStringAsFixed(2)}',
                                icon: Icons.check_circle, color: AppTheme.accentGreen),
                              const SizedBox(height: 12),
                              _SummaryCard(
                                title: 'Monthly Average',
                                value: '\$${RentCalculatorService.calculateMonthlyAverage(payments).toStringAsFixed(2)}',
                                icon: Icons.trending_up, color: Colors.purpleAccent),
                            ]
                          else 
                            ...[
                              Row(children: [
                                Expanded(child: _SummaryCard(
                                  title: 'Total Due (30 days)',
                                  value: '\$${totalDue.toStringAsFixed(2)}',
                                  icon: Icons.account_balance_wallet, color: AppTheme.primaryBlue)),
                                const SizedBox(width: 16),
                                Expanded(child: _SummaryCard(
                                  title: 'Upcoming Payments',
                                  value: upcoming.length.toString(),
                                  icon: Icons.calendar_today, color: AppTheme.accentOrange)),
                              ]),
                              const SizedBox(height: 16),
                              Row(children: [
                                Expanded(child: _SummaryCard(
                                  title: 'Paid This Month',
                                  value: '\$${payments.where((p) => p.isPaid && p.paidDate != null && p.paidDate!.month == now.month).fold<double>(0, (s, p) => s + p.amount).toStringAsFixed(2)}',
                                  icon: Icons.check_circle, color: AppTheme.accentGreen)),
                                const SizedBox(width: 16),
                                Expanded(child: _SummaryCard(
                                  title: 'Monthly Average',
                                  value: '\$${RentCalculatorService.calculateMonthlyAverage(payments).toStringAsFixed(2)}',
                                  icon: Icons.trending_up, color: Colors.purpleAccent)),
                              ]),
                            ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Calendar Section ────────────────────────────────────
                    const AnimateIn(
                      delay: Duration(milliseconds: 500),
                      child: Text('Payments Calendar',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    AnimateIn(
                      delay: const Duration(milliseconds: 600),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: MonthCalendarWidget(
                            onDateTap: (date) {
                              HapticFeedback.selectionClick();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(DateFormat('EEEE, MMMM d, yyyy').format(date)),
                                duration: const Duration(seconds: 2),
                              ));
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Upcoming Payments ────────────────────────────────────
                    const AnimateIn(
                      delay: Duration(milliseconds: 700),
                      child: Text('Upcoming Payments',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    AnimateIn(
                      delay: const Duration(milliseconds: 800),
                      child: upcoming.isEmpty
                          ? const Card(child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('No upcoming payments')),
                            ))
                          : Column(
                              children: upcoming.take(5).map((p) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: p.isPaid ? Colors.green : Colors.orange,
                                    child: Icon(p.isPaid ? Icons.check : Icons.pending,
                                        color: Colors.white),
                                  ),
                                  title: Text('\$${p.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                      'Due: ${DateFormat('MMM dd').format(p.dueDate)}'),
                                  trailing: p.isPaid
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : null,
                                ),
                              )).toList(),
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_up, size: 12, color: Colors.white24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                )),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon, 
    required this.label, 
    required this.color,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
