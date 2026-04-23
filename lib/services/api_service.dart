import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
    final resp = await http.post(
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
    //debugPrint('DEBUG ${resp.body} $baseUrl');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> elderUpdateProfile({
    required String elderId,
    required Map<String, dynamic> profile,
    File? image,
  }) async {
    if (image == null) {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/elder/update-profile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'elderId': elderId, 'profile': profile}),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      final uri = Uri.parse('$baseUrl/elder/update-profile-with-image');
      final request = http.MultipartRequest('POST', uri);
      request.fields['elderId'] = elderId;
      request.fields['profile'] = jsonEncode(profile);
      request.files.add(await http.MultipartFile.fromPath('photo', image.path));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
  }

  Future<Map<String, dynamic>> getElderCaregiver(String elderId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/elder/$elderId/caregiver'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load caregiver info');
    }
  }

  Future<Map<String, dynamic>> verifyElderCode(String code) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/elder/verify-code/$code'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      return {'valid': false, 'message': 'Erreur serveur'};
    }
  }

  Future<Map<String, dynamic>> getElderProfile(String elderId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/elder/$elderId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load elder profile');
    }
  }

  Future<Map<String, dynamic>> elderHeartbeat(String elderId) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/elder/$elderId/heartbeat'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to send elder heartbeat');
    }
  }

  Future<Map<String, dynamic>> analyzeImage(
    String base64Image,
    String elderId,
  ) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/ai/analyze-image'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': base64Image, 'elderId': elderId}),
    );
    debugPrint("DEBUG: ${resp.statusCode} ${resp.body}");
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      final errorData = jsonDecode(resp.body);
      debugPrint("DEBUG: $errorData");
      throw Exception(errorData['error'] ?? 'Failed to analyze image');
    }
  }

  Future<Map<String, dynamic>> caregiverSignup({
    required String email,
    required String password,
    required String phone,
    required String gender,
    String? firstName,
    String? lastName,
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
        'firstName': firstName,
        'lastName': lastName,
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

  Future<Map<String, dynamic>> caregiverHeartbeat(String caregiverId) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/caregiver/$caregiverId/heartbeat'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to send caregiver heartbeat');
    }
  }

  Future<Map<String, dynamic>> getCaregiverProfile(String caregiverId) async {
    final resp = await http.get(Uri.parse('$baseUrl/caregiver/$caregiverId'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Failed to load caregiver profile: Status ${resp.statusCode}, Body: ${resp.body}',
      );
    }
  }

  Future<Map<String, dynamic>> updateCaregiverProfile(
    String caregiverId,
    Map<String, dynamic> profileData,
  ) async {
    final resp = await http.put(
      Uri.parse('$baseUrl/caregiver/$caregiverId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(profileData),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update caregiver profile');
    }
  }

  // Alerte générique (utilisée par sos_service.dart)
  Future<void> createAlert({
    required String elderId,
    required String type,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/alerts/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'elderId': elderId,
        'type': type,
        'description': description,
        // Envoi en double (number), pas en string
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      }),
    );
  }

  Future<void> createSosAlert({
    required String elderId,
    required String latitude,
    required String longitude,
  }) async {
    await createAlert(
      elderId: elderId,
      type: 'SOS_BUTTON',
      description: "Bouton SOS pressé par l'utilisateur",
      latitude: double.tryParse(latitude),
      longitude: double.tryParse(longitude),
    );
  }

  Future<List<dynamic>> getCaregiverAlerts(String caregiverId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/alerts/caregiver/$caregiverId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load alerts');
    }
  }

  Future<List<dynamic>> getElderAlerts(String elderId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/alerts/elder/$elderId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load elder alerts');
    }
  }

  Future<void> markAlertAsRead(String alertId) async {
    await http.post(
      Uri.parse('$baseUrl/alerts/$alertId/read'),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // --- Medication Management ---

  Future<List<dynamic>> getMedications(String elderId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/medications/$elderId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load medications');
    }
  }

  Future<void> addMedication(
    Map<String, dynamic> medicationData, {
    File? image,
  }) async {
    final uri = Uri.parse('$baseUrl/medications');
    final request = http.MultipartRequest('POST', uri);
    medicationData.forEach((key, value) {
      if (value != null) {
        if (value is List) {
          request.fields[key] = jsonEncode(value);
        } else {
          request.fields[key] = value.toString();
        }
      }
    });
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', image.path));
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to add medication: ${response.body}');
    }
  }

  Future<void> updateMedication(
    String id,
    Map<String, dynamic> medicationData, {
    File? image,
  }) async {
    final uri = Uri.parse('$baseUrl/medications/$id');
    final request = http.MultipartRequest('PUT', uri);
    medicationData.forEach((key, value) {
      if (value != null) {
        if (value is List) {
          request.fields[key] = jsonEncode(value);
        } else {
          request.fields[key] = value.toString();
        }
      }
    });
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', image.path));
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception('Failed to update medication: ${response.body}');
    }
  }

  Future<void> deleteMedication(String id) async {
    final resp = await http.delete(
      Uri.parse('$baseUrl/medications/$id'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete medication: ${resp.body}');
    }
  }
  Future<void>uploadImage(File image,String elderId,String caregiverId) async{
    final uri=Uri.parse('$baseUrl/medications/upload');
    final request=http.MultipartRequest('POST', uri);
    request.fields['elderId'] = elderId;
    request.fields['caregiverId'] = caregiverId;
    request.files.add(await http.MultipartFile.fromPath('imageSOS', image.path));
    final stream =await request.send();
    final response = await http.Response.fromStream(stream);
    if (response.statusCode != 201) {
      throw Exception('Failed to upload image: ${response.body}');
    }
  }

  Future<void> confirmMedicationTake({
    required String medicationId,
    required String elderId,
    String? scheduledTime,
    String? note,
    File? audioFile,
    String status = 'taken',
  }) async {
    final uri = Uri.parse('$baseUrl/medications/confirm-take');
    final request = http.MultipartRequest('POST', uri);
    request.fields['medicationId'] = medicationId;
    request.fields['elderId'] = elderId;
    request.fields['status'] = status;
    if (scheduledTime != null) request.fields['scheduledTime'] = scheduledTime;
    if (note != null) request.fields['note'] = note;
    if (audioFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFile.path),
      );
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 201) {
      throw Exception('Failed to confirm medication: ${response.body}');
    }
  }

  Future<List<dynamic>> getMedicationHistory(String caregiverId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/medications/history/$caregiverId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load medication history');
    }
  }

  Future<List<dynamic>> getElderMedicationHistoryToday(String elderId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/medications/history/elder/$elderId/today'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load elder today medication history');
    }
  }

  // --- Tasks ---

  Future<Map<String, dynamic>> addTask({
    required String elderId,
    required String title,
    required String description,
    required String time,
    required DateTime date,
    bool reminderEnabled = true,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/tasks/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'elderId': elderId,
        'title': title,
        'description': description,
        'time': time,
        'date': date.toIso8601String(),
        'reminderEnabled': reminderEnabled,
      }),
    );
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getElderTasks(String elderId, {DateTime? date}) async {
    String url = '$baseUrl/tasks/elder/$elderId';
    if (date != null) {
      url += '?date=${date.toIso8601String()}';
    }
    final resp = await http.get(Uri.parse(url));
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['tasks'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateTask(
    String id,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.put(
      Uri.parse('$baseUrl/tasks/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<void> deleteTask(String id) async {
    final resp = await http.delete(Uri.parse('$baseUrl/tasks/$id'));
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete task');
    }
  }

  // --- Contacts ---

  Future<List<dynamic>> getContacts(String elderId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/contacts/elder/$elderId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load contacts');
    }
  }

  Future<void> addContact(
    Map<String, dynamic> contactData, {
    File? image,
  }) async {
    final uri = Uri.parse('$baseUrl/contacts');
    final request = http.MultipartRequest('POST', uri);
    contactData.forEach((key, value) {
      if (value != null) request.fields[key] = value.toString();
    });
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', image.path));
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 201) {
      throw Exception('Failed to add contact: ${response.body}');
    }
  }

  Future<void> deleteContact(String id) async {
    final resp = await http.delete(Uri.parse('$baseUrl/contacts/$id'));
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete contact');
    }
  }
}
