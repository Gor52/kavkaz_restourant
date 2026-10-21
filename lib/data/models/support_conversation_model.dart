class SupportConversationModel {
  final int id;
  final int userId;
  final int? assignedStaffId;
  final String status;
  final String? subject;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final String? userName;
  final String? userPhone;
  final String? assignedStaffName;
  final String? lastMessageText;
  final int unreadCount;

  const SupportConversationModel({
    required this.id,
    required this.userId,
    this.assignedStaffId,
    required this.status,
    this.subject,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.userName,
    this.userPhone,
    this.assignedStaffName,
    this.lastMessageText,
    this.unreadCount = 0,
  });

  bool get isClosed => status.toLowerCase() == 'closed';

  factory SupportConversationModel.fromJson(Map<String, dynamic> json) {
    return SupportConversationModel(
      id: json['id_support_conversation'] as int,
      userId: json['user_id'] as int,
      assignedStaffId: json['assigned_staff_id'] as int?,
      status: (json['status'] as String?) ?? 'open',
      subject: json['subject'] as String?,
      lastMessageAt:
          json['last_message_at'] != null
              ? DateTime.tryParse(json['last_message_at'].toString())
              : null,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
      closedAt:
          json['closed_at'] != null
              ? DateTime.tryParse(json['closed_at'].toString())
              : null,
      userName: json['user_name'] as String?,
      userPhone: json['user_phone'] as String?,
      assignedStaffName: json['assigned_staff_name'] as String?,
      lastMessageText: json['last_message_text'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}
