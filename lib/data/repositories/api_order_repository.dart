import '../models/order_model.dart';
import '../sources/remote/api_service.dart';
import 'package:dio/dio.dart';

class ApiOrderRepository {
  final ApiService _apiService;

  ApiOrderRepository(this._apiService);

  Future<List<OrderModel>> getOrders() async {
    final response = await _apiService.get<List<dynamic>>('/orders');

    return (response.data ?? [])
        .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<OrderModel> getOrderById(int orderId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/orders/$orderId',
    );

    if (response.data == null) {
      throw Exception('Заказ не найден');
    }

    return OrderModel.fromJson(response.data!);
  }

  Future<OrderModel> createOrder({
    required int pickupTypeId,
    required int paymentMethodId,
    int? addressId,
    required String receiveTimeIso,
    String? comment,
    int spentBonus = 0,
  }) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/orders',
        data: {
          'pickup_type_id': pickupTypeId,
          'payment_method_id': paymentMethodId,
          'address_id': addressId,
          'receive_time': receiveTimeIso,
          'comment': comment,
          'spent_bonus': spentBonus,
        },
      );

      if (response.data == null) {
        throw Exception('Не удалось оформить заказ');
      }

      return OrderModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw Exception(_mapOrderError(e));
    }
  }

  Future<void> cancelOrder(int orderId) async {
    await _apiService.put<void>('/orders/$orderId/cancel');
  }

  Future<void> repeatOrder(int orderId) async {
    await _apiService.post<void>('/orders/$orderId/repeat');
  }

  Future<OrderModel> updateOrderBeforeConfirmation({
    required int orderId,
    int? pickupTypeId,
    int? paymentMethodId,
    int? addressId,
    String? receiveTimeIso,
    String? comment,
    int? spentBonus,
  }) async {
    final payload = <String, dynamic>{};
    if (pickupTypeId != null) payload['pickup_type_id'] = pickupTypeId;
    if (paymentMethodId != null) payload['payment_method_id'] = paymentMethodId;
    if (addressId != null) payload['address_id'] = addressId;
    if (receiveTimeIso != null) payload['receive_time'] = receiveTimeIso;
    if (comment != null) payload['comment'] = comment;
    if (spentBonus != null) payload['spent_bonus'] = spentBonus;
    final response = await _apiService.put<Map<String, dynamic>>(
      '/orders/$orderId',
      data: payload,
    );
    if (response.data == null) {
      throw Exception('Не удалось обновить заказ');
    }
    return OrderModel.fromJson(response.data!);
  }

  String _mapOrderError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }

    final code = e.response?.statusCode;
    if (code == 400) return 'Проверьте данные заказа.';
    if (code == 401 || code == 403) return 'Требуется авторизация.';
    if (code == 404) return 'Ресурс не найден.';
    if (code == 409) return 'Заказ не может быть оформлен.';

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Нет соединения с сервером. Проверьте сеть и backend.';
    }
    return 'Ошибка оформления заказа.';
  }
}
