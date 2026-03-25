import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Constants (matching your theme) ─────────────────────────────────────────
const Color kPrimaryGreen  = Color(0xFF1A7A4A);
const Color kAccentGreen   = Color(0xFF25A865);
const Color kDarkBg        = Color(0xFF0D0D0D);
const Color kCardBg        = Color(0xFF1A1A1A);
const Color kSurfaceBg     = Color(0xFF242424);
const Color kBorder        = Color(0xFF2E2E2E);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF9E9E9E);

// ─── Worker Model ─────────────────────────────────────────────────────────────
class WorkerMarker {
  final String id;
  final String name;
  final String trade;
  final double rating;
  final double lat;
  final double lng;
  final bool isAvailable;
  final String initials;

  WorkerMarker({
    required this.id,
    required this.name,
    required this.trade,
    required this.rating,
    required this.lat,
    required this.lng,
    required this.isAvailable,
    required this.initials,
  });

  // Build from Firestore document
  factory WorkerMarker.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final nameParts = name.split(' ');
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : name.substring(0, 2).toUpperCase();

    return WorkerMarker(
      id:          doc.id,
      name:        name,
      trade:       data['category'] ?? 'Handyman',
      rating:      (data['rating'] ?? 0.0).toDouble(),
      lat:         (data['latitude'] ?? -1.2921).toDouble(),
      lng:         (data['longitude'] ?? 36.8219).toDouble(),
      isAvailable: data['isAvailable'] ?? false,
      initials:    initials,
    );
  }
}

// ─── Map Screen ───────────────────────────────────────────────────────────────
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // ── Map controller
  final MapController _mapController = MapController();

  // ── State
  LatLng _userLocation     = const LatLng(-1.2921, 36.8219); // Nairobi default
  bool   _locationLoaded   = false;
  bool   _isLoadingLocation = true;
  WorkerMarker? _selectedWorker;
  String _selectedCategory = 'All';

  // ── Workers from Firestore
  List<WorkerMarker> _workers = [];
  StreamSubscription? _workersSubscription;

  // ── Location update timer
  Timer? _locationTimer;

  // ── Categories
  final List<String> _categories = [
    'All', 'Plumber', 'Electrician', 'Cleaner', 'Handyman', 'AC Repair'
  ];

  // ── Animation for bottom sheet
  late AnimationController _sheetAnimCtrl;
  late Animation<Offset>   _sheetAnim;

  @override
  void initState() {
    super.initState();
    _sheetAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sheetAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sheetAnimCtrl,
      curve: Curves.easeOut,
    ));

    _getUserLocation();
    _listenToWorkers();

    // Update user location every 30 seconds
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _getUserLocation(),
    );
  }

  @override
  void dispose() {
    _workersSubscription?.cancel();
    _locationTimer?.cancel();
    _sheetAnimCtrl.dispose();
    super.dispose();
  }

  // ── Get user's live location ───────────────────────────────────────────────
  Future<void> _getUserLocation() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _userLocation    = newLocation;
        _locationLoaded  = true;
        _isLoadingLocation = false;
      });

      // Move map to user location
      if (_locationLoaded) {
        _mapController.move(_userLocation, 15.0);
      }

    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  // ── Listen to workers in Firestore real-time ───────────────────────────────
  void _listenToWorkers() {
    _workersSubscription = FirebaseFirestore.instance
        .collection('workers')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _workers = snapshot.docs
            .map((doc) => WorkerMarker.fromFirestore(doc))
            .toList();
      });
    });
  }

  // ── Filter workers by category ─────────────────────────────────────────────
  List<WorkerMarker> get _filteredWorkers {
    if (_selectedCategory == 'All') return _workers;
    return _workers
        .where((w) =>
            w.trade.toLowerCase() == _selectedCategory.toLowerCase())
        .toList();
  }

  // ── Calculate distance between user and worker ─────────────────────────────
  String _getDistance(WorkerMarker worker) {
    final distance = Geolocator.distanceBetween(
      _userLocation.latitude,
      _userLocation.longitude,
      worker.lat,
      worker.lng,
    );
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    }
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  // ── Select a worker ────────────────────────────────────────────────────────
  void _selectWorker(WorkerMarker worker) {
    setState(() => _selectedWorker = worker);
    _sheetAnimCtrl.forward();
  }

  // ── Deselect worker ────────────────────────────────────────────────────────
  void _deselectWorker() {
    _sheetAnimCtrl.reverse().then((_) {
      setState(() => _selectedWorker = null);
    });
  }

  // ── Center on user location ────────────────────────────────────────────────
  void _centerOnUser() {
    _mapController.move(_userLocation, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 15.0,
              maxZoom: 19.0,
              minZoom: 5.0,
              onTap: (_, _) => _deselectWorker(),
            ),
            children: [
              // Map tiles
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.easyfix.app',
              ),

              // Worker markers
              MarkerLayer(
                markers: [
                  // User location marker
                  Marker(
                    point: _userLocation,
                    width: 60,
                    height: 60,
                    child: _buildUserMarker(),
                  ),

                  // Worker markers
                  ..._filteredWorkers.map((worker) => Marker(
                    point: LatLng(worker.lat, worker.lng),
                    width: 56,
                    height: 56,
                    child: GestureDetector(
                      onTap: () => _selectWorker(worker),
                      child: _buildWorkerMarker(worker),
                    ),
                  )),
                ],
              ),
            ],
          ),

          // ── Top overlay ───────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Back button + title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: kCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kBorder),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: kTextPrimary, size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: kCardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kBorder),
                          ),
                          child: Row(children: [
                            const Icon(Icons.search_rounded,
                                color: kTextSecondary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${_filteredWorkers.length} workers nearby',
                              style: const TextStyle(
                                color: kTextSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (_isLoadingLocation)
                              const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                  color: kAccentGreen, strokeWidth: 2),
                              )
                            else
                              const Icon(Icons.my_location_rounded,
                                  color: kAccentGreen, size: 18),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Category filter chips
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _categories.length,
                    itemBuilder: (context, i) {
                      final cat = _categories[i];
                      final isSelected = cat == _selectedCategory;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? kPrimaryGreen : kCardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? kAccentGreen : kBorder,
                            ),
                          ),
                          child: Text(cat,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : kTextSecondary,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            )),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Center on me button ────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _selectedWorker != null ? 280 : 100,
            child: GestureDetector(
              onTap: _centerOnUser,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location_rounded,
                    color: kAccentGreen, size: 22),
              ),
            ),
          ),

          // ── Worker count badge ─────────────────────────────────────────────
          Positioned(
            left: 16,
            bottom: _selectedWorker != null ? 280 : 100,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_filteredWorkers.length} available',
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
          ),

          // ── Worker detail bottom sheet ─────────────────────────────────────
          if (_selectedWorker != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SlideTransition(
                position: _sheetAnim,
                child: _buildWorkerSheet(_selectedWorker!),
              ),
            ),
        ],
      ),
    );
  }

  // ── User location marker ───────────────────────────────────────────────────
  Widget _buildUserMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse ring
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kAccentGreen.withOpacity(0.15),
          ),
        ),
        // Inner dot
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kAccentGreen,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: kAccentGreen.withOpacity(0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Worker pin marker ──────────────────────────────────────────────────────
  Widget _buildWorkerMarker(WorkerMarker worker) {
    final isSelected = _selectedWorker?.id == worker.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isSelected ? 50 : 42,
            height: isSelected ? 50 : 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPrimaryGreen, kAccentGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: kPrimaryGreen.withOpacity(0.4),
                  blurRadius: isSelected ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(worker.initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: isSelected ? 14 : 12,
                )),
            ),
          ),
          // Pin tail
          Container(
            width: 2, height: 6,
            color: kPrimaryGreen,
          ),
        ],
      ),
    );
  }

  // ── Worker bottom sheet ────────────────────────────────────────────────────
  Widget _buildWorkerSheet(WorkerMarker worker) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: kBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Worker info row
          Row(children: [
            // Avatar
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPrimaryGreen, kAccentGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(worker.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ))),
            ),
            const SizedBox(width: 14),

            // Name + trade
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker.name,
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    )),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kPrimaryGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(worker.trade,
                        style: const TextStyle(
                          color: kAccentGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        )),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: worker.isAvailable
                            ? const Color(0xFF4CAF50)
                            : kTextSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      worker.isAvailable ? 'Available' : 'Busy',
                      style: TextStyle(
                        color: worker.isAvailable
                            ? const Color(0xFF4CAF50)
                            : kTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            // Close button
            GestureDetector(
              onTap: _deselectWorker,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: kSurfaceBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close_rounded,
                    color: kTextSecondary, size: 18),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // Stats row
          Row(children: [
            _statChip(Icons.star_rounded, '${worker.rating}',
                const Color(0xFFFFC107)),
            const SizedBox(width: 10),
            _statChip(Icons.location_on_rounded,
                _getDistance(worker), kAccentGreen),
            const SizedBox(width: 10),
            _statChip(Icons.work_outline_rounded,
                '${(worker.rating * 10).toInt()} jobs', kTextSecondary),
          ]),

          const SizedBox(height: 20),

          // Action buttons
          Row(children: [
            // Call button
            Expanded(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: kSurfaceBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call_outlined,
                          color: kAccentGreen, size: 18),
                      SizedBox(width: 8),
                      Text('Call',
                        style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Book Now button
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  // TODO: Navigate to booking screen
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimaryGreen, kAccentGreen],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryGreen.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('Book Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kSurfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label,
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )),
      ]),
    );
    
  }
}