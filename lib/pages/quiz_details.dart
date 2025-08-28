import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const int kFixedPoint = 10; // ✅ 전부 정답 시 지급되는 고정 포인트

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class QuizDetailsPage extends StatefulWidget {
  final String title;
  final int timeMinutes;

  final String category;
  final String topic;
  final int nQuestions;

  const QuizDetailsPage({
    super.key,
    required this.title,
    required this.timeMinutes,
    required this.category,
    required this.topic,
    required this.nQuestions,
  });

  @override
  State<QuizDetailsPage> createState() => _QuizDetailsPageState();
}

class _QuizDetailsPageState extends State<QuizDetailsPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String baseUrl = 'http://54.253.211.96:8000';

  late final int _totalSeconds;
  late int _secondsLeft;
  Timer? _timer;

  List<QuizQuestion> _questions = [];
  int _index = 0;
  final Map<int, int> _answers = {};
  bool _submitted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.timeMinutes * 60;
    _secondsLeft = _totalSeconds;
    _loadQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    final token = await _storage.read(key: 'accessToken');
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/quiz/generate');
      final body = jsonEncode({
        'category': widget.category,
        'topic': widget.topic,
        'n_questions': widget.nQuestions,
      });

      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: body,
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        List<dynamic> list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['questions'] is List) {
            list = decoded['questions'] as List;
          } else if (decoded['data'] is List) {
            list = decoded['data'] as List;
          } else {
            throw Exception('퀴즈 응답 형식을 인식할 수 없습니다.');
          }
        } else {
          throw Exception('알 수 없는 응답 타입입니다.');
        }

        int letterToIndex(String letter) {
          switch (letter.trim().toUpperCase()) {
            case 'A': return 0;
            case 'B': return 1;
            case 'C': return 2;
            case 'D': return 3;
            default:  return 0;
          }
        }

        final parsed = list.map((q) {
          final choices = (q['choices'] as Map).cast<String, dynamic>();
          final options = <String>[
            choices['A']?.toString() ?? '',
            choices['B']?.toString() ?? '',
            choices['C']?.toString() ?? '',
            choices['D']?.toString() ?? '',
          ];
          final correctIdx = letterToIndex(q['correct_answer']?.toString() ?? 'A');

          return QuizQuestion(
            question: q['question_text']?.toString() ?? '',
            options: options,
            correctIndex: correctIdx,
            explanation: q['explanation']?.toString() ?? '',
          );
        }).toList();

        if (!mounted) return;
        setState(() {
          _questions = parsed;
          _loading = false;
        });
        _startTimer();
      } else if (res.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('세션이 만료되었습니다. 다시 로그인해주세요.')),
          );
          await Future.delayed(const Duration(seconds: 1));
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('퀴즈 불러오기 실패: ${res.statusCode}')),
          );
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('퀴즈 불러오기 오류: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  /// 포인트 적립: 전부 정답일 때만 호출
  Future<String?> _addQuizPoint() async {
    try {
      final token = await _storage.read(key: 'accessToken');
      if (token == null) return null;

      final res = await http.patch(
        Uri.parse('$baseUrl/api/user/add-quiz-point'),
        headers: {
          'Authorization': 'Bearer $token',
          'accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        // 서버가 문자열 반환 → 그대로 안내 + 고정포인트 문구
        return '전부 정답! +${kFixedPoint}P 적립';
      } else {
        return '포인트 적립 실패(${res.statusCode})';
      }
    } catch (e) {
      return '포인트 적립 오류: $e';
    }
  }

  // 타이머
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        _autoSubmit();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _autoSubmit() {
    if (_submitted) return;
    setState(() => _submitted = true);
    _showResultDialog();
  }

  void _submitManually() {
    if (_submitted) return;
    _timer?.cancel();
    setState(() => _submitted = true);
    _showResultDialog();
  }

  int _score() {
    int s = 0;
    for (int i = 0; i < _questions.length; i++) {
      final picked = _answers[i];
      if (picked != null && picked == _questions[i].correctIndex) s++;
    }
    return s;
  }

  String _formatMMSS(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// ✅ 화면 중간에 뜨는 결과 다이얼로그
  Future<void> _showResultDialog() async {
    final score = _score();
    final isPerfect = score == _questions.length;

    String? pointMsg;
    if (isPerfect) {
      pointMsg = await _addQuizPoint();
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('결과', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score / ${_questions.length} 점',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (isPerfect)
                Text(pointMsg ?? '전부 정답! +${kFixedPoint}P 적립',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700))
              else
                const Text(
                  '모든 문제를 맞혀야 포인트를 받을 수 있어요.',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              const Text(
                '제출 후 각 문항 아래에 해설이 표시됩니다.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.pop(context, {'score': score});
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('나가기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _restart();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('다시 풀기'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _restart() {
    setState(() {
      _answers.clear();
      _submitted = false;
      _index = 0;
      _secondsLeft = _totalSeconds;
      _startTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('퀴즈 문제를 불러오지 못했습니다.')),
      );
    }

    final q = _questions[_index];
    final picked = _answers[_index];
    final progress = (_index + 1) / _questions.length;

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
        title: Text(widget.title,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _secondsLeft <= 15 ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatMMSS(_secondsLeft),
                  style: TextStyle(
                    color: _secondsLeft <= 15 ? Colors.red : Colors.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            color: Colors.blue,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('문제 ${_index + 1} / ${_questions.length}',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        for (int i = 0; i < q.options.length; i++)
                          _OptionTile(
                            index: i,
                            text: q.options[i],
                            selected: picked == i,
                            onTap: _submitted ? null : () => setState(() => _answers[_index] = i),
                            reviewMode: _submitted,
                            correct: q.correctIndex == i,
                            chosenWrong: _submitted && picked == i && picked != q.correctIndex,
                          ),
                        if (_submitted) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(child: Text(q.explanation, style: const TextStyle(height: 1.35))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _index == 0 ? null : () => setState(() => _index--),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('이전'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_submitted) {
                          if (_index < _questions.length - 1) setState(() => _index++);
                          else Navigator.pop(context, {'score': _score()});
                          return;
                        }
                        if (_index < _questions.length - 1) {
                          setState(() => _index++);
                        } else {
                          _submitManually();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_submitted
                          ? (_index < _questions.length - 1 ? '다음' : '완료')
                          : (_index < _questions.length - 1 ? '다음' : '제출하기')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final int index;
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  final bool reviewMode;
  final bool correct;
  final bool chosenWrong;

  const _OptionTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.onTap,
    required this.reviewMode,
    required this.correct,
    required this.chosenWrong,
  });

  @override
  Widget build(BuildContext context) {
    Color border = Colors.grey.shade300;
    Color bg = Colors.white;
    Color txt = Colors.black87;
    IconData? icon;

    if (reviewMode) {
      if (correct) {
        border = Colors.green;
        bg = Colors.green.shade50;
        icon = Icons.check_circle;
        txt = Colors.green.shade900;
      } else if (chosenWrong) {
        border = Colors.red;
        bg = Colors.red.shade50;
        icon = Icons.cancel;
        txt = Colors.red.shade900;
      }
    } else if (selected) {
      border = Colors.blue;
      bg = Colors.blue.shade50;
      txt = Colors.blue.shade900;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: reviewMode ? border : (selected ? Colors.blue : Colors.grey.shade400),
                ),
                color: reviewMode
                    ? (correct ? Colors.green : (chosenWrong ? Colors.red : Colors.white))
                    : (selected ? Colors.blue : Colors.white),
              ),
              child: reviewMode
                  ? (icon != null
                  ? Icon(icon, size: 18, color: Colors.white)
                  : Text(_alpha(index),
                  style: TextStyle(
                    color: (correct || chosenWrong) ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  )))
                  : Text(
                _alpha(index),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 16, color: txt)),
            ),
          ],
        ),
      ),
    );
  }

  String _alpha(int i) => String.fromCharCode('A'.codeUnitAt(0) + i);
}
