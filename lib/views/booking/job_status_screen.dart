import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rating_sheet.dart';
import '../booking/review_screen.dart';

const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

class JobStatusScreen extends StatefulWidget {
  final String jobId;
  const JobStatusScreen({super.key, required this.jobId});

  @override
  State<JobStatusScreen> createState() => _JobStatusScreenState();
}

class _JobStatusScreenState extends State<JobStatusScreen> {
  bool _ratingSheetShown = false;

  @override
  void initState() {
    super.initState();
    // ── Check on screen open whether job is already completed
    // and not yet rated — covers the case where customer opens
    // the screen AFTER the worker already marked it complete
    _checkAndShowRatingOnOpen();
  }

  // ── Runs once when screen opens ────────────────────────────────────────────
  Future<void> _checkAndShowRatingOnOpen() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .get();

      if (!doc.exists) return;

      final data   = doc.data() as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';
      final rated  = data['rated'] as bool? ?? false;

      if (status == 'completed' && !rated && !_ratingSheetShown) {
        // Small delay so the screen renders first
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted && !_ratingSheetShown) {
          _ratingSheetShown = true;
          await showRatingSheet(
            context,
            jobId:      widget.jobId,
            workerId:   data['workerId']?.toString() ?? '',
            workerName: data['workerName']?.toString() ?? 'Worker',
          );
        }
      }
    } catch (e) {
      debugPrint('Rating check error: $e');
    }
  }

  // ── Triggered by stream when status changes to completed live ──────────────
  void _maybeShowRatingSheet(Map<String, dynamic> data) {
    if (_ratingSheetShown) return;
    _ratingSheetShown = true;

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      showRatingSheet(
        context,
        jobId:      widget.jobId,
        workerId:   data['workerId']?.toString() ?? '',
        workerName: data['workerName']?.toString() ?? 'Worker',
      );
    });
  }

  // ── Fetch existing review for this job by current user ─────────────────────
  Future<QueryDocumentSnapshot?> _fetchExistingReview() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Reviews')
          .where('jobId', isEqualTo: widget.jobId)
          .where('customerId', isEqualTo: uid)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty ? snap.docs.first : null;
    } catch (e) {
      debugPrint('Fetch review error: $e');
      return null;
    }
  }

  String _categoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':   return '🔧';
      case 'electrical': return '⚡';
      case 'ac repair':  return '❄️';
      case 'painting':   return '🎨';
      case 'windows':    return '🪟';
      case 'cleaning':   return '🌿';
      case 'handyman':   return '🔨';
      default:           return '🛠️';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':   return const Color(0xFFFFC107);
      case 'accepted':  return kAccentGreen;
      case 'completed': return const Color(0xFF4CAF50);
      case 'declined':  return const Color(0xFFFF4444);
      default:          return kTextSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':   return 'Waiting for worker';
      case 'accepted':  return 'Worker is on the way!';
      case 'completed': return 'Job Completed';
      case 'declined':  return 'Request Declined';
      default:          return status;
    }
  }

  String _statusEmoji(String status) {
    switch (status) {
      case 'pending':   return '⏳';
      case 'accepted':  return '🚀';
      case 'completed': return '✅';
      case 'declined':  return '❌';
      default:          return '📋';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: kAccentGreen));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('Job not found',
                    style: TextStyle(color: kTextSecondary)));
          }

          final data   = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status']?.toString() ?? 'pending';
          final rated  = data['rated'] as bool? ?? false;

          // ── Live trigger — fires when worker marks complete
          // while customer is already on this screen ─────────────
          if (status == 'completed' && !rated && !_ratingSheetShown) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_ratingSheetShown) {
                _maybeShowRatingSheet(data);
              }
            });
          }

          return Column(children: [
            // ── Header ──────────────────────────────────────────
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
                  padding: const EdgeInsets.fromLTRB(
                      16, 12, 16, 24),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withOpacity(0.12),
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
                    const Text('Job Status',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [

                  // ── Status card ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius:
                          BorderRadius.circular(24),
                      border: Border.all(
                          color: _statusColor(status)
                              .withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                            color: _statusColor(status)
                                .withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: Column(children: [
                      status == 'pending'
                          ? _PulsingIcon(
                              emoji: _statusEmoji(status))
                          : Text(_statusEmoji(status),
                              style: const TextStyle(
                                  fontSize: 52)),
                      const SizedBox(height: 16),
                      Text(_statusLabel(status),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        status == 'pending'
                            ? 'Your request has been sent. Waiting for ${data['workerName'] ?? 'the worker'} to respond...'
                            : status == 'accepted'
                                ? '${data['workerName'] ?? 'Worker'} accepted your job and is on the way!'
                                : status == 'completed'
                                    ? 'Your job has been completed successfully!'
                                    : 'The worker was unable to take this job.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: kTextSecondary,
                            fontSize: 14,
                            height: 1.5),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── Progress timeline ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(children: [
                      _timelineStep(
                          '📤',
                          'Request Sent',
                          'Your booking was submitted',
                          true,
                          false),
                      _timelineLine(
                          status == 'accepted' ||
                              status == 'completed'),
                      _timelineStep(
                          '🤝',
                          'Worker Accepted',
                          status == 'accepted' ||
                                  status == 'completed'
                              ? '${data['workerName'] ?? 'Worker'} accepted'
                              : 'Waiting for response',
                          status == 'accepted' ||
                              status == 'completed',
                          status == 'pending'),
                      _timelineLine(
                          status == 'completed'),
                      _timelineStep(
                          '✅',
                          'Job Completed',
                          status == 'completed'
                              ? 'Job done successfully'
                              : 'In progress',
                          status == 'completed',
                          status != 'completed'),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── Job details ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(
                              _categoryEmoji(
                                  data['category'] ?? ''),
                              style: const TextStyle(
                                  fontSize: 20)),
                          const SizedBox(width: 10),
                          Text(
                              data['category'] ??
                                  'Job Details',
                              style: const TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w800)),
                        ]),
                        const SizedBox(height: 16),
                        _detailRow('👷', 'Worker',
                            data['workerName'] ?? '—'),
                        _divider(),
                        _detailRow('📝', 'Description',
                            data['description'] ?? '—'),
                        _divider(),
                        _detailRow('📍', 'Location',
                            data['location'] ?? '—'),
                        _divider(),
                        _detailRow(
                            '📅',
                            'Date & Time',
                            '${data['date'] ?? '—'} at ${data['time'] ?? '—'}'),
                        _divider(),
                        _detailRow('💰', 'Budget',
                            data['budget'] ?? 'Negotiable'),
                        _divider(),
                        _detailRow(
                            '🔖',
                            'Job ID',
                            widget.jobId
                                .substring(0, 8)
                                .toUpperCase()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Action buttons ───────────────────────────
                  if (status == 'completed')
                    FutureBuilder<QueryDocumentSnapshot?>(
                      future: _fetchExistingReview(),
                      builder: (context, reviewSnap) {
                        if (reviewSnap.connectionState ==
                            ConnectionState.waiting) {
                          return Column(children: [
                            _actionBtn(
                                'Rate Worker ⭐',
                                kPrimaryGreen,
                                null),
                            const SizedBox(height: 10),
                            _outlineBtn(
                                'View All Reviews', null),
                          ]);
                        }

                        final existingReview =
                            reviewSnap.data;
                        final hasReview =
                            existingReview != null;
                        final reviewData = hasReview
                            ? existingReview.data()
                                as Map<String, dynamic>
                            : null;

                        return Column(children: [
                          _actionBtn(
                            hasReview
                                ? 'Edit Your Review ✏️'
                                : 'Rate Worker ⭐',
                            kPrimaryGreen,
                            () => showRatingSheet(
                              context,
                              jobId: widget.jobId,
                              workerId:
                                  data['workerId']
                                          ?.toString() ??
                                      '',
                              workerName:
                                  data['workerName']
                                          ?.toString() ??
                                      'Worker',
                              existingReviewId: hasReview
                                  ? existingReview.id
                                  : null,
                              existingRating: hasReview
                                  ? (reviewData!['rating']
                                          as int? ??
                                      0)
                                  : 0,
                              existingComment: hasReview
                                  ? (reviewData!['comment']
                                          ?.toString() ??
                                      '')
                                  : '',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _outlineBtn(
                            'View All Reviews',
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReviewsScreen(
                                  workerId:
                                      data['workerId']
                                              ?.toString() ??
                                          '',
                                  workerName:
                                      data['workerName']
                                              ?.toString() ??
                                          'Worker',
                                ),
                              ),
                            ),
                          ),
                        ]);
                      },
                    ),

                  if (status == 'declined')
                    _actionBtn(
                        'Find Another Worker',
                        kPrimaryGreen,
                        () => Navigator.pop(context)),

                  if (status == 'pending')
                    _actionBtn(
                        'Cancel Request',
                        const Color(0xFF333333),
                        () async {
                      await FirebaseFirestore.instance
                          .collection('jobs')
                          .doc(widget.jobId)
                          .update(
                              {'status': 'cancelled'});
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }),

                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _timelineStep(String emoji, String title,
      String subtitle, bool done, bool pending) {
    return Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: done
              ? kPrimaryGreen.withOpacity(0.15)
              : kSurfaceBg,
          shape: BoxShape.circle,
          border: Border.all(
              color: done ? kAccentGreen : kBorder,
              width: done ? 1.5 : 1),
        ),
        child: Center(
            child: Text(emoji,
                style:
                    const TextStyle(fontSize: 16))),
      ),
      const SizedBox(width: 12),
      Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
        Text(title,
            style: TextStyle(
                color: done
                    ? kTextPrimary
                    : kTextSecondary,
                fontSize: 14,
                fontWeight: done
                    ? FontWeight.w700
                    : FontWeight.w500)),
        Text(subtitle,
            style: const TextStyle(
                color: kTextSecondary,
                fontSize: 12)),
      ]),
    ]);
  }

  Widget _timelineLine(bool active) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 19, top: 2, bottom: 2),
      child: Container(
          width: 2,
          height: 24,
          color: active ? kAccentGreen : kBorder),
    );
  }

  Widget _detailRow(
      String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
        Text(emoji,
            style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 10),
        Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
          Text(label,
              style: const TextStyle(
                  color: kTextSecondary,
                  fontSize: 11)),
          const SizedBox(height: 2),
          SizedBox(
            width: 260,
            child: Text(value,
                style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  Widget _divider() =>
      Container(height: 1, color: kBorder);

  Widget _actionBtn(String label, Color color,
      VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: onTap != null
              ? LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.85)
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight)
              : null,
          color: onTap == null
              ? color.withOpacity(0.4)
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6))
                ]
              : [],
        ),
        child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700))),
      ),
    );
  }

  Widget _outlineBtn(
      String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: kSurfaceBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700))),
      ),
    );
  }
}

// ── Pulsing icon ───────────────────────────────────────────────────────────────
class _PulsingIcon extends StatefulWidget {
  final String emoji;
  const _PulsingIcon({required this.emoji});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
        scale: _anim,
        child: Text(widget.emoji,
            style: const TextStyle(fontSize: 52)));
  }
}