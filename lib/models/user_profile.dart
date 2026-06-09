import 'farmer_field_data.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.disabled,
    this.phone,
    this.district,
    this.farmSizeHa,
    this.approvalStatus = 'approved',
    this.fieldData,
  });

  final String id;
  final String email;
  final String? displayName;
  final String role;
  final bool disabled;
  final String? phone;
  final String? district;
  final double? farmSizeHa;
  final String approvalStatus;
  final FarmerFieldData? fieldData;

  bool get isAdmin => role == 'admin';
  bool get isFarmer => role == 'farmer';
  bool get isApproved => isAdmin || approvalStatus == 'approved';
  bool get isPending => isFarmer && approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'].toString(),
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      role: json['role'] as String,
      disabled: json['disabled'] as bool? ?? false,
      phone: json['phone'] as String?,
      district: json['district'] as String?,
      farmSizeHa: (json['farm_size_ha'] as num?)?.toDouble(),
      approvalStatus: json['approval_status'] as String? ?? 'approved',
      fieldData: FarmerFieldData.tryParse(json['field_data']),
    );
  }
}
