// lib/pages/friend_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_friend_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _apiBase = 'http://54.253.211.96:8000';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  late final _api = ApiClient(baseUrl: _apiBase);
  late final _svc = EmergencyService(_api);

  String _message = '긴급 상황입니다. 연락 부탁합니다.';
  bool _includeLocation = true;

  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<FriendItem> _friends = [];

  int get _emergencyCount =>
      _friends.where((f) => f.isEmergency == true).length;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.fetchFriends();
      setState(() => _friends = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(FriendItem f, bool next) async {
    try {
      await _svc.toggleEmergency(
        friendUserId: f.id,
        isEmergency: next,
      );
      setState(() {
        _friends = _friends
            .map((x) => x.id == f.id ? x.copyWith(isEmergency: next) : x)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('변경 실패: $e')));
    }
  }

  Future<void> _send() async {
    if (_emergencyCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비상 연락처가 없습니다. 먼저 지정해 주세요.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final id = await _svc.sendBroadcast(
        message: _message.trim(),
        includeLocation: _includeLocation,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('긴급 전송 완료 (ID: $id)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openEditMessage() {
    final ctrl = TextEditingController(text: _message);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2))),
              const Text('보낼 메시지',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 4,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _message = ctrl.text.trim());
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('저장'),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rose = const Color(0xFFE11D48); // 메인 포인트 컬러
    final roseSoft = const Color(0xFFFFE4E6);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text('비상 연락처'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '친구 추가',
            onPressed: () {
              // 위젯으로 바로 이동하는 방식
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFriendPage()),
              );

              // 만약 네임드 라우트를 쓴다면 대신 아래 사용:
              // Navigator.pushNamed(context, '/add-friend');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ===== 상단 긴급 카드 =====
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFECACA)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: rose,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    const Text('긴급 위치 공유',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 6),
                    const Text(
                      '버튼을 누르면 비상 연락처에게 현재 위치를 전송합니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Switch(
                          value: _includeLocation,
                          activeColor: rose,
                          onChanged: (v) =>
                              setState(() => _includeLocation = v),
                        ),
                        const SizedBox(width: 6),
                        const Text('위치 포함', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: rose,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _sending ? '전송 중...' : '긴급 상황 - 위치 전송하기',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '비상 연락처 ${_emergencyCount}명에게 전송됩니다',
                      style:
                      TextStyle(fontSize: 12, color: rose.withOpacity(.9)),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: _openEditMessage,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_rounded,
                                  size: 16, color: Colors.black54),
                              const SizedBox(width: 6),
                              Text(
                                _message,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ===== 연락처 목록 카드 =====
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('연락처 목록',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    subtitle: Text('총 ${_friends.length}명',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    trailing: IconButton(
                      tooltip: '새로고침',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _fetch,
                    ),
                  ),
                  const Divider(height: 1),

                  if (_loading)
                    const Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!,
                          style:
                          const TextStyle(color: Colors.red, fontSize: 13)),
                    )
                  else if (_friends.isEmpty)
                      const Padding(
                        padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        child: Text('친구가 없습니다. 먼저 친구를 추가하세요.',
                            style:
                            TextStyle(fontSize: 13, color: Colors.black54)),
                      )
                    else
                      ..._friends.map((f) => _FriendRowPretty(
                        item: f,
                        rose: rose,
                        roseSoft: roseSoft,
                        onToggle: (next) => _toggle(f, next),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 친구 한 줄 (스크린샷 느낌)
class _FriendRowPretty extends StatelessWidget {
  const _FriendRowPretty({
    required this.item,
    required this.rose,
    required this.roseSoft,
    required this.onToggle,
  });

  final FriendItem item;
  final Color rose;
  final Color roseSoft;
  final Future<void> Function(bool next) onToggle;

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForRelation(item.relation);
    final initials = (item.targetUsername.isNotEmpty
        ? item.targetUsername.characters.first.toUpperCase()
        : '?')
        .toString();

    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: iconData.color.withOpacity(.12),
            child: Icon(iconData.icon, color: iconData.color),
          ),
          title: Row(
            children: [
              Text(item.targetUsername,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(width: 8),
              if (item.isEmergency)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: roseSoft, borderRadius: BorderRadius.circular(6)),
                  child: Text('비상연락처',
                      style: TextStyle(fontSize: 11, color: rose)),
                ),
            ],
          ),
          subtitle:
          item.relation == null ? null : Text(item.relation!, maxLines: 1),
          trailing: IconButton(
            tooltip: item.isEmergency ? '비상 해제' : '비상 지정',
            onPressed: () => onToggle(!item.isEmergency),
            icon: Icon(
              item.isEmergency
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              color: item.isEmergency ? rose : Colors.black26,
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  _RelIcon _iconForRelation(String? rel) {
    if (rel == null) return _RelIcon(Icons.person_rounded, Colors.blue);
    final r = rel.trim();
    if (r.contains('가족') || r.contains('부모') || r.contains('형제') || r.contains('자매')) {
      return _RelIcon(Icons.home_rounded, Colors.redAccent);
    }
    if (r.contains('동료') || r.contains('회사') || r.contains('직장')) {
      return _RelIcon(Icons.work_rounded, Colors.green);
    }
    return _RelIcon(Icons.person_rounded, Colors.blue);
  }
}

class _RelIcon {
  final IconData icon;
  final Color color;
  _RelIcon(this.icon, this.color);
}

/* =========================
 * 아래는 네트워크/모델/서비스
 * ========================= */

// 교체할 ApiClient
class ApiClient {
  ApiClient({required this.baseUrl});
  final String baseUrl;

  static const _storage = FlutterSecureStorage();
  // 로그인/다른 페이지에서 쓸 수 있는 모든 키를 우선순위대로 확인
  static const _tokenKeys = ['accessToken', 'access_token', 'token'];

  Future<String?> _readToken() async {
    // 1) SecureStorage 우선
    for (final k in _tokenKeys) {
      final v = await _storage.read(key: k);
      if (v != null && v.isNotEmpty) return v;
    }
    // 2) SharedPreferences fallback
    final prefs = await SharedPreferences.getInstance();
    for (final k in _tokenKeys) {
      final v = prefs.getString(k);
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _readToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> get(String path) async {
    final res = await http.get(_u(path), headers: await _headers());
    return _decodeOrThrow(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      _u(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decodeOrThrow(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      _u(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decodeOrThrow(res);
  }

  dynamic _decodeOrThrow(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    }
    try {
      final m = jsonDecode(res.body);
      throw Exception(m['detail'] ?? m['message'] ?? 'HTTP ${res.statusCode}');
    } catch (_) {
      throw Exception('HTTP ${res.statusCode}');
    }
  }
}


class FriendItem {
  final int id; // friend user id
  final String targetUsername;
  final String? targetProfileImageURL;
  final bool isEmergency;
  final String? relation;

  FriendItem({
    required this.id,
    required this.targetUsername,
    required this.isEmergency,
    this.targetProfileImageURL,
    this.relation,
  });

  FriendItem copyWith({bool? isEmergency}) => FriendItem(
    id: id,
    targetUsername: targetUsername,
    isEmergency: isEmergency ?? this.isEmergency,
    targetProfileImageURL: targetProfileImageURL,
    relation: relation,
  );

  factory FriendItem.fromJson(Map<String, dynamic> j) => FriendItem(
    id: j['id'] as int,
    targetUsername:
    (j['target_username'] ?? j['username'] ?? '') as String,
    targetProfileImageURL:
    (j['target_profile_imageURL'] ?? j['profile_imageURL']) as String?,
    isEmergency: (j['is_emergency'] ?? false) as bool,
    relation: j['relation'] as String?,
  );
}

class EmergencyService {
  EmergencyService(this.api);
  final ApiClient api;

  Future<List<FriendItem>> fetchFriends() async {
    final data = await api.get('/api/friend') as List<dynamic>;
    return data
        .map((e) => FriendItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleEmergency({
    required int friendUserId,
    required bool isEmergency,
    String? relation,
  }) async {
    await api.patch('/api/friend/$friendUserId/emergency', {
      'is_emergency': isEmergency,
      'relation': relation,
    });
  }

// friend_page.dart 안의 EmergencyService.sendBroadcast 교체
  Future<int> sendBroadcast({
    required String message,
    required bool includeLocation,
  }) async {
    // 기본값 (백엔드가 키를 항상 기대하므로 기본값을 채워둔다)
    double lat = 0;
    double lon = 0;
    String address = '';

    // 위치를 포함하라고 했으면 실제 좌표 시도
    if (includeLocation) {
      final pos = await _getPositionOrNull();
      if (pos != null) {
        lat = double.parse(pos.latitude.toStringAsFixed(6));
        lon = double.parse(pos.longitude.toStringAsFixed(6));
        // 실제 주소 역지오코딩이 필요하면 여기서 address 채우면 됨.
        // 지금은 스펙상 키만 있으면 되니까 빈 문자열 유지 가능.
      }
    }

    final payload = <String, dynamic>{
      'message': message,
      'include_location': includeLocation, // true/false 그대로
      'lat': lat,        // 키 항상 포함
      'lon': lon,        // 키 항상 포함
      'address': address // 키 항상 포함
    };

    final res = await api.post('/api/emergency/broadcasts', payload)
    as Map<String, dynamic>;
    return res['id'] as int;
  }


  Future<Position?> _getPositionOrNull() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) return null;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
  }
}
