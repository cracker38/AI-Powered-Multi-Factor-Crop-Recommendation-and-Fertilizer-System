import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/admin_pending_sensor_farmer.dart';
import '../models/admin_sensor_field_data.dart';
import '../models/farmer_field_data.dart';
import '../models/live_climate.dart';
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
  ApiService({required this.baseUrl, required this.getToken, this.timeout = const Duration(seconds: 25)});

  final String baseUrl;
  final Future<String?> Function() getToken;
  final Duration timeout;

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

  Future<http.Response> _timed(Future<http.Response> request) async {
    try {
      return await request.timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. The API may be running but is slow — wait and tap Retry, or restart scripts/start-api.ps1.',
        statusCode: 503,
      );
    } catch (e) {
      final detail = e.toString().toLowerCase();
      final unreachable = detail.contains('clientexception') ||
          detail.contains('failed to fetch') ||
          detail.contains('connection refused') ||
          detail.contains('failed host lookup') ||
          detail.contains('socketexception');
      if (unreachable) {
        throw ApiException(
          'The API is offline or unreachable. Start scripts/start-api.ps1 on port 8000, then retry.',
          statusCode: 503,
        );
      }
      rethrow;
    }
  }

  Future<http.Response> _get(String path) async =>
      _timed(http.get(_uri(path), headers: await _headers()));

  Future<http.Response> _post(String path, {String? body}) async =>
      _timed(http.post(_uri(path), headers: await _headers(), body: body));

  Future<http.Response> _patch(String path, {String? body}) async =>
      _timed(http.patch(_uri(path), headers: await _headers(), body: body));

  Future<http.Response> _delete(String path) async =>
      _timed(http.delete(_uri(path), headers: await _headers()));

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
    final res = await _post('/api/v1/auth/sync');
    return UserProfile.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<UserProfile> registerFarmer({
    required String displayName,
    required double farmSizeHa,
    String? phone,
    String? district,
    FarmerFieldData? fieldData,
  }) async {
    final res = await _post(
      '/api/v1/auth/register-farmer',
      body: jsonEncode({
        'display_name': displayName,
        'farm_size_ha': farmSizeHa,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (district != null && district.isNotEmpty) 'district': district,
        if (fieldData != null) 'field_data': fieldData.toJson(),
      }),
    );
    return UserProfile.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<UserProfile> submitFieldData(FarmerFieldData fieldData) async {
    final res = await _post(
      '/api/v1/auth/field-data',
      body: jsonEncode({'field_data': fieldData.toJson()}),
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
    final res = await _patch('/api/v1/auth/profile', body: jsonEncode(body));
    return UserProfile.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<UserProfile> fetchMe() async {
    final res = await _get('/api/v1/auth/me');
    return UserProfile.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<CropPrediction> evaluate(FarmInput input) async {
    try {
      final res = await http
          .post(_uri('/api/v1/predictions/evaluate'), headers: await _headers(), body: jsonEncode(input.toJson()))
          .timeout(const Duration(seconds: 45));
      return CropPrediction.fromJson((await _handle(res)) as Map<String, dynamic>);
    } on TimeoutException {
      throw ApiException(
        'Crop analysis timed out. Restart scripts/start-api.ps1, wait for "Application startup complete", then Retry.',
        statusCode: 503,
      );
    }
  }

  Future<List<PredictionHistoryItem>> fetchHistory({int limit = 30}) async {
    final res = await _get('/api/v1/predictions/history?limit=$limit');
    final list = (await _handle(res)) as List<dynamic>;
    return list.map((e) => PredictionHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> fetchPredictionDetail(String id) async {
    final res = await _get('/api/v1/predictions/history/$id');
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchFarmerTips() async {
    final res = await _get('/api/v1/farmer/tips');
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<LiveClimate> fetchLiveClimate({String? district}) async {
    final q = district != null && district.isNotEmpty ? '?district=${Uri.encodeComponent(district)}' : '';
    final res = await _get('/api/v1/farmer/live-climate$q');
    return LiveClimate.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>?> fetchOutcomeFeedback(String predictionId) async {
    final res = await _timed(http.get(
      _uri('/api/v1/farmer/feedback/$predictionId'),
      headers: await _headers(),
    ));
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
    final res = await _post(
      '/api/v1/farmer/feedback',
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
    final res = await _get('/api/v1/admin/users');
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> adminUpdateUser(String id, {bool? disabled, String? displayName}) async {
    final body = <String, dynamic>{};
    if (disabled != null) body['disabled'] = disabled;
    if (displayName != null) body['display_name'] = displayName;
    final res = await _patch('/api/v1/admin/users/$id', body: jsonEncode(body));
    await _handle(res);
  }

  Future<AdminSensorFieldData?> adminFetchSensorFieldData(String id) async {
    final res = await _get('/api/v1/admin/users/$id/sensor-field-data');
    if (res.statusCode == 404) return null;
    return AdminSensorFieldData.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  /// Pending farmer whose ESP8266 has live readings (for approval banner).
  Future<AdminPendingSensorFarmer?> adminFetchPendingSensorFarmer() async {
    final res = await _get('/api/v1/admin/users/pending/sensor-bound');
    if (res.statusCode == 404) return null;
    return AdminPendingSensorFarmer.fromJson((await _handle(res)) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> adminApproveFarmer({
    required String id,
    required String displayName,
    required double farmSizeHa,
    required FarmerFieldData fieldData,
    String? phone,
    String? district,
    String? adminNotes,
  }) async {
    final res = await _post(
      '/api/v1/admin/users/$id/approve',
      body: jsonEncode({
        'display_name': displayName,
        'farm_size_ha': farmSizeHa,
        'field_data': fieldData.toJson(),
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (district != null && district.isNotEmpty) 'district': district,
        if (adminNotes != null && adminNotes.isNotEmpty) 'admin_notes': adminNotes,
      }),
    );
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<void> adminRejectFarmer(String id) async {
    final res = await _post('/api/v1/admin/users/$id/reject');
    await _handle(res);
  }

  Future<void> adminDeleteUser(String id) async {
    final res = await _delete('/api/v1/admin/users/$id');
    await _handle(res);
  }

  Future<List<Map<String, dynamic>>> adminListDatasets() async {
    final res = await _get('/api/v1/admin/datasets');
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
    final res = await _get('/api/v1/admin/analytics');
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetPrediction(String id) async {
    final res = await _get('/api/v1/admin/predictions/$id');
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> adminListPredictions({int limit = 15}) async {
    final res = await _get('/api/v1/admin/predictions?limit=$limit');
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> adminTrainModel() async {
    final res = await _post('/api/v1/admin/model/train');
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
    final streamed = await req.send().timeout(timeout);
    final res = await http.Response.fromStream(streamed);
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<void> adminActivateDataset(String id) async {
    final res = await _post('/api/v1/admin/datasets/$id/activate');
    await _handle(res);
  }

  Future<Map<String, dynamic>> adminGetUser(String id) async {
    final res = await _get('/api/v1/admin/users/$id');
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<void> adminUpdateDataset(String id, String name) async {
    final res = await _patch('/api/v1/admin/datasets/$id', body: jsonEncode({'name': name}));
    await _handle(res);
  }

  Future<void> adminDeleteDataset(String id) async {
    final res = await _delete('/api/v1/admin/datasets/$id');
    await _handle(res);
  }

  Future<List<Map<String, dynamic>>> adminActivityLogs({int limit = 30}) async {
    final res = await _get('/api/v1/admin/activity-logs?limit=$limit');
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminNotifications({int limit = 25}) async {
    final res = await _get('/api/v1/admin/notifications?limit=$limit');
    return ((await _handle(res)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> adminMarkNotificationRead(String id) async {
    final res = await _patch('/api/v1/admin/notifications/$id/read');
    await _handle(res);
  }

  Future<Map<String, dynamic>> adminModelReport() async {
    final res = await _get('/api/v1/admin/model/report');
    return (await _handle(res)) as Map<String, dynamic>;
  }

  Future<String> adminDownloadModelReport() async {
    final res = await _get('/api/v1/admin/model/report/download');
    if (res.statusCode >= 200 && res.statusCode < 300) return res.body;
    throw ApiException(res.body, statusCode: res.statusCode);
  }
}
