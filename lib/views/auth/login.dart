import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../customer/home_dashboard.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl,  curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Toggle login / signup ──────────────────────────────────────────────────
  void _toggleMode() {
    _slideCtrl.reset();
    _fadeCtrl.reset();
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  // ── Navigate to Home ───────────────────────────────────────────────────────
  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => const HomeDashboard(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
  }

  // ── Sign In ────────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Sign Up ────────────────────────────────────────────────────────────────
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await credential.user?.updateDisplayName(_nameController.text.trim());
      if (mounted) _goHome();
      await FirebaseFirestore.instance
    .collection('users')
    .doc(credential.user!.uid)
    .set({
  'name':      _nameController.text.trim(),
  'phone':     _phoneController.text.trim(),
  'email':     _emailController.text.trim(),
  'createdAt': DateTime.now().toIso8601String(),
  'rating':    0,
});
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Forgot password ────────────────────────────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) _showSnack('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    }
  }

  // ── Error messages ─────────────────────────────────────────────────────────
  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':         return 'No account found with this email.';
      case 'wrong-password':         return 'Incorrect password. Try again.';
      case 'email-already-in-use':   return 'This email is already registered.';
      case 'weak-password':          return 'Password must be at least 6 characters.';
      case 'invalid-email':          return 'Please enter a valid email address.';
      case 'too-many-requests':      return 'Too many attempts. Please wait a moment.';
      case 'network-request-failed': return 'No internet connection.';
      default:                       return 'Something went wrong. Please try again.';
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: kPrimaryGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F3D26), Color(0xFF1A7A4A), Color(0xFF0D2B1A)],
              ),
            ),
          ),
          Positioned(top: -60, right: -60,
            child: Container(width: 220, height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: kAccentGreen.withOpacity(0.08)))),
          Positioned(top: 40, left: -40,
            child: Container(width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04)))),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(color: Colors.white,
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Center(child: Text('EF',
                                  style: TextStyle(color: kPrimaryGreen,
                                    fontWeight: FontWeight.w800, fontSize: 16,
                                    letterSpacing: -0.5)))),
                              const SizedBox(width: 10),
                              const Text('EasyFix',
                                style: TextStyle(color: Colors.white,
                                  fontSize: 20, fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5)),
                            ]),
                            const SizedBox(height: 40),
                            Text(
                              _isLogin ? 'Welcome\nback 👋' : 'Join\nEasyFix 🔧',
                              style: const TextStyle(color: Colors.white,
                                fontSize: 42, fontWeight: FontWeight.w800,
                                height: 1.1, letterSpacing: -1.5)),
                            const SizedBox(height: 10),
                            Text(
                              _isLogin
                                  ? 'Sign in to find trusted repair\nprofessionals near you'
                                  : 'Create an account and get repairs\ndone fast and safely',
                              style: const TextStyle(color: Color(0xFFB8D4C4),
                                fontSize: 15, height: 1.5)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Card
                    SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: kCardBg,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: kBorder),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTabs(),
                                const SizedBox(height: 28),

                                if (!_isLogin) ...[
                                  _buildLabel('Full Name'),
                                  const SizedBox(height: 8),
                                  _buildField(
                                    controller: _nameController,
                                    hint: 'John Kamau',
                                    icon: Icons.person_outline_rounded,
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Enter your name' : null,
                                  ),
                                  const SizedBox(height: 18),
                                  _buildLabel('Phone Number'),
                                  const SizedBox(height: 8),
                                  _buildField(
                                    controller: _phoneController,
                                    hint: '+254 712 345 678',
                                    icon: Icons.phone_outlined,
                                    keyboard: TextInputType.phone,
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Enter your phone' : null,
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                _buildLabel('Email Address'),
                                const SizedBox(height: 8),
                                _buildField(
                                  controller: _emailController,
                                  hint: 'you@gmail.com',
                                  icon: Icons.mail_outline_rounded,
                                  keyboard: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Enter your email';
                                    if (!v.contains('@')) return 'Enter a valid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                _buildLabel('Password'),
                                const SizedBox(height: 8),
                                _buildField(
                                  controller: _passwordController,
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  isPassword: true,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Enter your password';
                                    if (v.length < 6) return 'Min 6 characters';
                                    return null;
                                  },
                                ),

                                if (_isLogin) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      onTap: _forgotPassword,
                                      child: const Text('Forgot password?',
                                        style: TextStyle(color: kAccentGreen,
                                          fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],

                                // Error banner
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4444).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFFFF4444).withOpacity(0.3)),
                                    ),
                                    child: Row(children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: Color(0xFFFF6B6B), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFFF6B6B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ))),
                                    ]),
                                  ),
                                ],

                                const SizedBox(height: 28),
                                _buildSubmitBtn(),
                                const SizedBox(height: 24),

                                Row(children: [
                                  Expanded(child: Container(height: 1, color: kBorder)),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('or continue with',
                                      style: TextStyle(color: kTextSecondary, fontSize: 12))),
                                  Expanded(child: Container(height: 1, color: kBorder)),
                                ]),

                                const SizedBox(height: 20),
                                _buildGoogleBtn(),
                                const SizedBox(height: 24),

                                Center(
                                  child: GestureDetector(
                                    onTap: _toggleMode,
                                    child: RichText(
                                      text: TextSpan(
                                        text: _isLogin
                                            ? "Don't have an account? "
                                            : 'Already have an account? ',
                                        style: const TextStyle(
                                            color: kTextSecondary, fontSize: 14),
                                        children: [
                                          TextSpan(
                                            text: _isLogin ? 'Sign Up' : 'Sign In',
                                            style: const TextStyle(
                                              color: kAccentGreen,
                                              fontWeight: FontWeight.w700,
                                            )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Worker CTA
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: kBorder.withOpacity(0.6), width: 1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: kPrimaryGreen.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.handyman_outlined,
                                  color: kAccentGreen, size: 18)),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Are you a repair professional?',
                                  style: TextStyle(color: kTextPrimary,
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('Join as a worker →',
                                  style: TextStyle(color: kAccentGreen,
                                    fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────
  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
          color: kSurfaceBg, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _tab('Sign In', _isLogin),
        _tab('Sign Up', !_isLogin),
      ]),
    );
  }

  Widget _tab(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () { if ((label == 'Sign In') != _isLogin) _toggleMode(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? kPrimaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(label,
            style: TextStyle(
              color: active ? Colors.white : kTextSecondary,
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ))),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
    style: const TextStyle(color: kTextSecondary, fontSize: 12,
        fontWeight: FontWeight.w600, letterSpacing: 0.5));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(color: kTextPrimary, fontSize: 15,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF555555), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF555555), size: 20),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword))
            : null,
        filled: true,
        fillColor: kSurfaceBg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kAccentGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF4444))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF4444), width: 1.5)),
        errorStyle: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildSubmitBtn() {
    return GestureDetector(
      onTap: _isLoading ? null : (_isLogin ? _signIn : _signUp),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A7A4A), Color(0xFF25A865)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: kPrimaryGreen.withOpacity(0.4),
            blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(_isLogin ? 'Sign In' : 'Create Account',
                  style: const TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w700,
                    letterSpacing: 0.3)),
        ),
      ),
    );
  }

  Widget _buildGoogleBtn() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          color: kSurfaceBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white),
            child: const Center(child: Text('G',
              style: TextStyle(color: Color(0xFF4285F4),
                fontWeight: FontWeight.w800, fontSize: 13)))),
          const SizedBox(width: 10),
          const Text('Continue with Google',
            style: TextStyle(color: kTextPrimary,
              fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}