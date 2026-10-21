import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_bookings_page.dart';
import '../features/admin/presentation/admin_categories_page.dart';
import '../features/admin/presentation/admin_category_form_page.dart';
import '../features/admin/presentation/admin_dashboard_page.dart';
import '../features/admin/presentation/admin_dish_form_page.dart';
import '../features/admin/presentation/admin_dishes_page.dart';
import '../features/admin/presentation/admin_export_page.dart';
import '../features/admin/presentation/admin_import_page.dart';
import '../features/admin/presentation/admin_order_details_page.dart';
import '../features/admin/presentation/admin_orders_page.dart';
import '../features/admin/presentation/admin_user_bonus_history_page.dart';
import '../features/admin/presentation/admin_user_details_page.dart';
import '../features/admin/presentation/admin_users_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/auth_required_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/set_password_page.dart';
import '../features/booking/presentation/booking_page.dart';
import '../features/cart/presentation/cart_page.dart';
import '../features/cart/presentation/checkout_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/menu/presentation/menu_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/orders/presentation/order_details_page.dart';
import '../features/orders/presentation/order_tracking_page.dart';
import '../features/orders/presentation/orders_history_page.dart';
import '../features/profile/presentation/addresses_page.dart';
import '../features/profile/presentation/bonuses_page.dart';
import '../features/profile/presentation/change_password_page.dart';
import '../features/profile/presentation/notifications_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/shell/presentation/main_shell_page.dart';
import '../features/splash/presentation/splash_page.dart';
import '../features/support/presentation/support_chat_page.dart';
import '../features/support/presentation/support_conversations_page.dart';
import '../data/models/category_model.dart';
import '../data/models/dish_model.dart';
import '../data/models/order_model.dart';
import '../data/models/user_model.dart';
import '../shared/enums/user_role.dart';
import 'auth_required_navigation.dart';
import 'di.dart';
import 'navigation_service.dart';

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  overridePlatformDefaultLocation: true,
  debugLogDiagnostics: true,
  redirect: (context, state) async {
    const publicPaths = {
      '/splash',
      '/onboarding',
      '/shell',
      '/home',
      '/menu',
      '/login',
      '/register',
      '/forgot-password',
      '/set-password',
    };

    const protectedPaths = {
      '/cart',
      '/checkout',
      '/booking',
      '/profile',
      '/orders-history',
      '/order-details',
      '/order-tracking',
      '/addresses',
      '/bonuses',
      '/notifications',
      '/change-password',
      '/support',
      '/support/chat',
      '/admin',
      '/admin/dishes',
      '/admin/dishes/form',
      '/admin/categories',
      '/admin/categories/form',
      '/admin/orders',
      '/admin/orders/details',
      '/admin/users',
      '/admin/users/bonus-history',
      '/admin/users/details',
      '/admin/bookings',
      '/admin/import',
      '/admin/export',
    };

    final location = state.uri.path;
    final isAuthorized = await AppDi.sessionService.isAuthorized();

    if (location == '/auth-required') {
      if (isAuthorized) {
        return '/shell';
      }
      final ticket = state.uri.queryParameters['ticket'];
      if (!isValidAuthRequiredTicket(ticket)) {
        return '/shell';
      }
      return null;
    }

    if (publicPaths.contains(location)) {
      return null;
    }

    if (!protectedPaths.contains(location)) {
      return null;
    }

    if (isAuthorized) {
      const customerOnlyPaths = {'/cart', '/checkout', '/booking'};
      if (customerOnlyPaths.contains(location)) {
        final role = UserRole.fromTitle(await AppDi.sessionService.getRole());
        if (role.isStaff) {
          return '/shell';
        }
      }
      return null;
    }

    return buildAuthRequiredLocation(from: location);
  },
  errorBuilder:
      (context, state) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 12),
                const Text(
                  'Ошибка навигации',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  state.error?.toString() ?? 'Неизвестная ошибка',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/set-password',
      builder: (context, state) => const SetPasswordPage(),
    ),
    GoRoute(
      path: '/auth-required',
      builder: (context, state) => const AuthRequiredPage(),
    ),
    GoRoute(path: '/shell', builder: (context, state) => const MainShellPage()),
    GoRoute(path: '/home', builder: (context, state) => const HomePage()),
    GoRoute(path: '/menu', builder: (context, state) => const MenuPage()),
    GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutPage(),
    ),
    GoRoute(path: '/booking', builder: (context, state) => const BookingPage()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
    GoRoute(
      path: '/orders-history',
      builder: (context, state) => const OrdersHistoryPage(),
    ),
    GoRoute(
      path: '/order-details',
      builder: (context, state) {
        final order = state.extra as OrderModel;
        return OrderDetailsPage(order: order);
      },
    ),
    GoRoute(
      path: '/order-tracking',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return OrderTrackingPage(
          orderId: extra['orderId'] as int,
          status: extra['status'] as String,
        );
      },
    ),
    GoRoute(
      path: '/addresses',
      builder: (context, state) => const AddressesPage(),
    ),
    GoRoute(path: '/bonuses', builder: (context, state) => const BonusesPage()),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/change-password',
      builder: (context, state) => const ChangePasswordPage(),
    ),
    GoRoute(
      path: '/support',
      builder: (context, state) => const SupportConversationsPage(),
    ),
    GoRoute(
      path: '/support/chat',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! int) {
          throw ArgumentError(
            'Для /support/chat требуется идентификатор диалога',
          );
        }
        return SupportChatPage(conversationId: extra);
      },
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardPage(),
    ),
    GoRoute(
      path: '/admin/dishes',
      builder: (context, state) => const AdminDishesPage(),
    ),
    GoRoute(
      path: '/admin/dishes/form',
      builder: (context, state) {
        final dish = state.extra is DishModel ? state.extra as DishModel : null;
        return AdminDishFormPage(initialDish: dish);
      },
    ),
    GoRoute(
      path: '/admin/categories',
      builder: (context, state) => const AdminCategoriesPage(),
    ),
    GoRoute(
      path: '/admin/categories/form',
      builder: (context, state) {
        final category =
            state.extra is CategoryModel ? state.extra as CategoryModel : null;
        return AdminCategoryFormPage(initialCategory: category);
      },
    ),
    GoRoute(
      path: '/admin/orders',
      builder: (context, state) => const AdminOrdersPage(),
    ),
    GoRoute(
      path: '/admin/orders/details',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is OrderModel) {
          return AdminOrderDetailsPage(orderId: extra.id, initialOrder: extra);
        }
        if (extra is int) {
          return AdminOrderDetailsPage(orderId: extra);
        }
        throw ArgumentError(
          'Для /admin/orders/details требуется OrderModel или id заказа',
        );
      },
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const AdminUsersPage(),
    ),
    GoRoute(
      path: '/admin/users/bonus-history',
      builder: (context, state) {
        final user = state.extra;
        if (user is! UserModel) {
          throw ArgumentError(
            'Для /admin/users/bonus-history требуется UserModel',
          );
        }
        return AdminUserBonusHistoryPage(user: user);
      },
    ),
    GoRoute(
      path: '/admin/users/details',
      builder: (context, state) => const AdminUserDetailsPage(),
    ),
    GoRoute(
      path: '/admin/bookings',
      builder: (context, state) => const AdminBookingsPage(),
    ),
    GoRoute(
      path: '/admin/import',
      builder: (context, state) => const AdminImportPage(),
    ),
    GoRoute(
      path: '/admin/export',
      builder: (context, state) => const AdminExportPage(),
    ),
  ],
);
