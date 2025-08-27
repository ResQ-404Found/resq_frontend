import 'package:flutter/material.dart';
import 'map_page.dart'; // Disaster 정의 그대로 사용 (분리 없음)

class DisasterDetailPage extends StatelessWidget {
  final Disaster? disaster;            // 단일 항목(없어도 됨)
  final List<Disaster> disasters;      // 복수 항목(없어도 됨)
  final String? regionLabel;           // 지역 라벨(없어도 됨)

  const DisasterDetailPage({
    super.key,
    this.disaster,
    this.disasters = const [],
    this.regionLabel,
  });

  /// 라우트 arguments를 안전하게 파싱해 페이지 인스턴스를 만들어주는 헬퍼
  static Widget fromRouteArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    Disaster? single;
    List<Disaster> list = const [];
    String? region;

    if (args is Disaster) {
      single = args;
    } else if (args is List) {
      // List<Disaster>가 넘어오는 경우
      try {
        list = args.cast<Disaster>();
      } catch (_) {}
    } else if (args is Map) {
      // {'disasters': List<Disaster>, 'disaster': Disaster, 'region': String}
      final maybeList = args['disasters'];
      if (maybeList is List) {
        try {
          list = maybeList.cast<Disaster>();
        } catch (_) {}
      }
      final maybeSingle = args['disaster'];
      if (maybeSingle is Disaster) {
        single = maybeSingle;
      }
      final maybeRegion = args['region'];
      if (maybeRegion is String) region = maybeRegion;
    }

    return DisasterDetailPage(
      disaster: single,
      disasters: list,
      regionLabel: region,
    );
  }

  Color _getLevelColor(String level) {
    // 필요 시 레벨별 상세 분기 추가 가능
    return Colors.red.shade700;
  }

  String _getRouteByType(String type) {
    switch (type) {
      case '화재':
        return '/fire';
      case '산사태':
        return '/landslide';
      case '홍수':
        return '/flood';
      case '태풍':
        return '/typhoon';
      case '지진':
        return '/earthquake';
      case '한파':
        return '/coldwave';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 우선순위: `disaster` 단일 -> `disasters.first` -> 없음(null)
    final Disaster? shown = disaster ?? (disasters.isNotEmpty ? disasters.first : null);
    final String titleRegion = regionLabel ?? (shown?.region ?? '현재 지역');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 4,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 35),
          onPressed: () => Navigator.pop(context),
        ),

        title: Text(
          shown != null ? '$titleRegion ${shown.type}' : '$titleRegion 재난 정보',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),

      // ===== 데이터 없음: 빈 상태 UI =====
      body: shown == null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.notifications_off_outlined, size: 42, color: Colors.grey),
            SizedBox(height: 10),
            Text('재난 정보가 없습니다.', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      )

      // ===== 데이터 있음: 상세 화면 =====
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔔 안내 배너
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: _getLevelColor(shown.disasterLevel),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: const [
                  Icon(Icons.notifications_active, size: 36, color: Colors.white),
                  SizedBox(height: 4),
                  Text(
                    '안전안내',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('진행 중', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🕒 발생 시각 카드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCCCC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('발생 시간', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Text(shown.startTime, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 📢 재난 문자 내용
            const Text('재난 문자', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFFFCCCC)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                shown.info,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: 24),

            // 🧯 대처 방법 이동 버튼
            InkWell(
              onTap: () {
                final routeName = _getRouteByType(shown.type);
                if (routeName.isNotEmpty) {
                  Navigator.pushNamed(context, routeName);
                } else {
                  Navigator.pushNamed(context, '/disasterlist');
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFFFCCCC)),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('대처 방법', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Center(
              child: Text(
                '마지막 업데이트: 1시간 전',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
