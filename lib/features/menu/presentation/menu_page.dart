import 'dart:async';
import 'dart:math' as math;

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
import '../../../data/models/category_model.dart';
import '../../../data/models/dish_model.dart';
import '../../../shared/enums/user_role.dart';
import 'dish_details_page.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final TextEditingController _searchController = TextEditingController();

  List<CategoryModel> _categories = [];
  List<DishModel> _dishes = [];

  bool _isLoading = true;
  String? _error;

  int? _selectedCategoryId;

  String? _sortKey;
  bool _onlyAvailable = true;
  bool _lightCaloriesOnly = false;

  RangeValues _priceRange = const RangeValues(0, 1);
  double _priceLimitMin = 0;
  double _priceLimitMax = 1;

  Timer? _searchDebounce;

  List<DishModel> get _visibleDishes {
    return _dishes.where((d) {
      if (d.price < _priceRange.start || d.price > _priceRange.end) {
        return false;
      }
      if (_lightCaloriesOnly) {
        final c = d.calories;
        if (c == null || c > 400) return false;
      }
      return true;
    }).toList();
  }

  bool get _hasActiveLocalFilters {
    const e = 0.01;
    final full = (_priceRange.start <= _priceLimitMin + e) &&
        (_priceRange.end >= _priceLimitMax - e);
    return _lightCaloriesOnly || !full;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 380), () {
      if (mounted) _loadDishes();
    });
  }

  bool _priceLimitsSeeded = false;

  void _syncPriceLimitsAfterLoad(List<DishModel> dishes) {
    const e = 0.01;
    final prevLimitMin = _priceLimitMin;
    final prevLimitMax = _priceLimitMax;

    if (dishes.isEmpty) {
      _priceLimitMin = 0;
      _priceLimitMax = 1;
      _priceRange = const RangeValues(0, 1);
      _priceLimitsSeeded = false;
      return;
    }
    final prices = dishes.map((e) => e.price).toList();
    var minP = prices.reduce(math.min);
    var maxP = prices.reduce(math.max);
    if (maxP <= minP) {
      minP = math.max(0, minP - 1);
      maxP = maxP + 1;
    }

    if (minP < prevLimitMin - e || maxP > prevLimitMax + e) {
      _priceLimitMin = minP;
      _priceLimitMax = maxP;
      _priceRange = RangeValues(minP, maxP);
      _priceLimitsSeeded = true;
      return;
    }

    final prevMin = prevLimitMin;
    final prevMax = prevLimitMax;
    _priceLimitMin = minP;
    _priceLimitMax = maxP;

    if (!_priceLimitsSeeded ||
        (prevMin == 0 && prevMax == 1) ||
        _priceRange.start < minP ||
        _priceRange.end > maxP) {
      _priceRange = RangeValues(minP, maxP);
    } else {
      final start = _priceRange.start.clamp(minP, maxP);
      var end = _priceRange.end.clamp(minP, maxP);
      if (end <= start) end = maxP;
      _priceRange = RangeValues(start, end);
    }
    _priceLimitsSeeded = true;
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await AppDi.menuRepository.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _selectedCategoryId = null;
      });

      await _loadDishes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить меню.');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDishes() async {
    try {
      final dishes = await AppDi.menuRepository.getDishes(
        categoryId: _selectedCategoryId,
        search: _searchController.text.trim(),
        sort: _sortKey,
        onlyAvailable: _onlyAvailable ? true : null,
      );

      if (!mounted) return;

      setState(() {
        _dishes = dishes;
        _syncPriceLimitsAfterLoad(dishes);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить блюда.');
        _isLoading = false;
      });
    }
  }

  Future<void> _reload() async {
    await _loadInitialData();
  }

  void _resetLocalFilters() {
    setState(() {
      _lightCaloriesOnly = false;
      if (_dishes.isNotEmpty) {
        _priceRange = RangeValues(_priceLimitMin, _priceLimitMax);
      }
    });
  }

  Future<void> _openFiltersSheet() async {
    var tempRange = _priceRange;
    var tempOnlyAvailable = _onlyAvailable;
    var tempLight = _lightCaloriesOnly;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 24,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Фильтры',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Цена, калорийность и наличие на витрине',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Text(
                              'Цена, ₽',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              '${tempRange.start.round()} — ${tempRange.end.round()}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        RangeSlider(
                          values: tempRange,
                          min: _priceLimitMin,
                          max: _priceLimitMax,
                          divisions: _priceLimitMax > _priceLimitMin
                              ? math.min(
                                  40,
                                  ((_priceLimitMax - _priceLimitMin) / 25)
                                      .round()
                                      .clamp(1, 40),
                                )
                              : null,
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.primary.withValues(alpha: 0.18),
                          onChanged: (v) {
                            setModal(() => tempRange = v);
                          },
                        ),
                        const Divider(height: 28),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Только в наличии',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Скрыть блюда, которые временно недоступны',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(alpha: 0.95),
                            ),
                          ),
                          value: tempOnlyAvailable,
                          onChanged: (v) => setModal(() => tempOnlyAvailable = v),
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Лёгкие блюда',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'До 400 ккал (если указано в карточке)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(alpha: 0.95),
                            ),
                          ),
                          value: tempLight,
                          onChanged: (v) => setModal(() => tempLight = v),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModal(() {
                                  tempRange = RangeValues(
                                    _priceLimitMin,
                                    _priceLimitMax,
                                  );
                                  tempOnlyAvailable = true;
                                  tempLight = false;
                                });
                              },
                              child: const Text('Сбросить'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () {
                                final needReload =
                                    tempOnlyAvailable != _onlyAvailable;
                                Navigator.of(context).pop();
                                setState(() {
                                  _priceRange = tempRange;
                                  _onlyAvailable = tempOnlyAvailable;
                                  _lightCaloriesOnly = tempLight;
                                });
                                if (needReload) {
                                  _loadDishes();
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 14,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('Применить'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _requireAuth() async {
    final isAuthorized = await AppDi.sessionService.isAuthorized();
    if (isAuthorized) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Для этого действия требуется вход')),
    );
    context.push(buildAuthRequiredLocation(from: '/menu'));
    return false;
  }

  Future<bool> _canAddToCart() async {
    if (!await _requireAuth()) return false;
    final role = UserRole.fromTitle(await AppDi.sessionService.getRole());
    if (role.isStaff) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Менеджер и администратор не могут добавлять блюда в корзину',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _pickSort(String? key) async {
    if (_sortKey == key) return;
    setState(() {
      _sortKey = key;
      _isLoading = true;
    });
    await _loadDishes();
  }

  @override
  Widget build(BuildContext context) {
    final canPopMenuRoute = ModalRoute.of(context)?.canPop ?? false;

    return AppScaffold(
      appBar: canPopMenuRoute
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: AppColors.textPrimary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Назад',
                onPressed: () => context.pop(),
              ),
            )
          : null,
      body: _isLoading
          ? const LoadingView(message: 'Загружаем блюда...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _reload,
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _MenuSearchCard(
                        controller: _searchController,
                        onClear: () {
                          _searchController.clear();
                          _loadDishes();
                        },
                        onFiltersTap: _openFiltersSheet,
                      ),
                      const SizedBox(height: 14),
                      _MenuSortStrip(
                        sortKey: _sortKey,
                        lightOnly: _lightCaloriesOnly,
                        onSort: _pickSort,
                        onLightToggle: () {
                          setState(() {
                            _lightCaloriesOnly = !_lightCaloriesOnly;
                          });
                        },
                      ),
                      if (_hasActiveLocalFilters) ...[
                        const SizedBox(height: 10),
                        _MenuActiveFiltersBanner(
                          priceLabel:
                              '${_priceRange.start.round()}–${_priceRange.end.round()} ₽',
                          lightOnly: _lightCaloriesOnly,
                          onReset: _resetLocalFilters,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_categories.isNotEmpty) ...[
                        Row(
                          children: [
                            Text(
                              'Категории',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, index) {
                              if (index == 0) {
                                return CategoryChip(
                                  title: 'Все',
                                  isSelected: _selectedCategoryId == null,
                                  onTap: () async {
                                    setState(() {
                                      _selectedCategoryId = null;
                                      _isLoading = true;
                                    });
                                    await _loadDishes();
                                  },
                                );
                              }
                              final category = _categories[index - 1];
                              return CategoryChip(
                                title: category.title,
                                isSelected: category.id == _selectedCategoryId,
                                onTap: () async {
                                  setState(() {
                                    _selectedCategoryId = category.id;
                                    _isLoading = true;
                                  });
                                  await _loadDishes();
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Row(
                        children: [
                          Text(
                            'Блюда',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const Spacer(),
                          Text(
                            '${_visibleDishes.length} из ${_dishes.length}',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_visibleDishes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 52,
                                  color: AppColors.textHint.withValues(alpha: 0.65),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Ничего не найдено',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Измените поиск или фильтры',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_visibleDishes.length, (index) {
                          final dish = _visibleDishes[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _visibleDishes.length - 1 ? 0 : 14,
                            ),
                            child: DishCard(
                              dish: dish,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DishDetailsPage(dish: dish),
                                  ),
                                );
                              },
                              onAddToCart: () async {
                                if (!await _canAddToCart()) return;
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
                                  if (e.toString().contains(
                                        'Требуется авторизация',
                                      )) {
                                    context.go(
                                      buildAuthRequiredLocation(from: '/menu'),
                                    );
                                  }
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        humanizeError(
                                          e,
                                          fallback:
                                              'Не удалось добавить блюдо в корзину.',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _MenuSearchCard extends StatelessWidget {
  const _MenuSearchCard({
    required this.controller,
    required this.onClear,
    required this.onFiltersTap,
  });

  final TextEditingController controller;
  final VoidCallback onClear;
  final VoidCallback onFiltersTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.card,
            AppColors.accentSoft.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          const BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return TextField(
                  controller: controller,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Название или ингредиент…',
                    hintStyle: TextStyle(
                      color: AppColors.textHint.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.primary.withValues(alpha: 0.85),
                    ),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: onClear,
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.textHint.withValues(alpha: 0.9),
                            ),
                          ),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          Material(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onFiltersTap,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSortStrip extends StatelessWidget {
  const _MenuSortStrip({
    required this.sortKey,
    required this.lightOnly,
    required this.onSort,
    required this.onLightToggle,
  });

  final String? sortKey;
  final bool lightOnly;
  final Future<void> Function(String? key) onSort;
  final VoidCallback onLightToggle;

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required String label,
      required IconData icon,
      String? sortValue,
    }) {
      final selected = sortKey == sortValue;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSort(sortValue),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: selected
                    ? LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primaryDark,
                        ],
                      )
                    : null,
                color: selected ? null : AppColors.surface,
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : AppColors.border.withValues(alpha: 0.9),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сортировка',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(
                label: 'Новые',
                icon: Icons.auto_awesome_rounded,
                sortValue: null,
              ),
              chip(
                label: 'Дешевле',
                icon: Icons.south_rounded,
                sortValue: 'price_asc',
              ),
              chip(
                label: 'Дороже',
                icon: Icons.north_rounded,
                sortValue: 'price_desc',
              ),
              chip(
                label: 'А–Я',
                icon: Icons.sort_by_alpha_rounded,
                sortValue: 'title',
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onLightToggle,
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: lightOnly
                            ? LinearGradient(
                                colors: [
                                  AppColors.accent.withValues(alpha: 0.95),
                                  AppColors.primaryLight.withValues(alpha: 0.9),
                                ],
                              )
                            : null,
                        color: lightOnly ? null : AppColors.surface,
                        border: Border.all(
                          color: lightOnly
                              ? Colors.transparent
                              : AppColors.border.withValues(alpha: 0.9),
                        ),
                        boxShadow: lightOnly
                            ? [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            size: 18,
                            color: lightOnly
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Лёгкие',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: lightOnly
                                  ? AppColors.textPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuActiveFiltersBanner extends StatelessWidget {
  const _MenuActiveFiltersBanner({
    required this.priceLabel,
    required this.lightOnly,
    required this.onReset,
  });

  final String priceLabel;
  final bool lightOnly;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[priceLabel];
    if (lightOnly) parts.add('до 400 ккал');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_rounded,
            size: 20,
            color: AppColors.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onReset,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }
}
