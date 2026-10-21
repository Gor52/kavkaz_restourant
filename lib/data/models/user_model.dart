class UserModel {
  final int id;
  final int roleId;
  final String fullName;
  final String phone;
  final String? email;
  final bool isBlocked;
  final int bonusBalance;
  final DateTime? registeredAt;

  const UserModel({
    required this.id,
    required this.roleId,
    required this.fullName,
    required this.phone,
    this.email,
    required this.isBlocked,
    this.bonusBalance = 0,
    this.registeredAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id_user'] as int,
      roleId: json['role_id'] as int,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      isBlocked: json['is_blocked'] as bool? ?? false,
      bonusBalance: (json['bonus_balance'] as num?)?.toInt() ?? 0,
      registeredAt: json['registered_at'] != null
          ? DateTime.tryParse(json['registered_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_user': id,
      'role_id': roleId,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'is_blocked': isBlocked,
      'bonus_balance': bonusBalance,
      'registered_at': registeredAt?.toIso8601String(),
    };
  }
}