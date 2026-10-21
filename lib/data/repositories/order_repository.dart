import 'package:postgres/postgres.dart';

import '../../app/di.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../sources/remote/postgres_service.dart';

class OrderRepository {
  final PostgresService _postgresService;

  OrderRepository(this._postgresService);

  Future<List<OrderModel>> getOrders() async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
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
        WHERE o.user_id = @user_id
        ORDER BY o.id_order DESC
      '''),
      parameters: {
        'user_id': userId,
      },
    );

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

  Future<OrderModel> getOrderById(int orderId) async {
    final conn = await _postgresService.connection;

    final orderResult = await conn.execute(
      Sql.named(r'''
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
        WHERE o.id_order = @order_id
        LIMIT 1
      '''),
      parameters: {
        'order_id': orderId,
      },
    );

    if (orderResult.isEmpty) {
      throw Exception('Заказ не найден');
    }

    final itemsResult = await conn.execute(
      Sql.named(r'''
        SELECT
          oi.id_order_item,
          oi.order_id,
          oi.dish_id,
          oi.quantity,
          oi.price_at_order_time,
          oi.item_total,
          oi.selected_options,
          COALESCE(NULLIF(trim(oi.dish_title), ''), d.title, 'Удаленное блюдо') AS dish_title,
          d.photo_path AS dish_photo
        FROM order_items oi
        LEFT JOIN dishes d ON d.id_dish = oi.dish_id
        WHERE oi.order_id = @order_id
        ORDER BY oi.id_order_item ASC
      '''),
      parameters: {
        'order_id': orderId,
      },
    );

    final orderData = orderResult.first.toColumnMap();

    final items = itemsResult.map((row) {
      final data = row.toColumnMap();
      return OrderItemModel(
        id: data['id_order_item'] as int,
        orderId: data['order_id'] as int,
        dishId: data['dish_id'] as int?,
        quantity: data['quantity'] as int,
        priceAtOrderTime: double.parse(data['price_at_order_time'].toString()),
        itemTotal: double.parse(data['item_total'].toString()),
        selectedOptions: data['selected_options'] as String?,
        dishTitle: data['dish_title'] as String?,
        dishPhoto: data['dish_photo'] as String?,
      );
    }).toList();

    return OrderModel(
      id: orderData['id_order'] as int,
      userId: orderData['user_id'] as int,
      addressId: orderData['address_id'] as int?,
      orderStatusId: orderData['order_status_id'] as int,
      pickupTypeId: orderData['pickup_type_id'] as int,
      paymentMethodId: orderData['payment_method_id'] as int,
      receiveTime: orderData['receive_time'] as DateTime,
      comment: orderData['comment'] as String?,
      totalAmount: double.parse(orderData['total_amount'].toString()),
      spentBonus: orderData['spent_bonus'] as int? ?? 0,
      createdAt: orderData['created_at'] as DateTime?,
      orderStatusTitle: orderData['order_status_title'] as String?,
      pickupTypeTitle: orderData['pickup_type_title'] as String?,
      paymentMethodTitle: orderData['payment_method_title'] as String?,
      items: items,
    );
  }

  Future<OrderModel> createOrder({
    required int pickupTypeId,
    required int paymentMethodId,
    int? addressId,
    required String receiveTimeIso,
    String? comment,
    int spentBonus = 0,
  }) async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final cartResult = await conn.execute(
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

    if (cartResult.isEmpty) {
      throw Exception('Корзина пуста');
    }

    final cartId = cartResult.first.toColumnMap()['id_cart'] as int;

    final itemsResult = await conn.execute(
      Sql.named(r'''
        SELECT
          ci.id_cart_item,
          ci.dish_id,
          ci.quantity,
          ci.selected_options,
          d.price,
          d.title AS dish_title
        FROM cart_items ci
        JOIN dishes d ON d.id_dish = ci.dish_id
        WHERE ci.cart_id = @cart_id
      '''),
      parameters: {
        'cart_id': cartId,
      },
    );

    if (itemsResult.isEmpty) {
      throw Exception('Корзина пуста');
    }

    double totalAmount = 0;

    for (final row in itemsResult) {
      final data = row.toColumnMap();
      final price = double.parse(data['price'].toString());
      final quantity = data['quantity'] as int;
      totalAmount += price * quantity;
    }

    totalAmount -= spentBonus;
    if (totalAmount < 0) totalAmount = 0;

    final orderResult = await conn.execute(
      Sql.named(r'''
        INSERT INTO orders (
          user_id,
          address_id,
          order_status_id,
          pickup_type_id,
          payment_method_id,
          receive_time,
          comment,
          total_amount,
          spent_bonus
        )
        VALUES (
          @user_id,
          @address_id,
          1,
          @pickup_type_id,
          @payment_method_id,
          @receive_time,
          @comment,
          @total_amount,
          @spent_bonus
        )
        RETURNING id_order
      '''),
      parameters: {
        'user_id': userId,
        'address_id': addressId,
        'pickup_type_id': pickupTypeId,
        'payment_method_id': paymentMethodId,
        'receive_time': DateTime.parse(receiveTimeIso),
        'comment': comment,
        'total_amount': totalAmount,
        'spent_bonus': spentBonus,
      },
    );

    final orderId = orderResult.first.toColumnMap()['id_order'] as int;

    for (final row in itemsResult) {
      final data = row.toColumnMap();
      final price = double.parse(data['price'].toString());
      final quantity = data['quantity'] as int;
      final itemTotal = price * quantity;

      await conn.execute(
        Sql.named(r'''
          INSERT INTO order_items (
            order_id,
            dish_id,
            quantity,
            price_at_order_time,
            item_total,
            selected_options,
            dish_title
          )
          VALUES (
            @order_id,
            @dish_id,
            @quantity,
            @price_at_order_time,
            @item_total,
            @selected_options,
            @dish_title
          )
        '''),
        parameters: {
          'order_id': orderId,
          'dish_id': data['dish_id'] as int,
          'quantity': quantity,
          'price_at_order_time': price,
          'item_total': itemTotal,
          'selected_options': data['selected_options'] as String?,
          'dish_title': data['dish_title'] as String?,
        },
      );
    }

    await conn.execute(
      Sql.named(r'''
        DELETE FROM cart_items
        WHERE cart_id = @cart_id
      '''),
      parameters: {
        'cart_id': cartId,
      },
    );

    if (spentBonus > 0) {
      await conn.execute(
        Sql.named(r'''
          INSERT INTO bonus_operations (
            user_id,
            bonus_operation_type_id,
            bonus_amount,
            order_id
          )
          VALUES (
            @user_id,
            2,
            @bonus_amount,
            @order_id
          )
        '''),
        parameters: {
          'user_id': userId,
          'bonus_amount': spentBonus,
          'order_id': orderId,
        },
      );
    }

    return getOrderById(orderId);
  }

  Future<void> cancelOrder(int orderId) async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final orderResult = await conn.execute(
      Sql.named(r'''
        SELECT
          o.user_id,
          o.order_status_id,
          o.spent_bonus,
          LOWER(TRIM(os.title)) AS order_status_title
        FROM orders o
        JOIN order_statuses os ON os.id_order_status = o.order_status_id
        WHERE o.id_order = @order_id
        LIMIT 1
      '''),
      parameters: {
        'order_id': orderId,
      },
    );

    if (orderResult.isEmpty) {
      throw Exception('Заказ не найден');
    }

    final orderData = orderResult.first.toColumnMap();
    final orderUserId = orderData['user_id'] as int;
    if (orderUserId != userId) {
      throw Exception('Нельзя отменить чужой заказ');
    }

    final statusTitle =
        (orderData['order_status_title'] as String?)?.trim().toLowerCase() ?? '';
    if (statusTitle == 'отменен' || statusTitle == 'отменён') {
      return;
    }
    if (statusTitle != 'новый') {
      throw Exception('Заказ уже нельзя отменить');
    }

    final spentBonus = orderData['spent_bonus'] as int? ?? 0;

    await conn.execute(
      Sql.named(r'''
        UPDATE orders
        SET order_status_id = 7
        WHERE id_order = @order_id
      '''),
      parameters: {
        'order_id': orderId,
      },
    );

    if (spentBonus <= 0) {
      return;
    }

    final existingRefund = await conn.execute(
      Sql.named(r'''
        SELECT 1
        FROM bonus_operations
        WHERE user_id = @user_id
          AND order_id = @order_id
          AND bonus_operation_type_id = 1
        LIMIT 1
      '''),
      parameters: {
        'user_id': userId,
        'order_id': orderId,
      },
    );

    if (existingRefund.isNotEmpty) {
      return;
    }

    await conn.execute(
      Sql.named(r'''
        INSERT INTO bonus_operations (
          user_id,
          bonus_operation_type_id,
          bonus_amount,
          order_id
        )
        VALUES (
          @user_id,
          1,
          @bonus_amount,
          @order_id
        )
      '''),
      parameters: {
        'user_id': userId,
        'bonus_amount': spentBonus,
        'order_id': orderId,
      },
    );
  }

  Future<void> repeatOrder(int orderId) async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final cartResult = await conn.execute(
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

    int cartId;
    if (cartResult.isEmpty) {
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
      cartId = created.first.toColumnMap()['id_cart'] as int;
    } else {
      cartId = cartResult.first.toColumnMap()['id_cart'] as int;
    }

    final items = await conn.execute(
      Sql.named(r'''
        SELECT
          dish_id,
          quantity,
          selected_options
        FROM order_items
        WHERE order_id = @order_id
      '''),
      parameters: {
        'order_id': orderId,
      },
    );

    for (final row in items) {
      final data = row.toColumnMap();
      await conn.execute(
        Sql.named(r'''
          INSERT INTO cart_items (
            cart_id,
            dish_id,
            quantity,
            selected_options
          )
          VALUES (
            @cart_id,
            @dish_id,
            @quantity,
            @selected_options
          )
        '''),
        parameters: {
          'cart_id': cartId,
          'dish_id': data['dish_id'] as int?,
          'quantity': data['quantity'] as int,
          'selected_options': data['selected_options'] as String?,
        },
      );
    }
  }
}