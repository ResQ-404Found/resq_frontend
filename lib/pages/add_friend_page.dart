// add_friend_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서버 베이스 URL (끝에 슬래시 X)
const String _apiBase = 'http://54.253.211.96:8000';

/// --------------------------------------
/// ApiClient: SecureStorage → SharedPrefs 순으로 토큰 조회
/// --------------------------------------
class ApiClient {
  ApiClient({required this.baseUrl});
  final String baseUrl;

  static const _storage = FlutterSecureStorage();
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

  Uri _u(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_u(path, query), headers: await _headers());
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

/// --------------------------------------
/// 모델
/// --------------------------------------
class FoundUser {
  final int id;
  final String username;
  final String? profileImageURL;

  FoundUser({
    required this.id,
    required this.username,
    this.profileImageURL,
  });

  factory FoundUser.fromJson(Map<String, dynamic> j) => FoundUser(
    id: j['id'] as int,
    username: j['username'] as String,
    profileImageURL: j['profile_imageURL'] as String?,
  );
}

/// --------------------------------------
/// 페이지
/// --------------------------------------
class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  late final ApiClient _api;
  final _q = TextEditingController();

  bool _loading = false;
  String? _error;
  List<FoundUser> _results = [];

  // 요청 전송 상태(중복 전송 방지 및 버튼 라벨 변경)
  final Set<String> _requestedUsernames = {};
  final Set<String> _sendingUsernames = {};

  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: _apiBase);
  }

  Future<void> _search() async {
    final keyword = _q.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get(
        '/api/friend/search',
        query: {'username': keyword},
      ) as List<dynamic>;
      setState(() {
        _results = data
            .map((e) => FoundUser.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest(String username) async {
    if (_requestedUsernames.contains(username) ||
        _sendingUsernames.contains(username)) {
      return;
    }
    setState(() => _sendingUsernames.add(username));
    try {
      // 핵심: /api/friend/requests 로 전송
      await _api.post('/api/friend/requests', {'username': username});
      if (!mounted) return;
      setState(() {
        _requestedUsernames.add(username);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('친구 요청을 보냈습니다: $username')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요청 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingUsernames.remove(username));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 추가'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    decoration: InputDecoration(
                      hintText: '닉네임으로 검색',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: const Text('검색'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = _results[i];
                  final initial = u.username.isNotEmpty
                      ? u.username[0].toUpperCase()
                      : '?';

                  final sending = _sendingUsernames.contains(u.username);
                  final sent = _requestedUsernames.contains(u.username);

                  return ListTile(
                    leading: u.profileImageURL == null
                        ? CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Text(initial,
                          style: const TextStyle(
                              color: Colors.black87)),
                    )
                        : CircleAvatar(
                      backgroundImage:
                      NetworkImage(u.profileImageURL!),
                    ),
                    title: Text(
                      u.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: OutlinedButton(
                      onPressed:
                      (sending || sent) ? null : () => _sendRequest(u.username),
                      child: sending
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Text(sent ? '보냄' : '요청 보내기'),
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
