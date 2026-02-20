import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/default_users.dart';
import '../../services/remember_me_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _rememberedUser;

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final name = await RememberMeService.getRememberedUser();
    if (mounted) {
      setState(() => _rememberedUser = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon
                Icon(
                  Icons.home_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Rent Calculator',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Greeting changes if someone is remembered
                Text(
                  _rememberedUser != null
                      ? 'Welcome back, $_rememberedUser!'
                      : 'Who\'s signing in?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _rememberedUser != null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[600],
                        fontWeight: _rememberedUser != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // User profile cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: DefaultUsers.users.map((user) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _UserCard(
                        user: user,
                        isRemembered: _rememberedUser?.toLowerCase() ==
                            user.name.toLowerCase(),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 48),

                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text('Create a new account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final DefaultUser user;
  final bool isRemembered;

  const _UserCard({required this.user, this.isRemembered = false});

  @override
  Widget build(BuildContext context) {
    final color = Color(user.colorValue);

    return GestureDetector(
      onTap: () => context.go('/login/${user.name.toLowerCase()}'),
      child: Column(
        children: [
          // Avatar with optional "remembered" ring
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: isRemembered
                      ? Border.all(
                          color: Colors.green,
                          width: 3,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: isRemembered ? 0.6 : 0.3),
                      blurRadius: isRemembered ? 18 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              // Green checkmark badge for remembered user
              if (isRemembered)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight:
                      isRemembered ? FontWeight.bold : FontWeight.w600,
                  color: isRemembered
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
          ),
          if (isRemembered) ...[
            const SizedBox(height: 4),
            Text(
              'Remembered',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
