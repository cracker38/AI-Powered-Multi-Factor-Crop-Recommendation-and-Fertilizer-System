class FarmerTip {
  const FarmerTip({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
  });

  final String id;
  final String title;
  final String message;
  final String category;

  factory FarmerTip.fromJson(Map<String, dynamic> json) {
    return FarmerTip(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      category: json['category'] as String? ?? 'tip',
    );
  }
}
