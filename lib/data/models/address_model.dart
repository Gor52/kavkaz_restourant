class AddressModel {
  final int id;
  final int userId;
  final String addressText;
  final String? comment;
  final bool isDefault;
  final DateTime? createdAt;

  const AddressModel({
    required this.id,
    required this.userId,
    required this.addressText,
    this.comment,
    required this.isDefault,
    this.createdAt,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id_address'] as int,
      userId: json['user_id'] as int,
      addressText: json['address_text'] as String,
      comment: json['comment'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_address': id,
      'user_id': userId,
      'address_text': addressText,
      'comment': comment,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
