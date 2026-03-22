import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'core/supabase_connector.dart';
import 'core/powersync_connector.dart';
import 'core/app_config.dart';
import 'screens/home_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
    ),
  );

  // Initialise Supabase + PowerSync if credentials are configured
  if (AppConfig.supabaseUrl.isNotEmpty) {
    try {
      await initSupabase();
      await initPowerSync();
    } catch (e) {
      debugPrint('Init error (continuing without sync): $e');
    }
  }

  runApp(const CartaApp());
}

class CartaApp extends StatelessWidget {
  const CartaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AuthGate(),
    );
  }
}

/// Auth gate — checks if user is logged in.
/// If yes → main shell. If no → onboarding.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _ready = false;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // If Supabase is not configured, skip auth and go straight to home
    if (AppConfig.supabaseUrl.isEmpty) {
      setState(() {
        _ready = true;
        _loggedIn = true; // bypass auth in dev mode
      });
      return;
    }

    // Check if already logged in
    final user = currentUserId;
    setState(() {
      _ready = true;
      _loggedIn = user != null;
    });
  }

  void _onOnboardingComplete() {
    setState(() => _loggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
      );
    }

    if (!_loggedIn) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    return const _MainShell();
  }
}

/// Bottom-nav tab shell with Chat, Plan, Wallet tabs.
class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _tab = 0;

  static const _screens = [
    HomeScreen(),
    PlanScreen(),
    WalletScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.surfaceBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.neonBlue,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'My Plan'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Wallet'),
          ],
        ),
      ),
    );
  }
}
