import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _apiBase = 'http://54.253.211.96:8000';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  late final ApiClient _api;
  late final EmergencyService _svc;

  final _msgCtrl = TextEditingController(text: '긴급 상황입니다. 연락 부탁합니다.');
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
    _api = ApiClient(baseUrl:_apiBase);
    _svc = EmergencyService(_api);
    _fetch();
  }

  @override
  void dispose(){
    _msgCtrl.dispose();
    super.dispose();
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
        message: _msgCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text('비상 연락처'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 상단 긴급 카드
            Card(
              color: const Color(0xFFFFF1F2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFE11D48),
                      child: Text('📍',
                          style:
                          TextStyle(fontSize: 20, color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    Text('긴급 위치 공유',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('버튼을 누르면 비상 연락처에게 현재 위치를 전송합니다',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.black54)),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _msgCtrl,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Switch(
                          value: _includeLocation,
                          onChanged: (v) =>
                              setState(() => _includeLocation = v),
                        ),
                        const SizedBox(width: 8),
                        const Text('위치 포함'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    FilledButton(
                      onPressed: _sending ? null : _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child:
                      Text(_sending ? '전송 중...' : '긴급 상황 - 위치 전송하기'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '비상 연락처 $_emergencyCount명에게 전송됩니다',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFFE11D48)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 연락처 목록
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ListTile(
                    title: Text('연락처 목록'),
                  ),
                  const Divider(height: 1),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child:
                      Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    )
                  else if (_friends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('친구가 없습니다. 먼저 친구를 추가하세요.'),
                      )
                    else
                      ..._friends.map((f) => _FriendRow(
                        item: f,
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

/// 단일 행 위젯
class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.item,
    required this.onToggle,
  });

  final FriendItem item;
  final Future<void> Function(bool next) onToggle;

  @override
  Widget build(BuildContext context) {
    final initials = (item.targetUsername.isNotEmpty
        ? item.targetUsername.substring(0,1).toUpperCase()
        : '?')
        .toString();

    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            child: Text(initials,
                style: const TextStyle(color: Colors.black87)),
          ),
          title: Row(
            children: [
              Text(item.targetUsername,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              if (item.isEmergency)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('비상연락처',
                      style:
                      TextStyle(fontSize: 11, color: Color(0xFFE11D48))),
                ),
            ],
          ),
          subtitle: item.relation == null ? null : Text(item.relation!),
          trailing: OutlinedButton(
            onPressed: () => onToggle(!item.isEmergency),
            style: OutlinedButton.styleFrom(
              foregroundColor: item.isEmergency
                  ? const Color(0xFFE11D48)
                  : Colors.black54,
              side: BorderSide(
                color: item.isEmergency
                    ? const Color(0xFFE11D48)
                    : Colors.grey.shade400,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(item.isEmergency ? '해제' : '지정'),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/* =========================
 * 아래는 네트워크/모델/서비스
 * ========================= */

class ApiClient {
  ApiClient({required this.baseUrl});
  final String baseUrl;

  static const _tokenKey = 'access_token';

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> get(String path) async {
    final res = await http.get(_u(path), headers: await _headers());
    return _decodeOrThrow(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(_u(path),
        headers: await _headers(), body: jsonEncode(body));
    return _decodeOrThrow(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(_u(path),
        headers: await _headers(), body: jsonEncode(body));
    return _decodeOrThrow(res);
  }

  dynamic _decodeOrThrow(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    try {
      final m = jsonDecode(res.body);
      throw Exception(m['detail'] ?? 'HTTP ${res.statusCode}');
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
    targetUsername: (j['target_username'] ?? j['username'] ?? '') as String,
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

  Future<int> sendBroadcast({
    required String message,
    required bool includeLocation,
  }) async {
    final payload = <String, dynamic>{
      'message': message,
      'include_location': includeLocation,
    };

    if (includeLocation) {
      final pos = await _getPositionOrNull();
      if (pos != null) {
        payload['lat'] = double.parse(pos.latitude.toStringAsFixed(6));
        payload['lon'] = double.parse(pos.longitude.toStringAsFixed(6));
      } else {
        payload['include_location'] = false; // 위치 못 가져오면 제외
      }
    }

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
