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

/// 친구요청 모델(공용: incoming/outgoing)
class FriendRequestModel {
  final int id;
  final int requesterId;
  final int addresseeId;
  final String status; // FriendStatus.PENDING / ACCEPTED / REJECTED
  final String requesterUsername;
  final String addresseeUsername;

  FriendRequestModel({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.requesterUsername,
    required this.addresseeUsername,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> j) =>
      FriendRequestModel(
        id: j['id'] as int,
        requesterId: j['requester_id'] as int,
        addresseeId: j['addressee_id'] as int,
        status: j['status'] as String,
        requesterUsername: j['requester_username'] as String,
        addresseeUsername: j['addressee_username'] as String,
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

  // 종 아이콘 배지용(열기 전 간단 캐시)
  int? _incomingCountCache;

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

  /// ------------------------------
  /// 친구요청 API
  /// ------------------------------
  Future<List<FriendRequestModel>> _fetchIncoming() async {
    final res =
    await _api.get('/api/friend/requests/incoming') as List<dynamic>;
    return res
        .map((e) => FriendRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRequestModel>> _fetchOutgoing() async {
    final res =
    await _api.get('/api/friend/requests/outgoing') as List<dynamic>;
    return res
        .map((e) => FriendRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _openRequestsPanel() async {
    try {
      final incoming = await _fetchIncoming();
      setState(() => _incomingCountCache = incoming.length);
    } catch (_) {}

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Row(
                      children: [
                        Text(
                          '친구 요청',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const TabBar(
                    tabs: [
                      Tab(text: '요청받음'),
                      Tab(text: '보낸요청'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _RequestsList(
                          api: _api,
                          kind: RequestListKind.incoming,
                          loader: _fetchIncoming,
                          emptyText: '도착한 친구 요청이 없어요.',
                        ),
                        _RequestsList(
                          api: _api,
                          kind: RequestListKind.outgoing,
                          loader: _fetchOutgoing,
                          emptyText: '보낸 친구 요청이 없어요.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


    @override
    Widget build(BuildContext context) {
      const brand = Color(0xffff0034); // 원하는 색
      final base = Theme.of(context);
      final scheme = base.colorScheme.copyWith(
        primary: brand,
        secondary: brand,
        onPrimary: Colors.white,
      );

      return Theme(
          data: base.copyWith(
            colorScheme: scheme,
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(backgroundColor: brand),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(foregroundColor: brand),
            ),
            tabBarTheme: base.tabBarTheme.copyWith(
              labelColor: brand,
              indicatorColor: brand,
              unselectedLabelColor: Colors.grey,
            ),
          ),child:Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('친구 추가'),
        backgroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '요청 목록',
            onPressed: _openRequestsPanel,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if ((_incomingCountCache ?? 0) > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_incomingCountCache!}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

                  final sending =
                  _sendingUsernames.contains(u.username);
                  final sent = _requestedUsernames.contains(u.username);

                  return ListTile(
                    leading: u.profileImageURL == null
                        ? CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        initial,
                        style:
                        const TextStyle(color: Colors.black87),
                      ),
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
                      onPressed: (sending || sent)
                          ? null
                          : () => _sendRequest(u.username),
                      child: sending
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
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
    ),);
  }
}

/// 목록 종류
enum RequestListKind { incoming, outgoing }

/// 요청 목록 공용 위젯
class _RequestsList extends StatefulWidget {
  const _RequestsList({
    required this.api,
    required this.kind,
    required this.loader,
    required this.emptyText,
  });

  final ApiClient api;
  final RequestListKind kind;
  final Future<List<FriendRequestModel>> Function() loader;
  final String emptyText;

  @override
  State<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<_RequestsList> {
  late Future<List<FriendRequestModel>> _future;
  final Set<int> _acting = {}; // 요청별 진행중 표시

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.loader();
    });
    await _future;
  }

  String _statusLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'friendstatus.pending':
      case 'pending':
        return '취소';
      case 'friendstatus.accepted':
      case 'accepted':
        return '수락됨';
      case 'friendstatus.rejected':
      case 'rejected':
        return '거절됨';
      default:
        return raw;
    }
  }

  Color _statusColor(String s, ThemeData theme) {
    switch (s.toLowerCase()) {
      case 'friendstatus.accepted':
      case 'accepted':
        return Colors.green.shade600;
      case 'friendstatus.rejected':
      case 'rejected':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.primary;
    }
  }

  Future<void> _accept(int id) async {
    await _act(id, '/api/friend/requests/$id/accept', '수락했습니다.');
  }

  Future<void> _reject(int id) async {
    await _act(id, '/api/friend/requests/$id/reject', '거절했습니다.');
  }

  Future<void> _cancel(int id) async {
    await _act(id, '/api/friend/requests/$id/cancel', '요청을 취소했습니다.');
  }

  Future<void> _act(int id, String path, String okMsg) async {
    if (_acting.contains(id)) return;
    setState(() => _acting.add(id));
    try {
      await widget.api.post(path, {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('처리 실패: $e')));
    } finally {
      if (mounted) setState(() => _acting.remove(id));
    }
  }

  Widget _buildTrailing(FriendRequestModel r, ThemeData theme) {
    final pending = r.status.toLowerCase().contains('pending');

    if (widget.kind == RequestListKind.incoming) {
      // 요청받음: 대기중이면 수락/거절 두 버튼
      if (pending) {
        final busy = _acting.contains(r.id);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: busy ? null : () => _reject(r.id),
              child: busy
                  ? const SizedBox(
                  width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('거절'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: busy ? null : () => _accept(r.id),
              child: busy
                  ? const SizedBox(
                  width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('수락'),
            ),
          ],
        );
      }
      // 확정 상태면 상태칩
      return _statusChip(r, theme);
    } else {
      // 보낸요청: 대기중일 때 버튼 한 번 더 누르면 취소
      if (pending) {
        final busy = _acting.contains(r.id);
        return OutlinedButton(
          onPressed: busy ? null : () => _cancel(r.id),
          child: busy
              ? const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('취소'),
        );
      }
      return _statusChip(r, theme);
    }
  }

  Widget _statusChip(FriendRequestModel r, ThemeData theme) {
    final c = _statusColor(r.status, theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c),
      ),
      child: Text(
        _statusLabel(r.status),
        style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<FriendRequestModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('불러오기 실패: ${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return Center(child: Text(widget.emptyText));
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = items[i];
              // incoming: 보낸 사람(requester)을 제목에 표시
              final title = widget.kind == RequestListKind.incoming
                  ? r.requesterUsername
                  : r.addresseeUsername; // outgoing이면 받은 사람 보여주자
              final subtitle = widget.kind == RequestListKind.incoming
                  ? '→ ${r.addresseeUsername}'
                  : '← ${r.requesterUsername}';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    (title.isNotEmpty ? title[0] : '?').toUpperCase(),
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                trailing: _buildTrailing(r, theme),
              );
            },
          );
        },
      ),
    );
  }
}
