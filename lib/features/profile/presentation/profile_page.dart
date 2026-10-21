import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../app/di.dart';
import '../../../app/auth_required_navigation.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/profile_list_tile.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/user_model.dart';
import '../../../features/profile/presentation/edit_profile_page.dart';
import '../../../features/profile/presentation/my_reviews_page.dart';
import '../../../shared/enums/user_role.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserModel? _user;
  UserRole _role = UserRole.guest;
  bool _isLoading = true;
  String? _error;
  int _bonusBalance = 0;
  List<AddressModel> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await AppDi.profileRepository.getProfile();
      final mappedRole = _mapRole(user.roleId);
      final bonusBalance = mappedRole.isStaff
          ? 0
          : await AppDi.profileRepository.getBonusBalance();
      final addresses =
          !mappedRole.isStaff
              ? await AppDi.profileRepository.getAddresses()
              : <AddressModel>[];

      if (!mounted) return;

      setState(() {
        _user = user;
        _role = mappedRole;
        _bonusBalance = bonusBalance < 0 ? 0 : bonusBalance;
        _addresses = addresses;
      });
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        await AppDi.sessionService.clearSession();
        if (!mounted) return;
        context.go(buildAuthRequiredLocation(from: '/profile'));
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить профиль.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  UserRole _mapRole(int roleId) {
    switch (roleId) {
      case 1:
        return UserRole.user;
      case 2:
        return UserRole.manager;
      case 3:
        return UserRole.admin;
      default:
        return UserRole.guest;
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.user:
        return 'Пользователь';
      case UserRole.manager:
        return 'Менеджер';
      case UserRole.admin:
        return 'Администратор';
      case UserRole.guest:
        return 'Гость';
    }
  }

  Future<void> _logout() async {
    await AppDi.authRepository.logout();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _deleteAccount() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Удаление аккаунта'),
              content: const Text(
                'Ваш аккаунт будет деактивирован. Продолжить?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Удалить',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      await AppDi.profileRepository.deleteAccount();

      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeError(e, fallback: 'Не удалось удалить аккаунт.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final isAdminAreaVisible =
        _role == UserRole.admin || _role == UserRole.manager;

    return AppScaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body:
          _isLoading
              ? const LoadingView(message: 'Загружаем профиль...')
              : _error != null
              ? ErrorState(
                title: 'Ошибка загрузки',
                subtitle: _error!,
                onRetry: _loadProfile,
              )
              : RefreshIndicator(
                onRefresh: _loadProfile,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 34,
                            backgroundColor: AppColors.card,
                            child: Icon(
                              Icons.person_rounded,
                              size: 34,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.fullName ?? 'Пользователь',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.phone ?? '-',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (user?.email != null &&
                                    user!.email!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    user.email!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _roleLabel(_role),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!_role.isStaff) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: const Icon(
                                Icons.stars_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Текущий бонусный баланс: $_bonusBalance',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Адреса доставки',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/addresses'),
                            child: const Text('Управление'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_addresses.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'Нет сохранённых адресов. Добавьте адрес в разделе управления.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      else
                        ..._addresses.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => context.push('/addresses'),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.location_on_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              a.addressText,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (a.isDefault)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'По умолчанию',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (a.comment != null &&
                                          a.comment!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          a.comment!.trim(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 22),
                    const Text(
                      'Аккаунт',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ProfileListTile(
                      icon: Icons.edit_rounded,
                      title: 'Редактировать профиль',
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditProfilePage(initialUser: user),
                          ),
                        );
                        if (!mounted) return;
                        await _loadProfile();
                      },
                    ),
                    const SizedBox(height: 10),
                    ProfileListTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Сменить пароль',
                      onTap: () => context.push('/change-password'),
                    ),
                    const SizedBox(height: 10),
                    if (!_role.isStaff) ...[
                      ProfileListTile(
                        icon: Icons.location_on_rounded,
                        title: 'Адреса доставки',
                        onTap: () => context.push('/addresses'),
                      ),
                      const SizedBox(height: 10),
                      ProfileListTile(
                        icon: Icons.history_rounded,
                        title: 'История заказов',
                        onTap: () => context.push('/orders-history'),
                      ),
                      const SizedBox(height: 10),
                      ProfileListTile(
                        icon: Icons.stars_rounded,
                        title: 'Бонусы',
                        subtitle: 'Текущий баланс и операции',
                        onTap: () => context.push('/bonuses'),
                      ),
                      const SizedBox(height: 10),
                      ProfileListTile(
                        icon: Icons.rate_review_rounded,
                        title: 'Мои отзывы',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MyReviewsPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    ProfileListTile(
                      icon: Icons.notifications_rounded,
                      title: 'Уведомления',
                      onTap: () => context.push('/notifications'),
                    ),
                    const SizedBox(height: 10),
                    ProfileListTile(
                      icon: Icons.support_agent_rounded,
                      title:
                          _role.isStaff
                              ? 'Обращения поддержки'
                              : 'Чат поддержки',
                      subtitle:
                          _role.isStaff
                              ? 'Консультация пользователей'
                              : 'Связь с менеджером или администратором',
                      onTap: () => context.push('/support'),
                    ),
                    if (isAdminAreaVisible) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Управление',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ProfileListTile(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Административная панель',
                        onTap: () => context.push('/admin'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Выйти'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Удалить учетную запись'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
