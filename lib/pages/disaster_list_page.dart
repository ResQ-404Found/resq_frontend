// lib/pages/disaster_list_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'map_page.dart'; // Disaster 재사용
import 'all_disaster_type_detail_page.dart';

class DisasterListPage extends StatefulWidget {
  final String sido;
  final String sigungu;
  final String eupmyeondong;

  const DisasterListPage({
    super.key,
    required this.sido,
    required this.sigungu,
    required this.eupmyeondong,
  });

  /// 라우트에서 args 파싱 헬퍼
  static Widget fromRouteArgs(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    return DisasterListPage(
      sido: (args?['sido'] as String?) ?? '',
      sigungu: (args?['sigungu'] as String?) ?? '',
      eupmyeondong: (args?['eupmyeondong'] as String?) ?? '',
    );
  }

  @override
  State<DisasterListPage> createState() => _DisasterListPageState();
}

class _DisasterListPageState extends State<DisasterListPage> {
  bool _loading = true;
  List<Disaster> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchByRegion();
  }

  Future<void> _fetchByRegion() async {
    try {
      // 1) 파라미터를 조건부로 구성
      final qp = <String, String>{
        if (widget.sido.isNotEmpty) 'sido': widget.sido,
        if (widget.sigungu.isNotEmpty) 'sigungu': widget.sigungu,
        if (widget.eupmyeondong.isNotEmpty) 'eupmyeondong': widget.eupmyeondong,
        'active_only': 'true',
      };

      final uri = Uri(
        scheme: 'http',
        host: '54.253.211.96',
        port: 8000,
        path: '/api/disasters',
        queryParameters: qp,
      );

      // 디버그 로그로 실제 요청 파라미터 확인
      debugPrint('🔎 disasters GET: $uri');

      // 2) 최소 필드 검증(예: 시/군구 없으면 중단)
      if (!qp.containsKey('sido')) {
        setState(() {
          _items = [];
          _loading = false;
          _error = '지역 정보가 없어 목록을 불러올 수 없습니다.';
        });
        return;
      }

      final res = await http.get(uri, headers: {'accept': 'application/json'});
      if (res.statusCode != 200) {
        throw Exception('status ${res.statusCode}');
      }

      final jsonBody = json.decode(utf8.decode(res.bodyBytes));
      final List<dynamic> data = jsonBody['data'][0]['disasters'];

      final list = data.map<Disaster>((e) => Disaster.fromJson(e)).toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '목록을 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final regionLabel =
    '${widget.sido} ${widget.sigungu} ${widget.eupmyeondong}'.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '근처 재난',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 35),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllDisasterTypeDetailPage()),
              );
            },
            child: const Text(
              '전체 재난 보기',
              style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _items.isEmpty
          ? const Center(child: Text('재난 정보가 없습니다.'))
          : ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final d = _items[i];
          return InkWell(
            onTap: () => Navigator.pushNamed(context, '/disaster/detail', arguments: d),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [BoxShadow(color: Color(0xFFFFB8B8), blurRadius: 1)],
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
                        Row(children: [
                          Text(d.type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              d.region,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(d.startTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text(d.info,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
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
    );
  }
}
