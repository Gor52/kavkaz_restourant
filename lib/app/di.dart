import 'package:flutter/foundation.dart';

import '../core/services/local_storage_service.dart';
import '../core/services/session_service.dart';
import '../data/repositories/api_admin_repository.dart';
import '../data/repositories/api_auth_repository.dart';
import '../data/repositories/api_booking_repository.dart';
import '../data/repositories/api_cart_repository.dart';
import '../data/repositories/api_menu_repository.dart';
import '../data/repositories/api_notification_repository.dart';
import '../data/repositories/api_order_repository.dart';
import '../data/repositories/api_profile_repository.dart';
import '../data/repositories/api_review_repository.dart';
import '../data/repositories/api_support_repository.dart';
import '../data/sources/remote/api_service.dart';

class AppDi {
  AppDi._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://refutable-word-crewless.ngrok-free.dev',
  );

  static const bool _androidApiEmulator = bool.fromEnvironment(
    'ANDROID_API_EMULATOR',
    defaultValue: false,
  );

  static const bool _androidApiUsb = bool.fromEnvironment(
    'ANDROID_API_USB',
    defaultValue: true,
  );

  static String _resolveBaseUrl() {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        _androidApiUsb) {
      return 'http://127.0.0.1:3001';
    }

    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:3001';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (_androidApiEmulator) {
          return 'http://10.0.2.2:3001';
        }
        return 'http://127.0.0.1:3001';
      default:
        return 'http://localhost:3001';
    }
  }

  static final LocalStorageService localStorageService = LocalStorageService();
  static final SessionService sessionService =
      SessionService(localStorageService);

  static final ApiService apiService = ApiService(
    baseUrl: _resolveBaseUrl(),
    sessionService: sessionService,
  );

  static final ApiAuthRepository authRepository =
      ApiAuthRepository(apiService, sessionService);

  static final ApiMenuRepository menuRepository =
      ApiMenuRepository(apiService);

  static final ApiCartRepository cartRepository =
      ApiCartRepository(apiService);

  static final ApiOrderRepository orderRepository =
      ApiOrderRepository(apiService);

  static final ApiBookingRepository bookingRepository =
      ApiBookingRepository(apiService);

  static final ApiProfileRepository profileRepository =
      ApiProfileRepository(apiService, sessionService);

  static final ApiReviewRepository reviewRepository =
      ApiReviewRepository(apiService);

  static final ApiNotificationRepository notificationRepository =
      ApiNotificationRepository(apiService);

  static final ApiAdminRepository adminRepository =
      ApiAdminRepository(apiService);

  static final ApiSupportRepository supportRepository =
      ApiSupportRepository(apiService);
}