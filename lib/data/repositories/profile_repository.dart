import 'package:postgres/postgres.dart';

import '../../app/di.dart';
import '../models/address_model.dart';
import '../models/bonus_operation_model.dart';
import '../models/user_model.dart';
import '../sources/remote/postgres_service.dart';

class ProfileRepository {
  final PostgresService _postgresService;

  ProfileRepository(this._postgresService);

  Future<UserModel> getProfile() async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;
    final result = await conn.execute(
      Sql.named(r'''
        SELECT
          id_user,
          role_id,
          full_name,
          phone,
          email,
          is_blocked,
          registered_at
        FROM users
        WHERE id_user = @user_id
        LIMIT 1
      '''),
      parameters: {
        'user_id': userId,
      },
    );

    if (result.isEmpty) {
      throw Exception('Пользователь не найден');
    }

    final data = result.first.toColumnMap();

    return UserModel(
      id: data['id_user'] as int,
      roleId: data['role_id'] as int,
      fullName: data['full_name'] as String,
      phone: data['phone'] as String,
      email: data['email'] as String?,
      isBlocked: data['is_blocked'] as bool? ?? false,
      registeredAt: data['registered_at'] as DateTime?,
    );
  }

  Future<UserModel> updateProfile({
    required String fullName,
    required String phone,
    String? email,
  }) async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        UPDATE users
        SET full_name = @full_name,
            phone = @phone,
            email = @email
        WHERE id_user = @user_id
        RETURNING
          id_user,
          role_id,
          full_name,
          phone,
          email,
          is_blocked,
          registered_at
      '''),
      parameters: {
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'user_id': userId,
      },
    );

    final data = result.first.toColumnMap();

    return UserModel(
      id: data['id_user'] as int,
      roleId: data['role_id'] as int,
      fullName: data['full_name'] as String,
      phone: data['phone'] as String,
      email: data['email'] as String?,
      isBlocked: data['is_blocked'] as bool? ?? false,
      registeredAt: data['registered_at'] as DateTime?,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final check = await conn.execute(
      Sql.named(r'''
        SELECT id_user
        FROM users
        WHERE id_user = @user_id
          AND password_hash = @current_password
        LIMIT 1
      '''),
      parameters: {
        'user_id': userId,
        'current_password': currentPassword,
      },
    );

    if (check.isEmpty) {
      throw Exception('Текущий пароль введен неверно');
    }

    await conn.execute(
      Sql.named(r'''
        UPDATE users
        SET password_hash = @new_password
        WHERE id_user = @user_id
      '''),
      parameters: {
        'new_password': newPassword,
        'user_id': userId,
      },
    );
  }

  Future<void> deleteAccount() async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    await conn.execute(
      Sql.named(r'''
        UPDATE users
        SET is_blocked = TRUE
        WHERE id_user = @user_id
      '''),
      parameters: {
        'user_id': userId,
      },
    );

    await AppDi.sessionService.clearSession();
  }

  Future<List<AddressModel>> getAddresses() async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        SELECT
          id_address,
          user_id,
          address_text,
          comment,
          is_default,
          created_at
        FROM delivery_addresses
        WHERE user_id = @user_id
        ORDER BY is_default DESC, id_address DESC
      '''),
      parameters: {
        'user_id': userId,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();
      return AddressModel(
        id: data['id_address'] as int,
        userId: data['user_id'] as int,
        addressText: data['address_text'] as String,
        comment: data['comment'] as String?,
        isDefault: data['is_default'] as bool? ?? false,
        createdAt: data['created_at'] as DateTime?,
      );
    }).toList();
  }

  Future<AddressModel> addAddress({
    required String addressText,
    String? comment,
    bool isDefault = false,
  }) async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    if (isDefault) {
      await conn.execute(
        Sql.named(r'''
          UPDATE delivery_addresses
          SET is_default = FALSE
          WHERE user_id = @user_id
        '''),
        parameters: {
          'user_id': userId,
        },
      );
    }

    final result = await conn.execute(
      Sql.named(r'''
        INSERT INTO delivery_addresses (
          user_id,
          address_text,
          comment,
          is_default
        )
        VALUES (
          @user_id,
          @address_text,
          @comment,
          @is_default
        )
        RETURNING
          id_address,
          user_id,
          address_text,
          comment,
          is_default,
          created_at
      '''),
      parameters: {
        'user_id': userId,
        'address_text': addressText,
        'comment': comment,
        'is_default': isDefault,
      },
    );

    final data = result.first.toColumnMap();

    return AddressModel(
      id: data['id_address'] as int,
      userId: data['user_id'] as int,
      addressText: data['address_text'] as String,
      comment: data['comment'] as String?,
      isDefault: data['is_default'] as bool? ?? false,
      createdAt: data['created_at'] as DateTime?,
    );
  }

  Future<AddressModel> updateAddress({
    required int addressId,
    required String addressText,
    String? comment,
    bool isDefault = false,
  }) async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    if (isDefault) {
      await conn.execute(
        Sql.named(r'''
          UPDATE delivery_addresses
          SET is_default = FALSE
          WHERE user_id = @user_id
        '''),
        parameters: {
          'user_id': userId,
        },
      );
    }

    final result = await conn.execute(
      Sql.named(r'''
        UPDATE delivery_addresses
        SET address_text = @address_text,
            comment = @comment,
            is_default = @is_default
        WHERE id_address = @address_id
        RETURNING
          id_address,
          user_id,
          address_text,
          comment,
          is_default,
          created_at
      '''),
      parameters: {
        'address_text': addressText,
        'comment': comment,
        'is_default': isDefault,
        'address_id': addressId,
      },
    );

    final data = result.first.toColumnMap();

    return AddressModel(
      id: data['id_address'] as int,
      userId: data['user_id'] as int,
      addressText: data['address_text'] as String,
      comment: data['comment'] as String?,
      isDefault: data['is_default'] as bool? ?? false,
      createdAt: data['created_at'] as DateTime?,
    );
  }

  Future<void> deleteAddress(int addressId) async {
    final conn = await _postgresService.connection;

    await conn.execute(
      Sql.named(r'''
        DELETE FROM delivery_addresses
        WHERE id_address = @address_id
      '''),
      parameters: {
        'address_id': addressId,
      },
    );
  }

  Future<List<BonusOperationModel>> getBonusHistory() async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        SELECT
          bo.id_bonus_operation,
          bo.user_id,
          bo.bonus_operation_type_id,
          bo.bonus_amount,
          bo.order_id,
          bo.created_at,
          bot.title AS operation_title
        FROM bonus_operations bo
        JOIN bonus_operation_types bot
          ON bot.id_bonus_operation_type = bo.bonus_operation_type_id
        WHERE bo.user_id = @user_id
        ORDER BY bo.id_bonus_operation DESC
      '''),
      parameters: {
        'user_id': userId,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();
      return BonusOperationModel(
        id: data['id_bonus_operation'] as int,
        userId: data['user_id'] as int,
        bonusOperationTypeId: data['bonus_operation_type_id'] as int,
        bonusAmount: data['bonus_amount'] as int,
        orderId: data['order_id'] as int?,
        createdAt: data['created_at'] as DateTime?,
        operationTitle: data['operation_title'] as String?,
      );
    }).toList();
  }
}