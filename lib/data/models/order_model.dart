import 'order_item_model.dart';

class OrderModel {
  final int id;
  final int userId;
  final String? userFullName;
  final String? userPhone;
  final String? userEmail;
  final String? deliveryAddressText;
  final String? deliveryAddressComment;
  final int? addressId;
  final int orderStatusId;
  final int pickupTypeId;
  final int paymentMethodId;
  final DateTime receiveTime;
  final String? comment;
  final double totalAmount;
  final int spentBonus;
  final DateTime? createdAt;
  final String? orderStatusTitle;
  final String? pickupTypeTitle;
  final String? paymentMethodTitle;
  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.userId,
    this.userFullName,
    this.userPhone,
    this.userEmail,
    this.deliveryAddressText,
    this.deliveryAddressComment,
    this.addressId,
    required this.orderStatusId,
    required this.pickupTypeId,
    required this.paymentMethodId,
    required this.receiveTime,
    this.comment,
    required this.totalAmount,
    required this.spentBonus,
    this.createdAt,
    this.orderStatusTitle,
    this.pickupTypeTitle,
    this.paymentMethodTitle,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id_order'] as int,
      userId: json['user_id'] as int,
      userFullName: json['user_full_name'] as String?,
      userPhone: json['user_phone'] as String?,
      userEmail: json['user_email'] as String?,
      deliveryAddressText: json['delivery_address_text'] as String?,
      deliveryAddressComment: json['delivery_address_comment'] as String?,
      addressId: json['address_id'] as int?,
      orderStatusId: json['order_status_id'] as int,
      pickupTypeId: json['pickup_type_id'] as int,
      paymentMethodId: json['payment_method_id'] as int,
      receiveTime: DateTime.parse(json['receive_time'].toString()),
      comment: json['comment'] as String?,
      totalAmount: double.parse(json['total_amount'].toString()),
      spentBonus: json['spent_bonus'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      orderStatusTitle: json['order_status_title'] as String?,
      pickupTypeTitle: json['pickup_type_title'] as String?,
      paymentMethodTitle: json['payment_method_title'] as String?,
      items: ((json['orderItems'] ?? json['items']) as List<dynamic>?)
              ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_order': id,
      'user_id': userId,
      'user_full_name': userFullName,
      'user_phone': userPhone,
      'user_email': userEmail,
      'delivery_address_text': deliveryAddressText,
      'delivery_address_comment': deliveryAddressComment,
      'address_id': addressId,
      'order_status_id': orderStatusId,
      'pickup_type_id': pickupTypeId,
      'payment_method_id': paymentMethodId,
      'receive_time': receiveTime.toIso8601String(),
      'comment': comment,
      'total_amount': totalAmount,
      'spent_bonus': spentBonus,
      'created_at': createdAt?.toIso8601String(),
      'order_status_title': orderStatusTitle,
      'pickup_type_title': pickupTypeTitle,
      'payment_method_title': paymentMethodTitle,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}