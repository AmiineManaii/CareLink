import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class InMemoryFaceStorage {
  static final InMemoryFaceStorage _instance = InMemoryFaceStorage._internal();

  factory InMemoryFaceStorage() {
    return _instance;
  }

  InMemoryFaceStorage._internal();

  List<double>? _registeredEmbedding;
  String? _role;
  String? _elderId;
  String? _elderCode;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('face_embedding');
    if (data != null) {
      final list = (jsonDecode(data) as List)
          .map((e) => (e as num).toDouble())
          .toList();
      _registeredEmbedding = list;
    }
    _role = prefs.getString('role');
    _elderId = prefs.getString('elder_id');
    _elderCode = prefs.getString('elder_code');
  }

  Future<void> saveEmbedding(List<double> embedding) async {
    _registeredEmbedding = embedding;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('face_embedding', jsonEncode(embedding));
  }

  List<double>? getEmbedding() {
    return _registeredEmbedding;
  }

  bool hasRegisteredFace() {
    return _registeredEmbedding != null;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('logged_in') ?? false;
  }

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logged_in', value);
  }

  String? getRole() {
    return _role;
  }

  Future<void> setRole(String role) async {
    _role = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role);
  }

  String? getElderId() {
    return _elderId;
  }

  Future<void> setElderId(String id) async {
    _elderId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('elder_id', id);
  }

  String? getElderCode() {
    return _elderCode;
  }

  Future<void> setElderCode(String code) async {
    _elderCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('elder_code', code);
  }

  Future<void> clearEmbedding() async {
    _registeredEmbedding = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('face_embedding');
  }

  Future<void> clearAll() async {
    _registeredEmbedding = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('face_embedding');
    await prefs.remove('logged_in');
    await prefs.remove('role');
    await prefs.remove('elder_id');
    await prefs.remove('elder_code');
  }
}
