import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/utility_bill.dart';
import '../../models/payment_record.dart';
import '../../services/firebase_service.dart';
import '../../utils/default_users.dart';
import '../../widgets/app_drawer.dart';

const _userColors = {
  'Roommate A': Color(0xFF4A90D9),
  'Roommate B':  Color(0xFF27AE60),
  'Roommate C':  Color(0xFFE67E22),
};

String _displayName(String name) {
  if (name == 'Roommate A') return 'Roommate A';
  if (name == 'Roommate B')  return 'Roommate B';
  if (name == 'Roommate C')  return 'Roommate C';
  return name;
}

Color _colorFor(String name) => _userColors[name] ?? const Color(0xFF888888);

/// A transparent, shareable billing statement showing exactly what
/// each person owed, paid, and their running balance — month by month.
class BillingStatementScreen extends StatelessWidget {
  const BillingStatementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fb    = context.read<FirebaseService>();
    final fmt   = NumberFormat.currency(symbol: r'$');

    // Months to show: January and February 2026
    const months = [
      (month: 1, year: 2026, label: 'January 2026'),
      (month: 2, year: 2026, label: 'February 2026'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Statement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About this statement',
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────
            _HeaderCard(),
            const SizedBox(height: 20),

            // ── Per-month sections ────────────────────────────────────
            ...months.map((m) => _MonthSection(
                  fb:    fb,
                  fmt:   fmt,
                  month: m.month,
                  year:  m.year,
                  label: m.label,
                )),

            const SizedBox(height: 20),

            // ── Running Balance Summary ───────────────────────────────
            _RunningBalanceSummary(fb: fb, fmt: fmt),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How this works'),
        content: const Text(
          'This statement shows:\n\n'
          '• What each person OWED (calculated by the app)\n'
          '• What they actually PAID (recorded in the app)\n'
          '• The BALANCE (positive = credit, negative = still owed)\n\n'
          'All amounts are based on verified bill data from screenshots.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// ── Header Card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DefaultUsers.isPortfolioMode ? 'Room 4061 — Sample Unit' : 'Unit 4061 — Mueller Blvd',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text('Statement period: Jan 9 – Feb 28, 2026',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white30),
          const SizedBox(height: 12),
          // Splitting rules legend
          const Text('SPLITTING RULES',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _RulePill(icon: Icons.home, label: 'Rent & Fees → A 25% · C 25% · B 50%'),
          const SizedBox(height: 6),
          _RulePill(icon: Icons.bolt, label: 'Electricity Usage → A 50% · C 25% · B 25%'),
          const SizedBox(height: 6),
          _RulePill(icon: Icons.water_drop, label: 'Other Utility Fees → Even split (33.3% each)'),
        ],
      ),
    );
  }
}

class _RulePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RulePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ],
    );
  }
}

// ── Month Section ─────────────────────────────────────────────────────────────

class _MonthSection extends StatelessWidget {
  final FirebaseService fb;
  final NumberFormat fmt;
  final int month;
  final int year;
  final String label;
  const _MonthSection({required this.fb, required this.fmt, required this.month, required this.year, required this.label});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UtilityBill>>(
      stream: fb.getUtilityBills(month: month, year: year),
      builder: (context, billSnap) {
        return StreamBuilder<List<PaymentRecord>>(
          stream: fb.getPaymentRecords(month: month, year: year),
          builder: (context, paySnap) {
            final bills   = billSnap.data ?? [];
            final records = paySnap.data ?? [];

            // Tally owed per person from bills
            final owedMap = <String, double>{};
            for (final bill in bills) {
              for (final s in bill.splits) {
                owedMap[s.userName] = (owedMap[s.userName] ?? 0) + s.amount;
              }
            }
            // Tally paid per person from records
            final paidMap = <String, double>{};
            for (final r in records) {
              paidMap[r.userName] = (paidMap[r.userName] ?? 0) + r.actualPaid;
            }

            final isLoading = billSnap.connectionState == ConnectionState.waiting
                || paySnap.connectionState == ConnectionState.waiting;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Month title
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4, height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (bills.isEmpty && !isLoading)
                        const Chip(label: Text('No data', style: TextStyle(fontSize: 11))),
                    ],
                  ),
                ),

                // Bill line items
                if (bills.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Charges',
                    icon: Icons.receipt,
                    children: bills.map((bill) => _BillLineRow(bill: bill, fmt: fmt)).toList(),
                  ),
                  const SizedBox(height: 10),
                ],

                // Per-person table
                _SectionCard(
                  title: 'Who Owes What',
                  icon: Icons.people,
                  children: [
                    // Header row
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Expanded(flex: 3, child: Text('Person', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          const Expanded(flex: 2, child: Text('Owed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                          const Expanded(flex: 2, child: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                          const Expanded(flex: 2, child: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...DefaultUsers.users.map((u) {
                      final owed    = owedMap[u.name] ?? 0;
                      final paid    = paidMap[u.name] ?? 0;
                      final balance = paid - owed;
                      final color   = _colorFor(u.name);
                      return _PersonRow(
                        name:    u.name,
                        color:   color,
                        owed:    owed,
                        paid:    paid,
                        balance: balance,
                        fmt:     fmt,
                        noData:  owedMap.isEmpty,
                      );
                    }),
                    // Total row
                    if (owedMap.isNotEmpty) ...[
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text(
                            fmt.format(owedMap.values.fold(0.0, (a, b) => a + b)),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            textAlign: TextAlign.right,
                          )),
                          Expanded(flex: 2, child: Text(
                            fmt.format(paidMap.values.fold(0.0, (a, b) => a + b)),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            textAlign: TextAlign.right,
                          )),
                          const Expanded(flex: 2, child: SizedBox()),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Person Row ────────────────────────────────────────────────────────────────

class _PersonRow extends StatelessWidget {
  final String name;
  final Color color;
  final double owed;
  final double paid;
  final double balance;
  final NumberFormat fmt;
  final bool noData;

  const _PersonRow({
    required this.name, required this.color, required this.owed,
    required this.paid,  required this.balance, required this.fmt,
    required this.noData,
  });

  @override
  Widget build(BuildContext context) {
    final creditPos = balance >  0.005;
    final creditNeg = balance < -0.005;
    final balanceColor = creditPos ? Colors.green : creditNeg ? Colors.redAccent : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Text(name[0],
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Text(_displayName(name), style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              noData ? '—' : fmt.format(owed),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              paid > 0 ? fmt.format(paid) : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: paid > 0 ? null : Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: noData || paid == 0
                    ? Colors.transparent
                    : balanceColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                noData || paid == 0
                    ? '—'
                    : creditPos
                        ? '+${fmt.format(balance)}'
                        : fmt.format(balance),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: noData || paid == 0 ? Colors.grey : balanceColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bill Line Row ─────────────────────────────────────────────────────────────

class _BillLineRow extends StatelessWidget {
  final UtilityBill bill;
  final NumberFormat fmt;
  const _BillLineRow({required this.bill, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(_categoryIcon(bill.category), size: 15, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(child: Text(bill.name, style: const TextStyle(fontSize: 13))),
          Text(fmt.format(bill.totalAmount),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  IconData _categoryIcon(UtilityCategory cat) {
    switch (cat) {
      case UtilityCategory.rent:        return Icons.home;
      case UtilityCategory.electricity: return Icons.bolt;
      case UtilityCategory.water:       return Icons.water_drop;
      case UtilityCategory.gas:         return Icons.local_fire_department;
      case UtilityCategory.internet:    return Icons.wifi;
      case UtilityCategory.trash:       return Icons.delete_outline;
      default:                          return Icons.receipt;
    }
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Running Balance Summary ───────────────────────────────────────────────────

class _RunningBalanceSummary extends StatelessWidget {
  final FirebaseService fb;
  final NumberFormat fmt;
  const _RunningBalanceSummary({required this.fb, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentRecord>>(
      future: fb.getAllPaymentRecords(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final records = snap.data!;

        return _SectionCard(
          title: 'RUNNING BALANCE (ALL TIME)',
          icon: Icons.account_balance_wallet,
          children: DefaultUsers.users.map((u) {
            final totalCredit = records
                .where((r) => r.userName == u.name)
                .fold<double>(0, (s, r) => s + r.credit);
            final color = _colorFor(u.name);
            final pos   = totalCredit >  0.005;
            final neg   = totalCredit < -0.005;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                  backgroundColor: color.withValues(alpha: 0.2),
                    child: Text(u.name[0],
                        style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName(u.name), style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          pos ? 'Overpaid — credit toward March'
                              : neg  ? 'Underpaid — owes extra in March'
                              : 'Balanced ✓',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: pos  ? Colors.green.withValues(alpha: 0.12)
                           : neg  ? Colors.red.withValues(alpha: 0.12)
                           : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pos ? '+${fmt.format(totalCredit)}'
                          : totalCredit.abs() < 0.005 ? '✓ Even'
                          : fmt.format(totalCredit),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: pos  ? Colors.green
                             : neg  ? Colors.redAccent
                             : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
