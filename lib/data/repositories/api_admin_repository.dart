import '../models/booking_model.dart';
import '../models/bonus_operation_model.dart';
import '../models/category_model.dart';
import '../models/dish_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../sources/remote/api_service.dart';
import 'dart:io';
import 'package:dio/dio.dart';

class ApiAdminRepository {
  final ApiService _apiService;

  ApiAdminRepository(this._apiService);

  Future<({int activeOrders, int bookings, int users})> getDashboardStats() async {
    final response = await _apiService.get<Map<String, dynamic>>('/admin/stats');
    final d = response.data ?? {};
    int n(String key) => (d[key] as num?)?.toInt() ?? 0;
    return (
      activeOrders: n('activeOrders'),
      bookings: n('bookings'),
      users: n('users'),
    );
  }

  Future<List<CategoryModel>> getAdminCategories() async {
    final response = await _apiService.get<List<dynamic>>('/admin/categories');

    return (response.data ?? [])
        .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CategoryModel> createCategory({
    required String title,
    required int sortOrder,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/admin/categories',
      data: {
        'title': title,
        'sort_order': sortOrder,
      },
    );

    if (response.data == null) {
      throw Exception('Не удалось создать категорию');
    }

    return CategoryModel.fromJson(response.data!);
  }

  Future<CategoryModel> updateCategory({
    required int categoryId,
    required String title,
    required int sortOrder,
  }) async {
    final response = await _apiService.put<Map<String, dynamic>>(
      '/admin/categories/$categoryId',
      data: {
        'title': title,
        'sort_order': sortOrder,
      },
    );

    if (response.data == null) {
      throw Exception('Не удалось обновить категорию');
    }

    return CategoryModel.fromJson(response.data!);
  }

  Future<void> deleteCategory(int categoryId) async {
    await _apiService.delete<void>('/admin/categories/$categoryId');
  }

  Future<List<DishModel>> getAdminDishes() async {
    final response = await _apiService.get<List<dynamic>>('/admin/dishes');

    return (response.data ?? [])
        .map((item) => DishModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteDish(int dishId) async {
    await _apiService.delete<void>('/admin/dishes/$dishId');
  }

  Future<String> uploadDishPhoto(File imageFile) async {
    final fileName = imageFile.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        imageFile.path,
        filename: fileName,
      ),
    });
    final response = await _apiService.post<Map<String, dynamic>>(
      '/admin/dishes/photo',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final body = response.data ?? <String, dynamic>{};
    final photoPath = body['photo_path']?.toString();
    if (photoPath == null || photoPath.isEmpty) {
      throw Exception('Сервер не вернул ссылку на изображение');
    }
    return photoPath;
  }

  Future<DishModel> createDish({
    required int categoryId,
    required String title,
    required String description,
    required String ingredients,
    required double price,
    required int weight,
    int? calories,
    String? allergens,
    String? photoPath,
    required bool isAvailable,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/admin/dishes',
      data: {
        'category_id': categoryId,
        'title': title,
        'description': description,
        'ingredients': ingredients,
        'price': price,
        'weight': weight,
        'calories': calories,
        'allergens': allergens,
        'photo_path': photoPath,
        'is_available': isAvailable,
      },
    );
    if (response.data == null) {
      throw Exception('Не удалось создать блюдо');
    }
    return DishModel.fromJson(response.data!);
  }

  Future<DishModel> updateDish({
    required int dishId,
    required int categoryId,
    required String title,
    required String description,
    required String ingredients,
    required double price,
    required int weight,
    int? calories,
    String? allergens,
    String? photoPath,
    required bool isAvailable,
  }) async {
    final response = await _apiService.put<Map<String, dynamic>>(
      '/admin/dishes/$dishId',
      data: {
        'category_id': categoryId,
        'title': title,
        'description': description,
        'ingredients': ingredients,
        'price': price,
        'weight': weight,
        'calories': calories,
        'allergens': allergens,
        'photo_path': photoPath,
        'is_available': isAvailable,
      },
    );
    if (response.data == null) {
      throw Exception('Не удалось обновить блюдо');
    }
    return DishModel.fromJson(response.data!);
  }

  Future<List<OrderModel>> getAdminOrders() async {
    final response = await _apiService.get<List<dynamic>>('/admin/orders');

    return (response.data ?? [])
        .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<OrderModel> getAdminOrderById(int orderId) async {
    final response = await _apiService.get<Map<String, dynamic>>('/admin/orders/$orderId');
    if (response.data == null) {
      throw Exception('Заказ не найден');
    }
    return OrderModel.fromJson(response.data!);
  }

  Future<void> updateOrderStatus({
    required int orderId,
    required int orderStatusId,
  }) async {
    await _apiService.put<void>(
      '/admin/orders/$orderId/status',
      data: {'order_status_id': orderStatusId},
    );
  }

  Future<List<BookingModel>> getAdminBookings() async {
    final response = await _apiService.get<List<dynamic>>('/admin/bookings');

    return (response.data ?? [])
        .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateBookingStatus({
    required int bookingId,
    required int bookingStatusId,
  }) async {
    await _apiService.put<void>(
      '/admin/bookings/$bookingId/status',
      data: {'booking_status_id': bookingStatusId},
    );
  }

  Future<List<UserModel>> getUsers() async {
    final response = await _apiService.get<List<dynamic>>('/admin/users');

    return (response.data ?? [])
        .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<OrderModel>> getUserOrders(int userId) async {
    final response = await _apiService.get<List<dynamic>>('/admin/users/$userId/orders');
    return (response.data ?? [])
        .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<BonusOperationModel>> getUserBonusHistory(int userId) async {
    final response = await _apiService.get<List<dynamic>>('/admin/users/$userId/bonus-history');
    return (response.data ?? [])
        .map((item) => BonusOperationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateUserRole({
    required int userId,
    required int roleId,
  }) async {
    await _apiService.put<void>(
      '/admin/users/$userId/role',
      data: {'role_id': roleId},
    );
  }

  Future<void> blockUser(int userId, {required bool isBlocked}) async {
    await _apiService.put<void>(
      '/admin/users/$userId/block',
      data: {'is_blocked': isBlocked},
    );
  }

  Future<void> deleteUser(int userId) async {
    await _apiService.delete<void>('/admin/users/$userId');
  }

  Future<Map<String, dynamic>> adjustUserBonus({
    required int userId,
    required String operationType,
    required int bonusAmount,
    String? comment,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/admin/users/$userId/bonus',
      data: {
        'operation_type': operationType,
        'bonus_amount': bonusAmount,
        'comment': comment,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getReviews({
    int? dishId,
    int? userId,
  }) async {
    final query = <String, dynamic>{};
    if (dishId != null) query['dish_id'] = dishId;
    if (userId != null) query['user_id'] = userId;
    final response = await _apiService.get<List<dynamic>>(
      '/admin/reviews',
      queryParameters: query,
    );
    return (response.data ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createImport(Map<String, dynamic> data) async {
    final response =
        await _apiService.post<Map<String, dynamic>>('/admin/imports', data: data);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createExport(Map<String, dynamic> data) async {
    final response =
        await _apiService.post<Map<String, dynamic>>('/admin/exports', data: data);
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getExportTypes() async {
    final response = await _apiService.get<List<dynamic>>('/admin/export-types');
    return (response.data ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
