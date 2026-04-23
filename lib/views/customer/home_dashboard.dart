import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'map_screen.dart';
import '../booking/booking_screen.dart';
import '../booking/job_status_screen.dart';

const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});
  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with SingleTickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final List<Map<String, String>> _categories = [
    {'emoji': '🔧', 'label': 'Plumbing'},
    {'emoji': '⚡', 'label': 'Electrical'},
    {'emoji': '❄️', 'label': 'AC Repair'},
    {'emoji': '🎨', 'label': 'Painting'},
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  // ── CALLING LOGIC ──────────────────────────────────────────────────
  Future<void> _makeCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Technician's number not available yet.")),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open phone dialer.")),
      );
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildSectionHeader('Services', 'See all')),
            SliverToBoxAdapter(child: _buildCategoryList()),
            SliverToBoxAdapter(child: _buildSectionHeader('Active Bookings', 'History')),
            SliverToBoxAdapter(child: _buildActiveJobsStream()), 
            SliverToBoxAdapter(child: _buildSectionHeader('Nearby Workers', 'Map', 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())))),
            SliverToBoxAdapter(child: _buildWorkersStream()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return SliverAppBar(
      backgroundColor: kDarkBg, expandedHeight: 120, pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            String name = "User";
            if (snapshot.hasData && snapshot.data!.exists) {
              name = (snapshot.data!.data() as Map<String, dynamic>)['name']?.split(' ')[0] ?? "User";
            }
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F3D26), kPrimaryGreen])),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nairobi, Kenya 📍', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('Hi, $name 👋', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: const TextField(
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: "Search for a service...", hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none, icon: Icon(Icons.search, color: kAccentGreen)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          GestureDetector(onTap: onTap, child: Text(action, style: const TextStyle(color: kAccentGreen, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          bool selected = _selectedCategoryIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryIndex = i),
            child: Container(
              width: 80, margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: selected ? kPrimaryGreen : kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? kAccentGreen : kBorder)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_categories[i]['emoji']!, style: const TextStyle(fontSize: 24)),
                  Text(_categories[i]['label']!, style: TextStyle(color: selected ? Colors.white : kTextSecondary, fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveJobsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('jobs')
          .where('userId', isEqualTo: uid)
          .where('status', whereIn: ['pending', 'accepted'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.all(16), height: 60,
            decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder, style: BorderStyle.solid)),
            child: const Center(child: Text("No active bookings", style: TextStyle(color: kTextSecondary, fontSize: 12))),
          );
        }
        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            bool isAccepted = data['status'] == 'accepted';
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
              child: ListTile(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobStatusScreen(jobId: doc.id))),
                leading: Icon(Icons.circle, color: isAccepted ? kAccentGreen : Colors.amber, size: 12),
                title: Text(data['category'] ?? 'Repair', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(isAccepted ? "Worker is on the way!" : "Waiting for worker...", style: TextStyle(color: isAccepted ? kAccentGreen : kTextSecondary, fontSize: 12)),
                trailing: isAccepted 
                  ? IconButton(
                      icon: const Icon(Icons.phone, color: kAccentGreen),
                      onPressed: () => _makeCall(data['workerPhone']), 
                    )
                  : const Icon(Icons.chevron_right, color: kTextSecondary),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildWorkersStream() {
    return SizedBox(
      height: 160,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('workers').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kAccentGreen));
          
          final workerDocs = snapshot.data!.docs;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: workerDocs.length,
            itemBuilder: (context, i) {
              final doc = workerDocs[i];
              final data = doc.data() as Map<String, dynamic>;
              
              return GestureDetector(
                onTap: () {
                  // ── PASSING ALL 4 DYNAMIC ARGUMENTS ────────────────────────
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingScreen(
                      workerId: doc.id,
                      workerName: data['name'] ?? 'Worker',
                      workerTrade: data['category'] ?? 'Technician',
                      workerRating: (data['rating'] ?? 0.0).toDouble(),
                      workerInitials: (data['name'] ?? 'W')[0].toUpperCase(),
                      distance: data['distance'] ?? '-- km',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 130, 
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kCardBg, 
                    borderRadius: BorderRadius.circular(12), 
                    border: Border.all(color: kBorder)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: kAccentGreen, 
                        radius: 20, 
                        child: Text(data['name']?[0] ?? 'W', style: const TextStyle(color: Colors.white))
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['name'] ?? 'Worker', 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            (data['rating'] ?? 0.0).toString(),
                            style: const TextStyle(color: kTextSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                      Text(
                        data['category'] ?? 'Technician', 
                        style: TextStyle(color: kAccentGreen.withOpacity(0.8), fontSize: 11)
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}