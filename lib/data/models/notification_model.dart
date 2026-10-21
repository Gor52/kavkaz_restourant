class NotificationModel {
  final int id;
  final int userId;
  final String title;
  final String text;
  final bool isRead;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.text,
    required this.isRead,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id_notification'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      text: json['text'] as String,
      isRead: _parseBool(json['is_read']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_notification': id,
      'user_id': userId,
      'title': title,
      'text': text,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().toLowerCase().trim();
    if (s == 'true' || s == 't' || s == '1' || s == 'yes') return true;
    return false;
  }
}