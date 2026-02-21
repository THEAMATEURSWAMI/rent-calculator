import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/remember_me_service.dart';
import 'avatar_selector_widget.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  String _nameFrom(String email) {
    final base = email.split('@').first;
    return base.isEmpty ? '' : base[0].toUpperCase() + base.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.watch<FirebaseService>();
    final email = firebaseService.currentUser?.email ?? '';
    final displayName = _nameFrom(email);
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            ),
            child: Center(
              child: AvatarSelectorWidget(
                userName: displayName,
                size: 80,
                showLabel: true,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerTile(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  onTap: () => context.go('/dashboard'),
                ),
                _DrawerTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Rent Payments',
                  onTap: () => context.go('/rent'),
                ),
                _DrawerTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Budgeting',
                  onTap: () => context.go('/budget'),
                ),
                _DrawerTile(
                  icon: Icons.attach_money_outlined,
                  label: 'Expenses',
                  onTap: () => context.go('/expenses'),
                ),
                _DrawerTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Connected Banks',
                  onTap: () => context.go('/plaid'),
                ),
                _DrawerTile(
                  icon: Icons.water_drop_outlined,
                  label: 'Utility Splitter',
                  onTap: () => context.go('/utilities'),
                ),
                const Divider(),
                _DrawerTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    // TODO: Implement settings page
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await RememberMeService.clearRemembered();
                await firebaseService.signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        onTap();
        // Close drawer after navigation if needed? 
        // go_router context.go might handle it, but Navigator.pop(context) is safer.
        if (Navigator.canPop(context)) Navigator.pop(context);
      },
    );
  }
}
