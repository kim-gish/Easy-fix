import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'worker_dashboard.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

class WorkerRegisterScreen extends StatefulWidget {
  const WorkerRegisterScreen({super.key});

  @override
  State<WorkerRegisterScreen> createState() => _WorkerRegisterScreenState();
}

class _WorkerRegisterScreenState extends State<WorkerRegisterScreen>
    with TickerProviderStateMixin {
  // ── Page controller for multi-step form
  final PageController _pageCtrl = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // ── Form key
  final _formKey = GlobalKey<FormState>();

  // ── Controllers
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  // ── Selected trade
  String? _selectedTrade;
  final List<Map<String, String>> _trades = [
    {'emoji': '🔧', 'label': 'Plumber'},
    {'emoji': '⚡', 'label': 'Electrician'},
    {'emoji': '❄️', 'label': 'AC Repair'},
    {'emoji': '🎨', 'label': 'Painter'},
    {'emoji': '🪟', 'label': 'Window Fixer'},
    {'emoji': '🌿', 'label': 'Cleaner'},
    {'emoji': '🔨', 'label': 'Handyman'},
    {'emoji': '🚿', 'label': 'Mason'},
  ];

  // ── Animation
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Next step ─────────────────────────────────────────────────────────────
  void _nextStep() {
    if (_currentStep == 0) {
      if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty ||
          _phoneCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
        setState(() => _errorMessage = 'Please fill in all fields.');
        return;
      }
      if (!_emailCtrl.text.contains('@')) {
        setState(() => _errorMessage = 'Enter a valid email.');
        return;
      }
      if (_passwordCtrl.text.length < 6) {
        setState(() => _errorMessage = 'Password must be at least 6 characters.');
        return;
      }
    }
    if (_currentStep == 1) {
      if (_selectedTrade == null) {
        setState(() => _errorMessage = 'Please select your trade.');
        return;
      }
      if (_locationCtrl.text.isEmpty) {
        setState(() => _errorMessage = 'Please enter your service area.');
        return;
      }
    }
    setState(() { _errorMessage = null; _currentStep++; });
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  // ── Previous step ─────────────────────────────────────────────────────────
  void _prevStep() {
    setState(() { _errorMessage = null; _currentStep--; });
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  // ── Register worker ────────────────────────────────────────────────────────
  Future<void> _registerWorker() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      // Create auth account
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      await credential.user?.updateDisplayName(_nameCtrl.text.trim());

      // Save to Firestore workers collection
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(credential.user!.uid)
          .set({
        'name':        _nameCtrl.text.trim(),
        'email':       _emailCtrl.text.trim(),
        'phone':       _phoneCtrl.text.trim(),
        'category':    _selectedTrade,
        'location':    _locationCtrl.text.trim(),
        'verified':    false,
        'isAvailable': true,
        'rating':      0.0,
        'completedJobs': 0,
        'latitude':    -1.2921,
        'longitude':   36.8219,
        'role':        'worker',
        'createdAt':   DateTime.now().toIso8601String(),
        'approved':   false,
        'suspended':  false,
      });
if (mounted) {
        // Use pushAndRemoveUntil to ensure they can't "back" into the registration form
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => WorkerDashboard(), // No 'const' here!
          ),
          (route) => false, // This clears the login/register stack
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'This email is already registered.';
      case 'weak-password':        return 'Password must be at least 6 characters.';
      case 'invalid-email':        return 'Please enter a valid email address.';
      default:                     return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F3D26), Color(0xFF1A7A4A), Color(0xFF0D2B1A)],
              ),
            ),
          ),

          // Decorative circles
          Positioned(top: -60, right: -60,
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: kAccentGreen.withOpacity(0.08)))),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // ── Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _currentStep > 0
                              ? _prevStep
                              : () => Navigator.pop(context),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Join as Worker',
                              style: TextStyle(color: Colors.white,
                                fontSize: 20, fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                            Text('Step ${_currentStep + 1} of 3',
                              style: const TextStyle(
                                color: Color(0xFFB8D4C4), fontSize: 13)),
                          ],
                        ),
                        const Spacer(),
                        // Progress dots
                        Row(
                          children: List.generate(3, (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(left: 6),
                            width: i == _currentStep ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _currentStep
                                  ? kAccentGreen
                                  : i < _currentStep
                                      ? kAccentGreen.withOpacity(0.5)
                                      : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Page view
                  Expanded(
                    child: PageView(
                      controller: _pageCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStep1(),
                        _buildStep2(),
                        _buildStep3(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Personal details ───────────────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Personal Details',
              style: TextStyle(color: kTextPrimary,
                fontSize: 20, fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
            const SizedBox(height: 4),
            const Text('Tell us about yourself',
              style: TextStyle(color: kTextSecondary, fontSize: 14)),
            const SizedBox(height: 24),

            _label('Full Name'),
            const SizedBox(height: 8),
            _field(controller: _nameCtrl, hint: 'John Kamau',
                icon: Icons.person_outline_rounded),
            const SizedBox(height: 16),

            _label('Email Address'),
            const SizedBox(height: 8),
            _field(controller: _emailCtrl, hint: 'you@gmail.com',
                icon: Icons.mail_outline_rounded,
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 16),

            _label('Phone Number'),
            const SizedBox(height: 8),
            _field(controller: _phoneCtrl, hint: '+254 712 345 678',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone),
            const SizedBox(height: 16),

            _label('Password'),
            const SizedBox(height: 8),
            _field(controller: _passwordCtrl, hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                isPassword: true),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _errorBanner(_errorMessage!),
            ],

            const SizedBox(height: 24),
            _nextBtn('Continue', _nextStep),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Trade + Location ───────────────────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Trade',
              style: TextStyle(color: kTextPrimary,
                fontSize: 20, fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
            const SizedBox(height: 4),
            const Text('What services do you offer?',
              style: TextStyle(color: kTextSecondary, fontSize: 14)),
            const SizedBox(height: 24),

            // Trade grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: _trades.length,
              itemBuilder: (context, i) {
                final trade = _trades[i];
                final isSelected = _selectedTrade == trade['label'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedTrade = trade['label']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? kPrimaryGreen : kSurfaceBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? kAccentGreen : kBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected ? [BoxShadow(
                        color: kPrimaryGreen.withOpacity(0.3),
                        blurRadius: 10, offset: const Offset(0, 4),
                      )] : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(trade['emoji']!,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(trade['label']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : kTextSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          )),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            _label('Service Area'),
            const SizedBox(height: 8),
            _field(controller: _locationCtrl,
                hint: 'e.g. Westlands, Nairobi',
                icon: Icons.location_on_outlined),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _errorBanner(_errorMessage!),
            ],

            const SizedBox(height: 24),
            _nextBtn('Continue', _nextStep),
          ],
        ),
      ),
    );
  }

  // ── Step 3: Documents / Confirmation ──────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verification',
              style: TextStyle(color: kTextPrimary,
                fontSize: 20, fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
            const SizedBox(height: 4),
            const Text('Upload your documents for faster approval',
              style: TextStyle(color: kTextSecondary, fontSize: 14)),
            const SizedBox(height: 24),

            // ID upload card
            _uploadCard(
              icon: '🪪',
              title: 'National ID / Passport',
              subtitle: 'Front and back of your ID',
            ),
            const SizedBox(height: 12),

            // Certificate upload card
            _uploadCard(
              icon: '📜',
              title: 'Trade Certificate',
              subtitle: 'Any relevant certification',
            ),

            const SizedBox(height: 20),

            // Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAccentGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kAccentGreen.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Text('ℹ️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                const Expanded(child: Text(
                  'Documents are optional now but required for verification badge. You can upload them later from your profile.',
                  style: TextStyle(color: kTextSecondary,
                      fontSize: 12, height: 1.5),
                )),
              ]),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _errorBanner(_errorMessage!),
            ],

            const SizedBox(height: 24),

            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kSurfaceBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Column(children: [
                _summaryRow('Name',     _nameCtrl.text.isEmpty  ? '—' : _nameCtrl.text),
                _summaryRow('Email',    _emailCtrl.text.isEmpty ? '—' : _emailCtrl.text),
                _summaryRow('Phone',    _phoneCtrl.text.isEmpty ? '—' : _phoneCtrl.text),
                _summaryRow('Trade',    _selectedTrade          ?? '—'),
                _summaryRow('Location', _locationCtrl.text.isEmpty ? '—' : _locationCtrl.text),
              ]),
            ),

            const SizedBox(height: 24),
            _nextBtn('Create Worker Account', _registerWorker,
                loading: _isLoading),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────
  Widget _label(String text) => Text(text,
    style: const TextStyle(color: kTextSecondary, fontSize: 12,
        fontWeight: FontWeight.w600, letterSpacing: 0.5));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboard,
        style: const TextStyle(color: kTextPrimary, fontSize: 15,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 15),
          prefixIcon: Icon(icon, color: const Color(0xFF555555), size: 20),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFF555555), size: 20),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: Color(0xFFFF6B6B), size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
          style: const TextStyle(color: Color(0xFFFF6B6B),
            fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _nextBtn(String label, VoidCallback onTap, {bool loading = false}) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kPrimaryGreen, kAccentGreen],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: kPrimaryGreen.withOpacity(0.4),
            blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Center(child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w700, letterSpacing: 0.3))),
      ),
    );
  }

  Widget _uploadCard({required String icon, required String title,
      required String subtitle}) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: kPrimaryGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(icon,
                style: const TextStyle(fontSize: 20)))),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: kTextPrimary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(
                  color: kTextSecondary, fontSize: 12)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kPrimaryGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kAccentGreen.withOpacity(0.3)),
            ),
            child: const Text('Upload',
              style: TextStyle(color: kAccentGreen,
                  fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text(label, style: const TextStyle(
            color: kTextSecondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(
            color: kTextPrimary, fontSize: 13,
            fontWeight: FontWeight.w600)),
      ]),
    );
  }
}