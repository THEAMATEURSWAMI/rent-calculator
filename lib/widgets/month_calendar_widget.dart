import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pure month calendar — no avatar logic (avatar lives in dashboard layout).
class MonthCalendarWidget extends StatefulWidget {
  final Function(DateTime date)? onDateTap;

  const MonthCalendarWidget({super.key, this.onDateTap});

  @override
  State<MonthCalendarWidget> createState() => _MonthCalendarWidgetState();
}

class _MonthCalendarWidgetState extends State<MonthCalendarWidget>
    with TickerProviderStateMixin {

  // ── Year grid stagger ─────────────────────────────────────────────
  late final AnimationController _staggerCtrl;
  late final List<Animation<double>> _cardFade;
  late final AnimationController _zoomCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _zoomAnim;
  late final Animation<double> _pulseAnim;

  // ── Year → month zoom-in transition ──────────────────────────────
  late final AnimationController _zoomInCtrl;
  late final Animation<double> _yearScaleOut;
  late final Animation<double> _yearFadeOut;
  late final Animation<double> _monthScaleIn;
  late final Animation<double> _monthFadeIn;

  bool _inMonthView = false;
  int _viewMonth = DateTime.now().month;
  int _viewYear  = DateTime.now().year;
  final int _today    = DateTime.now().day;
  final int _nowMonth = DateTime.now().month;
  final int _nowYear  = DateTime.now().year;

  static const _monthShort = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  static const _weekDays = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _cardFade = List.generate(12, (i) {
      final s = (i / 12) * 0.50;
      final e = (s + 0.50).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _staggerCtrl,
              curve: Interval(s, e, curve: Curves.easeOutBack)));
    });

    _zoomCtrl = AnimationController(
        duration: const Duration(milliseconds: 550), vsync: this);
    _zoomAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
        CurvedAnimation(parent: _zoomCtrl, curve: Curves.elasticOut));

    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _zoomInCtrl = AnimationController(
        duration: const Duration(milliseconds: 480), vsync: this);
    _yearScaleOut = Tween<double>(begin: 1.0, end: 1.40).animate(
        CurvedAnimation(parent: _zoomInCtrl, curve: Curves.easeInCubic));
    _yearFadeOut  = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _zoomInCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeIn)));
    _monthScaleIn = Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(parent: _zoomInCtrl,
            curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic)));
    _monthFadeIn  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _zoomInCtrl,
            curve: const Interval(0.42, 1.0, curve: Curves.easeOut)));

    _staggerCtrl.forward().then((_) {
      if (!mounted) return;
      _zoomCtrl.forward();
      Future.delayed(const Duration(milliseconds: 520), _autoZoomIn);
    });
  }

  void _autoZoomIn() {
    if (!mounted) return;
    setState(() {
      _inMonthView = true;
      _viewMonth = _nowMonth;
      _viewYear  = _nowYear;
    });
    _zoomInCtrl.forward(from: 0);
  }

  void _goToYearView() {
    setState(() => _inMonthView = false);
    _zoomInCtrl.reverse();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _zoomCtrl.dispose();
    _pulseCtrl.dispose();
    _zoomInCtrl.dispose();
    super.dispose();
  }

  // ── Year grid ────────────────────────────────────────────────────
  Widget _buildYearGrid(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_viewYear',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  )),
              AnimatedBuilder(
                animation: _zoomCtrl,
                builder: (context, child) => Opacity(
                  opacity: _zoomCtrl.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_monthShort[_nowMonth - 1]} $_nowYear',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.25,
          ),
          itemCount: 12,
          itemBuilder: (ctx, i) {
            final month = i + 1;
            final isCurrent = month == _nowMonth && _viewYear == _nowYear;
            final isPast = DateTime(_viewYear, month)
                .isBefore(DateTime(_nowYear, _nowMonth));

            return AnimatedBuilder(
              animation: Listenable.merge([
                _cardFade[i],
                if (isCurrent) _zoomAnim,
                if (isCurrent) _pulseAnim,
              ]),
              builder: (context, child) {
                final fade  = _cardFade[i].value;
                final zoom  = isCurrent ? _zoomAnim.value : 1.0;
                final pulse = isCurrent ? _pulseAnim.value : 1.0;
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - fade)),
                  child: Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: zoom,
                      child: _MonthTile(
                        label: _monthShort[i],
                        isCurrent: isCurrent, isPast: isPast,
                        pulseValue: pulse,
                        onTap: () {
                          setState(() { _viewMonth = month; _inMonthView = true; });
                          _zoomInCtrl.forward(from: 0);
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ── Day grid ─────────────────────────────────────────────────────
  Widget _buildDayGrid(ThemeData theme) {
    final firstDay    = DateTime(_viewYear, _viewMonth, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_viewYear, _viewMonth);
    final startWeekday = firstDay.weekday % 7;
    final rows = ((startWeekday + daysInMonth) / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.grid_view_rounded, size: 20),
              tooltip: 'Year view',
              onPressed: _goToYearView,
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(firstDay),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left), padding: EdgeInsets.zero,
              onPressed: () => setState(() {
                if (_viewMonth == 1) { _viewYear--; _viewMonth = 12; }
                else { _viewMonth--; }
              }),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right), padding: EdgeInsets.zero,
              onPressed: () => setState(() {
                if (_viewMonth == 12) { _viewYear++; _viewMonth = 1; }
                else { _viewMonth++; }
              }),
            ),
          ],
        ),
        // Weekday headers
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Row(
            children: _weekDays.map((d) => Expanded(
              child: Center(
                child: Text(d, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: d == 'Sun' ? Colors.red[400] : Colors.grey[500],
                )),
              ),
            )).toList(),
          ),
        ),
        // Day cells
        ...List.generate(rows, (row) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List.generate(7, (col) {
              final day = row * 7 + col - startWeekday + 1;
              final valid = day >= 1 && day <= daysInMonth;
              final isToday = valid && day == _today &&
                  _viewMonth == _nowMonth && _viewYear == _nowYear;
              final isPast = valid &&
                  DateTime(_viewYear, _viewMonth, day)
                      .isBefore(DateTime.now().subtract(const Duration(days: 1)));
              return Expanded(
                child: GestureDetector(
                  onTap: valid
                      ? () => widget.onDateTap?.call(DateTime(_viewYear, _viewMonth, day))
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: isToday
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    child: Center(
                      child: Text(
                        valid ? '$day' : '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? Colors.white
                              : isPast ? Colors.grey[400]
                              : col == 0 ? Colors.red[400]
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _zoomInCtrl,
      builder: (context, child) {
        final v = _zoomInCtrl.value;
        final inTransition = _zoomInCtrl.isAnimating;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (!_inMonthView || inTransition || v < 1.0)
              Transform.scale(
                scale: _yearScaleOut.value,
                child: Opacity(
                  opacity: _yearFadeOut.value.clamp(0.0, 1.0),
                  child: _buildYearGrid(theme),
                ),
              ),
            if (_inMonthView)
              Transform.scale(
                scale: _monthScaleIn.value,
                child: Opacity(
                  opacity: _monthFadeIn.value.clamp(0.0, 1.0),
                  child: _buildDayGrid(theme),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MonthTile extends StatelessWidget {
  final String label;
  final bool isCurrent, isPast;
  final double pulseValue;
  final VoidCallback onTap;

  const _MonthTile({
    required this.label, required this.isCurrent, required this.isPast,
    required this.pulseValue, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final bg = isCurrent ? color
        : isPast ? Colors.grey.withValues(alpha: 0.07)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.50);
    final fg = isCurrent ? Colors.white
        : isPast ? Colors.grey[400]!
        : Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isCurrent
              ? Border.all(
                  color: Colors.white.withValues(alpha: pulseValue * 0.6), width: 1.5)
              : Border.all(color: Colors.grey.withValues(alpha: 0.18), width: 1),
          boxShadow: isCurrent
              ? [BoxShadow(
                  color: color.withValues(alpha: pulseValue * 0.40),
                  blurRadius: 14, spreadRadius: 1, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
              color: fg, letterSpacing: 0.5,
            )),
            if (isCurrent) ...[
              const SizedBox(height: 4),
              Container(
                width: 5, height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: pulseValue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
