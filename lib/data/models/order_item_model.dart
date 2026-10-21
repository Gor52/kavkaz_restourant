class OrderItemModel {
  final int id;
  final int orderId;
  final int? dishId;
  final int quantity;
  final double priceAtOrderTime;
  final double itemTotal;
  final String? selectedOptions;
  final String? dishTitle;
  final String? dishPhoto;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    this.dishId,
    required this.quantity,
    required this.priceAtOrderTime,
    required this.itemTotal,
    this.selectedOptions,
    this.dishTitle,
    this.dishPhoto,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id_order_item'] as int,
      orderId: json['order_id'] as int,
      dishId: json['dish_id'] as int?,
      quantity: json['quantity'] as int,
      priceAtOrderTime: double.parse(json['price_at_order_time'].toString()),
      itemTotal: double.parse(json['item_total'].toString()),
      selectedOptions: json['selected_options'] as String?,
      dishTitle: json['dish_title'] as String?,
      dishPhoto: json['dish_photo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_order_item': id,
      'order_id': orderId,
      'dish_id': dishId,
      'quantity': quantity,
      'price_at_order_time': priceAtOrderTime,
      'item_total': itemTotal,
      'selected_options': selectedOptions,
      'dish_title': dishTitle,
      'dish_photo': dishPhoto,
    };
  }
}