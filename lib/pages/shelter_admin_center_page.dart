// shelter_admin_center_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 서버 베이스 URL (끝에 슬래시 X)
const String _apiBase = 'http://54.253.211.96:8000';

void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '대피소 관리센터',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2D6CF6),
        fontFamily: 'Pretendard',
      ),
      home: const ShelterAdminCenterPage(),
    );
  }
}

/// =====================
/// 데이터 모델/클라이언트
/// =====================
class AdminShelter {
  final int id;
  final String source;
  final int hcode;
  final String sigungu;
  final String eupmyeon;
  final String facilityName;
  final String roadAddress;
  final String shelterTypeName;
  final int shelterTypeCode;
  final int assignedPop;
  final int capacityEst;
  final num pElderly;
  final num pChild;
  final num vuln;
  final num recommendScore;
  final int priority;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String priorityGrade;
  final String recommendGrade;

  const AdminShelter({
    required this.id,
    required this.source,
    required this.hcode,
    required this.sigungu,
    required this.eupmyeon,
    required this.facilityName,
    required this.roadAddress,
    required this.shelterTypeName,
    required this.shelterTypeCode,
    required this.assignedPop,
    required this.capacityEst,
    required this.pElderly,
    required this.pChild,
    required this.vuln,
    required this.recommendScore,
    required this.priority,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.priorityGrade,
    required this.recommendGrade,
  });

  factory AdminShelter.fromJson(Map<String, dynamic> j) {
    double _d(dynamic v) =>
        v == null ? 0 : (v is int ? v.toDouble() : (v as num).toDouble());
    int _i(dynamic v) => v == null ? 0 : (v as num).toInt();
    String _s(dynamic v) => v?.toString() ?? '';

    return AdminShelter(
      id: _i(j['id']),
      source: _s(j['source']),
      hcode: _i(j['HCODE']),
      sigungu: _s(j['SIGUNGU']),
      eupmyeon: _s(j['EUPMYEON']),
      facilityName: _s(j['facility_name']),
      roadAddress: _s(j['road_address']),
      shelterTypeName: _s(j['shelter_type_name']),
      shelterTypeCode: _i(j['shelter_type_code']),
      assignedPop: _i(j['assigned_pop']),
      capacityEst: _i(j['capacity_est']),
      pElderly: j['p_elderly'] ?? 0,
      pChild: j['p_child'] ?? 0,
      vuln: j['vuln'] ?? 0,
      recommendScore: (j['recommend_score'] ?? 0),
      priority: _i(j['priority']),
      latitude: _d(j['latitude']),
      longitude: _d(j['longitude']),
      distanceKm: _d(j['distance_km']),
      priorityGrade: _s(j['priority_grade']),
      recommendGrade: _s(j['recommend_grade']),
    );
  }
}

class ShelterApi {
  /// 기본 목록: 서버가 내부 로직으로 정렬/거리 계산. 파라미터는 limit만.
  static Future<List<AdminShelter>> fetchNearby({int limit = 20}) async {
    final uri = Uri.parse('$_apiBase/shelters/csv/admin/nearby')
        .replace(queryParameters: {'limit': '$limit'});

    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
    return _parseList(res.body);
  }

  /// 검색: q 필수, sort_mode 기본 priority
  static Future<List<AdminShelter>> search({
    required String q,
    int limit = 20,
    String sortMode = 'priority',
  }) async {
    final uri = Uri.parse('$_apiBase/shelters/csv/admin/search').replace(
      queryParameters: {
        'q': q,
        'limit': '$limit',
        'sort_mode': sortMode,
      },
    );

    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
    return _parseList(res.body);
  }

  /// 상세
  static Future<AdminShelter> fetchDetail({required int shelterId}) async {
    final uri = Uri.parse('$_apiBase/shelters/csv/admin/$shelterId');
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is Map && data['data'] is Map) {
      return AdminShelter.fromJson(data['data'] as Map<String, dynamic>);
    }
    if (data is Map) {
      return AdminShelter.fromJson(data as Map<String, dynamic>);
    }
    throw Exception('Unexpected detail response');
  }

  static List<AdminShelter> _parseList(String body) {
    final data = jsonDecode(body);
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => AdminShelter.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data
          .map((e) => AdminShelter.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}

/// =====================
/// UI
/// =====================
class ShelterAdminCenterPage extends StatefulWidget {
  const ShelterAdminCenterPage({super.key});

  @override
  State<ShelterAdminCenterPage> createState() => _ShelterAdminCenterPageState();
}

class _ShelterAdminCenterPageState extends State<ShelterAdminCenterPage> {
  int _limit = 20;
  bool _loading = false;
  String? _error;
  List<AdminShelter> _items = [];
  String _sortMode = 'priority';
  // 검색
  final _searchController = TextEditingController();
  String _query = ''; // 현재 검색어

  @override
  void initState() {
    super.initState();
    _loadNearby();
  }
  Future<void> _runSearch() async {
    final q = _searchController.text.trim();
    setState(() { _query = q; _loading = true; _error = null; });
    try {
      final items = q.isEmpty
          ? await ShelterApi.fetchNearby(limit: _limit)
          : await ShelterApi.search(q: q, limit: _limit, sortMode: _sortMode);
      setState(() => _items = items);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _loadNearby() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ShelterApi.fetchNearby(limit: _limit);
      setState(() => _items = items);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  void _changeLimit(int v) {
    if (_limit == v) return;
    setState(() => _limit = v);
    // 현재 검색모드 유지하여 다시 호출
    if (_query.isEmpty) {
      _loadNearby();
    } else {
      _runSearch();
    }
  }

  Future<void> _logout() async {
    // 1) 토큰 삭제
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'accessToken');
    await storage.delete(key: 'refreshToken');

    // (선택) 앱 내 전역 클라이언트/상태 초기화가 필요하다면 여기서 정리
    // HttpClient.clearAuth();  // 예시

    // 2) 로그인 화면으로 스택 싹 교체
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final clock =
        "${now.hourOfPeriod.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          height: 100,
          padding: const EdgeInsets.only(top: 15), // ← 여기서 위쪽 여백 조정
          color: const Color(0xFF1F2A37),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child:// appBar 안 Row 부분만 교체
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 왼쪽: 새로고침 (고정 48x48)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      tooltip: '새로고침',
                      onPressed: () {
                        if (_query.isEmpty) {
                          _loadNearby();
                        } else {
                          _runSearch();
                        }
                      },
                    ),
                  ),

                  // 가운데: 제목
                  const Text(
                    '대피소 관리센터',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),

                  // 오른쪽: 로그아웃 (고정 48x48)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.white70),
                      tooltip: '로그아웃',
                    ),
                  ),
              ],
              ),
            ),
          ),
        ),
      ),


      body: RefreshIndicator(
        onRefresh: () => _query.isEmpty ? _loadNearby() : _runSearch(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // 검색바 (서버 검색 사용)
            _SearchBar(
              controller: _searchController,
              onSubmitted: (_) => _runSearch(),
              onTapSearch: _runSearch,
              onTapClear: () {
                _searchController.clear();
                _query = '';
                _loadNearby();
              },
            ),
            const SizedBox(height: 10),

            _LimitRow(
              limit: _limit,
              onChanged: _changeLimit,
              showSort: _query.isNotEmpty,    // ← 검색했을 때만 정렬 드롭다운 표시
              sortMode: _sortMode,
              onSortChanged: (v) {
                setState(() => _sortMode = v);
                if (_query.isNotEmpty) _runSearch(); // 정렬 바꾸면 재검색
              },
            ),
            const SizedBox(height: 8),

            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: _ErrorBox(message: _error!),
              )
            else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: _EmptyBox(text: '대피소가 없습니다.'),
                )
              else
                ..._items.map(
                      (s) => _ShelterCard.fromAdminShelter(
                    s,
                    onTapDetail: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShelterDetailPage(shelterId: s.id),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// 검색창 위젯
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTapSearch;
  final VoidCallback? onTapClear;

  const _SearchBar({
    required this.controller,
    this.onSubmitted,
    this.onTapSearch,
    this.onTapClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '대피소명으로 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                  onPressed: onTapClear,
                  icon: const Icon(Icons.close_rounded),
                ),
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: onTapSearch,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('검색'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
class _LimitRow extends StatelessWidget {
  final int limit;
  final ValueChanged<int> onChanged;
  final bool showSort;
  final String? sortMode;
  final ValueChanged<String>? onSortChanged;

  const _LimitRow({
    required this.limit,
    required this.onChanged,
    this.showSort = false,
    this.sortMode,
    this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // 검색 안 했을 때는 왼쪽에서 가용폭의 절반만 차지
        if (!showSort) {
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: c.maxWidth * 0.5,
              child: _DropChip<int>(
                text: '개수: $limit',
                value: limit,
                items: const [
                  DropdownMenuItem(value: 10, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('10'))),
                  DropdownMenuItem(value: 20, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('20'))),
                  DropdownMenuItem(value: 30, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('30'))),
                  DropdownMenuItem(value: 50, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('50'))),
                  DropdownMenuItem(value: 100, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('100'))),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          );
        }

        // 검색했을 때는 둘 다 반반
        return Row(
          children: [
            Expanded(
              child: _DropChip<int>(
                text: '개수: $limit',
                value: limit,
                items: const [
                  DropdownMenuItem(value: 10, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('10'))),
                  DropdownMenuItem(value: 20, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('20'))),
                  DropdownMenuItem(value: 30, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('30'))),
                  DropdownMenuItem(value: 50, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('50'))),
                  DropdownMenuItem(value: 100, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('100'))),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SortChip(
                value: (sortMode ?? 'priority'),
                onChanged: (v) {
                  if (v == null) return;
                  onSortChanged?.call(v);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}


class _DropChip<T> extends StatelessWidget {
  final String text; // "개수: 20"
  final List<DropdownMenuItem<T>> items;
  final T value;
  final ValueChanged<T?> onChanged;

  const _DropChip({
    required this.text,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48, // 정렬 드롭다운과 높이 통일
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.keyboard_arrow_down),
          ),
          onChanged: onChanged,
          items: items,
          dropdownColor: Colors.white,                 // 팝업 배경 흰색
          borderRadius: BorderRadius.circular(12),     // 팝업 라운딩
          menuMaxHeight: 300,
          // 닫힌 상태에서 ‘개수: N’만 보이도록 items.length만큼 동일 위젯 반환
          selectedItemBuilder: (context) => List.generate(
            items.length,
                (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _SortChip extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _SortChip({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          onChanged: onChanged,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          menuMaxHeight: 300,
          items: const [
            DropdownMenuItem(value: 'priority',       child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('우선순위', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            )),
            DropdownMenuItem(value: 'priority_grade', child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('등급',     style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            )),
            DropdownMenuItem(value: 'accuracy',       child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('정확도',   style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            )),
          ],
          // 버튼에 보이는 모양도 패딩/정렬 통일
          selectedItemBuilder: (context) => const [
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Align(alignment: Alignment.centerLeft, child: Text('우선순위',   overflow: TextOverflow.ellipsis))),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Align(alignment: Alignment.centerLeft, child: Text('등급',     overflow: TextOverflow.ellipsis))),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Align(alignment: Alignment.centerLeft, child: Text('정확도',   overflow: TextOverflow.ellipsis))),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF991B1B)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String text;
  const _EmptyBox({required this.text});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.search_off, size: 48, color: Colors.black38),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: Color(0xFF000000))),
      ],
    );
  }
}

/// ===============
/// 대피소 카드
/// ===============
class _ShelterCard extends StatelessWidget {
  final Color accentColor;
  final String name;
  final List<_Badge> extraBadges; // 우선등급/취약자
  final String address;
  final String managerLine;
  final String subtitleRight;
  final VoidCallback onTapDetail;

  const _ShelterCard({
    required this.accentColor,
    required this.name,
    required this.extraBadges,
    required this.address,
    required this.managerLine,
    required this.subtitleRight,
    required this.onTapDetail,
    super.key,
  });

  /// API 모델 → 카드 빌더
  static _ShelterCard fromAdminShelter(
      AdminShelter s, {
        required VoidCallback onTapDetail,
      }) {
    // 이름 기본값 처리
    final shelterName =
    (s.facilityName.isEmpty) ? '민방위 대피소' : s.facilityName;

    // 취약자 텍스트 (임계값 0.3)
    String vulnText = '일반';
    if (s.pElderly >= 0.3 && s.pChild >= 0.3) {
      vulnText = '노인·아동 다수';
    } else if (s.pElderly >= 0.3) {
      vulnText = '노인 다수';
    } else if (s.pChild >= 0.3) {
      vulnText = '아동 다수';
    }

    final badges = <_Badge>[
      _Badge.blue('우선 ${s.priorityGrade} (#${s.priority})'),
      _Badge.violet(vulnText),
    ];

    return _ShelterCard(
      accentColor: _accentByType(s.shelterTypeCode),
      name: shelterName,
      extraBadges: badges,
      address: s.roadAddress,
      managerLine: '출처:${s.source} · 행정코드:${s.hcode} · ${s.sigungu}',
      subtitleRight: s.shelterTypeName,
      onTapDetail: onTapDetail,
    );
  }

  static Color _accentByType(int code) {
    switch (code) {
      case 1:
        return const Color(0xFF0EA5E9); // 한파
      case 2:
        return const Color(0xFFF59E0B); // 무더위
      default:
        return const Color(0xFF22C55E); // 민방위 등
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 좌측 포인트 라인
          Positioned(
            left: 0,
            top: 12,
            bottom: 12,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 + 배지
                Row(
                  crossAxisAlignment:  CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          ...extraBadges,
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      subtitleRight,
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(address,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 2),
                Text(managerLine,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
                const SizedBox(height: 12),

                // 버튼: 상세보기만
                // 버튼: 링크 스타일(오른쪽 정렬, 배경/테두리/아이콘 없음)
                Align(
                  alignment: Alignment.centerRight, // 오른쪽 정렬
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: TextButton(
                      onPressed: onTapDetail,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '상세 보기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Badge(this.text, this.bg, this.fg, {super.key});

  const _Badge.violet(this.text, {super.key})
      : bg = const Color(0xFFF1E8FF),
        fg = const Color(0xFF7C3AED);

  const _Badge.blue(this.text, {super.key})
      : bg = const Color(0xFFE8F1FF),
        fg = const Color(0xFF2563EB);

  const _Badge.orange(this.text, {super.key})
      : bg = const Color(0xFFFFF3E6),
        fg = const Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

String _comma(num n) {
  final s = n.toString();
  final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
  return s.replaceAllMapped(reg, (m) => ',');
}

/// =====================
/// 상세 페이지
/// =====================
class ShelterDetailPage extends StatefulWidget {
  final int shelterId;
  const ShelterDetailPage({super.key, required this.shelterId});

  @override
  State<ShelterDetailPage> createState() => _ShelterDetailPageState();
}

class _ShelterDetailPageState extends State<ShelterDetailPage> {
  AdminShelter? _detail;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ShelterApi.fetchDetail(shelterId: widget.shelterId);
      setState(() => _detail = d);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2A37),
        title: const Text('대피소 상세', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 30, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorBox(message: _error!)
          : _detail == null
          ? const _EmptyBox(text: '상세 데이터를 불러올 수 없습니다.')
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _detailHeader(_detail!),
          const SizedBox(height: 12),
          _kv('시설명', _detail!.facilityName.isEmpty ? '민방위 대피소' : _detail!.facilityName),
          _kv('주소', _detail!.roadAddress),
          _kv('유형', _detail!.shelterTypeName),
          _kv('시군구', _detail!.sigungu),
          _kv('행정코드(HCODE)', '${_detail!.hcode}'),
          const Divider(height: 24),
          _kv('우선등급', '${_detail!.priorityGrade} (#${_detail!.priority})'),
          _kv('예상 노인 비율', '${(_detail!.pElderly * 100).toStringAsFixed(1)}%'),
          _kv('예상 아동 비율', '${(_detail!.pChild * 100).toStringAsFixed(1)}%'),
          _kv('대피소 종류', _detail!.source),
        ],
      ),
    );
  }

  Widget _detailHeader(AdminShelter s) {
    // 취약자 텍스트
    String vulnText = '일반';
    if (s.pElderly >= 0.3 && s.pChild >= 0.3) {
      vulnText = '노인·아동 다수';
    } else if (s.pElderly >= 0.3) {
      vulnText = '노인 다수';
    } else if (s.pChild >= 0.3) {
      vulnText = '아동 다수';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.facilityName.isEmpty ? '민방위 대피소' : s.facilityName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge.blue('우선 ${s.priorityGrade} (#${s.priority})'),
              _Badge.violet(vulnText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(k,
                style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
