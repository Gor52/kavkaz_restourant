import 'dish_model.dart';

class CartItemModel {
  final int id;
  final int cartId;
  final int dishId;
  final int quantity;
  final String? comment;
  final String? selectedOptions;
  final DishModel? dish;

  const CartItemModel({
    required this.id,
    required this.cartId,
    required this.dishId,
    required this.quantity,
    this.comment,
    this.selectedOptions,
    this.dish,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id_cart_item'] as int,
      cartId: json['cart_id'] as int,
      dishId: json['dish_id'] as int,
      quantity: json['quantity'] as int,
      comment: json['comment'] as String?,
      selectedOptions: json['selected_options'] as String?,
      dish: json['dish'] != null
          ? DishModel.fromJson(json['dish'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_cart_item': id,
      'cart_id': cartId,
      'dish_id': dishId,
      'quantity': quantity,
      'comment': comment,
      'selected_options': selectedOptions,
      'dish': dish?.toJson(),
    };
  }
}