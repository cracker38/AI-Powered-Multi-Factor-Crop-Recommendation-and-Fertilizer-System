import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/crop_prediction.dart';
import '../models/farm_input.dart';
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
        if (profile.phone != null) 'phone': profile.phone,
        if (profile.district != null) 'district': profile.district,
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
    );
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
