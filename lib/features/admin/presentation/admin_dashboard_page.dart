import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/admin_stat_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/profile_list_tile.dart';
import '../../../shared/enums/user_role.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _activeOrders = 0;
  int _bookings = 0;
  int _users = 0;
  bool _loading = true;
  String? _error;
  UserRole _role = UserRole.guest;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roleTitle = await AppDi.sessionService.getRole();
      final s = await AppDi.adminRepository.getDashboardStats();
      if (!mounted) return;
      setState(() {
        _role = UserRole.fromTitle(roleTitle);
        _activeOrders = s.activeOrders;
        _bookings = s.bookings;
        _users = s.users;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(
          e,
          fallback: 'Не удалось загрузить статистику.',
        );
        _activeOrders = 0;
        _bookings = 0;
        _users = 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _role.isAdmin;
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadStats,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Статистика: $_error',
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            AdminStatCard(
              title: 'Активные заказы',
              value: '$_activeOrders',
              icon: Icons.shopping_bag_rounded,
            ),
            const SizedBox(height: 14),
            AdminStatCard(
              title: 'Бронирования',
              value: '$_bookings',
              icon: Icons.event_seat_rounded,
            ),
            const SizedBox(height: 14),
            AdminStatCard(
              title: 'Пользователи',
              value: '$_users',
              icon: Icons.people_alt_rounded,
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Разделы управления',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ProfileListTile(
            icon: Icons.restaurant_menu_rounded,
            title: 'Управление меню',
            onTap: isAdmin ? () => context.push('/admin/dishes') : null,
          ),
          const SizedBox(height: 10),
          ProfileListTile(
            icon: Icons.category_rounded,
            title: 'Категории',
            onTap: isAdmin ? () => context.push('/admin/categories') : null,
          ),
          const SizedBox(height: 10),
          ProfileListTile(
            icon: Icons.receipt_long_rounded,
            title: 'Заказы',
            onTap: () => context.push('/admin/orders'),
          ),
          const SizedBox(height: 10),
          ProfileListTile(
            icon: Icons.people_rounded,
            title: 'Пользователи',
            onTap: () => context.push('/admin/users'),
          ),
          const SizedBox(height: 10),
          ProfileListTile(
            icon: Icons.event_note_rounded,
            title: 'Бронирования',
            onTap: () => context.push('/admin/bookings'),
          ),
          const SizedBox(height: 10),
          ProfileListTile(
            icon: Icons.file_upload_rounded,
            title: 'Импорт данных',
            onTap: isAdmin ? () => context.push('/admin/import') : null,
          ),
          const SizedBox(height: 10),
          ProfileListTile(
            icon: Icons.file_download_rounded,
            title: 'Экспорт данных',
            onTap: isAdmin ? () => context.push('/admin/export') : null,
          ),
        ],
      ),
    );
  }
}
