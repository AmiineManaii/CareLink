import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get baseUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  Future<Map<String, dynamic>> elderSignupFace({
    required List<double> embedding,
    required Map<String, dynamic> profile,
  }) async {
    final resp = await http
        .post(
      Uri.parse('$baseUrl/elder/signup-face'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'embedding': embedding, 'profile': profile}),
    );
    return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    
       
 

  Future<Map<String, dynamic>> elderSigninFace({
    required List<double> embedding,
  }) async {
    final resp = await http
        .post(
      Uri.parse('$baseUrl/elder/signin-face'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'embedding': embedding}),
    )
        .timeout(const Duration(seconds: 10));
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> elderUpdateProfile({
    required String elderId,
    required Map<String, dynamic> profile,
  }) async {
    final resp = await http
        .post(
      Uri.parse('$baseUrl/elder/update-profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'elderId': elderId, 'profile': profile}),
    )
        .timeout(const Duration(seconds: 10));
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> caregiverSignup({
    required String email,
    required String password,
    required String phone,
    required String gender,
    String? elderCode,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/caregiver/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'phone': phone,
        'gender': gender,
        'elderCode': elderCode,
      }),
    );
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> caregiverSignin({
    required String email,
    required String password,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/caregiver/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
