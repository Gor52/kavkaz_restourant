import 'package:dio/dio.dart';

import '../../core/services/session_service.dart';
import '../models/user_model.dart';
import '../sources/remote/api_service.dart';

class ApiAuthRepository {
  final ApiService _apiService;
  final SessionService _sessionService;

  ApiAuthRepository(this._apiService, this._sessionService);

  Future<UserModel> login({
    required String login,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final response = await _postLogin(
        login: login,
        password: password,
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Не удалось войти. Проверьте логин и пароль.');
      }

      final data = response.data!;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['access_token'] as String;

      await _sessionService.saveSession(
        accessToken: token,
        userId: user.id,
        role: _mapRole(user.roleId),
        persistSession: true,
      );
      await _sessionService.setRememberMe(rememberMe);
      await _sessionService.setRememberedLogin(rememberMe ? login : null);

      return user;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Таймаут: сервер не ответил за 10 с. Проверьте: backend запущен, '
          'для USB выполнен `adb reverse tcp:3001 tcp:3001`, '
          'для эмулятора — dart-define ANDROID_API_EMULATOR, '
          'для Wi‑Fi — API_BASE_URL с IP ПК; файрвол пропускает порт.',
        );
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Нет соединения с API (${e.message}). Проверьте адрес, порт и сеть.',
        );
      }
      if (e.response?.statusCode == 401) {
        final raw = _apiErrorMessage(e.response?.data);
        throw Exception(_loginErrorRu(raw) ?? 'Неверный логин или пароль.');
      }
      if (e.response?.statusCode == 403) {
        final raw = _apiErrorMessage(e.response?.data);
        throw Exception(_loginErrorRu(raw) ?? 'Доступ запрещён.');
      }
      if (e.response?.statusCode == 404) {
        final path = e.requestOptions.path;
        throw Exception(
          'Ошибка входа: эндпоинт "$path" не найден (404). Проверьте путь API и backend.',
        );
      }
      rethrow;
    }
  }

  static String? _apiErrorMessage(dynamic data) {
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    return null;
  }

  static String? _loginErrorRu(String? english) {
    if (english == null) return null;
    switch (english) {
      case 'Invalid credentials':
        return 'Неверный логин или пароль.';
      case 'Account is blocked':
        return 'Аккаунт заблокирован.';
      default:
        return english;
    }
  }

  Future<Response<Map<String, dynamic>>> _postLogin({
    required String login,
    required String password,
  }) async {
    final paths = [
      '/auth/login',
      '/login',
      '/api/auth/login',
      '/api/login',
    ];

    DioException? lastException;

    for (final path in paths) {
      try {
        return await _apiService.post<Map<String, dynamic>>(
          path,
          data: {
            'login': login,
            'password': password,
          },
        );
      } on DioException catch (e) {
        lastException = e;
        if (e.response?.statusCode == 404) {
          continue;
        }
        rethrow;
      }
    }

    if (lastException != null) {
      throw lastException;
    }

    throw Exception('Не удалось выполнить вход.');
  }

  Future<void> requestLoginCode({required String email}) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/auth/request-login-code',
      data: {'login': email.trim().toLowerCase()},
      options: Options(
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Не удалось отправить код.');
    }
  }

  Future<UserModel> loginWithCode({
    required String email,
    required String code,
    bool rememberMe = false,
  }) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/auth/login-with-code',
        data: {
          'login': email.trim().toLowerCase(),
          'code': code.trim(),
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Не удалось войти по коду.');
      }

      final data = response.data!;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['access_token'] as String;

      await _sessionService.saveSession(
        accessToken: token,
        userId: user.id,
        role: _mapRole(user.roleId),
        persistSession: true,
      );
      await _sessionService.setRememberMe(rememberMe);
      await _sessionService.setRememberedLogin(rememberMe ? email.trim() : null);

      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
        final raw = _apiErrorMessage(e.response?.data);
        throw Exception(raw ?? 'Неверный или просроченный код.');
      }
      rethrow;
    }
  }

  Future<UserModel> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode != 201 || response.data == null) {
      throw Exception('Не удалось зарегистрироваться.');
    }

    return UserModel.fromJson(response.data!['user'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      data: {
        'login': email.trim().toLowerCase(),
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 15),
      ),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw Exception('Не удалось отправить код восстановления.');
    }

    return Map<String, dynamic>.from(response.data!);
  }

  Future<void> resetPassword({
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/auth/reset-password',
        data: {
          'code': code,
          'password': newPassword,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Не удалось сбросить пароль.');
      }
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map && raw['error'] != null) {
        throw Exception(raw['error'].toString());
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await _sessionService.clearSession();
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
