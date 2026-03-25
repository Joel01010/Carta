import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_theme.dart';
import 'core/supabase_connector.dart';
import 'core/powersync_connector.dart';
import 'core/app_config.dart';
import 'screens/home_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
    ),
  );

  // Load environment variables from assets/.env
  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    debugPrint('dotenv load failed (using defaults): $e');
  }

  // Initialise Supabase (required for auth)
  if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty) {
    try {
      await initSupabase();
    } catch (e) {
      debugPrint('Supabase init error: $e');
    }
  }

  // Initialise PowerSync (optional — app works without it)
  try {
    await initPowerSync();
  } catch (e) {
    debugPrint('PowerSync init error (continuing without sync): $e');
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

/// Auth gate — routes user through login → onboarding → main shell.
///
/// Flow:
///   1. No Supabase session → LoginScreen
///   2. Session exists but no profile → OnboardingScreen
///   3. Session + profile → MainShell
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _ready = false;
  _AuthStep _step = _AuthStep.login;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final userId = currentUserId;

    if (userId == null) {
      // Not signed in → login screen
      setState(() {
        _ready = true;
        _step = _AuthStep.login;
      });
      return;
    }

    // Signed in — check if user has a profile
    try {
      final profile = await supabase
          .from('user_profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      setState(() {
        _ready = true;
        _step = profile != null ? _AuthStep.main : _AuthStep.onboarding;
      });
    } catch (e) {
      // If profile check fails (table doesn't exist yet, etc.), go to onboarding
      debugPrint('Profile check error: $e');
      setState(() {
        _ready = true;
        _step = _AuthStep.onboarding;
      });
    }
  }

  void _onLoginSuccess() {
    // After login, re-check to decide onboarding vs main
    setState(() => _ready = false);
    _checkAuth();
  }

  void _onOnboardingComplete() {
    setState(() => _step = _AuthStep.main);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
      );
    }

    switch (_step) {
      case _AuthStep.login:
        return LoginScreen(onLoginSuccess: _onLoginSuccess);
      case _AuthStep.onboarding:
        return OnboardingScreen(onComplete: _onOnboardingComplete);
      case _AuthStep.main:
        return const _MainShell();
    }
  }
}

enum _AuthStep { login, onboarding, main }

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
