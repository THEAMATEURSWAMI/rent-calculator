import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/remember_me_service.dart';
import '../utils/app_theme.dart';
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

    return Drawer(
      backgroundColor: AppTheme.darkBackground,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                AvatarSelectorWidget(
                  userName: displayName,
                  size: 90,
                  showLabel: true,
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _DrawerTile(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  onTap: () => context.go('/dashboard'),
                ),
                _DrawerTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'Rent Payments',
                  onTap: () => context.go('/rent'),
                ),
                _DrawerTile(
                  icon: Icons.account_balance_rounded,
                  label: 'Budgeting',
                  onTap: () => context.go('/budget'),
                ),
                _DrawerTile(
                  icon: Icons.attach_money_rounded,
                  label: 'Expenses',
                  onTap: () => context.go('/expenses'),
                ),
                _DrawerTile(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Connected Banks',
                  onTap: () => context.go('/plaid'),
                ),
                _DrawerTile(
                  icon: Icons.water_drop_rounded,
                  label: 'Utility Splitter',
                  onTap: () => context.go('/utilities'),
                ),
                const Divider(height: 32, indent: 12, endIndent: 12),
                _DrawerTile(
                  icon: Icons.settings_rounded,
                  label: 'Account Settings',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                HapticFeedback.mediumImpact();
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
      leading: Icon(icon, color: AppTheme.primaryTeal),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
        if (Navigator.canPop(context)) Navigator.pop(context);
      },
    );
  }
}
