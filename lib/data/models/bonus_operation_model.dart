class BonusOperationModel {
  final int id;
  final int userId;
  final int bonusOperationTypeId;
  final int bonusAmount;
  final int? orderId;
  final DateTime? createdAt;
  final String? operationTitle;

  const BonusOperationModel({
    required this.id,
    required this.userId,
    required this.bonusOperationTypeId,
    required this.bonusAmount,
    this.orderId,
    this.createdAt,
    this.operationTitle,
  });

  factory BonusOperationModel.fromJson(Map<String, dynamic> json) {
    return BonusOperationModel(
      id: json['id_bonus_operation'] as int,
      userId: json['user_id'] as int,
      bonusOperationTypeId: json['bonus_operation_type_id'] as int,
      bonusAmount: json['bonus_amount'] as int,
      orderId: json['order_id'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      operationTitle: json['operation_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_bonus_operation': id,
      'user_id': userId,
      'bonus_operation_type_id': bonusOperationTypeId,
      'bonus_amount': bonusAmount,
      'order_id': orderId,
      'created_at': createdAt?.toIso8601String(),
      'operation_title': operationTitle,
    };
  }
}