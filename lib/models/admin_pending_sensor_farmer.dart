import 'farmer_field_data.dart';

class AdminPendingSensorFarmer {
  const AdminPendingSensorFarmer({
    required this.userId,
    required this.email,
    required this.fieldData,
    this.displayName,
    this.district,
    this.deviceId,
    this.source = 'sensor',
    this.updatedAtMs,
  });

  final String userId;
  final String email;
  final String? displayName;
  final String? district;
  final String? deviceId;
  final String source;
  final int? updatedAtMs;
  final FarmerFieldData fieldData;

  String get label => displayName?.trim().isNotEmpty == true ? displayName! : email;

  factory AdminPendingSensorFarmer.fromJson(Map<String, dynamic> json) {
    return AdminPendingSensorFarmer(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      district: json['district'] as String?,
      deviceId: json['device_id'] as String?,
      source: json['source'] as String? ?? 'sensor',
      updatedAtMs: (json['updated_at_ms'] as num?)?.toInt(),
      fieldData: FarmerFieldData.fromJson(json['field_data'] as Map<String, dynamic>),
    );
  }
}
