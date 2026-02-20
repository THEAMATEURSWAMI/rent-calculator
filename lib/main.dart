import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'utils/app_router.dart';
import 'services/firebase_service.dart';
import 'services/user_setup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDrhe_jNTXrGF1xiclVPXWAuztRAglGXuM',
        appId: '1:707294763198:web:d89c51bb2f52beeffe66ef',
        messagingSenderId: '707294763198',
        projectId: 'rent-calculator-bedd3',
        authDomain: 'rent-calculator-bedd3.firebaseapp.com',
        storageBucket: 'rent-calculator-bedd3.firebasestorage.app',
      ),
    );

    // Create Jacob, Nico & Eddy accounts if they don't exist yet
    await UserSetupService.createDefaultUsersIfNeeded();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const RentCalculatorApp());
}

class RentCalculatorApp extends StatelessWidget {
  const RentCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseService>(
          create: (_) => FirebaseService(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Rent Calculator',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        routerConfig: AppRouter.router,
      ),
    );
  }
}
