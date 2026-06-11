import 'farmer_field_data.dart';

class AdminSensorFieldData {
  const AdminSensorFieldData({
    required this.rawFieldData,
    this.source = 'sensor',
    this.deviceId,
    this.userUid,
    this.updatedAtMs,
  });

  final Map<String, dynamic> rawFieldData;
  final String source;
  final String? deviceId;
  final String? userUid;
  final int? updatedAtMs;

  FarmerFieldData get fieldData => FarmerFieldData.fromJson(rawFieldData);

  double? get ecUsCm => (rawFieldData['ec_us_cm'] as num?)?.toDouble();

  factory AdminSensorFieldData.fromJson(Map<String, dynamic> json) {
    return AdminSensorFieldData(
      rawFieldData: Map<String, dynamic>.from(json['field_data'] as Map<String, dynamic>),
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
