import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/farm_input.dart';
import '../models/farmer_field_data.dart';
import '../models/crop_prediction.dart';
import '../models/prediction_history_item.dart';
import '../models/user_profile.dart';

/// Mirrors app data to Firestore (visible in Firebase Console).
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _predictions => _db.collection('predictions');

  Future<void> upsertUserProfile(UserProfile profile) async {
    await _users.doc(profile.id).set(
      {
        'email': profile.email,
        'display_name': profile.displayName,
        'role': profile.role,
        'disabled': profile.disabled,
        'approval_status': profile.approvalStatus,
        if (profile.phone != null) 'phone': profile.phone,
        if (profile.district != null) 'district': profile.district,
        if (profile.farmSizeHa != null) 'farm_size_ha': profile.farmSizeHa,
        if (profile.fieldData != null) 'field_data': profile.fieldData!.toJson(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    final snap = await _users.doc(profile.id).get();
    if (!snap.exists || snap.data()?['created_at'] == null) {
      await _users.doc(profile.id).set(
        {'created_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
  }

  Future<void> syncCurrentAuthUser(UserProfile profile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != profile.id) return;
    await upsertUserProfile(profile);
  }

  /// Read `users/{uid}` with the signed-in client's token (no Admin SDK).
  Future<UserProfile?> fetchCurrentUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return UserProfile(
      id: uid,
      email: (data['email'] as String?) ?? FirebaseAuth.instance.currentUser?.email ?? '',
      displayName: data['display_name'] as String?,
      role: (data['role'] as String?) ?? 'farmer',
      disabled: data['disabled'] as bool? ?? false,
      phone: data['phone'] as String?,
      district: data['district'] as String?,
      farmSizeHa: (data['farm_size_ha'] as num?)?.toDouble(),
      approvalStatus: data['approval_status'] as String? ?? 'approved',
      fieldData: FarmerFieldData.tryParse(data['field_data']),
    );
  }

  Future<List<PredictionHistoryItem>> fetchMyPredictionHistory({int limit = 50}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final snaps = await _predictions.where('user_uid', isEqualTo: uid).limit(limit).get();
    final items = snaps.docs.map((doc) {
      final d = doc.data();
      final created = d['created_at'];
      DateTime when = DateTime.now();
      if (created is Timestamp) {
        when = created.toDate();
      }
      return PredictionHistoryItem(
        id: doc.id,
        topCrop: d['top_crop'] as String? ?? '',
        topConfidence: (d['top_confidence'] as num?)?.toDouble() ?? 0,
        createdAt: when,
        soilPh: (d['soil_ph'] as num?)?.toDouble() ?? 0,
        nitrogen: (d['nitrogen'] as num?)?.toDouble() ?? 0,
        soilType: d['soil_type'] as String? ?? 'loam',
        season: d['season'] as String? ?? 'season_a',
        soilHealthScore: (d['soil_health_score'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> savePrediction({
    required String userUid,
    required FarmInput input,
    required CropPrediction result,
    String? predictionId,
  }) async {
    final doc = predictionId != null ? _predictions.doc(predictionId) : _predictions.doc();
    await doc.set({
      'user_uid': userUid,
      'nitrogen': input.nitrogen,
      'phosphorus': input.phosphorus,
      'potassium': input.potassium,
      'soil_moisture': input.soilMoisture,
      'temperature_c': input.temperatureC,
      'humidity_pct': input.humidityPct,
      'soil_ph': input.soilPh,
      'rainfall_mm': input.rainfallMm,
      'soil_type': input.soilType,
      'season': input.season,
      if (input.district != null) 'district': input.district,
      'model_version': result.modelVersion,
      'top_crop': result.topCrop,
      'top_confidence': result.topConfidence,
      'explanation': result.explanation,
      'full_ranking': result.fullRanking.map((r) => {'crop': r.crop, 'confidence': r.confidence}).toList(),
      'soil_health_score': result.soilHealthScore,
      'soil_health_label': result.soilHealthLabel,
      'fertilizers': result.fertilizers
          .map(
            (f) => {
              'name': f.name,
              'type': f.type,
              'application_rate': f.applicationRate,
              'timing': f.timing,
              'purpose': f.purpose,
              'priority': f.priority,
              'npk': f.npk,
            },
          )
          .toList(),
      if (result.nutrientAnalysis != null)
        'nutrient_analysis': {
          'current': result.nutrientAnalysis!.current,
          'optimal': result.nutrientAnalysis!.optimal,
          'gaps_kg_per_ha': result.nutrientAnalysis!.gapsKgPerHa,
          'soil_ph': result.nutrientAnalysis!.soilPh,
          'soil_type': result.nutrientAnalysis!.soilType,
          'season': result.nutrientAnalysis!.season,
          'district': result.nutrientAnalysis!.district,
        },
      'precision_notes': result.precisionNotes,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
