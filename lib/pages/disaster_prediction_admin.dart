import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:resq_frontend/routes.dart';

class DisasterPredictionPage extends StatefulWidget {
  const DisasterPredictionPage({super.key});

  @override
  State<DisasterPredictionPage> createState() => _DisasterPredictionPageState();
}

class _DisasterPredictionPageState extends State<DisasterPredictionPage> {
  int _selectedIndex = 0;

  // ✅ 재난 종류 목록
  final disasterTypes = [
    {'title': '화재', 'icon': Icons.local_fire_department_rounded, 'color': Colors.red},
    {'title': '산사태', 'icon': Icons.terrain_rounded, 'color': Colors.brown},
    {'title': '홍수', 'icon': Icons.flood_rounded, 'color': Colors.blue},
    {'title': '태풍', 'icon': Icons.air_rounded, 'color': Colors.teal},
    {'title': '지진', 'icon': Icons.warning_amber_rounded, 'color': Colors.orange},
    {'title': '한파', 'icon': Icons.ac_unit_rounded, 'color': Colors.indigo},
  ];

  // ✅ 재난별 샘플 데이터 (나중에 API 연동 가능)
  final Map<int, List<Map<String, String>>> disasterShelters = {
    0: [
      {"name": "화재 대피소 A", "tag": "우선 A (#111111)"},
      {"name": "화재 대피소 B", "tag": "우선 B (#222222)"},
    ],
    1: [
      {"name": "산사태 대피소 A", "tag": "우선 A (#333333)"},
      {"name": "산사태 대피소 B", "tag": "우선 C (#444444)"},
    ],
    2: [
      {"name": "홍수 대피소 A", "tag": "우선 B (#555555)"},
      {"name": "홍수 대피소 B", "tag": "우선 A (#666666)"},
    ],
    3: [
      {"name": "태풍 대피소 A", "tag": "우선 A (#777777)"},
    ],
    4: [
      {"name": "지진 대피소 A", "tag": "우선 C (#888888)"},
    ],
    5: [
      {"name": "한파 대피소 A", "tag": "우선 B (#999999)"},
    ],
  };

  // ✅ 새로고침
  void _reloadData() {
    setState(() {
      disasterShelters[_selectedIndex] = [
        {"name": "새로 갱신된 대피소", "tag": "우선 A (#123456)"}
      ];
    });
  }

  // ✅ 로그아웃
  Future<void> _logout() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'accessToken');
    await storage.delete(key: 'refreshToken');

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = disasterTypes[_selectedIndex]['color'] as Color;
    final shelters = disasterShelters[_selectedIndex] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          height: 100,
          padding: const EdgeInsets.only(top: 15),
          color: const Color(0xFF1F2A37),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 새로고침
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      tooltip: '새로고침',
                      onPressed: _reloadData,
                    ),
                  ),

                  const Text(
                    '재난 예측',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),

                  // 로그아웃
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                      icon: const Icon(Icons.logout, color: Colors.white70),
                      tooltip: '로그아웃',
                      onPressed: _logout, // ✅ 연결
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // ✅ BottomAppBar 동일
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 4,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.night_shelter, color: Color(0xFF2563EB)),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.shelterAdminCenter);
              },
            ),
            IconButton(
              icon: const Icon(Icons.dangerous, color: Color(0xFF2563EB)),
              onPressed: () {},
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: List.generate(disasterTypes.length, (index) {
                final type = disasterTypes[index];
                final selected = index == _selectedIndex;

                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? (type['color'] as Color).withOpacity(0.15)
                          : Colors.white,
                      border: Border.all(
                        color: selected ? type['color'] as Color : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(type['icon'] as IconData,
                            size: 18, color: type['color'] as Color),
                        const SizedBox(width: 4),
                        Text(
                          type['title'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // ✅ 리스트뷰
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: shelters.length,
              itemBuilder: (context, index) {
                final shelter = shelters[index];
                return _ShelterCard(
                  name: shelter["name"] ?? "",
                  tag: shelter["tag"] ?? "",
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ 대피소 카드 (name + tag 1개만)
class _ShelterCard extends StatelessWidget {
  final String name;
  final String tag;

  const _ShelterCard({
    required this.name,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tag.contains("우선")
                        ? const Color(0xFFE8F1FF)
                        : const Color(0xFFF1E8FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tag.contains("우선")
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF7C3AED),
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
