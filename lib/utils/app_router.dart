import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/user_login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/rent/rent_tracking_screen.dart';
import '../screens/rent/add_rent_payment_screen.dart';
import '../screens/budget/budget_screen.dart';
import '../screens/budget/add_budget_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/expenses/add_expense_screen.dart';
import '../screens/plaid/plaid_connect_screen.dart';
import '../screens/utilities/utility_split_screen.dart';
import '../services/firebase_service.dart';

class AppRouter {
  static GoRouter createRouter(FirebaseService firebaseService) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final isLoggedIn = firebaseService.currentUser != null;
        final path = state.matchedLocation;
        final isGoingToAuth = path == '/login' ||
            path == '/signup' ||
            path.startsWith('/login/');

        if (!isLoggedIn && !isGoingToAuth) {
          return '/login';
        }
        if (isLoggedIn && isGoingToAuth) {
          return '/dashboard';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => const _NoTransitionPage(child: LoginScreen()),
        ),
        GoRoute(
          path: '/login/:userName',
          pageBuilder: (context, state) => _FadeTransitionPage(
            child: UserLoginScreen(
              userName: state.pathParameters['userName'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: '/signup',
          pageBuilder: (context, state) => const _FadeTransitionPage(child: SignUpScreen()),
        ),
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => const _FadeTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/rent',
          pageBuilder: (context, state) => const _FadeTransitionPage(child: RentTrackingScreen()),
        ),
        GoRoute(
          path: '/rent/add',
          pageBuilder: (context, state) => const _SlideTransitionPage(child: AddRentPaymentScreen()),
        ),
        GoRoute(
          path: '/budget',
          pageBuilder: (context, state) => const _FadeTransitionPage(child: BudgetScreen()),
        ),
        GoRoute(
          path: '/budget/add',
          pageBuilder: (context, state) => const _SlideTransitionPage(child: AddBudgetScreen()),
        ),
        GoRoute(
          path: '/expenses',
          pageBuilder: (context, state) => const _FadeTransitionPage(child: ExpensesScreen()),
        ),
        GoRoute(
          path: '/expenses/add',
          pageBuilder: (context, state) => const _SlideTransitionPage(child: AddExpenseScreen()),
        ),
        GoRoute(
          path: '/plaid',
          pageBuilder: (context, state) => const _FadeTransitionPage(child: PlaidConnectScreen()),
        ),
        GoRoute(
          path: '/utilities',
          pageBuilder: (context, state) => const _FadeTransitionPage(child: UtilitySplitScreen()),
        ),
      ],
    );
  }
}

class _NoTransitionPage extends CustomTransitionPage {
  const _NoTransitionPage({required super.child})
      : super(
          transitionsBuilder: _noTransition,
          transitionDuration: Duration.zero,
        );

  static Widget _noTransition(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => child;
}

class _FadeTransitionPage extends CustomTransitionPage {
  const _FadeTransitionPage({required super.child})
      : super(
          transitionsBuilder: _fadeTransition,
          transitionDuration: const Duration(milliseconds: 300),
        );

  static Widget _fadeTransition(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(opacity: animation, child: child);
  }
}

class _SlideTransitionPage extends CustomTransitionPage {
  const _SlideTransitionPage({required super.child})
      : super(
          transitionsBuilder: _slideTransition,
          transitionDuration: const Duration(milliseconds: 400),
        );

  static Widget _slideTransition(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return SlideTransition(
      position: animation.drive(
        Tween(begin: const Offset(0, 1), end: Offset.zero).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
      ),
      child: child,
    );
  }
}
