import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'job_status_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

class BookingScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  final String workerTrade;
  final double workerRating;
  final String workerInitials;
  final String distance;

  const BookingScreen({
    super.key,
    required this.workerId,
    required this.workerName,
    required this.workerTrade,
    required this.workerRating,
    required this.workerInitials,
    required this.distance,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  // ── State
  int _currentStep   = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  // ── Form controllers
  final _descriptionCtrl = TextEditingController();
  final _locationCtrl    = TextEditingController();
  final _budgetCtrl      = TextEditingController();

  // ── Selected values
  String?    _selectedCategory;
  DateTime?  _selectedDate;
  TimeOfDay? _selectedTime;

  // ── Animation
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  // ── Categories
  final List<Map<String, String>> _categories = [
    {'emoji': '🔧', 'label': 'Plumbing'},
    {'emoji': '⚡', 'label': 'Electrical'},
    {'emoji': '❄️', 'label': 'AC Repair'},
    {'emoji': '🎨', 'label': 'Painting'},
    {'emoji': '🪟', 'label': 'Windows'},
    {'emoji': '🌿', 'label': 'Cleaning'},
    {'emoji': '🔨', 'label': 'Handyman'},
    {'emoji': '🚿', 'label': 'Masonry'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.workerTrade;
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ────────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: kAccentGreen, surface: kCardBg),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: kAccentGreen, surface: kCardBg),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String get _formattedDate {
    if (_selectedDate == null) return 'Select date';
    return '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
  }

  String get _formattedTime {
    if (_selectedTime == null) return 'Select time';
    final h = _selectedTime!.hour.toString().padLeft(2, '0');
    final m = _selectedTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validateStep() {
    if (_currentStep == 0) {
      if (_selectedCategory == null) {
        setState(
            () => _errorMessage = 'Please select a service category.');
        return false;
      }
      if (_descriptionCtrl.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please describe the job.');
        return false;
      }
    }
    if (_currentStep == 1) {
      if (_selectedDate == null) {
        setState(() => _errorMessage = 'Please select a date.');
        return false;
      }
      if (_selectedTime == null) {
        setState(() => _errorMessage = 'Please select a time.');
        return false;
      }
      if (_locationCtrl.text.trim().isEmpty) {
        setState(
            () => _errorMessage = 'Please enter your location.');
        return false;
      }
    }
    setState(() => _errorMessage = null);
    return true;
  }

  void _nextStep() {
    if (!_validateStep()) return;
    setState(() => _currentStep++);
  }

  // ── Submit booking ─────────────────────────────────────────────────────────
  Future<void> _submitBooking() async {
    if (!_validateStep()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Fetch customer phone from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final customerPhone =
          userDoc.data()?['phone']?.toString() ?? '';

      final jobRef =
          await FirebaseFirestore.instance.collection('jobs').add({
        'userId':        user.uid,
        'name':          user.displayName ??
            userDoc.data()?['name'] ??
            'User',
        'customerPhone': customerPhone,
        'workerId':      widget.workerId,
        'workerName':    widget.workerName,
        'category':      _selectedCategory,
        'description':   _descriptionCtrl.text.trim(),
        'location':      _locationCtrl.text.trim(),
        'date':          _formattedDate,
        'time':          _formattedTime,
        'budget':        _budgetCtrl.text.trim().isEmpty
            ? 'Negotiable'
            : 'KES ${_budgetCtrl.text.trim()}',
        'status':            'pending',
        'amount':            0,
        'paymentRequested':  false,
        'createdAt':         DateTime.now().toIso8601String(),
        'rated': false,
      });

      if (mounted) _showSuccessSheet(jobRef.id);
    } catch (e) {
      setState(() =>
          _errorMessage = 'Failed to submit booking. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Success sheet ──────────────────────────────────────────────────────────
  void _showSuccessSheet(String jobId) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [kPrimaryGreen, kAccentGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: kPrimaryGreen.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ],
              ),
              child: const Center(
                  child:
                      Text('✅', style: TextStyle(fontSize: 32))),
            ),
            const SizedBox(height: 20),
            const Text('Booking Submitted!',
                style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
              'Your request has been sent to ${widget.workerName}.\nWaiting for them to accept.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: kTextSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: kSurfaceBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Job ID: ',
                      style: TextStyle(
                          color: kTextSecondary, fontSize: 13)),
                  Text(jobId.substring(0, 8).toUpperCase(),
                      style: const TextStyle(
                          color: kAccentGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          JobStatusScreen(jobId: jobId)),
                );
              },
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [kPrimaryGreen, kAccentGreen],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: kPrimaryGreen.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: const Center(
                    child: Text('Track Your Job 📍',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F3D26),
                    Color(0xFF1A7A4A),
                    Color(0xFF0D2B1A),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    children: [
                      Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text('Book a Service',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3)),
                        ),
                        Row(
                          children: List.generate(
                              3,
                              (i) => AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 300),
                                    margin: const EdgeInsets.only(
                                        left: 5),
                                    width: i == _currentStep
                                        ? 20
                                        : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: i == _currentStep
                                          ? Colors.white
                                          : i < _currentStep
                                              ? kAccentGreen
                                              : Colors.white
                                                  .withOpacity(0.3),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  )),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      // Worker info card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                color: kAccentGreen,
                                borderRadius:
                                    BorderRadius.circular(14)),
                            child: Center(
                                child: Text(widget.workerInitials,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                            Text(widget.workerName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            Row(children: [
                              Container(
                                margin:
                                    const EdgeInsets.only(top: 3),
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: kAccentGreen
                                        .withOpacity(0.25),
                                    borderRadius:
                                        BorderRadius.circular(5)),
                                child: Text(widget.workerTrade,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight:
                                            FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFFC107),
                                  size: 12),
                              Text(' ${widget.workerRating}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600)),
                            ]),
                          ])),
                          Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                            const Icon(Icons.location_on_rounded,
                                color: kAccentGreen, size: 14),
                            Text(widget.distance,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: _currentStep == 0
                    ? _buildStep1()
                    : _currentStep == 1
                        ? _buildStep2()
                        : _buildStep3(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Job details ────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Service Category', '1/3'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: _categories.length,
          itemBuilder: (_, i) {
            final cat = _categories[i];
            final isSelected = _selectedCategory == cat['label'];
            return GestureDetector(
              onTap: () =>
                  setState(() => _selectedCategory = cat['label']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryGreen : kCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color:
                          isSelected ? kAccentGreen : kBorder,
                      width: isSelected ? 1.5 : 1),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color:
                                  kPrimaryGreen.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat['emoji']!,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(cat['label']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : kTextSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _sectionTitle('Describe the Job', ''),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder)),
          child: TextField(
            controller: _descriptionCtrl,
            maxLines: 4,
            style: const TextStyle(
                color: kTextPrimary, fontSize: 14, height: 1.5),
            decoration: const InputDecoration(
              hintText:
                  'e.g. My kitchen sink is leaking under the cabinet. Need urgent fix...',
              hintStyle: TextStyle(
                  color: Color(0xFF555555), fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Estimated Budget (Optional)', ''),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 16),
              decoration: const BoxDecoration(
                  border: Border(
                      right: BorderSide(color: kBorder, width: 1))),
              child: const Text('KES',
                  style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: TextField(
                controller: _budgetCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    color: kTextPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'e.g. 1500',
                  hintStyle: TextStyle(
                      color: Color(0xFF555555), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16),
                ),
              ),
            ),
          ]),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _errorBanner(_errorMessage!),
        ],
        const SizedBox(height: 24),
        _nextButton('Continue', _nextStep),
      ],
    );
  }

  // ── Step 2: Date, time, location ───────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('When do you need this done?', '2/3'),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _pickerCard(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: _formattedDate,
              onTap: _pickDate,
              isSet: _selectedDate != null)),
          const SizedBox(width: 12),
          Expanded(child: _pickerCard(
              icon: Icons.access_time_rounded,
              label: 'Time',
              value: _formattedTime,
              onTap: _pickTime,
              isSet: _selectedTime != null)),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Your Location', ''),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder)),
          child: TextField(
            controller: _locationCtrl,
            style: const TextStyle(
                color: kTextPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'e.g. House 12, Westlands, Nairobi',
              hintStyle: TextStyle(
                  color: Color(0xFF555555), fontSize: 14),
              prefixIcon: Icon(Icons.location_on_outlined,
                  color: Color(0xFF555555), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Quick select:',
            style: TextStyle(
                color: kTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Westlands', 'Kilimani', 'Karen',
            'Eastleigh', 'Parklands', 'CBD'
          ]
              .map((area) => GestureDetector(
                    onTap: () => setState(
                        () => _locationCtrl.text = '$area, Nairobi'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: kSurfaceBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kBorder)),
                      child: Text(area,
                          style: const TextStyle(
                              color: kTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                  ))
              .toList(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _errorBanner(_errorMessage!),
        ],
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
              child: _outlineButton(
                  'Back', () => setState(() => _currentStep--))),
          const SizedBox(width: 12),
          Expanded(
              flex: 2, child: _nextButton('Continue', _nextStep)),
        ]),
      ],
    );
  }

  // ── Step 3: Review & confirm (NO escrow info) ──────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Review Your Booking', '3/3'),
        const SizedBox(height: 16),

        // Summary card
        Container(
          decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder)),
          child: Column(children: [
            _reviewRow('👷', 'Worker',
                '${widget.workerName} (${widget.workerTrade})'),
            _divider(),
            _reviewRow(
                '🔧', 'Service', _selectedCategory ?? '—'),
            _divider(),
            _reviewRow(
                '📝',
                'Description',
                _descriptionCtrl.text.trim().isEmpty
                    ? '—'
                    : _descriptionCtrl.text.trim()),
            _divider(),
            _reviewRow('📅', 'Date & Time',
                '$_formattedDate at $_formattedTime'),
            _divider(),
            _reviewRow(
                '📍',
                'Location',
                _locationCtrl.text.trim().isEmpty
                    ? '—'
                    : _locationCtrl.text.trim()),
            _divider(),
            _reviewRow(
                '💰',
                'Budget',
                _budgetCtrl.text.trim().isEmpty
                    ? 'Negotiable'
                    : 'KES ${_budgetCtrl.text.trim()}'),
          ]),
        ),

        // ── NOTE: escrow notice intentionally removed ──────────────
        // Payment is now handled directly via M-Pesa STK Push
        // triggered by the worker after job completion.
        // ──────────────────────────────────────────────────────────

        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _errorBanner(_errorMessage!),
        ],

        const SizedBox(height: 24),
        Row(children: [
          Expanded(
              child: _outlineButton(
                  'Back', () => setState(() => _currentStep--))),
          const SizedBox(width: 12),
          Expanded(
              flex: 2,
              child: _nextButton(
                  'Confirm Booking', _submitBooking,
                  loading: _isSubmitting)),
        ]),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, String step) {
    return Row(children: [
      Text(title,
          style: const TextStyle(
              color: kTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3)),
      const Spacer(),
      if (step.isNotEmpty)
        Text(step,
            style: const TextStyle(
                color: kTextSecondary, fontSize: 13)),
    ]);
  }

  Widget _pickerCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required bool isSet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              isSet ? kPrimaryGreen.withOpacity(0.1) : kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSet
                  ? kAccentGreen.withOpacity(0.5)
                  : kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: isSet ? kAccentGreen : kTextSecondary,
                size: 20),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: kTextSecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color:
                        isSet ? kTextPrimary : kTextSecondary,
                    fontSize: 13,
                    fontWeight: isSet
                        ? FontWeight.w700
                        : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(
      String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(label,
                style: const TextStyle(
                    color: kTextSecondary, fontSize: 12)),
            const SizedBox(height: 2),
            SizedBox(
              width: MediaQuery.of(context).size.width - 120,
              child: Text(value,
                  style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      height: 1,
      color: kBorder,
      margin: const EdgeInsets.symmetric(horizontal: 16));

  Widget _errorBanner(String msg) {
    return Container(
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
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _nextButton(String label, VoidCallback onTap,
      {bool loading = false}) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [kPrimaryGreen, kAccentGreen],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: kPrimaryGreen.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700))),
      ),
    );
  }

  Widget _outlineButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
            color: kSurfaceBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder)),
        child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600))),
      ),
    );
  }
}