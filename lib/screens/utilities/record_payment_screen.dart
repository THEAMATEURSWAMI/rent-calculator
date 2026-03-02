import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/payment_record.dart';
import '../../services/firebase_service.dart';
import '../../utils/default_users.dart';

/// Lets a user log what they (or anyone) actually paid for a given month.
class RecordPaymentScreen extends StatefulWidget {
  final int defaultMonth;
  final int defaultYear;
  final String? prefillUserName;
  final double? prefillOwed;

  const RecordPaymentScreen({
    super.key,
    required this.defaultMonth,
    required this.defaultYear,
    this.prefillUserName,
    this.prefillOwed,
  });

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  late String _selectedUser;
  late int _month;
  late int _year;
  final _owedCtrl  = TextEditingController();
  final _paidCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  final _fmt = NumberFormat.currency(symbol: r'$');

  @override
  void initState() {
    super.initState();
    _selectedUser = widget.prefillUserName ?? DefaultUsers.users.first.name;
    _month        = widget.defaultMonth;
    _year         = widget.defaultYear;
    if (widget.prefillOwed != null) {
      _owedCtrl.text = widget.prefillOwed!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _owedCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _owed   => double.tryParse(_owedCtrl.text) ?? 0;
  double get _paid   => double.tryParse(_paidCtrl.text) ?? 0;
  double get _credit => _paid - _owed;

  Future<void> _save() async {
    if (_paidCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final fb = context.read<FirebaseService>();
    final record = PaymentRecord(
      userName:   _selectedUser,
      month:      _month,
      year:       _year,
      owedAmount: _owed,
      actualPaid: _paid,
      notes:      _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt:  DateTime.now(),
    );
    await fb.addPaymentRecord(record);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final months    = List.generate(12, (i) => i + 1);
    final creditPos = _credit > 0.005;
    final creditNeg = _credit < -0.005;

    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Who paid ──────────────────────────────────────────────
            Text('Who paid?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: DefaultUsers.users
                  .map((u) => ButtonSegment(value: u.name, label: Text(u.name)))
                  .toList(),
              selected: {_selectedUser},
              onSelectionChanged: (s) => setState(() => _selectedUser = s.first),
            ),
            const SizedBox(height: 24),

            // ── Month/Year ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: months.map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(DateFormat.MMMM().format(DateTime(0, m))))).toList(),
                    onChanged: (v) => setState(() => _month = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: [2026, 2027].map((y) =>
                        DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (v) => setState(() => _year = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Owed & Paid ───────────────────────────────────────────
            TextField(
              controller: _owedCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount owed (from app)',
                prefixText: r'$',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _paidCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount actually paid',
                prefixText: r'$',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Venmo to Nico, rounded up',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // ── Live credit delta ─────────────────────────────────────
            if (_paidCtrl.text.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: creditPos
                      ? Colors.green.withValues(alpha: 0.12)
                      : creditNeg
                          ? Colors.red.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      creditPos ? Icons.arrow_downward : creditNeg ? Icons.arrow_upward : Icons.check,
                      color: creditPos ? Colors.green : creditNeg ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        creditPos
                            ? 'Overpaid by ${_fmt.format(_credit)} → credit toward next month'
                            : creditNeg
                                ? 'Underpaid by ${_fmt.format(_credit.abs())} → added to next month'
                                : 'Paid exactly. No adjustment needed.',
                        style: TextStyle(
                          color: creditPos ? Colors.green : creditNeg ? Colors.redAccent : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),

            // ── Save ──────────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save Payment Record'),
            ),
          ],
        ),
      ),
    );
  }
}
