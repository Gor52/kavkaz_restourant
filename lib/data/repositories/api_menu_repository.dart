import '../models/category_model.dart';
import '../models/dish_model.dart';
import '../sources/remote/api_service.dart';

class ApiMenuRepository {
  final ApiService _apiService;

  ApiMenuRepository(this._apiService);

  Future<List<CategoryModel>> getCategories() async {
    final response = await _apiService.get<List<dynamic>>(
      '/menu/categories',
    );

    return (response.data ?? [])
        .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<DishModel>> getDishes({
    int? categoryId,
    String? search,
    String? sort,
    bool? onlyAvailable,
  }) async {
    final queryParameters = <String, dynamic>{};

    if (categoryId != null) {
      queryParameters['category_id'] = categoryId;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (sort != null && sort.isNotEmpty) {
      queryParameters['sort'] = sort;
    }
    if (onlyAvailable == true) {
      queryParameters['available'] = true;
    }

    final response = await _apiService.get<List<dynamic>>(
      '/menu/dishes',
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );

    return (response.data ?? [])
        .map((item) => DishModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DishModel> getDishById(int dishId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/menu/dishes/$dishId',
    );

    if (response.data == null) {
      throw Exception('Блюдо не найдено');
    }

    return DishModel.fromJson(response.data!);
  }
}
