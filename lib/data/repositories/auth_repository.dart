import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';

import '../../core/services/session_service.dart';
import '../models/user_model.dart';
import '../sources/remote/postgres_service.dart';

class AuthRepository {
  final PostgresService _postgresService;
  final SessionService _sessionService;

  AuthRepository(this._postgresService, this._sessionService);

  Future<UserModel> login({
    required String login,
    required String password,
  }) async {
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
        WHERE (phone = @login OR email = @login)
          AND password_hash = @password
        LIMIT 1
      '''),
      parameters: {
        'login': login,
        'password': password,
      },
    );

    if (result.isEmpty) {
      throw Exception('Неверный логин или пароль');
    }

    final row = result.first.toColumnMap();

    final user = UserModel(
      id: row['id_user'] as int,
      roleId: row['role_id'] as int,
      fullName: row['full_name'] as String,
      phone: row['phone'] as String,
      email: row['email'] as String?,
      isBlocked: row['is_blocked'] as bool? ?? false,
      registeredAt: row['registered_at'] as DateTime?,
    );

    if (user.isBlocked) {
      throw Exception('Пользователь заблокирован');
    }

    await _sessionService.saveSession(
      accessToken: 'local_session_${user.id}',
      userId: user.id,
      role: _mapRole(user.roleId),
    );

    return user;
  }

  Future<UserModel> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final conn = await _postgresService.connection;

    final exists = await conn.execute(
      Sql.named(r'''
        SELECT id_user
        FROM users
        WHERE phone = @phone OR email = @email
        LIMIT 1
      '''),
      parameters: {
        'phone': phone,
        'email': email,
      },
    );

    if (exists.isNotEmpty) {
      throw Exception('Пользователь уже существует');
    }

    final result = await conn.execute(
      Sql.named(r'''
        INSERT INTO users (
          role_id,
          full_name,
          phone,
          email,
          password_hash,
          is_blocked
        )
        VALUES (
          1,
          @full_name,
          @phone,
          @email,
          @password_hash,
          FALSE
        )
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
        'password_hash': password,
      },
    );

    final row = result.first.toColumnMap();

    return UserModel(
      id: row['id_user'] as int,
      roleId: row['role_id'] as int,
      fullName: row['full_name'] as String,
      phone: row['phone'] as String,
      email: row['email'] as String?,
      isBlocked: row['is_blocked'] as bool? ?? false,
      registeredAt: row['registered_at'] as DateTime?,
    );
  }

  Future<String> forgotPassword({
    required String email,
  }) async {
    final conn = await _postgresService.connection;
    final emailNorm = email.trim().toLowerCase();

    final result = await conn.execute(
      Sql.named(r'''
        SELECT id_user
        FROM users
        WHERE LOWER(TRIM(email)) = @email
        LIMIT 1
      '''),
      parameters: {
        'email': emailNorm,
      },
    );

    if (result.isEmpty) {
      throw Exception('Пользователь не найден');
    }

    final userId = result.first.toColumnMap()['id_user'] as int;
    final code = _generateResetCode();

    await conn.execute(
      Sql.named(r'''
        UPDATE verification_codes
        SET is_used = TRUE,
            used_at = NOW()
        WHERE user_id = @user_id
          AND code_type = 'password_reset'
          AND is_used = FALSE
      '''),
      parameters: {
        'user_id': userId,
      },
    );

    await conn.execute(
      Sql.named(r'''
        INSERT INTO verification_codes (
          user_id,
          code_type,
          code,
          expires_at,
          is_used
        )
        VALUES (
          @user_id,
          'password_reset',
          @code,
          NOW() + INTERVAL '15 minutes',
          FALSE
        )
      '''),
      parameters: {
        'user_id': userId,
        'code': code,
      },
    );

    return code;
  }

  Future<void> resetPassword({
    required String code,
    required String newPassword,
  }) async {
    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        SELECT id_code, user_id
        FROM verification_codes
        WHERE code = @code
          AND code_type = 'password_reset'
          AND is_used = FALSE
          AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 1
      '''),
      parameters: {
        'code': code,
      },
    );

    if (result.isEmpty) {
      throw Exception('Код недействителен или истек');
    }

    final row = result.first.toColumnMap();
    final codeId = row['id_code'] as int;
    final userId = row['user_id'] as int;

    await conn.execute(
      Sql.named(r'''
        UPDATE users
        SET password_hash = @password
        WHERE id_user = @user_id
      '''),
      parameters: {
        'password': newPassword,
        'user_id': userId,
      },
    );

    await conn.execute(
      Sql.named(r'''
        UPDATE verification_codes
        SET is_used = TRUE,
            used_at = NOW()
        WHERE id_code = @id_code
      '''),
      parameters: {
        'id_code': codeId,
      },
    );
  }

  Future<UserModel> getProfile() async {
    final userId = await _sessionService.getUserId();
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

    final row = result.first.toColumnMap();

    return UserModel(
      id: row['id_user'] as int,
      roleId: row['role_id'] as int,
      fullName: row['full_name'] as String,
      phone: row['phone'] as String,
      email: row['email'] as String?,
      isBlocked: row['is_blocked'] as bool? ?? false,
      registeredAt: row['registered_at'] as DateTime?,
    );
  }

  Future<void> logout() async {
    await _sessionService.clearSession();
  }

  String _generateResetCode() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(12, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _mapRole(int roleId) {
    switch (roleId) {
      case 1:
        return 'Пользователь';
      case 2:
        return 'Менеджер';
      case 3:
        return 'Администратор';
      default:
        return 'Пользователь';
    }
  }
}