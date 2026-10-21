class PaymentMethodModel {
  final int id;
  final String title;

  const PaymentMethodModel({
    required this.id,
    required this.title,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id_payment_method'] as int,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_payment_method': id,
      'title': title,
    };
  }
}