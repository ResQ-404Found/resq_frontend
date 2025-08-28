// lib/pages/map_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'app_bottom_nav.dart';
// 라우트 상수 사용
import 'package:resq_frontend/routes.dart';

const String kakaoRestApiKey = 'KakaoAK 6c70d9ab4ca17bdfa047539c7d8ec0a8';

class Shelter {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distance;

  Shelter({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
  });

  factory Shelter.fromJson(Map<String, dynamic> json) {
    return Shelter(
      name: json['facility_name'],
      address: json['road_address'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      distance: json['distance_km'],
    );
  }
}

class Disaster {
  final String type;
  final String info;
  final String startTime;
  final String region;
  final String disasterLevel;

  Disaster({
    required this.type,
    required this.info,
    required this.startTime,
    required this.region,
    required this.disasterLevel,
  });

  factory Disaster.fromJson(Map<String, dynamic> json) {
    return Disaster(
      type: json['disaster_type'],
      info: json['info'],
      startTime: json['start_time'],
      region: json['region_name'],
      disasterLevel: json['disaster_level'] ?? '',
    );
  }
}

class Hospital {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distance;

  Hospital({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'],
      name: json['facility_name'],
      address: json['road_address'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      distance: json['distance_km'],
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with AutomaticKeepAliveClientMixin {
  // 컨트롤러/라이프사이클 가드
  NaverMapController? _controller;
  bool _alive = true;

  // 맵은 1회 생성·재사용
  late final Widget _mapView;

  // 주소/행정동
  String? _currentAddress;
  String? _sido, _sigungu, _eupmyeondong;

  // 마커들
  final List<NMarker> _shelterMarkers = [];
  final List<NMarker> _hospitalMarkers = [];
  NMarker? _userMarker;

  // 선택 상태
  Shelter? _selectedShelter;
  Hospital? _selectedHospital;

  // 재난
  List<Disaster> _disasterList = [];
  bool _showDisasterSheet = false;
  bool _hasDisasterMessage = false;

  // 모드
  String _selectedMenu = ''; // '', 'shelter', 'hospital'

  // 위치/로딩
  Position? _currentPosition;
  bool _loadingShelters = false;
  bool _loadingHospitals = false;
  bool _loadingDisasters = false;

  // 네비게이션 디바운스
  bool _navigating = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // 맵 인스턴스 고정 생성(고정 Key)
    _mapView = NaverMap(
      key: const ValueKey('naver.map.view'),
      options: const NaverMapViewOptions(
        mapType: NMapType.basic,
        locationButtonEnable: false,
        initialCameraPosition: NCameraPosition(
          target: NLatLng(35.2313, 129.0825),
          zoom: 12,
        ),
      ),
      onMapReady: _onMapReady,
      onMapTapped: (point, latLng) {
        if (!mounted) return;
        setState(() {
          _showDisasterSheet = false;
          _selectedMenu = '';
          _selectedHospital = null;
          _selectedShelter = null;
        });
      },
    );
  }

  void _onMapReady(NaverMapController controller) async {
    _controller = controller;
    if (!_alive || !mounted) return;
    await _getAndMoveToCurrentLocation();
  }

  @override
  void dispose() {
    _alive = false;
    _controller = null;
    super.dispose();
  }

  // 내 위치 마커가 항상 존재하도록 보장
  void _ensureUserMarker() {
    if (_controller == null) return;
    if (_userMarker == null && _currentPosition != null) {
      _userMarker = NMarker(
        id: 'user_location',
        position: NLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: NOverlayImage.fromAssetImage('lib/asset/user_marker.png'),
      );
    }
  }

  Future<void> _clearOverlaysKeepUser() async {
    if (_controller == null || !_alive || !mounted) return;
    await _controller!.clearOverlays();
    _ensureUserMarker();
    if (_userMarker != null) {
      await _controller!.addOverlay(_userMarker!);
    }
  }

  Future<void> _switchMode(String? mode) async {
    setState(() {
      _selectedShelter = null;
      _selectedHospital = null;
      _showDisasterSheet = false;
    });

    if (mode == null) {
      await _clearOverlaysKeepUser(); // 전부 끄기
      return;
    }

    final pos = _currentPosition ?? await Geolocator.getCurrentPosition();
    if (mode == 'shelter') {
      await _fetchNearbyShelters(pos);
    }
    if (mode == 'hospital') {
      await _fetchNearbyHospitals(pos);
    }
  }

  Future<void> _getAndMoveToCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (!_alive || !mounted) return;

    _currentPosition = position;
    final userLatLng = NLatLng(position.latitude, position.longitude);

    if (_controller == null || !_alive || !mounted) return;

    if (_userMarker == null) {
      _userMarker = NMarker(
        id: 'user_location',
        position: userLatLng,
        icon: NOverlayImage.fromAssetImage('lib/asset/user_marker.png'),
      );
      await _controller!.addOverlay(_userMarker!);
    } else {
      _userMarker!.setPosition(userLatLng);
    }

    await _controller!.updateCamera(
      NCameraUpdate.fromCameraPosition(
        NCameraPosition(target: userLatLng, zoom: 15),
      ),
    );
    if (!_alive || !mounted) return;

    await _getAddress(position);
    if (!_alive || !mounted) return;

    await _fetchDisasters();
  }

  Future<void> _getAddress(Position position) async {
    final url =
        'https://dapi.kakao.com/v2/local/geo/coord2address.json?x=${position.longitude}&y=${position.latitude}';
    final response = await http.get(Uri.parse(url), headers: {'Authorization': kakaoRestApiKey});

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final documents = data['documents'];
      if (documents != null && documents is List && documents.isNotEmpty) {
        final jibun = documents[0]['address']?['address_name'] ?? '';
        final road = documents[0]['road_address']?['address_name'] ?? '';
        final resultAddress = jibun.isNotEmpty ? jibun : road;

        if (!mounted) return;
        setState(() {
          _currentAddress = resultAddress;
          _sido = documents[0]['address']?['region_1depth_name'];
          _sigungu = documents[0]['address']?['region_2depth_name'];
          _eupmyeondong = documents[0]['address']?['region_3depth_name'];
        });
      }
    }
  }

  Future<void> _fetchNearbyShelters(Position position) async {
    if (!mounted) return;
    setState(() => _loadingShelters = true);
    try {
      final url = Uri.parse(
          'http://54.253.211.96:8000/api/shelters/nearby?latitude=${position.latitude}&longitude=${position.longitude}&limit=10');
      final response = await http.get(url, headers: {'accept': 'application/json'});

      if (response.statusCode == 200) {
        final jsonBody = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> data = jsonBody is List ? jsonBody : jsonBody['data'];

        _shelterMarkers.clear();
        for (var item in data) {
          final shelter = Shelter.fromJson(item);
          final marker = NMarker(
            id: 'shelter_${shelter.latitude}_${shelter.longitude}',
            position: NLatLng(shelter.latitude, shelter.longitude),
            icon: NOverlayImage.fromAssetImage('lib/asset/shelter_marker.png'),
            caption: NOverlayCaption(text: shelter.name),
          );
          marker.setOnTapListener((m) {
            if (!mounted) return;
            setState(() {
              _selectedShelter = (_selectedShelter?.name == shelter.name) ? null : shelter;
              _showDisasterSheet = false;
            });
          });
          _shelterMarkers.add(marker);
        }

        if (_controller != null && _alive && mounted) {
          await _controller!.clearOverlays();

          _ensureUserMarker();
          final overlays = <NAddableOverlay>{};
          if (_userMarker != null) overlays.add(_userMarker!);
          overlays.addAll(_shelterMarkers);

          await _controller!.addOverlayAll(overlays);
          if (!_alive || !mounted) return;
          await _zoomToFitMarkersIncludingUser(_shelterMarkers);
        }
      }
    } finally {
      if (mounted) setState(() => _loadingShelters = false);
    }
  }

  Future<void> _fetchNearbyHospitals(Position position) async {
    if (!mounted) return;
    setState(() => _loadingHospitals = true);
    try {
      final url = Uri.parse(
          'http://54.253.211.96:8000/api/hospital/nearby?latitude=${position.latitude}&longitude=${position.longitude}&limit=10');
      final response = await http.get(url, headers: {'accept': 'application/json'});

      if (response.statusCode == 200) {
        final jsonBody = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> data = jsonBody is List ? jsonBody : jsonBody['data'];

        _hospitalMarkers.clear();
        for (var item in data) {
          final hospital = Hospital.fromJson(item);
          final marker = NMarker(
            id: 'hospital_${hospital.latitude}_${hospital.longitude}',
            position: NLatLng(hospital.latitude, hospital.longitude),
            icon: NOverlayImage.fromAssetImage('lib/asset/hospital_marker.png'),
            caption: NOverlayCaption(text: hospital.name),
          );
          marker.setOnTapListener((m) {
            if (!mounted) return;
            setState(() {
              _selectedHospital = (_selectedHospital?.name == hospital.name) ? null : hospital;
            });
          });
          _hospitalMarkers.add(marker);
        }

        if (_controller != null && _alive && mounted) {
          await _controller!.clearOverlays();

          _ensureUserMarker();
          final overlays = <NAddableOverlay>{};
          if (_userMarker != null) overlays.add(_userMarker!);
          overlays.addAll(_hospitalMarkers);

          await _controller!.addOverlayAll(overlays);
          if (!_alive || !mounted) return;
          await _zoomToFitMarkersIncludingUser(_hospitalMarkers);
        }
      }
    } finally {
      if (mounted) setState(() => _loadingHospitals = false);
    }
  }

  Future<void> _fetchDisasters() async {
    if (_sido == null || _sigungu == null || _eupmyeondong == null) return;
    if (!mounted) return;
    setState(() => _loadingDisasters = true);
    try {
      final queryUri = Uri.parse(
          'http://54.253.211.96:8000/api/disasters?sido=$_sido&sigungu=$_sigungu&eupmyeondong=$_eupmyeondong&active_only=true');
      final response = await http.get(queryUri, headers: {'accept': 'application/json'});

      if (response.statusCode == 200) {
        final jsonBody = json.decode(utf8.decode(response.bodyBytes));
        final summary = jsonBody['data'][0]['summary'] as Map<String, dynamic>;
        final total = summary.values.fold<int>(0, (sum, val) => sum + (val as int));
        final List<dynamic> data = jsonBody['data'][0]['disasters'];

        if (!mounted) return;
        setState(() {
          _disasterList = data.map((e) => Disaster.fromJson(e)).toList();
          _hasDisasterMessage = total > 0;
          if (_selectedMenu == 'disaster') {
            _showDisasterSheet = true;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loadingDisasters = false);
    }
  }

  Future<void> _zoomToFitMarkersIncludingUser(List<NMarker> markers) async {
    if (_controller == null || !_alive || !mounted) return;
    if (markers.isEmpty && _userMarker == null) return;

    final positions = <NLatLng>[];
    if (_userMarker != null) positions.add(_userMarker!.position);
    positions.addAll(markers.map((m) => m.position));

    final bounds = _calculateBounds(positions);
    await _controller!.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(80)),
    );
  }

  Future<void> _zoomToFitAllMarkers() async {
    if (_shelterMarkers.isEmpty || _controller == null || !_alive || !mounted) return;
    final bounds = _calculateBounds(_shelterMarkers.map((m) => m.position).toList());
    await _controller!.updateCamera(NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(80)));
  }

  Future<void> _zoomToFitMarkers(List<NMarker> markers) async {
    if (markers.isEmpty || _controller == null || !_alive || !mounted) return;
    final bounds = _calculateBounds(markers.map((m) => m.position).toList());
    await _controller!.updateCamera(NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(80)));
  }

  NLatLngBounds _calculateBounds(List<NLatLng> positions) {
    double minLat = positions.first.latitude, maxLat = positions.first.latitude;
    double minLng = positions.first.longitude, maxLng = positions.first.longitude;
    for (var p in positions) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return NLatLngBounds(
      southWest: NLatLng(minLat, minLng),
      northEast: NLatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildLocationBox(),
            _buildLocationActions(),
            _buildStatusBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // 맵: 고정 생성본 재사용
                      _mapView,

                      // 로딩 오버레이
                      if (_loadingShelters || _loadingHospitals || _loadingDisasters)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.08),
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                        ),

                      // 바텀시트들 (부모 AnimatedPositioned만 위치 책임)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOut,
                        bottom: _selectedShelter != null ? 0 : -400,
                        left: 0,
                        right: 0,
                        child: _buildShelterDetailSheet(),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOut,
                        bottom: (_selectedMenu == 'disaster' && _showDisasterSheet) ? 0 : -400,
                        left: 0,
                        right: 0,
                        child: (_selectedMenu == 'disaster' && _showDisasterSheet)
                            ? _buildDisasterInfoSheet()
                            : const SizedBox.shrink(),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOut,
                        bottom: _selectedHospital != null ? 0 : -400,
                        left: 0,
                        right: 0,
                        child: _buildHospitalDetailSheet(),
                      ),

                      // 지도 줌 컨트롤
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.black),
                                onPressed: () async {
                                  if (_controller == null || !_alive || !mounted) return;
                                  final pos = await _controller!.getCameraPosition();
                                  await _controller!.updateCamera(
                                    NCameraUpdate.fromCameraPosition(
                                      NCameraPosition(target: pos.target, zoom: pos.zoom + 1),
                                    ),
                                  );
                                },
                              ),
                              Container(width: 36, height: 1, color: Colors.grey[300]),
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.black),
                                onPressed: () async {
                                  if (_controller == null || !_alive || !mounted) return;
                                  final pos = await _controller!.getCameraPosition();
                                  await _controller!.updateCamera(
                                    NCameraUpdate.fromCameraPosition(
                                      NCameraPosition(target: pos.target, zoom: pos.zoom - 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: const AppBottomNav(currentIndex: 0),
      ),
    );
  }

  Widget _buildLocationBox() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Icon(Icons.location_on, color: Colors.redAccent, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _currentAddress ?? '주소 불러오는 중...',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.grey),
            onPressed: () async {
              await _getAndMoveToCurrentLocation();
            },
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final selected = _selectedMenu == value;
    final activeColor = (value == 'shelter') ? const Color(0xFF43A85B) : Colors.red;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 92),
      child: GestureDetector(
        onTap: () async {
          if (!mounted) return;
          setState(() {
            final isSame = _selectedMenu == value;
            _selectedMenu = isSame ? '' : value;
            _selectedHospital = null;
            _selectedShelter = null;
            _showDisasterSheet = false;
          });

          if (_selectedMenu == 'shelter') {
            final pos = _currentPosition ?? await Geolocator.getCurrentPosition();
            await _fetchNearbyShelters(pos);
          }
          if (_selectedMenu == 'hospital') {
            final pos = _currentPosition ?? await Geolocator.getCurrentPosition();
            await _fetchNearbyHospitals(pos);
          }
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? activeColor : Colors.grey.shade300, width: 1.2),
            boxShadow: [
              if (selected)
                BoxShadow(color: activeColor.withOpacity(0.4), offset: const Offset(0, 2), blurRadius: 2),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? activeColor : Colors.black87),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? activeColor : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bellButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () async {
          if (_navigating) return;
          _navigating = true;
          try {
            await _fetchDisasters();
            if (!mounted) return;
            setState(() {
              _selectedMenu = '';
              _showDisasterSheet = false;
              _selectedHospital = null;
              _selectedShelter = null;
            });

            await Navigator.pushNamed(
              context,
              AppRoutes.allDisasters, // '/all-disasters'
              arguments: {
                'sido': _sido ?? '',
                'sigungu': _sigungu ?? '',
                'eupmyeondong': _eupmyeondong ?? '',
              },
            );
          } finally {
            if (mounted) _navigating = false;
          }
        },
        child: const Icon(Icons.notifications_none_rounded, size: 28, color: Colors.black87),
      ),
    );
  }

  Widget _buildLocationActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 52,
      child: Row(
        children: [
          _pillButton(label: '대피소', icon: Icons.favorite_border, value: 'shelter'),
          const SizedBox(width: 8),
          _pillButton(label: '병원', icon: Icons.local_hospital, value: 'hospital'),
          const Spacer(),
          _bellButton(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final has = _hasDisasterMessage;
    final text = has ? '재난 문자가 있습니다. 확인하세요' : '재난 문자가 없습니다.';
    final bgColor = has ? Colors.redAccent : Colors.green;
    final leadingIcon = has
        ? const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22)
        : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leadingIcon,
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ※ Positioned 제거 - 부모 AnimatedPositioned가 위치 결정
  Widget _buildShelterDetailSheet() {
    if (_selectedShelter == null) return const SizedBox.shrink();
    final shelter = _selectedShelter!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('대피소 상세 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_currentAddress != null) ...[
            _infoRow('내 위치', _currentAddress!),
            const SizedBox(height: 6),
          ],
          _infoRow('이름', shelter.name),
          _infoRow('주소', shelter.address),
          _infoRow('거리', '${(shelter.distance * 1000).toStringAsFixed(0)}m'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final lat = shelter.latitude;
              final lng = shelter.longitude;
              final name = Uri.encodeComponent(shelter.name);
              final url = 'nmap://route/public?dlat=$lat&dlng=$lng&dname=$name&appname=com.pan.resq';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('네이버지도 앱이 설치되어 있지 않습니다.')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('길찾기 안내', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDisasterInfoSheet() {
    final grouped = <String, List<Disaster>>{};
    for (final d in _disasterList) {
      grouped.putIfAbsent(d.type, () => []).add(d);
    }
    return Container(
      height: 340,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
              SizedBox(width: 6),
              Text('재난정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: grouped.entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                final first = entry.value.first;
                return GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.allDisasters,
                      arguments: {
                        'sido': _sido ?? '',
                        'sigungu': _sigungu ?? '',
                        'eupmyeondong': _eupmyeondong ?? '',
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(first.startTime, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(first.region, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalDetailSheet() {
    if (_selectedHospital == null) return const SizedBox.shrink();
    final hospital = _selectedHospital!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('병원 상세 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_currentAddress != null) ...[
            _infoRow('내 위치', _currentAddress!),
            const SizedBox(height: 6),
          ],
          _infoRow('이름', hospital.name),
          _infoRow('주소', hospital.address),
          _infoRow('거리', '${(hospital.distance * 1000).toStringAsFixed(0)}m'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final lat = hospital.latitude;
              final lng = hospital.longitude;
              final name = Uri.encodeComponent(hospital.name);
              final url = 'nmap://route/public?dlat=$lat&dlng=$lng&dname=$name&appname=com.pan.resq';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('네이버지도 앱이 설치되어 있지 않습니다.')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('길찾기 안내', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
