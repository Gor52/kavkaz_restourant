import 'package:postgres/postgres.dart';

import '../models/booking_model.dart';
import '../models/category_model.dart';
import '../models/dish_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../sources/remote/postgres_service.dart';

class AdminRepository {
  final PostgresService _postgresService;

  AdminRepository(this._postgresService);

  Future<List<UserModel>> getUsers() async {
    final conn = await _postgresService.connection;
    final result = await conn.execute(r'''
      SELECT
        id_user,
        role_id,
        full_name,
        phone,
        email,
        is_blocked,
        registered_at
      FROM users
      ORDER BY id_user DESC
    ''');

    return result.map((row) {
      final data = row.toColumnMap();
      return UserModel(
        id: data['id_user'] as int,
        roleId: data['role_id'] as int,
        fullName: data['full_name'] as String,
        phone: data['phone'] as String,
        email: data['email'] as String?,
        isBlocked: data['is_blocked'] as bool? ?? false,
        registeredAt: data['registered_at'] as DateTime?,
      );
    }).toList();
  }

  Future<void> updateUserRole({
    required int userId,
    required int roleId,
  }) async {
    final conn = await _postgresService.connection;
    await conn.execute(
      Sql.named(r'''
        UPDATE users
        SET role_id = @role_id
        WHERE id_user = @user_id
      '''),
      parameters: {
        'role_id': roleId,
        'user_id': userId,
      },
    );
  }

  Future<void> blockUser(int userId) async {
    final conn = await _postgresService.connection;
    await conn.execute(
      Sql.named(r'''
        UPDATE users
        SET is_blocked = NOT is_blocked
        WHERE id_user = @user_id
      '''),
      parameters: {
        'user_id': userId,
      },
    );
  }

  Future<void> deleteUser(int userId) async {
    final conn = await _postgresService.connection;
    await conn.execute(
      Sql.named(r'''
        DELETE FROM users
        WHERE id_user = @user_id
      '''),
      parameters: {
        'user_id': userId,
      },
    );
  }

  Future<List<DishModel>> getAdminDishes() async {
    final conn = await _postgresService.connection;
    final result = await conn.execute(r'''
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
      ORDER BY id_dish DESC
    ''');

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

  Future<DishModel> createDish(Map<String, dynamic> data) async {
    final conn = await _postgresService.connection;
    final result = await conn.execute(
      Sql.named(r'''
        INSERT INTO dishes (
          category_id,
          title,
          description,
          ingredients,
          price,
          weight,
          calories,
          allergens,
          photo_path,
          is_available
        )
        VALUES (
          @category_id,
          @title,
          @description,
          @ingredients,
          @price,
          @weight,
          @calories,
          @allergens,
          @photo_path,
          @is_available
        )
        RETURNING
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
      '''),
      parameters: data,
    );

    final row = result.first.toColumnMap();

    return DishModel(
      id: row['id_dish'] as int,
      categoryId: row['category_id'] as int,
      title: row['title'] as String,
      description: row['description'] as String,
      ingredients: row['ingredients'] as String,
      price: double.parse(row['price'].toString()),
      weight: row['weight'] as int,
      calories: row['calories'] as int?,
      allergens: row['allergens'] as String?,
      photoPath: row['photo_path'] as String?,
      isAvailable: row['is_available'] as bool? ?? true,
      createdAt: row['created_at'] as DateTime?,
    );
  }

  Future<DishModel> updateDish({
    required int dishId,
    required Map<String, dynamic> data,
  }) async {
    final conn = await _postgresService.connection;

    final params = {...data, 'dish_id': dishId};

    final result = await conn.execute(
      Sql.named(r'''
        UPDATE dishes
        SET category_id = @category_id,
            title = @title,
            description = @description,
            ingredients = @ingredients,
            price = @price,
            weight = @weight,
            calories = @calories,
            allergens = @allergens,
            photo_path = @photo_path,
            is_available = @is_available
        WHERE id_dish = @dish_id
        RETURNING
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
      '''),
      parameters: params,
    );

    final row = result.first.toColumnMap();

    return DishModel(
      id: row['id_dish'] as int,
      categoryId: row['category_id'] as int,
      title: row['title'] as String,
      description: row['description'] as String,
      ingredients: row['ingredients'] as String,
      price: double.parse(row['price'].toString()),
      weight: row['weight'] as int,
      calories: row['calories'] as int?,
      allergens: row['allergens'] as String?,
      photoPath: row['photo_path'] as String?,
      isAvailable: row['is_available'] as bool? ?? true,
      createdAt: row['created_at'] as DateTime?,
    );
  }

  Future<void> deleteDish(int dishId) async {
    final conn = await _postgresService.connection;
    await conn.execute(
      Sql.named(r'''
        DELETE FROM dishes
        WHERE id_dish = @dish_id
      '''),
      parameters: {
        'dish_id': dishId,
      },
    );
  }

  Future<List<CategoryModel>> getAdminCategories() async {
    final conn = await _postgresService.connection;
    final result = await conn.execute(r'''
      SELECT id_category, title, sort_order
      FROM categories
      ORDER BY sort_order ASC
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

  Future<CategoryModel> createCategory({
    required String title,
    required int sortOrder,
  }) async {
    final conn = await _postgresService.connection;
    final result = await conn.execute(
      Sql.named(r'''
        INSERT INTO categories (title, sort_order)
        VALUES (@title, @sort_order)
        RETURNING id_category, title, sort_order
      '''),
      parameters: {
        'title': title,
        'sort_order': sortOrder,
      },
    );

    final row = result.first.toColumnMap();

    return CategoryModel(
      id: row['id_category'] as int,
      title: row['title'] as String,
      sortOrder: row['sort_order'] as int,
    );
  }

  Future<CategoryModel> updateCategory({
    required int categoryId,
    required String title,
    required int sortOrder,
  }) async {
    final conn = await _postgresService.connection;
    final result = await conn.execute(
      Sql.named(r'''
        UPDATE categories
        SET title = @title,
            sort_order = @sort_order
        WHERE id_category = @category_id
        RETURNING id_category, title, sort_order
      '''),
      parameters: {
        'title': title,
        'sort_order': sortOrder,
        'category_id': categoryId,
      },
    );

    final row = result.first.toColumnMap();

    return CategoryModel(
      id: row['id_category'] as int,
      title: row['title'] as String,
      sortOrder: row['sort_order'] as int,
    );
  }

  Future<void> deleteCategory(int categoryId) async {
    final conn = await _postgresService.connection;
    await conn.execute(
      Sql.named(r'''
        DELETE FROM categories
        WHERE id_category = @category_id
      '''),
      parameters: {
        'category_id': categoryId,
      },
    );
  }

  Future<List<OrderModel>> getAdminOrders() async {
    final conn = await _postgresService.connection;

    final result = await conn.execute(r'''
      SELECT
        o.id_order,
        o.user_id,
        o.address_id,
        o.order_status_id,
        o.pickup_type_id,
        o.payment_method_id,
        o.receive_time,
        o.comment,
        o.total_amount,
        o.spent_bonus,
        o.created_at,
        os.title AS order_status_title,
        pt.title AS pickup_type_title,
        pm.title AS payment_method_title
      FROM orders o
      JOIN order_statuses os ON os.id_order_status = o.order_status_id
      JOIN pickup_types pt ON pt.id_pickup_type = o.pickup_type_id
      JOIN payment_methods pm ON pm.id_payment_method = o.payment_method_id
      ORDER BY o.id_order DESC
    ''');

    return result.map((row) {
      final data = row.toColumnMap();
      return OrderModel(
        id: data['id_order'] as int,
        userId: data['user_id'] as int,
        addressId: data['address_id'] as int?,
        orderStatusId: data['order_status_id'] as int,
        pickupTypeId: data['pickup_type_id'] as int,
        paymentMethodId: data['payment_method_id'] as int,
        receiveTime: data['receive_time'] as DateTime,
        comment: data['comment'] as String?,
        totalAmount: double.parse(data['total_amount'].toString()),
        spentBonus: data['spent_bonus'] as int? ?? 0,
        createdAt: data['created_at'] as DateTime?,
        orderStatusTitle: data['order_status_title'] as String?,
        pickupTypeTitle: data['pickup_type_title'] as String?,
        paymentMethodTitle: data['payment_method_title'] as String?,
      );
    }).toList();
  }

  Future<void> updateOrderStatus({
    required int orderId,
    required int orderStatusId,
  }) async {
    final conn = await _postgresService.connection;
    await conn.execute(
      Sql.named(r'''
        UPDATE orders
        SET order_status_id = @order_status_id
        WHERE id_order = @order_id
      '''),
      parameters: {
        'order_status_id': orderStatusId,
        'order_id': orderId,
      },
    );
  }

  Future<List<BookingModel>> getAdminBookings() async {
    final conn = await _postgresService.connection;

    final result = await conn.execute(r'''
      SELECT
        b.id_booking,
        b.user_id,
        b.booking_date,
        b.booking_time,
        b.guest_count,
        b.comment,
        b.booking_status_id,
        b.created_at,
        bs.title AS booking_status_title
      FROM bookings b
      JOIN booking_statuses bs ON bs.id_booking_status = b.booking_status_id
      ORDER BY b.id_booking DESC
    ''');

    return result.map((row) {
      final data = row.toColumnMap();
      return BookingModel(
        id: data['id_booking'] as int,
        userId: data['user_id'] as int,
        bookingDate: data['booking_date'] as DateTime,
        bookingTime: data['booking_time'].toString(),
        guestCount: data['guest_count'] as int,
        comment: data['comment'] as String?,
        bookingStatusId: data['booking_status_id'] as int,
        bookingStatusTitle: data['booking_status_title'] as String?,
        createdAt: data['created_at'] as DateTime?,
      );
    }).toList();
  }

  Future<void> updateBookingStatus({
    required int bookingId,
    required int bookingStatusId,
  }) async {
    final conn = await _postgresService.connection;
    await conn.execute(
      Sql.named(r'''
        UPDATE bookings
        SET booking_status_id = @booking_status_id
        WHERE id_booking = @booking_id
      '''),
      parameters: {
        'booking_status_id': bookingStatusId,
        'booking_id': bookingId,
      },
    );
  }

  Future<void> createImport(Map<String, dynamic> data) async {
    final conn = await _postgresService.connection;
    await conn.execute(
      Sql.named(r'''
        INSERT INTO imports (
          user_id,
          import_type_id,
          file_path
        )
        VALUES (
          @user_id,
          @import_type_id,
          @file_path
        )
      '''),
      parameters: data,
    );
  }

  Future<void> createExport(Map<String, dynamic> data) async {
    final conn = await _postgresService.connection;
    await conn.execute(
      Sql.named(r'''
        INSERT INTO exports (
          user_id,
          export_type_id,
          file_path
        )
        VALUES (
          @user_id,
          @export_type_id,
          @file_path
        )
      '''),
      parameters: data,
    );
  }
}