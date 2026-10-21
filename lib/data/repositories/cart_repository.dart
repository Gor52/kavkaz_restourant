import 'package:postgres/postgres.dart';

import '../models/cart_item_model.dart';
import '../models/dish_model.dart';
import '../sources/remote/postgres_service.dart';
import '../../app/di.dart';

class CartRepository {
  final PostgresService _postgresService;

  CartRepository(this._postgresService);

  Future<int> _getOrCreateCartId() async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final existing = await conn.execute(
      Sql.named(r'''
        SELECT id_cart
        FROM carts
        WHERE user_id = @user_id
        LIMIT 1
      '''),
      parameters: {
        'user_id': userId,
      },
    );

    if (existing.isNotEmpty) {
      return existing.first.toColumnMap()['id_cart'] as int;
    }

    final created = await conn.execute(
      Sql.named(r'''
        INSERT INTO carts (user_id)
        VALUES (@user_id)
        RETURNING id_cart
      '''),
      parameters: {
        'user_id': userId,
      },
    );

    return created.first.toColumnMap()['id_cart'] as int;
  }

  Future<List<CartItemModel>> getCartItems() async {
    final cartId = await _getOrCreateCartId();
    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        SELECT
          ci.id_cart_item,
          ci.cart_id,
          ci.dish_id,
          ci.quantity,
          ci.comment,
          ci.selected_options,
          d.id_dish,
          d.category_id,
          d.title,
          d.description,
          d.ingredients,
          d.price,
          d.weight,
          d.calories,
          d.allergens,
          d.photo_path,
          d.is_available,
          d.created_at
        FROM cart_items ci
        JOIN dishes d ON d.id_dish = ci.dish_id
        WHERE ci.cart_id = @cart_id
        ORDER BY ci.id_cart_item DESC
      '''),
      parameters: {
        'cart_id': cartId,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();
      return CartItemModel(
        id: data['id_cart_item'] as int,
        cartId: data['cart_id'] as int,
        dishId: data['dish_id'] as int,
        quantity: data['quantity'] as int,
        comment: data['comment'] as String?,
        selectedOptions: data['selected_options'] as String?,
        dish: DishModel(
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
        ),
      );
    }).toList();
  }

  Future<void> addToCart({
    required int dishId,
    required int quantity,
    String? comment,
    String? selectedOptions,
  }) async {
    final cartId = await _getOrCreateCartId();
    final conn = await _postgresService.connection;

    await conn.execute(
      Sql.named(r'''
        INSERT INTO cart_items (
          cart_id,
          dish_id,
          quantity,
          comment,
          selected_options
        )
        VALUES (
          @cart_id,
          @dish_id,
          @quantity,
          @comment,
          @selected_options
        )
      '''),
      parameters: {
        'cart_id': cartId,
        'dish_id': dishId,
        'quantity': quantity,
        'comment': comment,
        'selected_options': selectedOptions,
      },
    );

    await conn.execute(
      Sql.named(r'''
        UPDATE carts
        SET updated_at = NOW()
        WHERE id_cart = @cart_id
      '''),
      parameters: {
        'cart_id': cartId,
      },
    );
  }

  Future<void> updateCartItem({
    required int cartItemId,
    required int quantity,
    String? comment,
    String? selectedOptions,
  }) async {
    final conn = await _postgresService.connection;

    await conn.execute(
      Sql.named(r'''
        UPDATE cart_items
        SET quantity = @quantity,
            comment = @comment,
            selected_options = @selected_options
        WHERE id_cart_item = @cart_item_id
      '''),
      parameters: {
        'quantity': quantity,
        'comment': comment,
        'selected_options': selectedOptions,
        'cart_item_id': cartItemId,
      },
    );
  }

  Future<void> removeCartItem(int cartItemId) async {
    final conn = await _postgresService.connection;

    await conn.execute(
      Sql.named(r'''
        DELETE FROM cart_items
        WHERE id_cart_item = @cart_item_id
      '''),
      parameters: {
        'cart_item_id': cartItemId,
      },
    );
  }

  Future<void> clearCart() async {
    final cartId = await _getOrCreateCartId();
    final conn = await _postgresService.connection;

    await conn.execute(
      Sql.named(r'''
        DELETE FROM cart_items
        WHERE cart_id = @cart_id
      '''),
      parameters: {
        'cart_id': cartId,
      },
    );
  }
}