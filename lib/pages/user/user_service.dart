import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserMe {
  final String email;
  final String username;
  final int point;
  final String profileImageURL;
  final String role; // "USER" | "ADMIN" ...

  UserMe({
    required this.email,
    required this.username,
    required this.point,
    required this.profileImageURL,
    required this.role,
  });

  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      point: (json['point'] is int) ? json['point'] as int : 0,
      profileImageURL: json['profile_imageURL'] ?? '',
      role: (json['role'] ?? '').toString(),
    );
  }
}

class UserService {
  static const String _apiBase = 'http://54.253.211.96:8000';
  static const _storage = FlutterSecureStorage();
  static const _tokenKeys = ['accessToken', 'access_token', 'token'];

  static Future<String?> _readToken() async {
    for (final k in _tokenKeys) {
      final v = await _storage.read(key: k);
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// /api/user/me 호출해서 UserMe 반환 (실패/미인증 시 null)
  static Future<UserMe?> fetchMe() async {
    final token = await _readToken();
    if (token == null) return null;

    final uri = Uri.parse('$_apiBase/api/users/me'); // 단수 user
    final res = await http.get(uri, headers: {
      'accept': 'application/json',
      'authorization': 'Bearer $token',
    });

    if (res.statusCode != 200) return null;

    final body = json.decode(utf8.decode(res.bodyBytes));
    final data = (body is Map && body['data'] != null) ? body['data'] : body;
    if (data is! Map) return null;

    return UserMe.fromJson(data as Map<String, dynamic>);
  }
}
