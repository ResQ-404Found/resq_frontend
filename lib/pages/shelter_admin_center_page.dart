// shelter_admin_center_page.dart
import 'package:flutter/material.dart';

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
        fontFamily: 'Pretendard', // 없어도 동작
      ),
      home: const ShelterAdminCenterPage(),
    );
  }
}

class ShelterAdminCenterPage extends StatelessWidget {
  const ShelterAdminCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    String clock =
        "${now.hourOfPeriod.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: Container(
          padding: const EdgeInsets.only(top: 26),
          decoration: const BoxDecoration(
            color: Color(0xFF1F2A37),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: SafeArea(
            bottom: false,
            child: ListTile(
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white),
              ),
              title: const Text(
                '대피소 관리센터',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              subtitle: const Text(
                '실시간 모니터링 및 관리',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, color: Colors.white70),
                  const SizedBox(height: 4),
                  Text(clock,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _SearchBar(),
          const SizedBox(height: 10),
          const _FilterRow(),
          const SizedBox(height: 8),
          _ShelterCard(
            accentColor: const Color(0xFF22C55E),
            name: '서울시청 대피소',
            statusBadge: _Badge.blue('운영중'),
            extraBadges: const [
              _Badge.violet('취약자지원'),
            ],
            address: '서울특별시 중구 세종대로 110',
            managerLine: '담당자: 김관리 | 직원: 15명 (의료: 3명)',
            capacityNow: 1200,
            capacityMax: 5000,
            capacityDelta: 150,
            lastReport: '10분전',
            rate: 0.24,
            facilityChips: const ['의료시설', '급식시설', '화장실', '샤워시설'],
          ),
          _ShelterCard(
            accentColor: const Color(0xFF10B981),
            name: '부산시민회관 대피소',
            statusBadge: _Badge.orange('거의만석'),
            extraBadges: const [
              _Badge.violet('취약자지원'),
            ],
            address: '부산광역시 중구 대청로 120',
            managerLine: '담당자: 이담당 | 직원: 22명 (의료: 8명)',
            capacityNow: 2850,
            capacityMax: 3000,
            capacityDelta: 50,
            lastReport: '5분전',
            rate: 0.95,
            facilityChips: const ['휠체어접근', '의료진상주', '급식시설', '응급실'],
          ),
        ],
      ),
    );
  }
}

/// 검색창
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: '대피소명 또는 주소로 검색',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

/// 필터 셀
class _FilterRow extends StatelessWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _FilterChip(text: '전체'),
        SizedBox(width: 8),
        _FilterChip(text: '전체 상태'),
        SizedBox(width: 8),
        _FilterChip(text: '전체 유형'),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String text;
  const _FilterChip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(text, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// 대피소 카드
class _ShelterCard extends StatelessWidget {
  final Color accentColor;
  final String name;
  final _Badge statusBadge;
  final List<_Badge> extraBadges;
  final String address;
  final String managerLine;
  final int capacityNow;
  final int capacityMax;
  final int capacityDelta;
  final String lastReport;
  final double rate; // 0.0 ~ 1.0
  final List<String> facilityChips;

  const _ShelterCard({
    required this.accentColor,
    required this.name,
    required this.statusBadge,
    required this.extraBadges,
    required this.address,
    required this.managerLine,
    required this.capacityNow,
    required this.capacityMax,
    required this.capacityDelta,
    required this.lastReport,
    required this.rate,
    required this.facilityChips,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final dangerColor = rate >= .9
        ? const Color(0xFFEF4444)
        : rate >= .7
        ? const Color(0xFFF59E0B)
        : const Color(0xFF22C55E);

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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          statusBadge,
                        ],
                      ),
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

                // 수용 현황 헤더
                Row(
                  children: [
                    const Text('수용 현황',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    Text(
                      '${_comma(capacityNow)} / ${_comma(capacityMax)}명',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+$capacityDelta',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 프로그레스 바
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 10,
                    child: Stack(
                      children: [
                        Container(color: const Color(0xFFF3F4F6)),
                        FractionallySizedBox(
                          widthFactor: rate.clamp(0, 1),
                          child: Container(color: dangerColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 수용률 / 최종보고
                Row(
                  children: [
                    const Icon(Icons.show_chart,
                        size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Text('수용률: ${(rate * 100).round()}%',
                        style: const TextStyle(color: Color(0xFF4B5563))),
                    const Spacer(),
                    const Icon(Icons.access_time,
                        size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Text('최종보고: $lastReport',
                        style: const TextStyle(color: Color(0xFF4B5563))),
                  ],
                ),
                const SizedBox(height: 10),

                // 시설 태그
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                  facilityChips.map((t) => _TagChip(text: t)).toList(),
                ),
                const SizedBox(height: 14),

                // 버튼들
                Row(
                  children: [
                    _ghostButton(
                      icon: Icons.visibility_outlined,
                      label: '상세보기',
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _fillButton(
                      icon: Icons.admin_panel_settings_outlined,
                      label: '관리',
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _ghostButton(
                      icon: Icons.settings_outlined,
                      label: '설정',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fillButton(
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) {
    return Expanded(
      child: SizedBox(
        height: 42,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _ghostButton(
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) {
    return Expanded(
      child: SizedBox(
        height: 42,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  const _TagChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Badge(this.text, this.bg, this.fg, {super.key});

  const _Badge.violet(this.text,
      {super.key})
      : bg = const Color(0xFFF1E8FF),
        fg = const Color(0xFF7C3AED);

  const _Badge.blue(this.text,
      {super.key})
      : bg = const Color(0xFFE8F1FF),
        fg = const Color(0xFF2563EB);

  const _Badge.orange(this.text,
      {super.key})
      : bg = const Color(0xFFFFF3E6),
        fg = const Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

String _comma(num n) {
  final s = n.toString();
  final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
  return s.replaceAllMapped(reg, (m) => ',');
}
