import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../booking/review_screen.dart';

const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

// ── Replace with your actual Render backend URL after deploying ───────────────
const String kBackendUrl = 'https://easyfixmpesa.onrender.com';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});
  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard>
    with SingleTickerProviderStateMixin {
  bool _isAvailable   = true;
  int  _selectedTab   = 0;
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  String _workerName     = 'Worker';
  String _workerTrade    = 'Handyman';
  String _workerInitials = 'WK';
  double _workerRating   = 0.0;
  int    _completedJobs  = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadWorkerData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Load worker profile from Firestore ────────────────────────────────────
  Future<void> _loadWorkerData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('workers')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        final d    = doc.data()!;
        final name = d['name'] ?? 'Worker';
        final parts = name.split(' ');
        setState(() {
          _workerName     = name;
          _workerTrade    = d['category'] ?? 'Handyman';
          _workerInitials = parts.length >= 2
              ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
              : name.substring(0, 2).toUpperCase();
          _workerRating  = (d['rating'] ?? 0.0).toDouble();
          _completedJobs = d['completedJobs'] ?? 0;
          _isAvailable   = d['isAvailable'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Worker load error: $e');
    }
  }

  // ── Toggle availability ────────────────────────────────────────────────────
  Future<void> _toggleAvailability() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final val = !_isAvailable;
    setState(() => _isAvailable = val);
    await FirebaseFirestore.instance
        .collection('workers')
        .doc(uid)
        .update({'isAvailable': val});
    _showSnack(val ? 'You are now Online 🟢' : 'You are now Offline 🔴');
  }

  // ── Accept job ─────────────────────────────────────────────────────────────
  Future<void> _acceptJob(
      String jobId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .update({
      'status':     'accepted',
      'acceptedAt': DateTime.now().toIso8601String(),
    });
    if (!mounted) return;
    _showAcceptedSheet(jobId, data);
  }

  // ── Decline job ────────────────────────────────────────────────────────────
  Future<void> _declineJob(String jobId) async {
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .update({'status': 'declined'});
    _showSnack('Job declined');
  }

  // ── Mark complete → open M-Pesa payment sheet ─────────────────────────────
  Future<void> _markComplete(
      String jobId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .update({
      'status':      'completed',
      'completedAt': DateTime.now().toIso8601String(),
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(uid)
          .update({'completedJobs': FieldValue.increment(1)});
    }
    if (!mounted) return;
    _showMpesaPaymentSheet(jobId, data);
  }

  // ── Fetch customer phone from Firestore ───────────────────────────────────
  Future<String?> _getUserPhone(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final phone = doc.data()?['phone']?.toString() ?? '';
        if (phone.isNotEmpty) return phone;
      }
    } catch (e) {
      debugPrint('Phone fetch error: $e');
    }
    return null;
  }

  // ── Call client ────────────────────────────────────────────────────────────
  Future<void> _callUser(String userId, String userName) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: kAccentGreen)),
    );

    final phone = await _getUserPhone(userId);
    if (!mounted) return;
    Navigator.pop(context);

    if (phone == null || phone.isEmpty) {
      _showSnack('Phone number not found for $userName');
      return;
    }

    String formatted =
        phone.trim().replaceAll(' ', '').replaceAll('-', '');
    if (formatted.startsWith('0') && formatted.length == 10) {
      formatted = '+254${formatted.substring(1)}';
    } else if (formatted.startsWith('254') &&
        !formatted.startsWith('+')) {
      formatted = '+$formatted';
    } else if (!formatted.startsWith('+')) {
      formatted = '+254$formatted';
    }

    final uri = Uri(scheme: 'tel', path: formatted);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('Could not open dialler. Number: $formatted');
    }
  }

  // ── Trigger M-Pesa STK Push via backend ───────────────────────────────────
  Future<void> _triggerStkPush({
    required String customerPhone,
    required String amount,
    required String jobId,
    required String customerName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$kBackendUrl/stk-push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone':      customerPhone,
          'amount':     amount,
          'jobId':      jobId,
          'workerName': _workerName,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .update({
          'amount':           int.tryParse(amount) ?? 0,
          'paymentRequested': true,
        });
        if (mounted) {
          _showSnack('M-Pesa prompt sent to $customerName ✅');
        }
      } else {
        final errMsg = body['error'] ?? 'Payment request failed';
        if (mounted) _showSnack('Error: $errMsg');
      }
    } catch (e) {
      debugPrint('STK Push error: $e');
      if (mounted) {
        _showSnack('Network error. Check connection and try again.');
      }
    }
  }

  // ── M-Pesa payment bottom sheet ───────────────────────────────────────────
  void _showMpesaPaymentSheet(
      String jobId, Map<String, dynamic> data) {
    final budgetStr      = data['budget']?.toString() ?? '';
    final prefilledAmount =
        budgetStr.replaceAll(RegExp(r'[^0-9]'), '');
    final amountCtrl =
        TextEditingController(text: prefilledAmount);

    final customerUserId =
        data['userId']?.toString() ?? '';
    final customerName =
        data['name']?.toString() ??
        data['userName']?.toString() ??
        'Client';
    final customerPhone =
        data['customerPhone']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          bool isSending = false;

          return Padding(
            padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: kBorder,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),

                // M-Pesa icon
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A550).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF00A550)
                            .withOpacity(0.35),
                        width: 1.5),
                  ),
                  child: const Center(
                      child: Text('📱',
                          style: TextStyle(fontSize: 30))),
                ),
                const SizedBox(height: 14),

                const Text('Request M-Pesa Payment',
                    style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),

                Text(
                  'Set the amount and send an M-Pesa prompt\nto $customerName\'s phone.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 20),

                // Amount input
                Container(
                  decoration: BoxDecoration(
                      color: kSurfaceBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBorder)),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 18),
                      decoration: const BoxDecoration(
                          border: Border(
                              right: BorderSide(color: kBorder))),
                      child: const Text('KES',
                          style: TextStyle(
                              color: kTextSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                              color: Color(0xFF555555)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),

                // Quick amount chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '500', '1000', '1500',
                    '2000', '3000', '5000'
                  ]
                      .map((amt) => GestureDetector(
                            onTap: () => amountCtrl.text = amt,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7),
                              decoration: BoxDecoration(
                                color: kSurfaceBg,
                                borderRadius:
                                    BorderRadius.circular(20),
                                border:
                                    Border.all(color: kBorder),
                              ),
                              child: Text('KES $amt',
                                  style: const TextStyle(
                                      color: kTextSecondary,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),

                // Info note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kAccentGreen.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: kAccentGreen.withOpacity(0.2)),
                  ),
                  child: Row(children: const [
                    Text('ℹ️', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The customer will receive an M-Pesa PIN prompt on their phone. Once they enter their PIN, the money is sent directly to your M-Pesa number.',
                        style: TextStyle(
                            color: kTextSecondary,
                            fontSize: 11,
                            height: 1.5),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Send M-Pesa prompt button
                GestureDetector(
                  onTap: isSending
                      ? null
                      : () async {
                          final amount =
                              amountCtrl.text.trim();
                          if (amount.isEmpty ||
                              amount == '0') {
                            _showSnack(
                                'Please enter an amount');
                            return;
                          }

                          // Resolve phone
                          String phone = customerPhone;
                          if (phone.isEmpty) {
                            phone = await _getUserPhone(
                                    customerUserId) ??
                                '';
                          }

                          if (phone.isEmpty) {
                            _showSnack(
                                'Customer phone not found. Cannot send M-Pesa prompt.');
                            return;
                          }

                          setSheetState(
                              () => isSending = true);
                          Navigator.pop(ctx);

                          await _triggerStkPush(
                            customerPhone: phone,
                            amount:        amount,
                            jobId:         jobId,
                            customerName:  customerName,
                          );
                        },
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: isSending
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF00A550),
                                Color(0xFF00C060)
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      color: isSending
                          ? const Color(0xFF00A550)
                              .withOpacity(0.4)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isSending
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF00A550)
                                    .withOpacity(0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              )
                            ],
                    ),
                    child: Center(
                      child: isSending
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5))
                          : const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text('📲',
                                    style: TextStyle(
                                        fontSize: 18)),
                                SizedBox(width: 8),
                                Text('Send M-Pesa Prompt',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Accepted job sheet ─────────────────────────────────────────────────────
  void _showAcceptedSheet(
      String jobId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [kPrimaryGreen, kAccentGreen]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: kPrimaryGreen.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: const Center(
                child: Text('🤝',
                    style: TextStyle(fontSize: 30))),
          ),
          const SizedBox(height: 14),
          const Text('Job Accepted!',
              style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'You accepted a ${data['category'] ?? 'repair'} job.\nHead to the client\'s location.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: kTextSecondary,
                fontSize: 14,
                height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: kSurfaceBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder)),
            child: Column(children: [
              _sheetRow('📍', 'Location',
                  data['location'] ?? '—'),
              const SizedBox(height: 8),
              _sheetRow('📅', 'Date & Time',
                  '${data['date'] ?? '—'} at ${data['time'] ?? '—'}'),
              const SizedBox(height: 8),
              _sheetRow('💰', 'Budget',
                  data['budget'] ?? 'Negotiable'),
            ]),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              _callUser(
                data['userId'] ?? '',
                data['name'] ?? data['userName'] ?? 'Client',
              );
            },
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(
                  color: kSurfaceBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: kAccentGreen.withOpacity(0.4))),
              child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.call_rounded,
                        color: kAccentGreen, size: 20),
                    SizedBox(width: 8),
                    Text('Call Client',
                        style: TextStyle(
                            color: kAccentGreen,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ]),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [kPrimaryGreen, kAccentGreen]),
                  borderRadius: BorderRadius.circular(14)),
              child: const Center(
                  child: Text('Got it!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700))),
            ),
          ),
        ]),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: kCardBg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _sheetRow(String emoji, String label, String value) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Text(emoji, style: const TextStyle(fontSize: 15)),
      const SizedBox(width: 8),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
        Text(label,
            style: const TextStyle(
                color: kTextSecondary, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: kTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ])),
    ]);
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildAvailabilityCard()),
            SliverToBoxAdapter(child: _buildStatsRow()),

            // ── My Reviews button ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewsScreen(
                        workerId:
                            FirebaseAuth.instance.currentUser!.uid,
                        workerName: _workerName,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(children: const [
                      Text('⭐',
                          style: TextStyle(fontSize: 20)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('My Reviews',
                            style: TextStyle(
                                color: kTextPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: kTextSecondary, size: 14),
                    ]),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(child: _buildTabBar()),
            SliverToBoxAdapter(child: _buildTabContent()),
            const SliverToBoxAdapter(
                child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: kDarkBg,
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                Color(0xFF0F3D26),
                Color(0xFF1A7A4A),
                Color(0xFF0D2B1A),
              ])),
          padding:
              const EdgeInsets.fromLTRB(20, 56, 20, 16),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text('Worker Dashboard',
                        style: TextStyle(
                            color: Color(0xFFB8D4C4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('Hey, $_workerName 👷',
                        style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                  ]),
              Row(children: [
                Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.12),
                        borderRadius:
                            BorderRadius.circular(12)),
                    child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 20)),
                const SizedBox(width: 8),
                Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: kAccentGreen,
                        borderRadius:
                            BorderRadius.circular(12)),
                    child: Center(
                        child: Text(_workerInitials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Availability card ──────────────────────────────────────────────────────
  Widget _buildAvailabilityCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _isAvailable
            ? const LinearGradient(
                colors: [kPrimaryGreen, kAccentGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : LinearGradient(
                colors: [kCardBg, kSurfaceBg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _isAvailable ? kAccentGreen : kBorder),
        boxShadow: _isAvailable
            ? [
                BoxShadow(
                    color: kPrimaryGreen.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ]
            : [],
      ),
      child: Row(children: [
        Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(_isAvailable ? 0.15 : 0.05),
                borderRadius: BorderRadius.circular(14)),
            child: Center(
                child: Text(_isAvailable ? '🟢' : '🔴',
                    style:
                        const TextStyle(fontSize: 22)))),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
          Text(
              _isAvailable
                  ? 'You are Available'
                  : 'You are Offline',
              style: TextStyle(
                  color: _isAvailable
                      ? Colors.white
                      : kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Text(
              _isAvailable
                  ? 'Accepting new job requests'
                  : 'Toggle on to receive jobs',
              style: TextStyle(
                  color: _isAvailable
                      ? Colors.white.withOpacity(0.8)
                      : kTextSecondary,
                  fontSize: 13)),
        ])),
        GestureDetector(
          onTap: _toggleAvailability,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 56, height: 30,
            decoration: BoxDecoration(
                color: _isAvailable
                    ? Colors.white.withOpacity(0.25)
                    : kSurfaceBg,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: _isAvailable
                        ? Colors.white.withOpacity(0.5)
                        : kBorder,
                    width: 1.5)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: _isAvailable
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                      color: _isAvailable
                          ? Colors.white
                          : kTextSecondary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color:
                                Colors.black.withOpacity(0.2),
                            blurRadius: 4)
                      ])),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        _statCard(
            '⭐',
            _workerRating == 0
                ? 'New'
                : _workerRating.toStringAsFixed(1),
            'Rating'),
        const SizedBox(width: 10),
        _statCard(
            '✅', _completedJobs.toString(), 'Completed'),
        const SizedBox(width: 10),
        _statCard('🔧', _workerTrade, 'Trade'),
      ]),
    );
  }

  Widget _statCard(
      String emoji, String value, String label) {
    return Expanded(
        child: Container(
      padding: const EdgeInsets.symmetric(
          vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder)),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: kTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: kTextSecondary, fontSize: 11)),
      ]),
    ));
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = ['Requests', 'Active', 'History'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder)),
        padding: const EdgeInsets.all(4),
        child: Row(
            children: tabs.asMap().entries.map((e) {
          final sel = e.key == _selectedTab;
          return Expanded(
              child: GestureDetector(
            onTap: () =>
                setState(() => _selectedTab = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding:
                  const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                  color: sel
                      ? kPrimaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                  child: Text(e.value,
                      style: TextStyle(
                          color: sel
                              ? Colors.white
                              : kTextSecondary,
                          fontSize: 13,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w500))),
            ),
          ));
        }).toList()),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:  return _buildRequests();
      case 1:  return _buildActive();
      case 2:  return _buildHistory();
      default: return _buildRequests();
    }
  }

  // ── Requests tab ───────────────────────────────────────────────────────────
  Widget _buildRequests() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('workerId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: CircularProgressIndicator(
                      color: kAccentGreen,
                      strokeWidth: 2)));
        }
        final jobs = snap.data?.docs ?? [];
        if (jobs.isEmpty) {
          return _empty(
              '📭',
              'No pending requests',
              _isAvailable
                  ? 'New requests will appear here'
                  : 'Go online to receive jobs');
        }
        return Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
                children: jobs
                    .map((d) => _requestCard(
                        d.id,
                        d.data()
                            as Map<String, dynamic>))
                    .toList()));
      },
    );
  }

  // ── Active tab ─────────────────────────────────────────────────────────────
  Widget _buildActive() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('workerId', isEqualTo: uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: CircularProgressIndicator(
                      color: kAccentGreen,
                      strokeWidth: 2)));
        }
        final jobs = snap.data?.docs ?? [];
        if (jobs.isEmpty) {
          return _empty('🔨', 'No active jobs',
              'Accepted jobs appear here');
        }
        return Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
                children: jobs
                    .map((d) => _activeCard(
                        d.id,
                        d.data()
                            as Map<String, dynamic>))
                    .toList()));
      },
    );
  }

  // ── History tab ────────────────────────────────────────────────────────────
  Widget _buildHistory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('workerId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: CircularProgressIndicator(
                      color: kAccentGreen,
                      strokeWidth: 2)));
        }
        final jobs = snap.data?.docs ?? [];
        if (jobs.isEmpty) {
          return _empty('📋', 'No completed jobs',
              'Your history appears here');
        }
        return Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
                children: jobs
                    .map((d) => _histCard(
                        d.data() as Map<String, dynamic>))
                    .toList()));
      },
    );
  }

  // ── Request card ───────────────────────────────────────────────────────────
  Widget _requestCard(
      String jobId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: kAccentGreen.withOpacity(0.25))),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                      color:
                          kPrimaryGreen.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(14)),
                  child: Center(
                      child: Text(
                          _emoji(data['category'] ?? ''),
                          style: const TextStyle(
                              fontSize: 22)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                Text(data['category'] ?? 'Repair',
                    style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                Text(
                    'from ${data['name'] ?? data['userName'] ?? 'User'}',
                    style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 13)),
              ])),
              Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFC107)
                          .withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(8)),
                  child: const Text('New',
                      style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 11,
                          fontWeight: FontWeight.w700))),
            ])),
        Container(height: 1, color: kBorder),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _dRow(Icons.description_outlined,
                  data['description'] ?? 'No description'),
              const SizedBox(height: 8),
              _dRow(Icons.location_on_outlined,
                  data['location'] ?? '—'),
              const SizedBox(height: 8),
              _dRow(Icons.calendar_today_outlined,
                  '${data['date'] ?? '—'} at ${data['time'] ?? '—'}'),
              const SizedBox(height: 8),
              _dRow(Icons.payments_outlined,
                  data['budget'] ?? 'Negotiable'),
            ])),
        Container(height: 1, color: kBorder),
        Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                  child: GestureDetector(
                onTap: () => _declineJob(jobId),
                child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                        color: kSurfaceBg,
                        borderRadius:
                            BorderRadius.circular(12),
                        border:
                            Border.all(color: kBorder)),
                    child: const Center(
                        child: Text('Decline',
                            style: TextStyle(
                                color: kTextSecondary,
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w600)))),
              )),
              const SizedBox(width: 10),
              Expanded(
                  flex: 2,
                  child: GestureDetector(
                onTap: () => _acceptJob(jobId, data),
                child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [
                              kPrimaryGreen,
                              kAccentGreen
                            ]),
                        borderRadius:
                            BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: kPrimaryGreen
                                  .withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
                    child: const Center(
                        child: Text('Accept Job ✓',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w700)))),
              )),
            ])),
      ]),
    );
  }

  // ── Active card ────────────────────────────────────────────────────────────
  Widget _activeCard(
      String jobId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: kAccentGreen.withOpacity(0.4))),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                      color:
                          kAccentGreen.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(14)),
                  child: Center(
                      child: Text(
                          _emoji(data['category'] ?? ''),
                          style: const TextStyle(
                              fontSize: 22)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                Text(data['category'] ?? 'Job',
                    style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                Text(data['location'] ?? '—',
                    style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 12)),
              ])),
              Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color:
                          kAccentGreen.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(8)),
                  child: const Text('Active',
                      style: TextStyle(
                          color: kAccentGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700))),
            ])),
        Container(height: 1, color: kBorder),
        Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _dRow(Icons.person_outline,
                  'Client: ${data['name'] ?? data['userName'] ?? '—'}'),
              const SizedBox(height: 8),
              _dRow(Icons.access_time_rounded,
                  '${data['date'] ?? '—'} at ${data['time'] ?? '—'}'),
              const SizedBox(height: 8),
              _dRow(Icons.payments_outlined,
                  data['budget'] ?? 'Negotiable'),
            ])),
        Container(height: 1, color: kBorder),
        Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                  child: GestureDetector(
                onTap: () => _callUser(
                    data['userId'] ?? '',
                    data['name'] ??
                        data['userName'] ??
                        'Client'),
                child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                        color: kSurfaceBg,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: kAccentGreen
                                .withOpacity(0.3))),
                    child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.call_rounded,
                              color: kAccentGreen,
                              size: 16),
                          SizedBox(width: 6),
                          Text('Call',
                              style: TextStyle(
                                  color: kAccentGreen,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w700)),
                        ])),
              )),
              const SizedBox(width: 10),
              Expanded(
                  flex: 2,
                  child: GestureDetector(
                onTap: () => _markComplete(jobId, data),
                child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [
                              kPrimaryGreen,
                              kAccentGreen
                            ]),
                        borderRadius:
                            BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: kPrimaryGreen
                                  .withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
                    child: const Center(
                        child: Text('Mark Complete ✓',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w700)))),
              )),
            ])),
      ]),
    );
  }

  // ── History card ───────────────────────────────────────────────────────────
  Widget _histCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder)),
      child: Row(children: [
        Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: kPrimaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text(
                    _emoji(data['category'] ?? ''),
                    style:
                        const TextStyle(fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
          Text(data['category'] ?? 'Repair',
              style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          Text(
              '${data['name'] ?? data['userName'] ?? '—'} · ${data['date'] ?? '—'}',
              style: const TextStyle(
                  color: kTextSecondary, fontSize: 12)),
        ])),
        Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
          Text(data['budget'] ?? '—',
              style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: kAccentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('Done',
                  style: TextStyle(
                      color: kAccentGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
        ]),
      ]),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────
  Widget _dRow(IconData icon, String text) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Icon(icon, color: kTextSecondary, size: 15),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                    height: 1.4))),
      ]);

  String _emoji(String cat) {
    switch (cat.toLowerCase()) {
      case 'plumbing':   return '🔧';
      case 'electrical': return '⚡';
      case 'ac repair':  return '❄️';
      case 'painting':   return '🎨';
      case 'windows':    return '🪟';
      case 'cleaning':   return '🌿';
      case 'handyman':   return '🔨';
      case 'masonry':    return '🚿';
      default:           return '🛠️';
    }
  }

  Widget _empty(
      String emoji, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Text(emoji,
              style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: kTextSecondary, fontSize: 13)),
        ]),
      );

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
          color: kCardBg,
          border:
              Border(top: BorderSide(color: kBorder, width: 1))),
      padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context).padding.bottom + 8,
          top: 8),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _nav(Icons.dashboard_rounded, 'Dashboard', true),
            _nav(Icons.receipt_long_rounded, 'Jobs', false),
            _nav(Icons.bar_chart_rounded, 'Earnings', false),
            _nav(Icons.person_rounded, 'Profile', false),
          ]),
    );
  }

  Widget _nav(IconData icon, String label, bool active) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
                color: active
                    ? kPrimaryGreen.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon,
                color:
                    active ? kAccentGreen : kTextSecondary,
                size: 22)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: active
                    ? kAccentGreen
                    : kTextSecondary,
                fontSize: 11,
                fontWeight: active
                    ? FontWeight.w700
                    : FontWeight.w400)),
      ]);
}