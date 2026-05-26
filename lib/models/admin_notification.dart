class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.severity,
    required this.read,
    this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String category;
  final String severity;
  final bool read;
  final DateTime? createdAt;

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['created_at'];
    if (raw is String) created = DateTime.tryParse(raw);
    return AdminNotification(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      category: json['category'] as String? ?? 'system',
      severity: json['severity'] as String? ?? 'info',
      read: json['read'] as bool? ?? false,
      createdAt: created,
    );
  }
}
