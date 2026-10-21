class OrderStatusModel {
  final int id;
  final String title;

  const OrderStatusModel({
    required this.id,
    required this.title,
  });

  factory OrderStatusModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusModel(
      id: json['id_order_status'] as int,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_order_status': id,
      'title': title,
    };
  }
}