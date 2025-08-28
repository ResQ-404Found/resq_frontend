import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'quiz_details.dart';

// ✅ 프로젝트 라우트에 맞게 수정하세요 (예: '/login' 또는 AppRoutes.login 등)
const String kLoginRoute = '/login';

class QuizListPage extends StatelessWidget {
  const QuizListPage({super.key});

  List<_QuizItem> get _items => const [
    _QuizItem(
      title: '지진 퀴즈',
      category: '지진',
      topic: '지진 발생 시 행동요령',
      minutes: 5,
      count: 5,
      emoji: '🌎',
      color: Color(0xFF2196F3),
    ),
    _QuizItem(
      title: '화재 퀴즈',
      category: '화재',
      topic: '소화기 사용법',
      minutes: 5,
      count: 5,
      emoji: '🔥',
      color: Color(0xFFF44336),
    ),
    _QuizItem(
      title: '태풍 퀴즈',
      category: '태풍',
      topic: '태풍 대비 안전수칙',
      minutes: 5,
      count: 5,
      emoji: '🌪️',
      color: Color(0xFF9C27B0),
    ),
    _QuizItem(
      title: '홍수 퀴즈',
      category: '홍수',
      topic: '홍수 시 대피 요령',
      minutes: 5,
      count: 5,
      emoji: '🌊',
      color: Color(0xFF4CAF50),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          '퀴즈',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final it = items[i];
          return _QuizCard(item: it);
        },
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final _QuizItem item;
  const _QuizCard({required this.item});

  Future<void> _handleStart(BuildContext context) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'accessToken');

    if (token == null) {
      // 로그인 안 된 경우: 다이얼로그 -> 확인 누르면 로그인 페이지로 이동
      // (요청: "로그인 필요합니다" 뜨고 확인 버튼 클릭 시 이동)
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('로그인 필요'),
            content: const Text('퀴즈를 풀려면 로그인이 필요합니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // 다이얼로그 닫기
                  Navigator.pushNamed(context, kLoginRoute); // 로그인 페이지로 이동
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 로그인된 경우 퀴즈 상세로 이동
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizDetailsPage(
            title: item.title,
            timeMinutes: item.minutes,
            category: item.category,
            topic: item.topic,
            nQuestions: item.count,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: item.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: item.color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${item.category} · ${item.topic}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${item.minutes}분',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.help_outline, color: Colors.white70, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${item.count}문항',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleStart(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: item.color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  '퀴즈 시작하기',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizItem {
  final String title;
  final String category;
  final String topic;
  final int minutes;
  final int count;
  final String emoji;
  final Color color;

  const _QuizItem({
    required this.title,
    required this.category,
    required this.topic,
    required this.minutes,
    required this.count,
    required this.emoji,
    required this.color,
  });
}
