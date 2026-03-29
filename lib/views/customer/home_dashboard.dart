import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'map_screen.dart';
import '../booking/booking_screen.dart';

// ─── Constants (same as login) ───────────────────────────────────────────────
const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

// ─── Models ──────────────────────────────────────────────────────────────────
class ServiceCategory {
  final String emoji;
  final String label;
  const ServiceCategory(this.emoji, this.label);
}

class NearbyWorker {
  final String id;
  final String initials;
  final String name;
  final String trade;
  final double rating;
  final String distance;
  final bool isAvailable;
  const NearbyWorker({
    required this.id,
    required this.initials,
    required this.name,
    required this.trade,
    required this.rating,
    required this.distance,
    required this.isAvailable,
  });
}

// ─── Screen ──────────────────────────────────────────────────────────────────
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

  final List<NearbyWorker> _workers = const [
    NearbyWorker(id: 'worker_1', initials: 'JK', name: 'James Kamau',    trade: 'Plumber',     rating: 4.9, distance: '0.3 km', isAvailable: true),
    NearbyWorker(id: 'worker_2', initials: 'AO', name: 'Amina Odhiambo', trade: 'Electrician', rating: 4.7, distance: '0.7 km', isAvailable: true),
    NearbyWorker(id: 'worker_3', initials: 'PM', name: 'Peter Mwangi',   trade: 'Handyman',    rating: 4.5, distance: '1.2 km', isAvailable: false),
    NearbyWorker(id: 'worker_4', initials: 'GN', name: 'Grace Njeri',    trade: 'Cleaner',     rating: 4.8, distance: '1.5 km', isAvailable: true),
  ];

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
              onActionTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, animation, __) => const MapScreen(),
                  transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              ),
            )),
            SliverToBoxAdapter(child: _buildWorkersList()),
            SliverToBoxAdapter(child: _buildRecentJobsHeader()),
            SliverToBoxAdapter(child: _buildRecentJobs()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: kDarkBg,
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
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
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: kAccentGreen, size: 16),
                      const SizedBox(width: 4),
                      Text('Nairobi, Kenya',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          )),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: kAccentGreen, size: 16),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text('Good morning, John 👋',
                      style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      )),
                ],
              ),
              Row(
                children: [
                  _iconBtn(Icons.notifications_none_rounded, badge: true),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kAccentGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('JK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          )),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {bool badge = false}) {
    return Stack(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        if (badge)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFFF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.search_rounded, color: kTextSecondary, size: 20),
            ),
            const Expanded(
              child: TextField(
                style: TextStyle(color: kTextPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search for a service or worker...',
                  hintStyle: TextStyle(color: Color(0xFF555555), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kPrimaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ── Banner ─────────────────────────────────────────────────────────────────
  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 130,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A7A4A), Color(0xFF25A865)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimaryGreen.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            right: 40, bottom: -30,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('LIMITED OFFER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            )),
                      ),
                      const SizedBox(height: 8),
                      const Text('First repair\n20% off! 🎉',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.5,
                          )),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Book Now',
                            style: TextStyle(
                              color: kPrimaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ],
                  ),
                ),
                const Text('🔧', style: TextStyle(fontSize: 64)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, String action, {VoidCallback? onActionTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                color: kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              )),
          GestureDetector(
            onTap: onActionTap,
            child: Text(action,
                style: const TextStyle(
                  color: kAccentGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  // ── Service categories ─────────────────────────────────────────────────────
  Widget _buildCategories() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = i == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryGreen : kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? kAccentGreen : kBorder,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: kPrimaryGreen.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(cat.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : kTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Workers list ───────────────────────────────────────────────────────────
  Widget _buildWorkersList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _workers.length,
        itemBuilder: (context, i) => _workerCard(_workers[i]),
      ),
    );
  }

  Widget _workerCard(NearbyWorker w) {
    return GestureDetector(
      onTap: () {
        if (!w.isAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('This worker is currently unavailable.',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF333333),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
          return;
        }
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => BookingScreen(
              workerId:    w.id,
              workerName:  w.name,
              workerTrade: w.trade,
              workerRating: w.rating,
              workerInitials: w.initials,
              distance:    w.distance,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOut)),
                  child: child,
                ),
            transitionDuration: const Duration(milliseconds: 400),
          ),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimaryGreen, kAccentGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(w.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        )),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: w.isAvailable
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(w.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 2),
            Text(w.trade,
                style: const TextStyle(
                    color: kTextSecondary, fontSize: 11)),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFC107), size: 13),
                const SizedBox(width: 3),
                Text(w.rating.toString(),
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
                const Spacer(),
                Text(w.distance,
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
            if (w.isAvailable) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimaryGreen, kAccentGreen],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Book',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    )),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Recent Jobs ────────────────────────────────────────────────────────────
  Widget _buildRecentJobsHeader() =>
      _buildSectionHeader('Recent Jobs', 'History');

  Widget _buildRecentJobs() {
    final jobs = [
      {'icon': '🔧', 'title': 'Pipe Leak Fixed', 'worker': 'James K.', 'date': 'Mar 10', 'status': 'Completed', 'amount': 'KES 1,200'},
      {'icon': '⚡', 'title': 'Socket Repair',   'worker': 'Amina O.', 'date': 'Mar 6',  'status': 'Completed', 'amount': 'KES 800'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: jobs.map((job) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kPrimaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(job['icon']!,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job['title']!,
                          style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 3),
                      Text('${job['worker']} · ${job['date']}',
                          style: const TextStyle(
                            color: kTextSecondary,
                            fontSize: 12,
                          )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(job['amount']!,
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kAccentGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(job['status']!,
                          style: const TextStyle(
                            color: kAccentGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
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
          _navItem(Icons.home_rounded, 'Home', true),
          _navItem(Icons.search_rounded, 'Explore', false),
          _navItem(Icons.receipt_long_rounded, 'Jobs', false),
          _navItem(Icons.person_rounded, 'Profile', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Text(label,
              style: TextStyle(
                color: active ? kAccentGreen : kTextSecondary,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              )),
        ],
      ),
    );
  }
}