import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> addPoint() async {
  try {
    final response = await http.patch(
      Uri.parse('http://54.253.211.96:8000/user/add-quiz-point'),
      headers: <String, String>{
        'Authorization': 'Bearer {accessToken}',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      print('포인트가 성공적으로 추가되었습니다: ${data['total_points']}');
    } else {
      print('포인트 추가 실패: ${response.statusCode}');
    }
  } catch (e) {
    print('네트워크 오류로 포인트 추가 실패: $e');
  }
}