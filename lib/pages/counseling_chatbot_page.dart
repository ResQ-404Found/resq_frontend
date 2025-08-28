import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'app_bottom_nav.dart';
import 'chatbot_page.dart';

class CounselingChatbotPage extends StatefulWidget {
  const CounselingChatbotPage({super.key});
  @override
  State<CounselingChatbotPage> createState() => _CounselingChatbotPageState();
}

class _CounselingChatbotPageState extends State<CounselingChatbotPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  bool _loadingHistory = false;
  bool _isTyping = false;
  bool _canSend = false; // ← 입력 여부에 따른 전송 버튼 상태

  static const String baseUrl = 'http://54.253.211.96:8000';
  static const String historyPath = '/api/chatbot/counseling/history';
  static const String chatPath = '/api/chatbot/counseling';

  final List<String> _suggestions = const [
    '불안 진정 호흡법',
    '수면 개선 팁',
    '트라우마 대처',
    '스트레스 해소법',
    '위기 대응 연락처',
    '감정 기록 방법',
    '자기 위로 문장',
    '마음챙김 가이드',
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    // 입력 변화 감지 → 버튼 활성/비활성 토글
    _messageController.addListener(() {
      final can = _messageController.text.trim().isNotEmpty;
      if (can != _canSend) {
        setState(() => _canSend = can);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    setState(() => _loadingHistory = true);
    final token = await _storage.read(key: 'accessToken');

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해주세요.')),
        );
      }
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        // Replace '/login' with your actual login route
        Navigator.pushReplacementNamed(context, '/login');
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
            "message": "안녕하세요, 심리상담 챗봇입니다. 편하게 고민을 남겨주세요.",
          });
          for (final item in ordered) {
            _messages.add({"role": "user", "message": item['user_message']});
            _messages.add({"role": "bot", "message": item['bot_response']});
          }
        });
        _jumpToBottom();
      } else if (response.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('세션이 만료되었습니다. 다시 로그인해주세요.')),
          );
        }
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          // Replace '/login' with your actual login route
          Navigator.pushReplacementNamed(context, '/login');
        }
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
    final message = (preset ?? _messageController.text).trim(); // ← 추가
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
      _canSend = false; // 입력창 비우면 버튼 회색/비활성
    });
    _jumpToBottom();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$chatPath'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"message": message, "mode": "counseling"}),
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
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 파란 헤더(심리)
  PreferredSizeWidget _styledAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(92),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF1E88E5)),
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
                  child: const Icon(Icons.favorite_outline, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '심리 지원 상담',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 4),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatbotPage()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      '재난 상담',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.white, // ← 안 흰색
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E87E3)),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF1E87E3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  // 말풍선(재난과 동일 스타일)
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
            const Text('심리상담 챗봇',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF555555))),
          ],
        ),
        _bubble(text: text, isUser: false),
      ],
    );
  }

  // 타이핑 버블(재난 스타일: 화이트 + 테두리)
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

  @override
  Widget build(BuildContext context) {
    if (_loadingHistory) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _styledAppBar(),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _styledAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) return _typingBubble();
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return isUser ? _bubble(text: msg['message'] ?? '', isUser: true) : _botMessage(msg['message'] ?? '');
              },
            ),
          ),_suggestionBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6E6E6)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                        contentPadding: EdgeInsets.only(left: 8),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _canSend ? _sendMessage() : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: _canSend ? const Color(0xFF1E88E5) : Colors.grey[400], // 파랑 활성 / 회색 비활성
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _canSend ? _sendMessage : null,
                    tooltip: '전송',
                  ),
                ),
              ],
            ),
          ),
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