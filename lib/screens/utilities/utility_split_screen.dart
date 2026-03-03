import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../models/utility_bill.dart';
import '../../models/payment_record.dart';
import '../../services/firebase_service.dart';
import '../../utils/default_users.dart';
import 'add_utility_bill_screen.dart';
import 'record_payment_screen.dart';

import 'package:fl_chart/fl_chart.dart';
import '../../widgets/app_drawer.dart';

import '../../widgets/avatar_selector_widget.dart';

// Per-user accent colours (match DefaultUsers)
const _userColors = {
  'Roommate A': Color(0xFF4A90D9),
  'Roommate B':  Color(0xFF27AE60),
  'Roommate C':  Color(0xFFE67E22),
};

Color _colorFor(String name) =>
    _userColors[name] ?? const Color(0xFF888888);

class UtilitySplitScreen extends StatefulWidget {
  const UtilitySplitScreen({super.key});

  @override
  State<UtilitySplitScreen> createState() => _UtilitySplitScreenState();
}

class _UtilitySplitScreenState extends State<UtilitySplitScreen> {
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year  = now.year;
  }

  void _prevMonth() => setState(() {
        if (_month == 1) {
          _month = 12;
          _year--;
        } else {
          _month--;
        }
      });

  void _nextMonth() => setState(() {
        if (_month == 12) {
          _month = 1;
          _year++;
        } else {
          _month++;
        }
      });

  @override
  Widget build(BuildContext context) {
    final fb     = context.read<FirebaseService>();
    final fmtMon = NumberFormat.currency(symbol: r'$');
    
    final displayName = fb.currentUser?.email?.split('@').first ?? '';
    final formattedName = displayName.isEmpty 
        ? '' 
        : displayName[0].toUpperCase() + displayName.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cost Split'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add bill',
            onPressed: () => _openAddBill(context, fb),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: AvatarBadge(userName: formattedName, size: 36),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // ── Month navigator ────────────────────────────────────────────
          _MonthBar(
            month: _month,
            year:  _year,
            onPrev: _prevMonth,
            onNext: _nextMonth,
          ),

          // ── Scrollable body ────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<UtilityBill>>(
              stream: fb.getUtilityBills(month: _month, year: _year),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Error: ${snap.error}',
                        style: TextStyle(color: Colors.grey[600])),
                  );
                }

                final bills = snap.data ?? [];

                if (bills.isEmpty) {
                  return _EmptyState(
                    month: _month,
                    year:  _year,
                    onAdd: () => _openAddBill(context, fb),
                  );
                }

                // ── compute per-person totals ─────────────────────────
                final personTotals = <String, double>{};
                final personPaid   = <String, double>{};
                for (final bill in bills) {
                  for (final s in bill.splits) {
                    personTotals[s.userName] =
                        (personTotals[s.userName] ?? 0) + s.amount;
                    if (s.isPaid) {
                      personPaid[s.userName] =
                          (personPaid[s.userName] ?? 0) + s.amount;
                    }
                  }
                }
                final grandTotal = bills.fold<double>(0, (a, b) => a + b.totalAmount);
                final grandPaid  = bills.fold<double>(0, (a, b) => a + b.paidAmount);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // ── Month summary ───────────────────────────────
                      _MonthSummary(
                        total:    grandTotal,
                        paid:     grandPaid,
                        fmtMon:   fmtMon,
                      ),
                      const SizedBox(height: 16),

                      // ── Usage Graph ─────────────────────────────────
                      if (bills.isNotEmpty)
                        _CostBreakdownChart(personTotals: personTotals),
                      const SizedBox(height: 24),

                      // ── Per-person cards ────────────────────────────
                      Row(
                        children: DefaultUsers.users.map((u) {
                          final total = personTotals[u.name] ?? 0;
                          final paid  = personPaid[u.name]   ?? 0;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: u == DefaultUsers.users.last
                                    ? 0
                                    : 8,
                              ),
                              child: _PersonCard(
                                name:   u.name,
                                total:  total,
                                paid:   paid,
                                fmtMon: fmtMon,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // ── Reconciliation Card ────────────────────────
                      _ReconciliationCard(
                        fb:     fb,
                        month:  _month,
                        year:   _year,
                        fmtMon: fmtMon,
                        personTotals: personTotals,
                        onRecord: () => _openRecordPayment(context, fb),
                      ),

                      // ── Bills list ──────────────────────────────────
                      Text(
                        'Bills  (${bills.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ...bills.map((bill) => _BillCard(
                            bill:    bill,
                            fb:      fb,
                            fmtMon:  fmtMon,
                            onEdit:  () => _openAddBill(context, fb,
                                existing: bill),
                            onDelete: () => _deleteBill(context, fb, bill),
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // FAB so there's always an obvious add button
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'record_payment',
            onPressed: () => _openRecordPayment(context, fb),
            tooltip: 'Record Payment',
            child: const Icon(Icons.payments_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'add_bill',
            onPressed: () => _openAddBill(context, fb),
            icon: const Icon(Icons.add),
            label: const Text('Add Bill'),
          ),
        ],
      ),
    );
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _openRecordPayment(BuildContext context, FirebaseService fb) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordPaymentScreen(
          defaultMonth: _month,
          defaultYear:  _year,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _openAddBill(
    BuildContext context,
    FirebaseService fb, {
    UtilityBill? existing,
  }) async {
    final result = await Navigator.of(context).push<UtilityBill>(
      MaterialPageRoute(
        builder: (_) => AddUtilityBillScreen(
          existing:     existing,
          defaultMonth: _month,
          defaultYear:  _year,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == null) return;
    if (existing != null) {
      await fb.updateUtilityBill(result);
    } else {
      await fb.addUtilityBill(result);
    }
  }

  Future<void> _deleteBill(
      BuildContext ctx, FirebaseService fb, UtilityBill bill) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: Text('Remove "${bill.name}" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) await fb.deleteUtilityBill(bill.id!);
  }
}

// ─── Month navigator ──────────────────────────────────────────────────────────

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.year,
    required this.onPrev,
    required this.onNext,
  });
  final int month, year;
  final VoidCallback onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy')
        .format(DateTime(year, month));
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded)),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}

// ─── Month summary banner ─────────────────────────────────────────────────────

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.total,
    required this.paid,
    required this.fmtMon,
  });
  final double total, paid;
  final NumberFormat fmtMon;

  @override
  Widget build(BuildContext context) {
    final remaining = total - paid;
    final pct       = total > 0 ? paid / total : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatChip(
                    label: 'Total',
                    value: fmtMon.format(total),
                    color: Colors.blue),
                _StatChip(
                    label: 'Paid',
                    value: fmtMon.format(paid),
                    color: Colors.green),
                _StatChip(
                    label: 'Remaining',
                    value: fmtMon.format(remaining),
                    color: remaining > 0 ? Colors.orange : Colors.green),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor:
                    const AlwaysStoppedAnimation(Colors.green),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(pct * 100).toStringAsFixed(0)}% paid',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

// ─── Per-person card ──────────────────────────────────────────────────────────

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.name,
    required this.total,
    required this.paid,
    required this.fmtMon,
  });
  final String name;
  final double total, paid;
  final NumberFormat fmtMon;

  @override
  Widget build(BuildContext context) {
    final color     = _colorFor(name);
    final remaining = total - paid;
    final done      = total > 0 && remaining <= 0.005;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: done ? Colors.green.withValues(alpha: 0.4) : color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color,
              radius: 18,
              child: Text(
                name[0],
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            const SizedBox(height: 6),
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              fmtMon.format(remaining > 0 ? remaining : 0),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: done ? Colors.green : color),
            ),
            Text(
              done ? 'all paid ✓' : 'owes',
              style: TextStyle(
                  fontSize: 10,
                  color: done ? Colors.green : Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bill card ────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  const _BillCard({
    required this.bill,
    required this.fb,
    required this.fmtMon,
    required this.onEdit,
    required this.onDelete,
  });
  final UtilityBill    bill;
  final FirebaseService fb;
  final NumberFormat    fmtMon;
  final VoidCallback    onEdit;
  final VoidCallback    onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header ─────────────────────────────────────────────────
            Row(
              children: [
                Text(bill.category.emoji,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bill.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text(
                        '${bill.category.label}  •  due ${DateFormat('MMM d').format(bill.dueDate)}',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmtMon.format(bill.totalAmount),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (bill.isFullyPaid)
                      const Text('fully paid',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w600))
                    else
                      Text(
                        '${fmtMon.format(bill.remainingAmount)} left',
                        style: TextStyle(
                            color: Colors.orange[700], fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (v) {
                    if (v == 'edit')   onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ])),
                    PopupMenuItem(value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── split breakdown ─────────────────────────────────────────
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: bill.splits.map((split) {
                return Expanded(
                  child: _SplitChip(
                    split:  split,
                    bill:   bill,
                    fb:     fb,
                    fmtMon: fmtMon,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Split chip (per-person row inside a bill card) ────────────────────────────

class _SplitChip extends StatelessWidget {
  const _SplitChip({
    required this.split,
    required this.bill,
    required this.fb,
    required this.fmtMon,
  });
  final UtilitySplit    split;
  final UtilityBill     bill;
  final FirebaseService fb;
  final NumberFormat    fmtMon;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(split.userName);
    final pct   = bill.totalAmount > 0
        ? (split.amount / bill.totalAmount * 100).toStringAsFixed(0)
        : '0';

    return GestureDetector(
      onTap: () async {
        await fb.markSplitPaid(
          billId:        bill.id!,
          userName:      split.userName,
          isPaid:        !split.isPaid,
          currentSplits: bill.splits,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: split.isPaid
              ? Colors.green.withValues(alpha: 0.08)
              : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: split.isPaid
                ? Colors.green.withValues(alpha: 0.45)
                : color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: split.isPaid ? Colors.green : color,
              child: split.isPaid
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text(
                      split.userName[0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
            ),
            const SizedBox(height: 4),
            Text(split.userName,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
            Text(
              fmtMon.format(split.amount),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: split.isPaid ? Colors.green : color),
            ),
            Text('$pct%',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey[500])),
            Text(
              split.isPaid ? 'paid ✓' : 'tap to pay',
              style: TextStyle(
                  fontSize: 9,
                  color: split.isPaid ? Colors.green : Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.month,
    required this.year,
    required this.onAdd,
  });
  final int month, year;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final label =
        DateFormat('MMMM yyyy').format(DateTime(year, month));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧾', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('No bills for $label',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Add your shared costs — rent, electricity,\nwater, internet — and we\'ll split them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add First Bill'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Usage Graph Widget ────────────────────────────────────────────────────────

class _CostBreakdownChart extends StatelessWidget {
  final Map<String, double> personTotals;

  const _CostBreakdownChart({required this.personTotals});

  @override
  Widget build(BuildContext context) {
    final total = personTotals.values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: personTotals.entries.map((e) {
                    final percentage = (e.value / total) * 100;
                    return PieChartSectionData(
                      color: _userColors[e.key] ?? Colors.grey,
                      value: e.value,
                      title: '${percentage.toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Household Cost Distribution',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    letterSpacing: 1.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reconciliation Card ───────────────────────────────────────────────────────

class _ReconciliationCard extends StatelessWidget {
  final FirebaseService fb;
  final int month;
  final int year;
  final NumberFormat fmtMon;
  final Map<String, double> personTotals;
  final VoidCallback onRecord;

  const _ReconciliationCard({
    required this.fb,
    required this.month,
    required this.year,
    required this.fmtMon,
    required this.personTotals,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentRecord>>(
      stream: fb.getPaymentRecords(month: month, year: year),
      builder: (context, snap) {
        final records = snap.data ?? [];
        if (records.isEmpty && personTotals.isEmpty) return const SizedBox.shrink();

        // Build a map: userName → total credit for this month
        final creditMap = <String, double>{};
        for (final r in records) {
          creditMap[r.userName] = (creditMap[r.userName] ?? 0) + r.credit;
        }
        final paidMap = <String, double>{};
        for (final r in records) {
          paidMap[r.userName] = (paidMap[r.userName] ?? 0) + r.actualPaid;
        }

        return Card(
          elevation: 0,
          color: Colors.white.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.balance, size: 18),
                    const SizedBox(width: 8),
                    Text('Payments & Credits',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onRecord,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Record'),
                    ),
                  ],
                ),
                const Divider(height: 20),
                ...DefaultUsers.users.map((u) {
                  final owed   = personTotals[u.name] ?? 0;
                  final paid   = paidMap[u.name] ?? 0;
                  final credit = creditMap[u.name] ?? 0;
                  final color  = _colorFor(u.name);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: color.withValues(alpha: 0.2),
                          child: Text(u.name[0],
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                              if (paid > 0)
                                Text(
                                  'Paid ${fmtMon.format(paid)} of ${fmtMon.format(owed)}',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 11),
                                )
                              else
                                Text('Owes ${fmtMon.format(owed)} — not recorded yet',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 11)),
                            ],
                          ),
                        ),
                        if (paid > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: credit > 0
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : credit < 0
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              credit > 0.005
                                  ? '+${fmtMon.format(credit)}'
                                  : credit < -0.005
                                      ? fmtMon.format(credit)
                                      : '✓ Even',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: credit > 0.005
                                    ? Colors.green
                                    : credit < -0.005
                                        ? Colors.redAccent
                                        : Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/statement/discrepancy'),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('Discrepancy Audit'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
