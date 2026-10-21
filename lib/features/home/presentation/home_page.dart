import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/auth_required_navigation.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/dish_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/dish_model.dart';
import '../../../shared/enums/user_role.dart';
import '../../menu/presentation/dish_details_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onOpenMenu, this.hideCustomerActions});

  final VoidCallback? onOpenMenu;
  final bool? hideCustomerActions;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CategoryModel> _categories = [];
  List<DishModel> _popularDishes = [];

  bool _isLoading = true;
  String? _error;
  int? _selectedCategoryId;
  UserRole _role = UserRole.guest;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final roleTitle = await AppDi.sessionService.getRole();
    if (!mounted) return;
    setState(() => _role = UserRole.fromTitle(roleTitle));
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await AppDi.menuRepository.getCategories();
      final dishes = await AppDi.menuRepository.getDishes(
        onlyAvailable: true,
      );

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
        _popularDishes = dishes.take(6).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(
          e,
          fallback: 'Не удалось загрузить данные главной страницы.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<DishModel> get _filteredDishes {
    if (_selectedCategoryId == null) return _popularDishes;
    return _popularDishes
        .where((dish) => dish.categoryId == _selectedCategoryId)
        .toList();
  }

  Future<bool> _requireAuth() async {
    final isAuthorized = await AppDi.sessionService.isAuthorized();
    if (isAuthorized) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Для этого действия требуется вход')),
    );
    context.push(buildAuthRequiredLocation(from: '/home'));
    return false;
  }

  void _openMenu() {
    if (widget.onOpenMenu != null) {
      widget.onOpenMenu!();
    } else {
      context.push('/menu');
    }
  }

  bool get _hideCustomerActions =>
      widget.hideCustomerActions ?? _role.isStaff;

  Future<bool> _ensureCustomerRole(String actionLabel) async {
    if (!await _requireAuth()) return false;
    final role = UserRole.fromTitle(await AppDi.sessionService.getRole());
    if (role.isStaff) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Для менеджера и администратора $actionLabel недоступно',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: _isLoading
          ? const LoadingView(message: 'Загружаем меню...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadHomeData,
                )
              : RefreshIndicator(
                  onRefresh: _loadHomeData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    children: [
                      _HomeHeader(
                        onNotificationsTap: () => context.push('/notifications'),
                      ),
                      const SizedBox(height: 14),
                      _HomePromoCard(onMenuTap: _openMenu),
                      const SizedBox(height: 14),
                      _QuickActionsRow(
                        showCustomerActions: !_hideCustomerActions,
                        onDeliveryTap: _openMenu,
                        onBookingTap: () async {
                          if (!await _ensureCustomerRole('бронирование')) return;
                          if (!mounted) return;
                          context.push('/booking');
                        },
                        onCartTap: () async {
                          if (!await _ensureCustomerRole('корзина')) return;
                          if (!mounted) return;
                          context.push('/cart');
                        },
                      ),
                      const SizedBox(height: 20),
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _openMenu,
                        child: IgnorePointer(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Поиск блюд',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SectionTitle(
                        title: 'Категории',
                        actionText: _categories.isEmpty ? null : 'Все',
                      ),
                      const SizedBox(height: 12),
                      if (_categories.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'Категории пока не добавлены',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      else
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, index) {
                              final category = _categories[index];
                              return CategoryChip(
                                title: category.title,
                                isSelected: category.id == _selectedCategoryId,
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryId = category.id;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      SectionTitle(
                        title: 'Популярные блюда',
                        actionText: 'Смотреть все',
                        onActionTap: _openMenu,
                      ),
                      const SizedBox(height: 12),
                      if (_filteredDishes.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'Нет доступных блюд',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      else
                        ListView.separated(
                          itemCount: _filteredDishes.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (_, index) {
                            final dish = _filteredDishes[index];
                            return DishCard(
                              dish: dish,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DishDetailsPage(dish: dish),
                                  ),
                                );
                              },
                              onAddToCart: () async {
                                if (!await _ensureCustomerRole('добавление в корзину')) return;
                                try {
                                  await AppDi.cartRepository.addToCart(
                                    dishId: dish.id,
                                    quantity: 1,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${dish.title} добавлено в корзину',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  if (e.toString().contains('Требуется авторизация')) {
                                    context.go(buildAuthRequiredLocation(from: '/home'));
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        humanizeError(
                                          e,
                                          fallback: 'Не удалось добавить блюдо в корзину.',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onNotificationsTap});

  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.accent.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: const Icon(
            Icons.restaurant_menu_rounded,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Добро пожаловать',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
              ),
              Text(
                'Кавказская кухня',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.surface,
          elevation: 1,
          shadowColor: AppColors.cardShadow,
          surfaceTintColor: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: IconButton(
            onPressed: onNotificationsTap,
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.icon,
          ),
        ),
      ],
    );
  }
}

class _HomePromoCard extends StatelessWidget {
  const _HomePromoCard({required this.onMenuTap});

  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.45, 1.0],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Теплые вкусы\nКавказа',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.08,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Хинкали, шашлык, хачапури\nс доставкой и самовывозом',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 2,
                    shadowColor: Colors.black26,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: onMenuTap,
                  icon: const Icon(Icons.local_dining_rounded),
                  label: const Text('Открыть меню'),
                ),
              ],
            ),
          ),
          Positioned(
            right: -30,
            top: -40,
            child: IgnorePointer(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -50,
            child: IgnorePointer(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.showCustomerActions,
    required this.onDeliveryTap,
    required this.onBookingTap,
    required this.onCartTap,
  });

  final bool showCustomerActions;
  final VoidCallback onDeliveryTap;
  final VoidCallback onBookingTap;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.delivery_dining_rounded,
            title: 'Доставка',
            subtitle: '30-45 мин',
            onTap: onDeliveryTap,
          ),
        ),
        if (showCustomerActions) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.event_seat_rounded,
              title: 'Бронь',
              subtitle: 'Выберите стол',
              onTap: onBookingTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.shopping_bag_outlined,
              title: 'Корзина',
              subtitle: 'К оформлению',
              onTap: onCartTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.cardShadow,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}