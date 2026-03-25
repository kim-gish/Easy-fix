import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

class WorkerDashboard extends StatefulWidget {
   WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard>
    with SingleTickerProviderStateMixin {
  bool _isAvailable = true;
  int _selectedTab = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // Current worker data
  String _workerName = 'Worker';
  String _workerTrade = 'Handyman';
  String _workerInitials = 'WK';
  double _workerRating = 0.0;
  int _completedJobs = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadWorkerData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Load worker data from Firestore ───────────────────────────────────────
  Future<void> _loadWorkerData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('workers').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final name = data['name'] ?? 'Worker';
        final parts = name.split(' ');
        setState(() {
          _workerName     = name;
          _workerTrade    = data['category'] ?? 'Handyman';
          _workerInitials = parts.length >= 2
              ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
              : name.substring(0, 2).toUpperCase();
          _workerRating   = (data['rating'] ?? 0.0).toDouble();
          _completedJobs  = data['completedJobs'] ?? 0;
          _isAvailable    = data['isAvailable'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading worker data: $e');
    }
  }

  // ── Toggle availability ────────────────────────────────────────────────────
  Future<void> _toggleAvailability() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final newVal = !_isAvailable;
    setState(() => _isAvailable = newVal);
    await FirebaseFirestore.instance
        .collection('workers').doc(uid)
        .update({'isAvailable': newVal});
  }

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
            SliverToBoxAdapter(child: _buildTabBar()),
            SliverToBoxAdapter(child: _buildTabContent()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
              colors: [Color(0xFF0F3D26), Color(0xFF1A7A4A), Color(0xFF0D2B1A)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Worker Dashboard',
                    style: TextStyle(color: Color(0xFFB8D4C4),
                        fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Hey, $_workerName 👷',
                    style: const TextStyle(color: kTextPrimary,
                      fontSize: 20, fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
                ],
              ),
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: kAccentGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(_workerInitials,
                    style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 13))),
                ),
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
        boxShadow: _isAvailable ? [BoxShadow(
          color: kPrimaryGreen.withOpacity(0.3),
          blurRadius: 16, offset: const Offset(0, 6))] : [],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_isAvailable ? 0.15 : 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(_isAvailable ? '🟢' : '🔴',
              style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isAvailable ? 'You are Available' : 'You are Offline',
                style: TextStyle(
                  color: _isAvailable ? Colors.white : kTextPrimary,
                  fontSize: 16, fontWeight: FontWeight.w800)),
              Text(
                _isAvailable
                    ? 'Accepting new job requests'
                    : 'Toggle on to receive jobs',
                style: TextStyle(
                  color: _isAvailable
                      ? Colors.white.withOpacity(0.8)
                      : kTextSecondary,
                  fontSize: 13)),
            ],
          ),
        ),
        GestureDetector(
          onTap: _toggleAvailability,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 52, height: 30,
            decoration: BoxDecoration(
              color: _isAvailable
                  ? Colors.white.withOpacity(0.25)
                  : kSurfaceBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _isAvailable
                    ? Colors.white.withOpacity(0.4)
                    : kBorder),
            ),
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
                  color: _isAvailable ? Colors.white : kTextSecondary,
                  shape: BoxShape.circle,
                ),
              ),
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
        _statCard('⭐', _workerRating == 0 ? 'New' : _workerRating.toString(), 'Rating'),
        const SizedBox(width: 10),
        _statCard('✅', _completedJobs.toString(), 'Completed'),
        const SizedBox(width: 10),
        _statCard('🔧', _workerTrade, 'Trade'),
      ]),
    );
  }

  Widget _statCard(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kTextPrimary,
              fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(
              color: kTextSecondary, fontSize: 11)),
        ]),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = ['Requests', 'History'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: tabs.asMap().entries.map((e) {
            final isSelected = e.key == _selectedTab;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(e.value,
                    style: TextStyle(
                      color: isSelected ? Colors.white : kTextSecondary,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700 : FontWeight.w500))),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Tab content ────────────────────────────────────────────────────────────
  Widget _buildTabContent() {
    return _selectedTab == 0
        ? _buildJobRequests()
        : _buildJobHistory();
  }

  // ── Job Requests ───────────────────────────────────────────────────────────
  Widget _buildJobRequests() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('workerId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(
                color: kAccentGreen, strokeWidth: 2)),
          );
        }

        final jobs = snapshot.data?.docs ?? [];

        if (jobs.isEmpty) {
          return _emptyState(
            emoji: '📭',
            title: 'No pending requests',
            subtitle: _isAvailable
                ? 'New job requests will appear here'
                : 'Go online to receive requests',
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: jobs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _jobRequestCard(doc.id, data);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _jobRequestCard(String jobId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAccentGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: kPrimaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('🔧',
                  style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['category'] ?? 'Repair Job',
                  style: const TextStyle(color: kTextPrimary,
                    fontSize: 15, fontWeight: FontWeight.w800)),
                Text(data['description'] ?? 'No description',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextSecondary, fontSize: 12)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('New',
                style: TextStyle(color: Color(0xFFFFC107),
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),

          const SizedBox(height: 12),
          const Divider(color: kBorder, height: 1),
          const SizedBox(height: 12),

          Row(children: [
            const Icon(Icons.location_on_outlined,
                color: kTextSecondary, size: 14),
            const SizedBox(width: 4),
            Text(data['location'] ?? 'Location not set',
              style: const TextStyle(color: kTextSecondary, fontSize: 12)),
          ]),

          const SizedBox(height: 14),

          Row(children: [
            // Decline button
            Expanded(child: GestureDetector(
              onTap: () => _updateJobStatus(jobId, 'declined'),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: kSurfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: const Center(child: Text('Decline',
                  style: TextStyle(color: kTextSecondary,
                    fontSize: 14, fontWeight: FontWeight.w600))),
              ),
            )),
            const SizedBox(width: 10),
            // Accept button
            Expanded(flex: 2, child: GestureDetector(
              onTap: () => _updateJobStatus(jobId, 'accepted'),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimaryGreen, kAccentGreen],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                    color: kPrimaryGreen.withOpacity(0.3),
                    blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Center(child: Text('Accept Job',
                  style: TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w700))),
              ),
            )),
          ]),
        ],
      ),
    );
  }

  Future<void> _updateJobStatus(String jobId, String status) async {
    await FirebaseFirestore.instance
        .collection('jobs').doc(jobId)
        .update({'status': status});
  }

  // ── Job History ────────────────────────────────────────────────────────────
  Widget _buildJobHistory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('workerId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(
                color: kAccentGreen, strokeWidth: 2)),
          );
        }

        final jobs = snapshot.data?.docs ?? [];

        if (jobs.isEmpty) {
          return _emptyState(
            emoji: '📋',
            title: 'No completed jobs yet',
            subtitle: 'Your finished jobs will appear here',
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: jobs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _historyCard(data);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _historyCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
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
          child: const Center(child: Text('✅',
              style: TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['category'] ?? 'Repair Job',
              style: const TextStyle(color: kTextPrimary,
                fontSize: 14, fontWeight: FontWeight.w700)),
            Text(data['createdAt']?.toString().substring(0, 10) ?? '',
              style: const TextStyle(color: kTextSecondary, fontSize: 12)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('KES ${data['amount'] ?? 0}',
            style: const TextStyle(color: kTextPrimary,
              fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kAccentGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Completed',
              style: TextStyle(color: kAccentGreen,
                fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _emptyState({required String emoji, required String title,
      required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: kTextPrimary,
            fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center,
            style: const TextStyle(color: kTextSecondary, fontSize: 13)),
      ]),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border(top: BorderSide(color: kBorder, width: 1)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.dashboard_rounded, 'Dashboard', true),
          _navItem(Icons.receipt_long_rounded, 'Jobs', false),
          _navItem(Icons.bar_chart_rounded, 'Earnings', false),
          _navItem(Icons.person_rounded, 'Profile', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kPrimaryGreen.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: active ? kAccentGreen : kTextSecondary, size: 22),
      ),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
        color: active ? kAccentGreen : kTextSecondary,
        fontSize: 11,
        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
      )),
    ]);
  }
}