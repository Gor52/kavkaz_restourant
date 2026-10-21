import 'package:postgres/postgres.dart';

import '../models/category_model.dart';
import '../models/dish_model.dart';
import '../sources/remote/postgres_service.dart';

class MenuRepository {
  final PostgresService _postgresService;

  MenuRepository(this._postgresService);

  Future<List<CategoryModel>> getCategories() async {
    final conn = await _postgresService.connection;

    final result = await conn.execute(r'''
      SELECT id_category, title, sort_order
      FROM categories
      ORDER BY sort_order ASC, title ASC
    ''');

    return result.map((row) {
      final data = row.toColumnMap();
      return CategoryModel(
        id: data['id_category'] as int,
        title: data['title'] as String,
        sortOrder: data['sort_order'] as int,
      );
    }).toList();
  }

  Future<List<DishModel>> getDishes({
    int? categoryId,
    String? search,
    String? sort,
    bool? onlyAvailable,
  }) async {
    final conn = await _postgresService.connection;

    final conditions = <String>[];
    final params = <String, dynamic>{};

    if (categoryId != null) {
      conditions.add('category_id = @category_id');
      params['category_id'] = categoryId;
    }

    if (search != null && search.trim().isNotEmpty) {
      conditions.add(
        '(LOWER(title) LIKE LOWER(@search) OR LOWER(description) LIKE LOWER(@search))',
      );
      params['search'] = '%${search.trim()}%';
    }

    if (onlyAvailable == true) {
      conditions.add('is_available = TRUE');
    }

    var query = '''
      SELECT
        id_dish,
        category_id,
        title,
        description,
        ingredients,
        price,
        weight,
        calories,
        allergens,
        photo_path,
        is_available,
        created_at
      FROM dishes
    ''';

    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
    }

    switch (sort) {
      case 'price_asc':
        query += ' ORDER BY price ASC';
        break;
      case 'price_desc':
        query += ' ORDER BY price DESC';
        break;
      case 'title_asc':
        query += ' ORDER BY title ASC';
        break;
      default:
        query += ' ORDER BY id_dish DESC';
    }

    final result = params.isEmpty
        ? await conn.execute(query)
        : await conn.execute(Sql.named(query), parameters: params);

    return result.map((row) {
      final data = row.toColumnMap();
      return DishModel(
        id: data['id_dish'] as int,
        categoryId: data['category_id'] as int,
        title: data['title'] as String,
        description: data['description'] as String,
        ingredients: data['ingredients'] as String,
        price: double.parse(data['price'].toString()),
        weight: data['weight'] as int,
        calories: data['calories'] as int?,
        allergens: data['allergens'] as String?,
        photoPath: data['photo_path'] as String?,
        isAvailable: data['is_available'] as bool? ?? true,
        createdAt: data['created_at'] as DateTime?,
      );
    }).toList();
  }

  Future<DishModel> getDishById(int dishId) async {
    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        SELECT
          id_dish,
          category_id,
          title,
          description,
          ingredients,
          price,
          weight,
          calories,
          allergens,
          photo_path,
          is_available,
          created_at
        FROM dishes
        WHERE id_dish = @dish_id
        LIMIT 1
      '''),
      parameters: {
        'dish_id': dishId,
      },
    );

    if (result.isEmpty) {
      throw Exception('Блюдо не найдено');
    }

    final data = result.first.toColumnMap();

    return DishModel(
      id: data['id_dish'] as int,
      categoryId: data['category_id'] as int,
      title: data['title'] as String,
      description: data['description'] as String,
      ingredients: data['ingredients'] as String,
      price: double.parse(data['price'].toString()),
      weight: data['weight'] as int,
      calories: data['calories'] as int?,
      allergens: data['allergens'] as String?,
      photoPath: data['photo_path'] as String?,
      isAvailable: data['is_available'] as bool? ?? true,
      createdAt: data['created_at'] as DateTime?,
    );
  }
}