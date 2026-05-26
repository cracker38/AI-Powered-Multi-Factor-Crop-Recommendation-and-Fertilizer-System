import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/crop_prediction.dart';
import '../models/farm_input.dart';
import '../models/prediction_history_item.dart';
import '../models/user_profile.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({required this.baseUrl, required this.getToken});

  final String baseUrl;
  final Future<String?> Function() getToken;

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<Map<String, String>> _headers() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Not authenticated');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<dynamic> _handle(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String msg = res.body;
    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['detail'] != null) {
        msg = j['detail'] is String ? j['detail'] as String : j['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(msg, statusCode: res.statusCode);
  }

  Future<UserProfile> syncProfile() async {
    final res = await http.post(_uri('/api/v1/auth/sync'), headers: await _headers());
    return UserProfile.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<UserProfile> registerFarmer({
    required String displayName,
    String? phone,
    String? district,
  }) async {
    final res = await http.post(
      _uri('/api/v1/auth/register-farmer'),
      headers: await _headers(),
      body: jsonEncode({
        'display_name': displayName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (district != null && district.isNotEmpty) 'district': district,
      }),
    );
    return UserProfile.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<UserProfile> updateFarmerProfile({
    String? displayName,
    String? phone,
    String? district,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (phone != null) body['phone'] = phone;
    if (district != null) body['district'] = district;
    final res = await http.patch(
      _uri('/api/v1/auth/profile'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return UserProfile.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<UserProfile> fetchMe() async {
    final res = await http.get(_uri('/api/v1/auth/me'), headers: await _headers());
    return UserProfile.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<CropPrediction> evaluate(FarmInput input) async {
    final res = await http.post(
      _uri('/api/v1/predictions/evaluate'),
      headers: await _headers(),
      body: jsonEncode(input.toJson()),
    );
    return CropPrediction.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<List<PredictionHistoryItem>> fetchHistory({int limit = 30}) async {
    final res = await http.get(
      _uri('/api/v1/predictions/history?limit=$limit'),
      headers: await _headers(),
    );
    final list = (await _handle(res)) as List<dynamic>;
    return list.map((e) => PredictionHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> fetchPredictionDetail(String id) async {
    final res = await http.get(_uri('/api/v1/predictions/history/$id'), headers: await _headers());
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchFarmerTips() async {
    final res = await http.get(_uri('/api/v1/farmer/tips'), headers: await _headers());
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> fetchOutcomeFeedback(String predictionId) async {
    final res = await http.get(
      _uri('/api/v1/farmer/feedback/$predictionId'),
      headers: await _headers(),
    );
    if (res.statusCode == 404) return null;
    final data = await _handle(res);
    if (data == null || data is! Map<String, dynamic>) return null;
    return data;
  }

  Future<Map<String, dynamic>> submitOutcomeFeedback({
    required String predictionId,
    required int yieldRating,
    String? cropGrown,
    bool followedFertilizer = true,
    String? notes,
  }) async {
    final res = await http.post(
      _uri('/api/v1/farmer/feedback'),
      headers: await _headers(),
      body: jsonEncode({
        'prediction_id': predictionId,
        'yield_rating': yieldRating,
        if (cropGrown != null && cropGrown.isNotEmpty) 'crop_grown': cropGrown,
        'followed_fertilizer': followedFertilizer,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
    return (await _handle(res)) as Map<String, dynamic>;
  }

  // —— Admin ——

  Future<List<Map<String, dynamic>>> adminListUsers() async {
    final res = await http.get(_uri('/api/v1/admin/users'), headers: await _headers());
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> adminUpdateUser(String id, {bool? disabled, String? displayName}) async {
    final body = <String, dynamic>{};
    if (disabled != null) body['disabled'] = disabled;
    if (displayName != null) body['display_name'] = displayName;
    final res = await http.patch(
      _uri('/api/v1/admin/users/$id'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    await _handle(res);
  }

  Future<void> adminDeleteUser(String id) async {
    final res = await http.delete(_uri('/api/v1/admin/users/$id'), headers: await _headers());
    await _handle(res);
  }

  Future<List<Map<String, dynamic>>> adminListDatasets() async {
    final res = await http.get(_uri('/api/v1/admin/datasets'), headers: await _headers());
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Public health probe (no auth). Returns true when API responds OK.
  Future<bool> healthCheck() async {
    try {
      final res = await http.get(_uri('/health')).timeout(const Duration(seconds: 5));
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> adminAnalytics() async {
    final res = await http.get(_uri('/api/v1/admin/analytics'), headers: await _headers());
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetPrediction(String id) async {
    final res = await http.get(_uri('/api/v1/admin/predictions/$id'), headers: await _headers());
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> adminListPredictions({int limit = 15}) async {
    final res = await http.get(
      _uri('/api/v1/admin/predictions?limit=$limit'),
      headers: await _headers(),
    );
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> adminTrainModel() async {
    final res = await http.post(_uri('/api/v1/admin/model/train'), headers: await _headers());
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminUploadDataset({
    required String name,
    required List<int> bytes,
    required String filename,
  }) async {
    final token = await getToken();
    final req = http.MultipartRequest('POST', _uri('/api/v1/admin/datasets/upload'));
    req.headers['Authorization'] = 'Bearer $token';
    req.fields['name'] = name;
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<void> adminActivateDataset(String id) async {
    final res = await http.post(_uri('/api/v1/admin/datasets/$id/activate'), headers: await _headers());
    await _handle(res);
  }

  Future<Map<String, dynamic>> adminGetUser(String id) async {
    final res = await http.get(_uri('/api/v1/admin/users/$id'), headers: await _headers());
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<void> adminUpdateDataset(String id, String name) async {
    final res = await http.patch(
      _uri('/api/v1/admin/datasets/$id'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );
    await _handle(res);
  }

  Future<void> adminDeleteDataset(String id) async {
    final res = await http.delete(_uri('/api/v1/admin/datasets/$id'), headers: await _headers());
    await _handle(res);
  }

  Future<List<Map<String, dynamic>>> adminActivityLogs({int limit = 30}) async {
    final res = await http.get(
      _uri('/api/v1/admin/activity-logs?limit=$limit'),
      headers: await _headers(),
    );
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminNotifications({int limit = 25}) async {
    final res = await http.get(
      _uri('/api/v1/admin/notifications?limit=$limit'),
      headers: await _headers(),
    );
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> adminMarkNotificationRead(String id) async {
    final res = await http.patch(
      _uri('/api/v1/admin/notifications/$id/read'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  Future<Map<String, dynamic>> adminModelReport() async {
    final res = await http.get(_uri('/api/v1/admin/model/report'), headers: await _headers());
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<String> adminDownloadModelReport() async {
    final res = await http.get(
      _uri('/api/v1/admin/model/report/download'),
      headers: await _headers(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return res.body;
    throw ApiException(res.body, statusCode: res.statusCode);
  }
}
