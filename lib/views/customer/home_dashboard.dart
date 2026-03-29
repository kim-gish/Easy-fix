import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'map_screen.dart';
import '../booking/booking_screen.dart';

// ─── Constants (STYLING PRESERVED) ──────────────────────────────────────────
const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

class ServiceCategory {
  final String emoji;
  final String label;
  const ServiceCategory(this.emoji, this.label);
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedCategory = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final List<ServiceCategory> _categories = const [
    ServiceCategory('🔧', 'Plumbing'),
    ServiceCategory('⚡', 'Electrical'),
    ServiceCategory('❄️', 'AC Repair'),
    ServiceCategory('🪟', 'Windows'),
    ServiceCategory('🎨', 'Painting'),
    ServiceCategory('🌿', 'Cleaning'),
  ];

  // NOTE: THE DUMMY _WORKERS LIST IS GONE. 
  // If you see a list named _workers here, delete it!

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    List<String> names = name.trim().split(" ");
    if (names.length >= 2) {
      return "${names[0][0]}${names[1][0]}".toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : "P";
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
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildBanner()),
            SliverToBoxAdapter(child: _buildSectionHeader('Services', 'See all')),
            SliverToBoxAdapter(child: _buildCategories()),
            SliverToBoxAdapter(child: _buildSectionHeader('Nearby Workers', 'View map',
              onActionTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen())),
            )),
            
            // THIS IS THE DYNAMIC SECTION
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: StreamBuilder<QuerySnapshot>(
                  // Ensure your collection is named 'workers' in Firebase
                  stream: FirebaseFirestore.instance
                      .collection('workers')
                      .where('isAvailable', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: kAccentGreen));
                    }
                    
                    final docs = snapshot.data?.docs ?? [];
                    
                    if (docs.isEmpty) {
                      return const Center(child: Text("No workers currently available", style: TextStyle(color: kTextSecondary)));
                    }

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        var data = docs[i].data() as Map<String, dynamic>;
                        return _workerCard(
                          docs[i].id,
                          data['name'] ?? 'No Name',
                          data['category'] ?? 'General',
                          (data['rating'] ?? 0.0).toDouble(),
                          _getInitials(data['name'] ?? 'P'),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            SliverToBoxAdapter(child: _buildRecentJobsHeader()),
            SliverToBoxAdapter(child: _buildRecentJobs()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Worker Card UI (STYLING PRESERVED) ───────────────────────────────────
  Widget _workerCard(String id, String name, String trade, double rating, String initials) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookingScreen(
            workerId: id,
            workerName: name,
            workerTrade: trade,
            workerRating: rating,
            workerInitials: initials,
            distance: "Nearby",
          )),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kPrimaryGreen, kAccentGreen]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
                ),
                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4CAF50))),
              ],
            ),
            const SizedBox(height: 10),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(trade, style: const TextStyle(color: kTextSecondary, fontSize: 11)),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 13),
                const SizedBox(width: 3),
                Text(rating.toString(), style: const TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kPrimaryGreen, kAccentGreen]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Text('Book', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rest of UI Components (STYLING PRESERVED) ───────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: kDarkBg,
      expandedHeight: 120, pinned: true, elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0F3D26), Color(0xFF1A7A4A), Color(0xFF0D2B1A)]),
          ),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nairobi, Kenya', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('Good morning! 👋', style: TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              _iconBtn(Icons.notifications_none_rounded, badge: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {bool badge = false}) {
    return Stack(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 20)),
      if (badge) Positioned(top: 6, right: 6, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
    ]);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const TextField(
          style: TextStyle(color: kTextPrimary),
          decoration: InputDecoration(hintText: 'Search services...', hintStyle: TextStyle(color: kTextSecondary), border: InputBorder.none),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 120,
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [kPrimaryGreen, kAccentGreen]), borderRadius: BorderRadius.circular(20)),
      child: const Center(child: Text("20% OFF FIRST REPAIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildSectionHeader(String title, String action, {VoidCallback? onActionTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          GestureDetector(onTap: onActionTap, child: Text(action, style: const TextStyle(color: kAccentGreen, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final isSelected = i == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = i),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: isSelected ? kPrimaryGreen : kCardBg, borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_categories[i].emoji, style: const TextStyle(fontSize: 22)), Text(_categories[i].label, style: const TextStyle(color: Colors.white, fontSize: 11))]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentJobsHeader() => _buildSectionHeader('Recent Jobs', 'History');
  Widget _buildRecentJobs() => const Padding(padding: EdgeInsets.all(16), child: Text("No history yet", style: TextStyle(color: kTextSecondary)));

  Widget _buildBottomNav() {
    return Container(
      color: kCardBg,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.home_rounded, color: kAccentGreen),
          Icon(Icons.search_rounded, color: kTextSecondary),
          Icon(Icons.receipt_long_rounded, color: kTextSecondary),
          Icon(Icons.person_rounded, color: kTextSecondary),
        ],
      ),
    );
  }
}