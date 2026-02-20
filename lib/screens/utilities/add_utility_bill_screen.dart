import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/utility_bill.dart';
import '../../utils/default_users.dart';

// ─── User colours ─────────────────────────────────────────────────────────────
const _userColors = {
  'Jacob': Color(0xFF4A90D9),
  'Nico':  Color(0xFF27AE60),
  'Eddy':  Color(0xFFE67E22),
};
Color _colorFor(String n) => _userColors[n] ?? const Color(0xFF888888);

// ─── Quick-pick presets ───────────────────────────────────────────────────────
class _Preset {
  final String          label;
  final UtilityCategory category;
  const _Preset(this.label, this.category);
}

const _presets = [
  _Preset('Rent',      UtilityCategory.rent),
  _Preset('Electric',  UtilityCategory.electricity),
  _Preset('Water',     UtilityCategory.water),
  _Preset('Gas',       UtilityCategory.gas),
  _Preset('Internet',  UtilityCategory.internet),
  _Preset('Trash',     UtilityCategory.trash),
];

// ─── 4-notch weight options ────────────────────────────────────────────────────
// ⅓ · ½ · ⅔ · Full — natural fractions for a 3-person household.
// Weights are relative: all at Full (1.0) = equal thirds automatically.
// ⅓ weight = half what a Full person pays; ⅔ weight = two-thirds.
const _notches = <double>[1 / 3, 0.5, 2 / 3, 1.0];
const _notchLabels = <String>['⅓', '½', '⅔', 'Full'];

// ─────────────────────────────────────────────────────────────────────────────

class AddUtilityBillScreen extends StatefulWidget {
  const AddUtilityBillScreen({
    super.key,
    this.existing,
    required this.defaultMonth,
    required this.defaultYear,
  });
  final UtilityBill? existing;
  final int defaultMonth;
  final int defaultYear;

  @override
  State<AddUtilityBillScreen> createState() =>
      _AddUtilityBillScreenState();
}

class _AddUtilityBillScreenState extends State<AddUtilityBillScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();

  late UtilityCategory     _category;
  late DateTime            _dueDate;
  late Map<String, double> _weights;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (_isEdit) {
      final b = widget.existing!;
      _nameCtrl.text   = b.name;
      _amountCtrl.text = b.totalAmount.toStringAsFixed(2);
      _notesCtrl.text  = b.notes ?? '';
      _category        = b.category;
      _dueDate         = b.dueDate;
      _weights = {for (final s in b.splits) s.userName: s.weight};
    } else {
      _category = UtilityCategory.rent;
      _dueDate  = DateTime(widget.defaultYear, widget.defaultMonth,
          now.day.clamp(1, 28));
      _weights = {for (final u in DefaultUsers.users) u.name: 1.0};
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  double get _total => double.tryParse(_amountCtrl.text) ?? 0;

  List<UtilitySplit> _buildSplits() {
    final base = DefaultUsers.users.map((u) => UtilitySplit(
          userName: u.name,
          weight:   _weights[u.name] ?? 1.0,
          amount:   0,
          isPaid:   _isEdit
              ? (widget.existing!.splitFor(u.name)?.isPaid ?? false)
              : false,
          paidDate: _isEdit
              ? widget.existing!.splitFor(u.name)?.paidDate
              : null,
        )).toList();
    return UtilityBill.calcAmounts(base, _total);
  }

  /// Applies a quick-pick preset — fills name + category + resets weights.
  void _applyPreset(_Preset p) {
    final month = DateFormat('MMMM').format(_dueDate);
    setState(() {
      _category      = p.category;
      _nameCtrl.text = '$month ${p.label}';
      // Reset to equal split when switching presets
      for (final u in DefaultUsers.users) {
        _weights[u.name] = 1.0;
      }
    });
  }

  // ── custom weight dialog ──────────────────────────────────────────────────
  Future<void> _showCustomWeightDialog(String userName) async {
    final ctrl = TextEditingController(
        text: _weights[userName]?.toStringAsFixed(2) ?? '1.00');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Custom weight for $userName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter any decimal (e.g. 0.33, 1.5, 2).\n'
              'Weight is relative — 0.5 pays half of what a 1.0 person pays.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,4}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Weight',
                border: OutlineInputBorder(),
                suffixText: '×',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) setState(() => _weights[userName] = result);
  }

  // ── submit ────────────────────────────────────────────────────────────────
  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final bill = UtilityBill(
      id:          widget.existing?.id,
      name:        _nameCtrl.text.trim(),
      category:    _category,
      totalAmount: _total,
      dueDate:     _dueDate,
      month:       _dueDate.month,
      year:        _dueDate.year,
      splits:      _buildSplits(),
      notes:       _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );
    Navigator.of(context).pop(bill);
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context:     context,
      initialDate: _dueDate,
      firstDate:   DateTime(2020),
      lastDate:    DateTime(2030),
    );
    if (p != null) setState(() => _dueDate = p);
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final fmtMon = NumberFormat.currency(symbol: r'$');
    final splits = _buildSplits();
    final theme  = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Bill' : 'New Bill'),
        actions: [
          TextButton(
            onPressed: _submit,
            child: Text(
              _isEdit ? 'Save' : 'Add',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Quick-pick presets ────────────────────────────────────
              if (!_isEdit) ...[
                _SectionLabel('Quick Pick'),
                const SizedBox(height: 8),
                _AutoFetchBanner(),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _presets.map((p) {
                      final active = p.category == _category &&
                          _nameCtrl.text.endsWith(p.label);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _PresetChip(
                          preset:   p,
                          active:   active,
                          onTap:    () => _applyPreset(p),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 18),
              ],

              // ── Category ──────────────────────────────────────────────
              _SectionLabel('Category'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: UtilityCategory.values.map((cat) {
                  final sel = cat == _category;
                  return FilterChip(
                    label: Text('${cat.emoji}  ${cat.label}'),
                    selected: sel,
                    onSelected: (_) => setState(() => _category = cat),
                    selectedColor: theme.colorScheme.primary
                        .withValues(alpha: 0.15),
                    checkmarkColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      fontWeight:
                          sel ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Bill name ─────────────────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText:  'Bill name',
                  hintText:   'e.g. March Electric',
                  prefixIcon: Icon(Icons.receipt_long),
                  border:     OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),

              // ── Amount ────────────────────────────────────────────────
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText:  'Total amount',
                  prefixIcon: Icon(Icons.attach_money),
                  border:     OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return (n == null || n <= 0)
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
              const SizedBox(height: 16),

              // ── Due date ──────────────────────────────────────────────
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText:  'Due date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border:     OutlineInputBorder(),
                  ),
                  child: Text(
                      DateFormat('MMMM d, yyyy').format(_dueDate)),
                ),
              ),
              const SizedBox(height: 28),

              // ── Split weights ─────────────────────────────────────────
              _SectionLabel('Who pays — and how much?'),
              const SizedBox(height: 4),
              Text(
                'All at Full = equal split (each pays ⅓). '
                'Drop someone to ⅔ or ½ to reduce their share. '
                'Tap ✎ for any custom fraction.',
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              ...DefaultUsers.users.map((u) => _NotchRow(
                    name:   u.name,
                    weight: _weights[u.name] ?? 1.0,
                    amount: splits
                        .firstWhere(
                          (s) => s.userName == u.name,
                          orElse: () => UtilitySplit(
                              userName: u.name, weight: 1, amount: 0),
                        )
                        .amount,
                    fmtMon: fmtMon,
                    onNotch:  (v) =>
                        setState(() => _weights[u.name] = v),
                    onCustom: () =>
                        _showCustomWeightDialog(u.name),
                  )),
              const SizedBox(height: 8),

              // ── Live preview ──────────────────────────────────────────
              if (_total > 0)
                _SplitPreview(splits: splits, fmtMon: fmtMon),
              const SizedBox(height: 20),

              // ── Notes ─────────────────────────────────────────────────
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText:  'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                  border:     OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isEdit ? 'Save Changes' : 'Add Bill',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      );
}

// ─── Auto-fetch banner (future API hook) ──────────────────────────────────────

class _AutoFetchBanner extends StatelessWidget {
  const _AutoFetchBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withValues(alpha: 0.08),
            Colors.blue.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_fix_high_rounded,
              size: 18, color: Colors.deepPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Auto-fetch coming soon — connect your billing accounts '
              'to import bills automatically each month.',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.deepPurple[700],
                  height: 1.4),
            ),
          ),
          // Future: onTap → /billing-providers route
          Icon(Icons.chevron_right_rounded,
              size: 16,
              color: Colors.deepPurple.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

// ─── Preset chip ──────────────────────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.active,
    required this.onTap,
  });
  final _Preset      preset;
  final bool         active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? primary.withValues(alpha: 0.12)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? primary.withValues(alpha: 0.5)
                : Colors.grey[300]!,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(preset.category.emoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              preset.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
                color: active ? primary : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 4-notch weight row ───────────────────────────────────────────────────────

class _NotchRow extends StatelessWidget {
  const _NotchRow({
    required this.name,
    required this.weight,
    required this.amount,
    required this.fmtMon,
    required this.onNotch,
    required this.onCustom,
  });
  final String               name;
  final double               weight;
  final double               amount;
  final NumberFormat         fmtMon;
  final ValueChanged<double> onNotch;
  final VoidCallback         onCustom;

  // Floating-point ⅓ / ⅔ need tolerance comparison
  bool get _isCustom =>
      !_notches.any((n) => (n - weight).abs() < 0.001);

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── name + amount ─────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: color,
                child: Text(name[0],
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(amount),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    amount > 0 ? fmtMon.format(amount) : '—',
                    style: TextStyle(
                        color:      color,
                        fontWeight: FontWeight.bold,
                        fontSize:   13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── 4 notch buttons + Custom ───────────────────────────────────
          Row(
            children: [
              // Standard notches: ¼ ½ ¾ Full
              ...List.generate(_notches.length, (i) {
                final val = _notches[i];
                final sel = !_isCustom && (weight - val).abs() < 0.001;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: i < _notches.length - 1 ? 5 : 0),
                    child: _NotchBtn(
                      label:    _notchLabels[i],
                      selected: sel,
                      color:    color,
                      onTap:    () => onNotch(val),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 5),
              // Custom button
              _NotchBtn(
                label:    _isCustom ? '$weight×' : '✎',
                selected: _isCustom,
                color:    color,
                onTap:    onCustom,
                isCustom: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotchBtn extends StatelessWidget {
  const _NotchBtn({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.isCustom = false,
  });
  final String     label;
  final bool       selected;
  final Color      color;
  final VoidCallback onTap;
  final bool       isCustom;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? color
              : (isCustom
                  ? Colors.grey[100]
                  : color.withValues(alpha: 0.07)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? color
                : (isCustom ? Colors.grey[300]! : color.withValues(alpha: 0.25)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize:   isCustom ? 11 : 13,
            fontWeight: FontWeight.bold,
            color:      selected
                ? Colors.white
                : (isCustom ? Colors.grey[600] : color),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─── Split preview ────────────────────────────────────────────────────────────

class _SplitPreview extends StatelessWidget {
  const _SplitPreview({required this.splits, required this.fmtMon});
  final List<UtilitySplit> splits;
  final NumberFormat       fmtMon;

  @override
  Widget build(BuildContext context) {
    final total =
        splits.fold<double>(0, (acc, s) => acc + s.amount);
    if (total <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Split Preview',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey)),
          const SizedBox(height: 10),
          // Stacked proportion bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: splits.map((s) {
                  final frac = total > 0 ? s.amount / total : 0.0;
                  return Expanded(
                    flex: (frac * 1000).round().clamp(1, 999),
                    child:
                        Container(color: _colorFor(s.userName)),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: splits.map((s) {
              final c = _colorFor(s.userName);
              return Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 3),
                      Text(s.userName,
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  Text(
                    fmtMon.format(s.amount),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: c),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
