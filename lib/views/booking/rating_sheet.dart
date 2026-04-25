import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

// ── Call this anywhere to show the rating / edit sheet ────────────────────────
Future<void> showRatingSheet(
  BuildContext context, {
  required String jobId,
  required String workerId,
  required String workerName,
  String? existingReviewId,
  int    existingRating  = 0,
  String existingComment = '',
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _RatingSheetContent(
      jobId:            jobId,
      workerId:         workerId,
      workerName:       workerName,
      existingReviewId: existingReviewId,
      existingRating:   existingRating,
      existingComment:  existingComment,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _RatingSheetContent extends StatefulWidget {
  final String  jobId;
  final String  workerId;
  final String  workerName;
  final String? existingReviewId;
  final int     existingRating;
  final String  existingComment;

  const _RatingSheetContent({
    required this.jobId,
    required this.workerId,
    required this.workerName,
    this.existingReviewId,
    required this.existingRating,
    required this.existingComment,
  });

  @override
  State<_RatingSheetContent> createState() => _RatingSheetContentState();
}

class _RatingSheetContentState extends State<_RatingSheetContent> {
  int  _selectedRating = 0;
  bool _isSubmitting   = false;
  late TextEditingController _commentCtrl;

  bool get _isEdit => widget.existingReviewId != null;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.existingRating;
    _commentCtrl    = TextEditingController(text: widget.existingComment);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    switch (_selectedRating) {
      case 1:  return 'Poor 😞';
      case 2:  return 'Fair 😐';
      case 3:  return 'Good 🙂';
      case 4:  return 'Great 😊';
      case 5:  return 'Excellent! 🤩';
      default: return 'Tap to rate';
    }
  }

  // ── Submit or update ───────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select a star rating',
            style: TextStyle(color: Colors.white)),
        backgroundColor: kCardBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final customerName =
          userDoc.data()?['name']?.toString() ??
          user.displayName ??
          'Customer';

      final db  = FirebaseFirestore.instance;
      final now = DateTime.now().toIso8601String();

      if (_isEdit) {
        // Update existing review
        await db.collection('Reviews').doc(widget.existingReviewId).update({
          'rating':   _selectedRating,
          'comment':  _commentCtrl.text.trim(),
          'edited':   true,
          'editedAt': now,
        });
      } else {
        // Create new review
        await db.collection('Reviews').add({
          'jobId':        widget.jobId,
          'workerId':     widget.workerId,
          'customerId':   user.uid,
          'customerName': customerName,
          'rating':       _selectedRating,
          'comment':      _commentCtrl.text.trim(),
          'edited':       false,
          'createdAt':    now,
          'editedAt':     null,
        });

        // Mark job as rated
        await db.collection('jobs').doc(widget.jobId).update({'rated': true});
      }

      // Recalculate worker average rating
      await _recalculateWorkerRating(widget.workerId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _isEdit
                ? 'Review updated successfully ✅'
                : 'Thanks for your review! ⭐',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: kPrimaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      debugPrint('Review submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to submit review. Try again.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Recalculate worker average rating ─────────────────────────────────────
  Future<void> _recalculateWorkerRating(String workerId) async {
    final snap = await FirebaseFirestore.instance
        .collection('Reviews')
        .where('workerId', isEqualTo: workerId)
        .get();

    if (snap.docs.isEmpty) return;

    final ratings = snap.docs
        .map((d) => (d.data()['rating'] as num).toDouble())
        .toList();
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;

    await FirebaseFirestore.instance
        .collection('workers')
        .doc(workerId)
        .update({
      'rating':      double.parse(avg.toStringAsFixed(1)),
      'reviewCount': ratings.length,
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: kBorder, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          // Icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [kPrimaryGreen, kAccentGreen]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                  color: kPrimaryGreen.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6))],
            ),
            child: const Center(
                child: Text('⭐', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(height: 14),

          Text(
            _isEdit ? 'Edit Your Review' : 'Rate the Job',
            style: const TextStyle(
                color: kTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _isEdit
                ? 'Update your review for ${widget.workerName}'
                : 'How was your experience with ${widget.workerName}?',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: kTextSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Star selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = star),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: Text(
                    '★',
                    style: TextStyle(
                      fontSize: star <= _selectedRating ? 40 : 32,
                      color: star <= _selectedRating
                          ? const Color(0xFFFFC107)
                          : kBorder,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),

          // Rating label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _ratingLabel,
              key: ValueKey(_selectedRating),
              style: TextStyle(
                color: _selectedRating > 0
                    ? const Color(0xFFFFC107)
                    : kTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Comment box
          Container(
            decoration: BoxDecoration(
                color: kSurfaceBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder)),
            child: TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: 300,
              style: const TextStyle(
                  color: kTextPrimary, fontSize: 14, height: 1.5),
              decoration: const InputDecoration(
                hintText:
                    'Share details about quality of work, punctuality, professionalism...',
                hintStyle:
                    TextStyle(color: Color(0xFF555555), fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
                counterStyle:
                    TextStyle(color: kTextSecondary, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          GestureDetector(
            onTap: _isSubmitting ? null : _submit,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [kPrimaryGreen, kAccentGreen],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: kPrimaryGreen.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6))],
              ),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        _isEdit ? 'Update Review ✓' : 'Submit Review ⭐',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}