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
  static final FirebaseService _firebaseService = FirebaseService();

  static GoRouter get router => _router;

  static final _router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = _firebaseService.currentUser != null;
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
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/login/:userName',
        builder: (context, state) => UserLoginScreen(
          userName: state.pathParameters['userName'] ?? '',
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/rent',
        builder: (context, state) => const RentTrackingScreen(),
      ),
      GoRoute(
        path: '/rent/add',
        builder: (context, state) => const AddRentPaymentScreen(),
      ),
      GoRoute(
        path: '/budget',
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: '/budget/add',
        builder: (context, state) => const AddBudgetScreen(),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpensesScreen(),
      ),
      GoRoute(
        path: '/expenses/add',
        builder: (context, state) => const AddExpenseScreen(),
      ),
      GoRoute(
        path: '/plaid',
        builder: (context, state) => const PlaidConnectScreen(),
      ),
      GoRoute(
        path: '/utilities',
        builder: (context, state) => const UtilitySplitScreen(),
      ),
    ],
  );
}
