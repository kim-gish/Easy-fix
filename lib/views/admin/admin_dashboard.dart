import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../views/auth/login.dart';

const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedTab = 0;

  final List<String> _tabs = ['Overview', 'Users', 'Workers', 'Jobs'];

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) =>
                const _AdminSignOutPlaceholder()),
        (route) => false,
      );
    }
  }

  // ── Confirm dialog helper ──────────────────────────────────────────────────
  Future<bool> _confirm(
      BuildContext context, String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: const TextStyle(
                color: kTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        content: Text(message,
            style: const TextStyle(
                color: kTextSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm',
                style: TextStyle(
                    color: Color(0xFFFF4444),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? const Color(0xFFFF4444) : kPrimaryGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  WORKER ACTIONS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _approveWorker(String workerId) async {
    await FirebaseFirestore.instance
        .collection('workers')
        .doc(workerId)
        .update({'approved': true, 'suspended': false});
    _showSnack('Worker approved ✅');
  }

  Future<void> _suspendWorker(
      BuildContext context, String workerId, String name) async {
    final ok = await _confirm(
        context, 'Suspend Worker', 'Suspend $name? They won\'t be able to log in.');
    if (!ok) return;
    await FirebaseFirestore.instance
        .collection('workers')
        .doc(workerId)
        .update({'suspended': true, 'isAvailable': false});
    _showSnack('$name suspended');
  }

  Future<void> _unsuspendWorker(String workerId, String name) async {
    await FirebaseFirestore.instance
        .collection('workers')
        .doc(workerId)
        .update({'suspended': false});
    _showSnack('$name unsuspended ✅');
  }

  Future<void> _deleteWorker(
      BuildContext context, String workerId, String name) async {
    final ok = await _confirm(
        context,
        'Delete Worker',
        'Permanently delete $name? This cannot be undone.');
    if (!ok) return;
    await FirebaseFirestore.instance
        .collection('workers')
        .doc(workerId)
        .delete();
    _showSnack('$name deleted');
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  USER ACTIONS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _suspendUser(
      BuildContext context, String userId, String name) async {
    final ok = await _confirm(
        context, 'Suspend User', 'Suspend $name? They won\'t be able to log in.');
    if (!ok) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'suspended': true});
    _showSnack('$name suspended');
  }

  Future<void> _unsuspendUser(String userId, String name) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'suspended': false});
    _showSnack('$name unsuspended ✅');
  }

  Future<void> _deleteUser(
      BuildContext context, String userId, String name) async {
    final ok = await _confirm(
        context,
        'Delete User',
        'Permanently delete $name? This cannot be undone.');
    if (!ok) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .delete();
    _showSnack('$name deleted');
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: Column(children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(child: _buildTabContent()),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('A',
                    style: TextStyle(
                        color: kPrimaryGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Panel',
                      style: TextStyle(
                          color: Color(0xFFB8D4C4),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  Text('EasyFix Dashboard',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                ],
              ),
            ),
            GestureDetector(
              onTap: _signOut,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Sign Out',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: kCardBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
            color: kSurfaceBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder)),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: _tabs.asMap().entries.map((e) {
            final sel = e.key == _selectedTab;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding:
                      const EdgeInsets.symmetric(vertical: 9),
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
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:  return _buildOverview();
      case 1:  return _buildUsers();
      case 2:  return _buildWorkers();
      case 3:  return _buildJobs();
      default: return _buildOverview();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  TAB 0 — OVERVIEW
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildOverview() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Platform Overview',
              style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          // ── Stats grid ─────────────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _statStream(
                  label: 'Total Users',
                  emoji: '👥',
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  color: const Color(0xFF4285F4)),
              _statStream(
                  label: 'Total Workers',
                  emoji: '🔧',
                  stream: FirebaseFirestore.instance
                      .collection('workers')
                      .snapshots(),
                  color: kAccentGreen),
              _statStream(
                  label: 'Pending Approval',
                  emoji: '⏳',
                  stream: FirebaseFirestore.instance
                      .collection('workers')
                      .where('approved', isEqualTo: false)
                      .snapshots(),
                  color: const Color(0xFFFFC107)),
              _statStream(
                  label: 'Completed Jobs',
                  emoji: '✅',
                  stream: FirebaseFirestore.instance
                      .collection('jobs')
                      .where('status', isEqualTo: 'completed')
                      .snapshots(),
                  color: const Color(0xFF4CAF50)),
              _statStream(
                  label: 'Active Jobs',
                  emoji: '🚀',
                  stream: FirebaseFirestore.instance
                      .collection('jobs')
                      .where('status', isEqualTo: 'accepted')
                      .snapshots(),
                  color: kPrimaryGreen),
              _statStream(
                  label: 'Total Jobs',
                  emoji: '📋',
                  stream: FirebaseFirestore.instance
                      .collection('jobs')
                      .snapshots(),
                  color: const Color(0xFF9C27B0)),
            ],
          ),

          const SizedBox(height: 24),

          // ── Pending workers quick list ─────────────────────────────
          const Text('Pending Worker Approvals',
              style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('workers')
                .where('approved', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder)),
                  child: const Center(
                    child: Text('No pending approvals 🎉',
                        style: TextStyle(
                            color: kTextSecondary,
                            fontSize: 14)),
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _pendingWorkerCard(doc.id, data);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statStream({
    required String label,
    required String emoji,
    required Stream<QuerySnapshot> stream,
    required Color color,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(emoji,
                      style: const TextStyle(fontSize: 22)),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count',
                      style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1)),
                  Text(label,
                      style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pendingWorkerCard(
      String workerId, Map<String, dynamic> data) {
    final name     = data['name']?.toString() ?? 'Worker';
    final category = data['category']?.toString() ?? 'General';
    final phone    = data['phone']?.toString() ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC107).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
              child: Text('⏳',
                  style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text('$category · $phone',
                  style: const TextStyle(
                      color: kTextSecondary, fontSize: 12)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _approveWorker(workerId),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [kPrimaryGreen, kAccentGreen]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Approve',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  TAB 1 — USERS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: kAccentGreen, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState('👥', 'No users yet');
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _userCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _userCard(String userId, Map<String, dynamic> data) {
    final name      = data['name']?.toString() ?? 'User';
    final email     = data['email']?.toString() ?? '—';
    final phone     = data['phone']?.toString() ?? '—';
    final suspended = data['suspended'] as bool? ?? false;
    final initials  = name.trim().isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: suspended
                ? const Color(0xFFFF4444).withOpacity(0.3)
                : kBorder),
      ),
      child: Column(children: [
        // Top row
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(name,
                        style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    if (suspended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4444)
                              .withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: const Text('Suspended',
                            style: TextStyle(
                                color: Color(0xFFFF4444),
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  Text(email,
                      style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 12)),
                  Text(phone,
                      style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),

        Container(height: 1, color: kBorder),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Suspend / Unsuspend
            Expanded(
              child: GestureDetector(
                onTap: () => suspended
                    ? _unsuspendUser(userId, name)
                    : _suspendUser(context, userId, name),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: kSurfaceBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: suspended
                            ? kAccentGreen.withOpacity(0.4)
                            : const Color(0xFFFFC107)
                                .withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text(
                      suspended ? 'Unsuspend' : 'Suspend',
                      style: TextStyle(
                          color: suspended
                              ? kAccentGreen
                              : const Color(0xFFFFC107),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Delete
            Expanded(
              child: GestureDetector(
                onTap: () => _deleteUser(context, userId, name),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4444)
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFF4444)
                            .withOpacity(0.3)),
                  ),
                  child: const Center(
                    child: Text('Delete',
                        style: TextStyle(
                            color: Color(0xFFFF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  TAB 2 — WORKERS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildWorkers() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('workers')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: kAccentGreen, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState('🔧', 'No workers yet');
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _workerCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _workerCard(
      String workerId, Map<String, dynamic> data) {
    final name      = data['name']?.toString() ?? 'Worker';
    final category  = data['category']?.toString() ?? 'General';
    final phone     = data['phone']?.toString() ?? '—';
    final rating    = (data['rating'] ?? 0.0).toDouble();
    final jobs      = data['completedJobs'] ?? 0;
    final approved  = data['approved'] as bool? ?? false;
    final suspended = data['suspended'] as bool? ?? false;
    final available = data['isAvailable'] as bool? ?? false;

    Color statusColor;
    String statusLabel;
    if (suspended) {
      statusColor  = const Color(0xFFFF4444);
      statusLabel  = 'Suspended';
    } else if (!approved) {
      statusColor  = const Color(0xFFFFC107);
      statusLabel  = 'Pending';
    } else if (available) {
      statusColor  = kAccentGreen;
      statusLabel  = 'Online';
    } else {
      statusColor  = kTextSecondary;
      statusLabel  = 'Offline';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: suspended
                ? const Color(0xFFFF4444).withOpacity(0.3)
                : !approved
                    ? const Color(0xFFFFC107).withOpacity(0.3)
                    : kBorder),
      ),
      child: Column(children: [
        // Top info
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: kPrimaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(_tradeEmoji(category),
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text('$category · $phone',
                      style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Text('⭐',
                        style: TextStyle(fontSize: 11)),
                    Text(
                        ' ${rating.toStringAsFixed(1)} · $jobs jobs done',
                        style: const TextStyle(
                            color: kTextSecondary,
                            fontSize: 11)),
                  ]),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        Container(height: 1, color: kBorder),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Approve (only if not approved)
            if (!approved) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => _approveWorker(workerId),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [kPrimaryGreen, kAccentGreen]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                        child: Text('Approve ✓',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Suspend / Unsuspend
            Expanded(
              child: GestureDetector(
                onTap: () => suspended
                    ? _unsuspendWorker(workerId, name)
                    : _suspendWorker(context, workerId, name),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: kSurfaceBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: suspended
                            ? kAccentGreen.withOpacity(0.4)
                            : const Color(0xFFFFC107)
                                .withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text(
                      suspended ? 'Unsuspend' : 'Suspend',
                      style: TextStyle(
                          color: suspended
                              ? kAccentGreen
                              : const Color(0xFFFFC107),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Delete
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    _deleteWorker(context, workerId, name),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4444)
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFF4444)
                            .withOpacity(0.3)),
                  ),
                  child: const Center(
                    child: Text('Delete',
                        style: TextStyle(
                            color: Color(0xFFFF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  TAB 3 — JOBS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildJobs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: kAccentGreen, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState('📋', 'No jobs yet');
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _jobCard(docs[i].id, data);
          },
        );
      },
    );
  }

  Widget _jobCard(String jobId, Map<String, dynamic> data) {
    final category   = data['category']?.toString() ?? 'Job';
    final customerName =
        data['name']?.toString() ?? data['userName']?.toString() ?? '—';
    final workerName = data['workerName']?.toString() ?? '—';
    final status     = data['status']?.toString() ?? 'pending';
    final budget     = data['budget']?.toString() ?? 'Negotiable';
    final date       = data['date']?.toString() ?? '—';
    final location   = data['location']?.toString() ?? '—';

    Color statusColor;
    switch (status) {
      case 'pending':   statusColor = const Color(0xFFFFC107); break;
      case 'accepted':  statusColor = kAccentGreen;            break;
      case 'completed': statusColor = const Color(0xFF4CAF50); break;
      case 'declined':  statusColor = const Color(0xFFFF4444); break;
      case 'cancelled': statusColor = kTextSecondary;          break;
      default:          statusColor = kTextSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: statusColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: kPrimaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(_tradeEmoji(category),
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category,
                      style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text('Job ID: ${jobId.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),

          const SizedBox(height: 14),
          Container(height: 1, color: kBorder),
          const SizedBox(height: 12),

          // Details
          _jobDetailRow('👤', 'Customer', customerName),
          const SizedBox(height: 6),
          _jobDetailRow('👷', 'Worker', workerName),
          const SizedBox(height: 6),
          _jobDetailRow('📍', 'Location', location),
          const SizedBox(height: 6),
          _jobDetailRow('📅', 'Date', date),
          const SizedBox(height: 6),
          _jobDetailRow('💰', 'Budget', budget),
        ],
      ),
    );
  }

  Widget _jobDetailRow(
      String emoji, String label, String value) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 8),
      Text('$label: ',
          style: const TextStyle(
              color: kTextSecondary, fontSize: 12)),
      Expanded(
        child: Text(value,
            style: const TextStyle(
                color: kTextPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _tradeEmoji(String cat) {
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

  Widget _emptyState(String emoji, String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(label,
              style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Placeholder to navigate back to login after sign out ──────────────────────
// Replace this with your actual LoginScreen import
class _AdminSignOutPlaceholder extends StatelessWidget {
  const _AdminSignOutPlaceholder();

  @override
  Widget build(BuildContext context) {
    // Navigate back to login — replace with your LoginScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) =>
                const LoginScreen()),
        (route) => false,
      );
    });
    return const SizedBox.shrink();
  }
}