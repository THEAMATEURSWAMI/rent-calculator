// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/plaid_service.dart';
import '../../services/firebase_service.dart';
import '../../models/plaid_account.dart';

// ─── JS interop ──────────────────────────────────────────────────────────────
@JS('openPlaidLink')
external void _openPlaidLinkJs(
  JSString linkToken,
  JSFunction onSuccess,
  JSFunction onExit,
);

// ─── colours ─────────────────────────────────────────────────────────────────
const _plaidGreen = Color(0xFF00B050);
const _plaidBlack = Color(0xFF111111);

class PlaidConnectScreen extends StatefulWidget {
  const PlaidConnectScreen({super.key});

  @override
  State<PlaidConnectScreen> createState() => _PlaidConnectScreenState();
}

class _PlaidConnectScreenState extends State<PlaidConnectScreen>
    with SingleTickerProviderStateMixin {
  // ── service ───────────────────────────────────────────────────────────────
  final PlaidService _plaid = const PlaidService();

  // ── state ─────────────────────────────────────────────────────────────────
  _ScreenState _screen = _ScreenState.checking;
  List<PlaidAccount> _accounts  = [];
  String? _institutionName;
  DateTime? _lastSynced;
  String? _error;

  // pulse animation for the connect button
  late final AnimationController _pulse;
  late final Animation<double>    _pulseAnim;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _loadConnectionStatus();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ── load ──────────────────────────────────────────────────────────────────
  Future<void> _loadConnectionStatus() async {
    setState(() => _screen = _ScreenState.checking);
    try {
      final fb     = context.read<FirebaseService>();
      final userId = fb.currentUser?.uid;
      if (userId == null) throw Exception('Not signed in');

      final stored = await fb.getPlaidConnection(userId);
      if (!mounted) return;

      if (stored != null) {
        final rawAccounts = (stored['accounts'] as List? ?? [])
            .map((a) => PlaidAccount.fromJson(
                Map<String, dynamic>.from(a as Map)))
            .toList();
        final ts = stored['lastSynced'];
        setState(() {
          _accounts        = rawAccounts;
          _institutionName = stored['institutionName'] as String?;
          _lastSynced      = ts != null ? (ts as dynamic).toDate() as DateTime : null;
          _screen          = _ScreenState.connected;
        });
        return;
      }

      final backendUp = await _plaid.ping();
      if (!mounted) return;
      setState(() {
        _screen = backendUp
            ? _ScreenState.readyToConnect
            : _ScreenState.setupRequired;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error  = e.toString();
        _screen = _ScreenState.setupRequired;
      });
    }
  }

  // ── connect ───────────────────────────────────────────────────────────────
  Future<void> _startConnect() async {
    setState(() {
      _screen = _ScreenState.connecting;
      _error  = null;
    });

    try {
      final fb     = context.read<FirebaseService>();
      final userId = fb.currentUser?.uid;
      if (userId == null) throw Exception('Not signed in');

      final linkToken = await _plaid.createLinkToken(userId);
      if (!mounted) return;

      _openPlaidLinkWeb(linkToken: linkToken, userId: userId, fb: fb);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error  = 'Could not start bank connection: $e';
        _screen = _ScreenState.readyToConnect;
      });
    }
  }

  void _openPlaidLinkWeb({
    required String linkToken,
    required String userId,
    required FirebaseService fb,
  }) {
    // onSuccess: called by Plaid with (publicToken, metadataJsonString)
    void onSuccess(JSAny? pubTokenJs, JSAny? metaJs) {
      final publicToken = (pubTokenJs as JSString?)?.toDart ?? '';
      // Schedule async work outside this synchronous JS callback
      Future(() async {
        if (!mounted) return;
        setState(() => _screen = _ScreenState.connecting);
        try {
          final result = await _plaid.exchangePublicToken(
            publicToken: publicToken,
            userId:      userId,
          );
          if (!mounted) return;

          final institutionName =
              result['institution_name'] as String? ?? 'Your Bank';
          final institutionId =
              result['institution_id'] as String? ?? '';
          final rawAccounts =
              (result['accounts'] as List? ?? [])
                  .map((a) => PlaidAccount.fromJson(
                      Map<String, dynamic>.from(a as Map)))
                  .toList();

          await fb.savePlaidConnection(
            userId:          userId,
            institutionId:   institutionId,
            institutionName: institutionName,
            accounts:        rawAccounts,
          );
          if (!mounted) return;

          setState(() {
            _accounts        = rawAccounts;
            _institutionName = institutionName;
            _lastSynced      = DateTime.now();
            _screen          = _ScreenState.connected;
          });
          _showSnack('🎉 Bank connected successfully!');
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _error  = 'Connection failed: $e';
            _screen = _ScreenState.readyToConnect;
          });
        }
      });
    }

    // onExit: called when user closes Plaid Link (with optional error)
    void onExit(JSAny? errJs, JSAny? metaJs) {
      if (!mounted) return;
      setState(() => _screen = _ScreenState.readyToConnect);
      final errStr = (errJs as JSString?)?.toDart;
      if (errStr != null && errStr.isNotEmpty && errStr != 'null') {
        setState(() => _error = 'Plaid Link closed: $errStr');
      }
    }

    _openPlaidLinkJs(
      linkToken.toJS,
      onSuccess.toJS,
      onExit.toJS,
    );
  }

  // ── sync ──────────────────────────────────────────────────────────────────
  Future<void> _syncTransactions() async {
    setState(() {
      _screen = _ScreenState.syncing;
      _error  = null;
    });
    try {
      final fb     = context.read<FirebaseService>();
      final userId = fb.currentUser?.uid ?? '';

      await _plaid.syncTransactions(userId);
      if (!mounted) return;

      final fresh = await _plaid.getAccounts(userId);
      if (!mounted) return;

      await fb.savePlaidConnection(
        userId:          userId,
        institutionId:   '',
        institutionName: _institutionName ?? '',
        accounts:        fresh,
      );
      if (!mounted) return;

      setState(() {
        _accounts   = fresh;
        _lastSynced = DateTime.now();
        _screen     = _ScreenState.connected;
      });
      _showSnack('Transactions synced!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error  = 'Sync failed: $e';
        _screen = _ScreenState.connected;
      });
    }
  }

  // ── disconnect ────────────────────────────────────────────────────────────
  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Bank?'),
        content: const Text(
          'This will remove your linked bank account. '
          'Synced transactions will stay in your expenses.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Disconnect',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _screen = _ScreenState.connecting);
    try {
      final fb     = context.read<FirebaseService>();
      final userId = fb.currentUser?.uid ?? '';
      await _plaid.disconnect(userId);
      if (!mounted) return;
      await fb.disconnectPlaid(userId);
      if (!mounted) return;
      setState(() {
        _accounts        = [];
        _institutionName = null;
        _lastSynced      = null;
        _screen          = _ScreenState.readyToConnect;
      });
      _showSnack('Bank disconnected.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error  = 'Disconnect failed: $e';
        _screen = _ScreenState.connected;
      });
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Bank Account'),
        actions: [
          if (_screen == _ScreenState.connected)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync transactions',
              onPressed: _syncTransactions,
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return switch (_screen) {
      _ScreenState.checking ||
      _ScreenState.connecting ||
      _ScreenState.syncing    => _buildLoader(theme),
      _ScreenState.setupRequired   => _buildSetupRequired(theme),
      _ScreenState.readyToConnect  => _buildReadyToConnect(theme),
      _ScreenState.connected       => _buildConnected(theme),
    };
  }

  // ── loader ────────────────────────────────────────────────────────────────
  Widget _buildLoader(ThemeData theme) {
    final label = switch (_screen) {
      _ScreenState.syncing    => 'Syncing transactions…',
      _ScreenState.connecting => 'Opening secure connection…',
      _                       => 'Checking connection…',
    };
    return Center(
      key: const ValueKey('loader'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(label, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  // ── setup required ────────────────────────────────────────────────────────
  Widget _buildSetupRequired(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('setup'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _HeroCard(
            icon:      Icons.developer_mode,
            iconColor: Colors.orange,
            title:     'Backend Setup Required',
            subtitle:
                'Bank linking uses Plaid, which needs a small server-side backend '
                'to keep your credentials safe. '
                'Follow these steps once and you\'re set.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          const _SetupSteps(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loadConnectionStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Again'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── ready to connect ──────────────────────────────────────────────────────
  Widget _buildReadyToConnect(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('ready'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _HeroCard(
            icon:      Icons.account_balance_rounded,
            iconColor: _plaidGreen,
            title:     'Connect Your Bank',
            subtitle:
                'Securely link your bank account through Plaid to automatically '
                'track transactions and stay on top of your budget.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 28),
          ScaleTransition(
            scale: _pulseAnim,
            child: ElevatedButton.icon(
              onPressed: _startConnect,
              icon: const Icon(Icons.link_rounded),
              label: const Text('Connect Bank Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _plaidBlack,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SecurityNote(),
          const SizedBox(height: 16),
          const _PlaidBadge(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── connected ─────────────────────────────────────────────────────────────
  Widget _buildConnected(ThemeData theme) {
    final fmtDate  = DateFormat('MMM d, y  h:mm a');
    final fmtMoney = NumberFormat.currency(symbol: r'$');

    return SingleChildScrollView(
      key: const ValueKey('connected'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // status badge
          Card(
            color: _plaidGreen.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: _plaidGreen.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: _plaidGreen,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _institutionName ?? 'Bank Connected',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        if (_lastSynced != null)
                          Text(
                            'Last synced: ${fmtDate.format(_lastSynced!)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle,
                      color: _plaidGreen, size: 26),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          if (_accounts.isNotEmpty) ...[
            Text('Accounts',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ..._accounts.map((acc) =>
                _AccountTile(account: acc, fmtMoney: fmtMoney)),
            const SizedBox(height: 20),
          ],
          ElevatedButton.icon(
            onPressed: _syncTransactions,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Sync Transactions Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _plaidBlack,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off_rounded,
                color: Colors.red),
            label: const Text('Disconnect Bank',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),
          const _SecurityNote(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── private widgets ─────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: Colors.orange[800], fontSize: 13))),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              color: Colors.blue[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your bank credentials are never stored by us. '
              'All connections use bank-level 256-bit encryption through Plaid.',
              style: TextStyle(
                  color: Colors.blue[900],
                  fontSize: 12,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaidBadge extends StatelessWidget {
  const _PlaidBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Powered by ',
              style:
                  TextStyle(color: Colors.grey[500], fontSize: 12)),
          Text('Plaid',
              style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.fmtMoney});
  final PlaidAccount account;
  final NumberFormat fmtMoney;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (account.subtype != null)
        account.subtype![0].toUpperCase() +
            account.subtype!.substring(1),
      if (account.mask != null) '••••${account.mask}',
    ].join('  ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey[200]!)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _plaidBlack,
          child: Icon(_accountIcon(account.type),
              color: Colors.white, size: 18),
        ),
        title: Text(account.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: sub.isNotEmpty
            ? Text(sub,
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 12))
            : null,
        trailing: account.balance != null
            ? Text(
                fmtMoney.format(account.balance),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              )
            : null,
      ),
    );
  }

  IconData _accountIcon(String type) {
    return switch (type.toLowerCase()) {
      'credit'     => Icons.credit_card_rounded,
      'loan'       => Icons.receipt_long_rounded,
      'investment' => Icons.trending_up_rounded,
      _            => Icons.account_balance_rounded,
    };
  }
}

// ─── Setup instructions ───────────────────────────────────────────────────────

class _SetupSteps extends StatelessWidget {
  const _SetupSteps();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: const ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(Icons.list_alt_rounded),
          title: Text('Setup Instructions',
              style: TextStyle(fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Step(
                    n:     1,
                    title: 'Create a free Plaid account',
                    body:
                        'Go to dashboard.plaid.com → sign up for free → '
                        'copy your client_id and sandbox secret.',
                    linkText: 'dashboard.plaid.com',
                  ),
                  _Step(
                    n:     2,
                    title: 'Deploy Cloud Functions',
                    body:
                        'From the project root:\n'
                        '  npm install -g firebase-tools\n'
                        '  firebase login\n'
                        '  cd functions && npm install\n'
                        '  firebase functions:config:set \\\n'
                        '    plaid.client_id="YOUR_ID" \\\n'
                        '    plaid.secret="YOUR_SECRET" \\\n'
                        '    plaid.env="sandbox"\n'
                        '  firebase deploy --only functions',
                  ),
                  _Step(
                    n:     3,
                    title: 'Come back and connect',
                    body:
                        'Once deployed, tap "Check Again" below, '
                        'then hit Connect Bank Account.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.title,
    required this.body,
    this.linkText,
  });
  final int     n;
  final String  title;
  final String  body;
  final String? linkText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _plaidBlack,
            child: Text('$n',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.5)),
                if (linkText != null)
                  Text(linkText!,
                      style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                          decoration: TextDecoration.underline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── screen state enum ────────────────────────────────────────────────────────
enum _ScreenState {
  checking,
  setupRequired,
  readyToConnect,
  connecting,
  syncing,
  connected,
}
