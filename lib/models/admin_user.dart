import '../models/farmer_field_data.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.disabled,
    this.createdAt,
    this.predictionCount = 0,
    this.phone,
    this.district,
    this.farmSizeHa,
    this.approvalStatus = 'approved',
    this.fieldData,
  });

  final String id;
  final String? displayName;
  final String email;
  final String role;
  final bool disabled;
  final DateTime? createdAt;
  final int predictionCount;
  final String? phone;
  final String? district;
  final double? farmSizeHa;
  final String approvalStatus;
  final FarmerFieldData? fieldData;

  bool get isAdmin => role == 'admin';
  bool get isFarmer => role == 'farmer';
  bool get isPending => isFarmer && approvalStatus == 'pending';
  bool get isRejected => isFarmer && approvalStatus == 'rejected';
  bool get isApproved => isAdmin || approvalStatus == 'approved';

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['created_at'];
    if (raw is String) {
      created = DateTime.tryParse(raw);
    }
    return AdminUser(
      id: json['id'].toString(),
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      role: json['role'] as String,
      disabled: json['disabled'] as bool? ?? false,
      createdAt: created,
      predictionCount: json['prediction_count'] as int? ?? 0,
      phone: json['phone'] as String?,
      district: json['district'] as String?,
      farmSizeHa: (json['farm_size_ha'] as num?)?.toDouble(),
      approvalStatus: json['approval_status'] as String? ?? 'approved',
      fieldData: FarmerFieldData.tryParse(json['field_data']),
    );
  }
}
