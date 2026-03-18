import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true, _loading = false;
  String? _error;

  @override
  void dispose() { _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your credentials.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authProvider);
      final response = await auth.signIn(email, password);
      if (response.user == null) {
        setState(() { _error = 'Invalid credentials. Try again.'; _loading = false; });
        return;
      }
      final profile = await supabase.from('profiles').select('role, is_active').eq('id', response.user!.id).single();
      if (!mounted) return;
      if (profile['is_active'] == false) {
        await auth.signOut();
        setState(() { _error = 'Account inactive. Contact admin.'; _loading = false; });
        return;
      }
      final role = profile['role'] as String;
      if (role == 'teacher') context.go('/teacher/home');
      else if (role == 'student') context.go('/student/home');
      else {
        await auth.signOut();
        setState(() { _error = 'Please use the web admin panel.'; _loading = false; });
      }
    } catch (_) {
      setState(() { _error = 'Invalid email or password.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Blue top section
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1A6FD1), Color(0xFF1557A8)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 44),
                    ),
                    const SizedBox(height: 16),
                    Text('EduTrack', style: GoogleFonts.publicSans(
                      color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Smart Attendance for Smart Schools', style: GoogleFonts.publicSans(
                      color: Colors.white.withOpacity(0.75), fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),

          // White bottom form section
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student Login', style: GoogleFonts.publicSans(
                      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 24),

                    // Email
                    Text('Roll Number / Email', style: GoogleFonts.publicSans(
                      fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textGray)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.publicSans(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter your roll number',
                        prefixIcon: const Icon(Icons.person_outline, size: 20, color: AppColors.textGray),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    Text('Password', style: GoogleFonts.publicSans(
                      fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textGray)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      onSubmitted: (_) => _login(),
                      style: GoogleFonts.publicSans(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textGray),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20, color: AppColors.textGray),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text('Forgot Password?', style: GoogleFonts.publicSans(
                          color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],

                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text('Login', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),

                    const SizedBox(height: 20),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 16),
                    Center(child: RichText(text: TextSpan(
                      style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.textGray),
                      children: [
                        const TextSpan(text: 'Need a new account? '),
                        TextSpan(text: 'Contact school admin',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ))),
                    const SizedBox(height: 24),
                    Center(child: Text('VERSION 1.2.0',
                      style: GoogleFonts.publicSans(fontSize: 11, color: AppColors.textLight, letterSpacing: 1.5))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
