class SupportMessageModel {
  final int id;
  final int conversationId;
  final int senderUserId;
  final String messageText;
  final DateTime? createdAt;
  final bool isRead;
  final String? senderName;
  final int? senderRoleId;

  const SupportMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.messageText,
    this.createdAt,
    required this.isRead,
    this.senderName,
    this.senderRoleId,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id_support_message'] as int,
      conversationId: json['conversation_id'] as int,
      senderUserId: json['sender_user_id'] as int,
      messageText: json['message_text'] as String? ?? '',
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      isRead: json['is_read'] as bool? ?? false,
      senderName: json['sender_name'] as String?,
      senderRoleId: json['sender_role_id'] as int?,
    );
  }
}
