import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'app_bottom_nav.dart';
import 'counseling_chatbot_page.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});
  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _canSend = false;
  bool _loadingHistory = false;
  bool _isTyping = false;

  static const String baseUrl = 'http://54.253.211.96:8000';
  static const String historyPath = '/api/chatbot/disaster/history';
  static const String chatPath = '/api/chatbot/disaster';

  // 하단 추천 칩 (스샷처럼)
  final List<String> _suggestions = const [
    '지진 대응법',
    '화재 대응법',
    '침수 대응법',
    '태풍 대비 요령',
    '응급 처치',
    '대피 요령',
    '가족 연락 방법',
    '비상 물품 목록'
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();

    _messageController.addListener(() {
      final can = _messageController.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
  }


  Future<void> _loadChatHistory() async {
    setState(() => _loadingHistory = true);
    final token = await _storage.read(key: 'accessToken');
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
      }
      if (mounted) setState(() => _loadingHistory = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl$historyPath'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> history = jsonDecode(response.body);
        final ordered = history.reversed.toList();
        if (!mounted) return;
        setState(() {
          _messages.add({
            "role": "bot",
            "message": "안녕하세요! 재난 대응 전문가 챗봇입니다. 궁금하신 내용이 있으면 언제든지 질문해주세요."
          });
          for (final item in ordered) {
            _messages.add({"role": "user", "message": item['user_message']});
            _messages.add({"role": "bot", "message": item['bot_response']});
          }
        });
        _jumpToBottom();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('기록 불러오기 실패: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅 기록 불러오기 오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<String?> _getAccessToken() async => _storage.read(key: 'accessToken');

  Future<void> _sendMessage([String? preset]) async {
    final message = (preset ?? _messageController.text).trim();
    if (message.isEmpty) return;

    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
      }
      return;
    }

    setState(() {
      _messages.add({"role": "user", "message": message});
      _messageController.clear();
      _isTyping = true;
      _canSend = false;
    });
    _jumpToBottom();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$chatPath'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"message": message, "mode": "channel"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botResponse = data['response'] ?? '답변을 가져오지 못했습니다.';
        setState(() {
          _messages.add({"role": "bot", "message": botResponse});
          _isTyping = false;
        });
      } else {
        setState(() {
          _messages.add({"role": "bot", "message": "오류 발생: ${response.statusCode}"});
          _isTyping = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({"role": "bot", "message": "네트워크 오류: $e"});
        _isTyping = false;
      });
    }
    _jumpToBottom();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 140,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─────────── 상단바: 스샷의 빨간 헤더 ───────────
  PreferredSizeWidget _disasterAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(92),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFFE53935)),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 92,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 35,color:Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),

                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '재난 대응 상담',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 4),
                    ],
                  ),
                ),
                // 우측 스위치 칩 → 심리상담 화면으로
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const CounselingChatbotPage()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text('심리 상담',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────── 말풍선 ───────────
  Widget _bubble({required String text, required bool isUser}) {
    final Color userBg = const Color(0xFFF1F5F9); // 밝은 회색
    final Color botBg = Colors.white;
    final BorderRadius userRadius = const BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
    );
    final BorderRadius botRadius = const BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: isUser
            ? const EdgeInsets.fromLTRB(80, 12, 16, 6)
            : const EdgeInsets.fromLTRB(16, 12, 80, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? userBg : botBg,
          borderRadius: isUser ? userRadius : botRadius,
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15.0, height: 1.35, color: Color(0xFF333333)),
        ),
      ),
    );
  }

  Widget _botMessage(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 16),
            const CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('lib/asset/chatbot_profile.png'),
              backgroundColor: Colors.white,
            ),
            const SizedBox(width: 8),
            const Text('재난 전문 챗봇',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
          ],
        ),
        _bubble(text: text, isUser: false),
      ],
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 80, 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: const _AnimatedDots(),
      ),
    );
  }

  // ─────────── 하단 입력 + 추천칩 ───────────
  Widget _suggestionBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = _suggestions[i];
          return InkWell(
            onTap: () => _sendMessage(label),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 5,),
              decoration: BoxDecoration(
                color: Colors.white, // ← 안 흰색
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE53935)), // ← 빨강 테두리
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFE53935), // ← 글자 빨강
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE6E6E6)),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                  contentPadding: EdgeInsets.only(left: 6, bottom: 12, top: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: _canSend ? const Color(0xFFE53935) : Colors.grey[400], // 빈칸=회색, 입력 있음=빨강
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _canSend ? _sendMessage : null, // 빈칸이면 비활성화
              tooltip: '전송',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingHistory) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _disasterAppBar(),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _disasterAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _typingBubble();
                }
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return isUser
                    ? _bubble(text: msg['message'] ?? '', isUser: true)
                    : _botMessage(msg['message'] ?? '');
              },
            ),
          ),
          _suggestionBar(),
          _inputBar(),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _a1;
  late final Animation<double> _a2;
  late final Animation<double> _a3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _a1 = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6));
    _a2 = CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8));
    _a3 = CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(Animation<double> a) {
    return FadeTransition(
      opacity: a,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 3),
        child: CircleAvatar(radius: 4.5, backgroundColor: Color(0xFFB16C7A)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [_dot(_a1), _dot(_a2), _dot(_a3)]);
  }
}
