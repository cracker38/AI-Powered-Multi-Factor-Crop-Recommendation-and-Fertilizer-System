import 'farmer_field_data.dart';

class AdminSensorFieldData {
  const AdminSensorFieldData({
    required this.fieldData,
    this.source = 'sensor',
    this.deviceId,
    this.userUid,
    this.updatedAtMs,
  });

  final FarmerFieldData fieldData;
  final String source;
  final String? deviceId;
  final String? userUid;
  final int? updatedAtMs;

  factory AdminSensorFieldData.fromJson(Map<String, dynamic> json) {
    return AdminSensorFieldData(
      fieldData: FarmerFieldData.fromJson(json['field_data'] as Map<String, dynamic>),
      source: json['source'] as String? ?? 'sensor',
      deviceId: json['device_id'] as String?,
      userUid: json['user_uid'] as String?,
      updatedAtMs: (json['updated_at_ms'] as num?)?.toInt(),
    );
  }

  String get summaryLabel {
    final parts = <String>[];
    if (deviceId != null && deviceId!.isNotEmpty) parts.add(deviceId!);
    if (source.isNotEmpty) parts.add(source);
    return parts.isEmpty ? 'ESP8266 sensor' : parts.join(' · ');
  }
}
