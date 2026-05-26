class AdminActivityLog {
  const AdminActivityLog({
    required this.id,
    required this.actorEmail,
    required this.action,
    required this.category,
    required this.detail,
    required this.severity,
    this.createdAt,
  });

  final String id;
  final String actorEmail;
  final String action;
  final String category;
  final String detail;
  final String severity;
  final DateTime? createdAt;

  factory AdminActivityLog.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['created_at'];
    if (raw is String) created = DateTime.tryParse(raw);
    return AdminActivityLog(
      id: json['id'].toString(),
      actorEmail: json['actor_email'] as String? ?? '',
      action: json['action'] as String? ?? '',
      category: json['category'] as String? ?? 'system',
      detail: json['detail'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      createdAt: created,
    );
  }
}
