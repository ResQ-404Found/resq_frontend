// lib/services/emergency_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'emergency_models.dart';

// 너의 베이스 URL에 맞춰서
const String _apiBase = 'http://54.253.211.96:8000';

typedef AccessTokenProvider = Future<String?> Function();

class EmergencyApi {
  final AccessTokenProvider getAccessToken;
  EmergencyApi({required this.getAccessToken});

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<List<EmergencyContact>> listContacts() async {
    final token = await getAccessToken();
    final res = await http.get(
      Uri.parse('$_apiBase/emergency/contacts'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) {
      throw Exception('contacts 오류 ${res.statusCode} ${res.body}');
    }
    final List data = jsonDecode(res.body) as List;
    return data.map((e) => EmergencyContact.fromJson(e)).toList();
  }

  Future<int> sendBroadcast(EmergencyBroadcastCreate payload) async {
    final token = await getAccessToken();
    final res = await http.post(
      Uri.parse('$_apiBase/emergency/broadcasts'),
      headers: _headers(token),
      body: jsonEncode(payload.toJson()),
    );
    if (res.statusCode != 201) {
      throw Exception('broadcast 오류 ${res.statusCode} ${res.body}');
    }
    final Map<String, dynamic> j = jsonDecode(res.body);
    // 백엔드가 EmergencyBroadcast 반환 → id 포함
    return (j['id'] as num).toInt();
  }
}
