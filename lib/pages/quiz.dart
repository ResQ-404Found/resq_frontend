import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final List<String> categories = ['전체', '지진', '화재', '태풍', '홍수'];
  String selected = '전체';

  final List<QuizItem> allQuizzes = [
    QuizItem(
      id: 'q1',
      category: '지진',
      title: '지진 발생시 행동요령',
      subtitle: '지진 발생 시 올바른 대처방법을 배워보세요',
      questions: 10,
      minutes: 5,
      difficulty: Difficulty.easy,
      imageUrl: 'https://picsum.photos/400/200?random=1',
      completedScore: 90,
    ),
    QuizItem(
      id: 'q2',
      category: '화재',
      title: '화재 안전 및 대피요령',
      subtitle: '화재 상황에서의 안전한 대피방법',
      questions: 12,
      minutes: 6,
      difficulty: Difficulty.normal,
      imageUrl: 'https://picsum.photos/400/200?random=2',
      completedScore: 85,
    ),
    QuizItem(
      id: 'q3',
      category: '태풍',
      title: '태풍 대비 안전수칙',
      subtitle: '태풍 예보 시 준비사항과 대처법',
      questions: 8,
      minutes: 4,
      difficulty: Difficulty.easy,
      imageUrl: 'https://picsum.photos/400/200?random=3',
      completedScore: null,
    ),
    QuizItem(
      id: 'q4',
      category: '홍수',
      title: '홍수/호우 시 행동수칙',
      subtitle: '침수, 범람 상황에서의 안전 지침',
      questions: 9,
      minutes: 5,
      difficulty: Difficulty.normal,
      imageUrl: 'https://picsum.photos/400/200?random=4',
      completedScore: null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final quizzes = selected == '전체'
        ? allQuizzes
        : allQuizzes.where((q) => q.category == selected).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '재난 퀴즈',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final label = categories[i];
                  final picked = label == selected;
                  return ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: picked ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: picked,
                    onSelected: (_) => setState(() => selected = label),
                    selectedColor: Colors.blue,
                    backgroundColor: Colors.grey.shade200,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: picked ? Colors.blue : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: quizzes.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: QuizCard(item: quizzes[i], onStart: _handleStart),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    return token != null && token.isNotEmpty;
  }

  void _handleStart(QuizItem item) async {
    final isLoggedIn = await _isLoggedIn();

    if (!isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await http.post(
        Uri.parse('http://54.253.211.96:8000/quiz/generate'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(<String, dynamic>{
          'category': item.category,
          'topic': item.title,
          'n_questions': item.questions,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> fetchedQuestions = data['questions'];

        Navigator.pushNamed(
          context,
          '/quiz/start',
          arguments: {
            'id': item.id,
            'title': item.title,
            'minutes': item.minutes,
            'questions': fetchedQuestions,
          },
        );
      } else {
        print('API 호출 실패: ${response.statusCode}');
        _showErrorDialog('퀴즈를 불러오는 데 실패했습니다.');
      }
    } catch (e) {
      print('네트워크 오류 발생: $e');
      _showErrorDialog('네트워크 오류가 발생했습니다. 다시 시도해 주세요.');
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // ✨ 여기 수정: 배경색을 흰색으로 지정
          backgroundColor: Colors.white,
          title: const Text('로그인 필요'),
          content: const Text('퀴즈를 시작하려면 로그인해야 합니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // 에러 다이얼로그도 흰색 배경으로 통일
          title: const Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}

enum Difficulty { easy, normal, hard }

extension DifficultyLabel on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return '쉬움';
      case Difficulty.normal:
        return '보통';
      case Difficulty.hard:
        return '어려움';
    }
  }
}

class QuizItem {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final int questions;
  final int minutes;
  final Difficulty difficulty;
  final String imageUrl;
  final int? completedScore;

  QuizItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.questions,
    required this.minutes,
    required this.difficulty,
    required this.imageUrl,
    this.completedScore,
  });
}

class QuizCard extends StatelessWidget {
  final QuizItem item;
  final void Function(QuizItem) onStart;

  const QuizCard({super.key, required this.item, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final completed = item.completedScore != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (completed)
                    const Positioned(
                      top: 10,
                      left: 10,
                      child: Icon(Icons.check_circle, color: Colors.green, size: 28),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.difficulty.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.category,
                          style: const TextStyle(
                            color: Colors.pink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (completed)
                        Row(
                          children: [
                            const Icon(Icons.emoji_events, size: 18, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              '${item.completedScore}점',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.help_outline, size: 18, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text('${item.questions}문항', style: const TextStyle(color: Colors.black54)),
                      const SizedBox(width: 14),
                      const Icon(Icons.access_time, size: 18, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text('${item.minutes}분', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => onStart(item),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: completed ? Colors.grey.shade200 : Colors.blue,
                        foregroundColor: completed ? Colors.black87 : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        completed ? '다시 도전하기' : '퀴즈 시작하기',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}