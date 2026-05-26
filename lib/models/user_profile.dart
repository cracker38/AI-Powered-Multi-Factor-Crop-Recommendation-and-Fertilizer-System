class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.disabled,
    this.phone,
    this.district,
  });

  final String id;
  final String email;
  final String? displayName;
  final String role;
  final bool disabled;
  final String? phone;
  final String? district;

  bool get isAdmin => role == 'admin';
  bool get isFarmer => role == 'farmer';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'].toString(),
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      role: json['role'] as String,
      disabled: json['disabled'] as bool? ?? false,
      phone: json['phone'] as String?,
      district: json['district'] as String?,
    );
  }
}
