import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

/// Login screen — email/password sign in, sign up, or guest access.
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Please enter both email and password.');
      return;
    }

    setState(() { _loading = true; _errorText = null; });

    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      if (mounted) widget.onLoginSuccess();
    } on AuthException catch (e) {
      setState(() => _errorText = _friendlyAuthError(e.message));
    } catch (e) {
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Enter an email and password to create an account.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorText = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _errorText = null; });

    try {
      final response = await _supabase.auth.signUp(email: email, password: password);
      if (response.user != null && mounted) {
        widget.onLoginSuccess();
      }
    } on AuthException catch (e) {
      setState(() => _errorText = _friendlyAuthError(e.message));
    } catch (e) {
      setState(() => _errorText = 'Could not create account. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() { _loading = true; _errorText = null; });

    try {
      await _supabase.auth.signInAnonymously();
      if (mounted) widget.onLoginSuccess();
    } on AuthException catch (e) {
      setState(() => _errorText = 'Guest access unavailable: ${e.message}');
    } catch (e) {
      setState(() => _errorText = 'Guest access failed. Please sign in instead.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') || lower.contains('invalid_credentials')) {
      return 'Wrong email or password.';
    }
    if (lower.contains('user not found')) return 'No account found with this email.';
    if (lower.contains('email not confirmed')) return 'Check your inbox to confirm your email.';
    if (lower.contains('user already registered')) return 'An account with this email already exists. Try signing in.';
    if (lower.contains('rate limit')) return 'Too many attempts. Wait a moment and try again.';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w800),
                    children: const [
                      TextSpan(text: 'Car', style: TextStyle(color: AppColors.neonBlue)),
                      TextSpan(text: 'ta', style: TextStyle(color: AppColors.deepBlue)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your intelligent event planner',
                  style: GoogleFonts.outfit(color: AppColors.neonBlue, fontSize: 13),
                ),
                const SizedBox(height: 40),

                // Card
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back',
                          style: GoogleFonts.outfit(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                          )),
                      const SizedBox(height: 4),
                      Text('Sign in to your account',
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 24),

                      // Email
                      Text('Email address',
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'you@example.com',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      if (_errorText != null && _errorText!.contains('email')) ...[
                        const SizedBox(height: 4),
                        Text(_errorText!, style: GoogleFonts.outfit(color: AppColors.neonBlue, fontSize: 11)),
                      ],
                      const SizedBox(height: 20),

                      // Password
                      Text('Password',
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _passwordController,
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      if (_errorText != null && !_errorText!.contains('email')) ...[
                        const SizedBox(height: 6),
                        Text(_errorText!, style: GoogleFonts.outfit(color: AppColors.neonBlue, fontSize: 11)),
                      ],
                      const SizedBox(height: 28),

                      // Sign In button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Sign In',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Create account link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
                    GestureDetector(
                      onTap: _loading ? null : _signUp,
                      child: Text('Create account',
                          style: GoogleFonts.outfit(
                            color: AppColors.neonBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.neonBlue,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Divider
                Row(children: [
                  Expanded(child: Container(height: 1, color: AppColors.surfaceBorder)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                  Expanded(child: Container(height: 1, color: AppColors.surfaceBorder)),
                ]),
                const SizedBox(height: 20),

                // Guest button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _continueAsGuest,
                    icon: const Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                    label: Text('Continue as Guest',
                        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.surfaceBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15),
      cursorColor: AppColors.neonBlue,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffix,
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: AppColors.textSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neonBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
