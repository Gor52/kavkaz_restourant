import 'package:dio/dio.dart';

import '../models/cart_item_model.dart';
import '../sources/remote/api_service.dart';

class ApiCartRepository {
  final ApiService _apiService;

  ApiCartRepository(this._apiService);

  Future<List<CartItemModel>> getCartItems() async {
    try {
      final response = await _apiService.get<List<dynamic>>(
        '/cart/items',
      );

      return (response.data ?? [])
          .map((item) => CartItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_mapCartError(e));
    }
  }

  Future<void> addToCart({
    required int dishId,
    required int quantity,
    String? comment,
    String? selectedOptions,
  }) async {
    try {
      await _apiService.post<void>(
        '/cart/items',
        data: {
          'dish_id': dishId,
          'quantity': quantity,
          'comment': comment,
          'selected_options': selectedOptions,
        },
      );
    } on DioException catch (e) {
      throw Exception(_mapCartError(e));
    }
  }

  Future<void> updateCartItem({
    required int cartItemId,
    required int quantity,
    String? comment,
    String? selectedOptions,
  }) async {
    try {
      await _apiService.put<void>(
        '/cart/items/$cartItemId',
        data: {
          'quantity': quantity,
          'comment': comment,
          'selected_options': selectedOptions,
        },
      );
    } on DioException catch (e) {
      throw Exception(_mapCartError(e));
    }
  }

  Future<void> removeCartItem(int cartItemId) async {
    try {
      await _apiService.delete<void>(
        '/cart/items/$cartItemId',
      );
    } on DioException catch (e) {
      throw Exception(_mapCartError(e));
    }
  }

  Future<void> clearCart() async {
    try {
      await _apiService.delete<void>('/cart');
    } on DioException catch (e) {
      throw Exception(_mapCartError(e));
    }
  }

  String _mapCartError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return 'Требуется авторизация. Войдите в аккаунт.';
    }
    if (code == 404) {
      return 'Позиция корзины не найдена.';
    }
    if (code == 409) {
      return 'Нельзя добавить блюдо в корзину.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Нет соединения с сервером. Проверьте сеть и backend.';
    }
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    return 'Ошибка работы с корзиной.';
  }
}
