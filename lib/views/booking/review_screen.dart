import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rating_sheet.dart';

const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

class ReviewsScreen extends StatelessWidget {
  final String workerId;
  final String workerName;

  const ReviewsScreen({
    super.key,
    required this.workerId,
    required this.workerName,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: kDarkBg,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Reviews')
            .where('workerId', isEqualTo: workerId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final reviews = snapshot.data?.docs ?? [];

          // ── Calculate stats ──────────────────────────────────────────
          double avgRating = 0;
          final starCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

          if (reviews.isNotEmpty) {
            for (final doc in reviews) {
              final d = doc.data() as Map<String, dynamic>;
              final r = (d['rating'] as int?) ?? 0;
              starCounts[r] = (starCounts[r] ?? 0) + 1;
            }
            final total = reviews
                .map((d) =>
                    ((d.data() as Map<String, dynamic>)['rating'] as num)
                        .toDouble())
                .reduce((a, b) => a + b);
            avgRating = total / reviews.length;
          }

          return Column(children: [
            // ── Header ──────────────────────────────────────────────────
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reviews',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          Text(workerName,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: kAccentGreen, strokeWidth: 2))
                  : reviews.isEmpty
                      ? _buildEmpty()
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            _buildSummaryCard(
                                avgRating, reviews.length, starCounts),
                            const SizedBox(height: 16),
                            ...reviews.map((doc) {
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              final isOwner =
                                  data['customerId'] == currentUserId;
                              return _buildReviewCard(
                                context: context,
                                doc:     doc,
                                data:    data,
                                isOwner: isOwner,
                              );
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

  // ── Rating summary card ────────────────────────────────────────────────────
  Widget _buildSummaryCard(
      double avg, int total, Map<int, int> starCounts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        // Big average
        Column(children: [
          Text(
            avg.toStringAsFixed(1),
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 52,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
            ),
          ),
          Row(
            children: List.generate(
              5,
              (i) => Text('★',
                  style: TextStyle(
                    fontSize: 14,
                    color: (i + 1) <= avg.round()
                        ? const Color(0xFFFFC107)
                        : kBorder,
                  )),
            ),
          ),
          const SizedBox(height: 4),
          Text('$total review${total == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: kTextSecondary, fontSize: 12)),
        ]),

        const SizedBox(width: 20),
        Container(width: 1, height: 80, color: kBorder),
        const SizedBox(width: 20),

        // Star breakdown bars
        Expanded(
          child: Column(
            children: [5, 4, 3, 2, 1].map((star) {
              final count    = starCounts[star] ?? 0;
              final fraction = total > 0 ? count / total : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Text('$star',
                      style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Text('★',
                      style: TextStyle(
                          color: Color(0xFFFFC107), fontSize: 10)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor: kSurfaceBg,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFC107)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 20,
                    child: Text('$count',
                        style: const TextStyle(
                            color: kTextSecondary, fontSize: 11)),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── Individual review card ─────────────────────────────────────────────────
  Widget _buildReviewCard({
    required BuildContext context,
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
    required bool isOwner,
  }) {
    final rating    = (data['rating'] as int?) ?? 0;
    final comment   = data['comment']?.toString() ?? '';
    final name      = data['customerName']?.toString() ?? 'Customer';
    final createdAt = data['createdAt']?.toString() ?? '';
    final edited    = data['edited'] as bool? ?? false;
    final initials  = name.trim().isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'C';

    String dateStr = '';
    try {
      final dt = DateTime.parse(createdAt);
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isOwner ? kAccentGreen.withOpacity(0.25) : kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(children: [
            // Avatar
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: kPrimaryGreen.withOpacity(0.15),
                shape: BoxShape.circle,
                border:
                    Border.all(color: kAccentGreen.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        color: kAccentGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),

            // Name + date
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
                    if (isOwner) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: kAccentGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                color: kAccentGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  Row(children: [
                    Text(dateStr,
                        style: const TextStyle(
                            color: kTextSecondary, fontSize: 11)),
                    if (edited) ...[
                      const SizedBox(width: 6),
                      const Text('· edited',
                          style: TextStyle(
                              color: kTextSecondary,
                              fontSize: 11,
                              fontStyle: FontStyle.italic)),
                    ],
                  ]),
                ],
              ),
            ),

            // Stars
            Row(
              children: List.generate(
                5,
                (i) => Text('★',
                    style: TextStyle(
                      fontSize: 14,
                      color: (i + 1) <= rating
                          ? const Color(0xFFFFC107)
                          : kBorder,
                    )),
              ),
            ),
          ]),

          // Comment
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(comment,
                style: const TextStyle(
                    color: kTextSecondary, fontSize: 13, height: 1.5)),
          ],

          // Edit button — only for review owner
          if (isOwner) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => showRatingSheet(
                context,
                jobId:            data['jobId']?.toString() ?? '',
                workerId:         workerId,
                workerName:       workerName,
                existingReviewId: doc.id,
                existingRating:   rating,
                existingComment:  comment,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: kSurfaceBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: kAccentGreen.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.edit_rounded,
                        color: kAccentGreen, size: 14),
                    SizedBox(width: 6),
                    Text('Edit Review',
                        style: TextStyle(
                            color: kAccentGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('No Reviews Yet',
                style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              '$workerName hasn\'t received any reviews yet.\nBe the first to leave one!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: kTextSecondary, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}